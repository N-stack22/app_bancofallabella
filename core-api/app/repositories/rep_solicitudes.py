import json
import uuid
from datetime import date, datetime, timedelta, timezone
from sqlalchemy import text
from sqlalchemy.orm import Session


def _upsert_cliente(db: Session, d: dict) -> str:
    """Devuelve el cliente_id; lo crea si no existe (por numero_documento)."""
    row = db.execute(
        text("SELECT id FROM clientes WHERE numero_documento = :doc"),
        {"doc": d["numero_documento"]},
    ).first()
    if row:
        return str(row[0])
    cid = str(uuid.uuid4())
    db.execute(
        text(
            """INSERT INTO clientes (id, numero_documento, nombres, apellidos,
                   telefono, tipo_negocio, nombre_negocio, es_prospecto)
               VALUES (:id,:doc,:nom,:ape,:tel,:tn,:nn,TRUE)"""
        ),
        {
            "id": cid,
            "doc": d["numero_documento"],
            "nom": d.get("nombres", ""),
            "ape": d.get("apellidos", ""),
            "tel": d.get("telefono"),
            "tn": d.get("tipo_negocio"),
            "nn": d.get("nombre_negocio"),
        },
    )
    return cid


def crear(db: Session, asesor_id: str, agencia_id: str | None, d: dict) -> dict:
    """Crea una solicitud de credito (M5 / HU-17)."""
    cliente_id = _upsert_cliente(db, d)
    sol_id = str(uuid.uuid4())
    expediente = "EXP-" + sol_id.replace("-", "")[:8].upper()
    db.execute(
        text(
            """INSERT INTO solicitudes_credito
                 (id, numero_expediente, asesor_id, cliente_id, agencia_id,
                  canal, tipo_negocio, nombre_negocio, ingresos_estimados,
                  monto_solicitado, plazo_meses, moneda, tipo_cuota, garantia,
                  destino_credito, cuota_estimada, tea_referencial,
                  firma_cliente_base64, estado)
               VALUES
                 (:id,:exp,:asesor,:cli,:ag,'asesor',:tn,:nn,:ing,
                  :monto,:plazo,:mon,:tc,:gar,:dest,:cuota,:tea,:firma,'enviado')"""
        ),
        {
            "id": sol_id,
            "exp": expediente,
            "asesor": asesor_id,
            "cli": cliente_id,
            "ag": agencia_id,
            "tn": d.get("tipo_negocio"),
            "nn": d.get("nombre_negocio"),
            "ing": d.get("ingresos_estimados"),
            "monto": d["monto_solicitado"],
            "plazo": d["plazo_meses"],
            "mon": d.get("moneda", "PEN"),
            "tc": d.get("tipo_cuota", "mensual"),
            "gar": d.get("garantia", "sin_garantia"),
            "dest": d.get("destino_credito"),
            "cuota": d.get("cuota_estimada"),
            "tea": d.get("tea_referencial"),
            "firma": d.get("firma_cliente_base64"),
        },
    )

    # Encola para promover al nucleo bancario (puente sync_outbox -> core).
    payload = {
        "numero_documento": d["numero_documento"],
        "nombres": d.get("nombres", ""),
        "apellidos": d.get("apellidos", ""),
        "monto_solicitado": float(d["monto_solicitado"]),
        "plazo_meses": int(d["plazo_meses"]),
        "numero_expediente": expediente,
    }
    db.execute(
        text(
            """INSERT INTO sync_outbox (id, entidad, entidad_id, operacion, payload, estado)
               VALUES (:id, 'solicitudes_credito', :eid, 'create', CAST(:payload AS jsonb), 'pendiente')"""
        ),
        {
            "id": str(uuid.uuid4()),
            "eid": sol_id,
            "payload": json.dumps(payload),
        },
    )
    db.commit()
    return {"id": sol_id, "numero_expediente": expediente, "estado": "enviado"}


def crear_desde_cliente(db: Session, d: dict) -> dict:
    """Crea la solicitud del cliente y la deja en la cartera del asesor."""
    asesor = db.execute(
        text(
            """SELECT id, agencia_id
               FROM asesores
               WHERE activo = TRUE
                 AND lower(replace(COALESCE(perfil, ''), '-', '_')) IN (
                   'asesor', 'operador', 'asesor_negocios',
                   'asesor de negocios', 'asesor_de_negocios'
                 )
               ORDER BY created_at NULLS LAST
               LIMIT 1"""
        )
    ).mappings().first()
    if asesor is None:
        raise ValueError("No existe un asesor activo para asignar la solicitud")

    cliente_id = _upsert_cliente(db, d)
    sol_id = str(uuid.uuid4())
    expediente = "EXP-" + sol_id.replace("-", "")[:8].upper()
    prioridad = _prioridad(d.get("monto_solicitado") or 0)
    score_prioridad = _score_prioridad(d.get("monto_solicitado") or 0)
    db.execute(
        text(
            """INSERT INTO solicitudes_credito
                 (id, numero_expediente, asesor_id, cliente_id, agencia_id,
                  canal, tipo_negocio, nombre_negocio, ingresos_estimados,
                  monto_solicitado, plazo_meses, moneda, tipo_cuota, garantia,
                  destino_credito, cuota_estimada, tea_referencial,
                  firma_cliente_base64, estado)
               VALUES
                 (:id,:exp,:asesor,:cli,:ag,'cliente',:tn,:nn,:ing,
                  :monto,:plazo,:mon,:tc,:gar,:dest,:cuota,:tea,:firma,'enviado')"""
        ),
        {
            "id": sol_id,
            "exp": expediente,
            "asesor": asesor["id"],
            "cli": cliente_id,
            "ag": asesor["agencia_id"],
            "tn": d.get("tipo_negocio"),
            "nn": d.get("nombre_negocio"),
            "ing": d.get("ingresos_estimados"),
            "monto": d["monto_solicitado"],
            "plazo": d["plazo_meses"],
            "mon": d.get("moneda", "PEN"),
            "tc": d.get("tipo_cuota", "mensual"),
            "gar": d.get("garantia", "sin_garantia"),
            "dest": d.get("destino_credito"),
            "cuota": d.get("cuota_estimada"),
            "tea": d.get("tea_referencial"),
            "firma": d.get("firma_cliente_base64"),
        },
    )
    db.execute(
        text(
            """INSERT INTO cartera_diaria
                 (id, asesor_id, cliente_id, agencia_id, fecha_asignacion,
                  tipo_gestion, prioridad, score_prioridad, monto_credito,
                  estado_visita)
               VALUES
                 (:id,:asesor,:cli,:ag,:fecha,'NUEVA_SOLICITUD',:prioridad,
                  :score,:monto,'pendiente')
               ON CONFLICT (asesor_id, cliente_id, fecha_asignacion)
               DO UPDATE SET
                  tipo_gestion = 'NUEVA_SOLICITUD',
                  prioridad = EXCLUDED.prioridad,
                  score_prioridad = EXCLUDED.score_prioridad,
                  monto_credito = EXCLUDED.monto_credito,
                  estado_visita = 'pendiente',
                  resultado_visita = NULL,
                  observacion_visita = NULL,
                  timestamp_visita = NULL,
                  lat_visita = NULL,
                  lng_visita = NULL"""
        ),
        {
            "id": str(uuid.uuid4()),
            "asesor": asesor["id"],
            "cli": cliente_id,
            "ag": asesor["agencia_id"],
            "fecha": date.today(),
            "prioridad": prioridad,
            "score": score_prioridad,
            "monto": d["monto_solicitado"],
        },
    )
    db.execute(
        text(
            """INSERT INTO sync_outbox (id, entidad, entidad_id, operacion, payload, estado)
               VALUES (:id, 'solicitudes_credito', :eid, 'create', CAST(:payload AS jsonb), 'pendiente')"""
        ),
        {
            "id": str(uuid.uuid4()),
            "eid": sol_id,
            "payload": json.dumps(
                {
                    "numero_documento": d["numero_documento"],
                    "nombres": d.get("nombres", ""),
                    "apellidos": d.get("apellidos", ""),
                    "monto_solicitado": float(d["monto_solicitado"]),
                    "plazo_meses": int(d["plazo_meses"]),
                    "numero_expediente": expediente,
                    "canal": "cliente",
                }
            ),
        },
    )
    db.commit()
    return {"id": sol_id, "numero_expediente": expediente, "estado": "enviado"}


def listar_por_documento(db: Session, numero_documento: str) -> list[dict]:
    rows = db.execute(
        text(
            """
            SELECT s.id, s.numero_expediente, s.monto_solicitado, s.monto_aprobado,
                   s.estado, s.created_at, c.nombres, c.apellidos
            FROM solicitudes_credito s
            JOIN clientes c ON c.id = s.cliente_id
            WHERE c.numero_documento = :doc
            ORDER BY s.created_at DESC
            LIMIT 20
            """
        ),
        {"doc": numero_documento},
    ).mappings().all()
    return [_row_resumen(r) for r in rows]


def agregar_nota(db: Session, solicitud_id: str, asesor_id: str, contenido: str) -> dict:
    """Agrega una nota interna a una solicitud (RF-72)."""
    nid = str(uuid.uuid4())
    db.execute(
        text(
            """INSERT INTO solicitudes_notas_internas
                 (id, solicitud_id, asesor_id, contenido)
               VALUES (:id,:sol,:asesor,:cont)"""
        ),
        {"id": nid, "sol": solicitud_id, "asesor": asesor_id, "cont": contenido[:500]},
    )
    db.commit()
    return {"id": nid}


def listar_notas(db: Session, solicitud_id: str) -> list[dict]:
    """Notas internas de una solicitud, recientes primero (RF-72)."""
    rows = db.execute(
        text(
            """SELECT contenido, created_at
               FROM solicitudes_notas_internas
               WHERE solicitud_id = :sol
               ORDER BY created_at DESC"""
        ),
        {"sol": solicitud_id},
    ).mappings().all()
    return [
        {
            "contenido": r["contenido"],
            "created_at": r["created_at"].isoformat() if r["created_at"] else None,
        }
        for r in rows
    ]


def listar(
    db: Session,
    asesor_id: str | None = None,
    fecha_desde: date | None = None,
    fecha_hasta: date | None = None,
) -> list[dict]:
    """Solicitudes historicas, filtradas por asesor y rango cuando corresponde."""
    rows = db.execute(
        text(
            """
            SELECT s.id, s.numero_expediente, s.monto_solicitado, s.monto_aprobado,
                   s.estado, s.created_at, c.nombres, c.apellidos
            FROM solicitudes_credito s
            JOIN clientes c ON c.id = s.cliente_id
            WHERE (:asesor IS NULL OR s.asesor_id = CAST(:asesor AS uuid))
              AND (:fecha_desde IS NULL OR s.created_at::date >= :fecha_desde)
              AND (:fecha_hasta IS NULL OR s.created_at::date <= :fecha_hasta)
            ORDER BY s.created_at DESC
            """
        ),
        {
            "asesor": asesor_id,
            "fecha_desde": fecha_desde,
            "fecha_hasta": fecha_hasta,
        },
    ).mappings().all()
    return [_row_resumen(r) for r in rows]


def listar_demo(db: Session) -> list[dict]:
    """Solicitudes del asesor demo, recientes primero, sin token."""
    asesor = db.execute(
        text(
            """SELECT id
               FROM asesores
               WHERE activo = TRUE
               ORDER BY created_at NULLS LAST
               LIMIT 1"""
        )
    ).first()
    if not asesor:
        return []
    return listar(db, str(asesor[0]))


def obtener_detalle(db: Session, solicitud_id: str) -> dict | None:
    row = db.execute(
        text(
            """
            SELECT s.*, c.numero_documento, c.tipo_documento, c.nombres,
                   c.apellidos, c.telefono, c.email, c.direccion,
                   c.tipo_negocio AS cliente_tipo_negocio,
                   c.nombre_negocio AS cliente_nombre_negocio,
                   a.codigo_empleado, a.nombres AS asesor_nombres,
                   a.apellidos AS asesor_apellidos
            FROM solicitudes_credito s
            JOIN clientes c ON c.id = s.cliente_id
            LEFT JOIN asesores a ON a.id = s.asesor_id
            WHERE s.id = :id
            """
        ),
        {"id": solicitud_id},
    ).mappings().first()
    if not row:
        return None

    documentos = db.execute(
        text(
            """SELECT id, tipo_documento, storage_url, tamanio_kb,
                      nitidez_score, created_at
               FROM solicitudes_documentos
               WHERE solicitud_id = :id
               ORDER BY created_at DESC"""
        ),
        {"id": solicitud_id},
    ).mappings().all()
    buro = db.execute(
        text(
            """SELECT id, dni_consultado, calificacion_sbs, entidades_con_deuda,
                      deuda_total_pen, mayor_deuda, dias_mayor_mora,
                      resultado_json, firma_consentimiento_base64, created_at
               FROM consultas_buro
               WHERE solicitud_id = :id
               ORDER BY created_at DESC
               LIMIT 1"""
        ),
        {"id": solicitud_id},
    ).mappings().first()
    notas = listar_notas(db, solicitud_id)
    return {
        "id": str(row["id"]),
        "numero_expediente": row["numero_expediente"],
        "estado": row["estado"],
        "canal": row.get("canal"),
        "cliente": {
            "id": str(row["cliente_id"]),
            "numero_documento": row["numero_documento"],
            "tipo_documento": row["tipo_documento"],
            "nombres": row["nombres"],
            "apellidos": row["apellidos"],
            "telefono": row["telefono"],
            "email": row["email"],
            "direccion": row["direccion"],
            "tipo_negocio": row["cliente_tipo_negocio"],
            "nombre_negocio": row["cliente_nombre_negocio"],
        },
        "asesor": {
            "id": str(row["asesor_id"]) if row["asesor_id"] else None,
            "codigo_empleado": row["codigo_empleado"],
            "nombre": f"{row['asesor_nombres'] or ''} {row['asesor_apellidos'] or ''}".strip(),
        },
        "negocio": {
            "tipo_negocio": row["tipo_negocio"],
            "nombre_negocio": row["nombre_negocio"],
            "ingresos_estimados": float(row["ingresos_estimados"] or 0),
            "monto_solicitado": float(row["monto_solicitado"] or 0),
            "plazo_meses": row["plazo_meses"],
            "moneda": row["moneda"],
            "tipo_cuota": row["tipo_cuota"],
            "garantia": row["garantia"],
            "destino_credito": row["destino_credito"],
            "cuota_estimada": float(row["cuota_estimada"] or 0),
            "tea_referencial": float(row["tea_referencial"] or 0),
        },
        "decision": {
            "monto_aprobado": float(row["monto_aprobado"] or 0),
            "motivo_rechazo": row["motivo_rechazo"],
            "condicion_adicional": row["condicion_adicional"],
            "analista_asignado": row["analista_asignado"],
            "firma_cliente_base64": row["firma_cliente_base64"],
        },
        "documentos": [_serializar_documento(d) for d in documentos],
        "buro": _safe_dict(buro) if buro else None,
        "notas": notas,
        "created_at": row["created_at"].isoformat() if row["created_at"] else None,
        "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
    }


def enviar_comite(db: Session, solicitud_id: str) -> dict | None:
    row = db.execute(
        text("SELECT id, numero_expediente, estado FROM solicitudes_credito WHERE id=:id"),
        {"id": solicitud_id},
    ).mappings().first()
    if not row:
        return None
    if row["estado"] not in {"borrador", "enviado"}:
        raise ValueError("Solo solicitudes en borrador o enviadas pueden pasar a comite")
    db.execute(
        text(
            """UPDATE solicitudes_credito
               SET estado='recibido_comite', pendiente_sync=TRUE, updated_at=now()
               WHERE id=:id"""
        ),
        {"id": solicitud_id},
    )
    _outbox(db, solicitud_id, "enviar_comite", {"numero_expediente": row["numero_expediente"]})
    db.commit()
    return {"id": solicitud_id, "numero_expediente": row["numero_expediente"], "estado": "recibido_comite"}


def actualizar_estado(
    db: Session,
    solicitud_id: str,
    data: dict,
    analista: str | None = None,
) -> dict | None:
    estado = data.get("estado")
    if estado in {"aprobado", "condicionado", "rechazado"}:
        return decidir_comite(db, solicitud_id, {"decision": estado, **data}, analista)
    if estado == "desembolsado":
        return desembolsar(db, solicitud_id, data)
    if estado not in {"borrador", "enviado", "recibido_comite", "en_evaluacion"}:
        raise ValueError("Estado de solicitud invalido")
    row = db.execute(
        text("SELECT id, numero_expediente, estado FROM solicitudes_credito WHERE id=:id"),
        {"id": solicitud_id},
    ).mappings().first()
    if not row:
        return None
    db.execute(
        text(
            """UPDATE solicitudes_credito
               SET estado=:estado,
                   analista_asignado=COALESCE(:analista, analista_asignado),
                   pendiente_sync=TRUE,
                   updated_at=now()
               WHERE id=:id"""
        ),
        {"id": solicitud_id, "estado": estado, "analista": analista},
    )
    _outbox(db, solicitud_id, "cambio_estado", {
        "numero_expediente": row["numero_expediente"],
        "estado_anterior": row["estado"],
        "estado": estado,
        "analista_asignado": analista,
    })
    db.commit()
    return {"id": solicitud_id, "numero_expediente": row["numero_expediente"], "estado": estado}


def decidir_comite(
    db: Session,
    solicitud_id: str,
    data: dict,
    analista: str | None = None,
) -> dict | None:
    decision = data.get("decision")
    if decision not in {"aprobado", "condicionado", "rechazado"}:
        raise ValueError("Decision de comite invalida")
    if decision == "rechazado" and not (data.get("motivo_rechazo") or "").strip():
        raise ValueError("El motivo de rechazo es obligatorio")
    if decision == "condicionado" and not (data.get("condicion_adicional") or "").strip():
        raise ValueError("La condicion adicional es obligatoria")
    if decision == "aprobado" and data.get("monto_aprobado") is None:
        raise ValueError("El monto aprobado es obligatorio")

    row = db.execute(
        text(
            """SELECT id, numero_expediente, monto_solicitado, estado
               FROM solicitudes_credito
               WHERE id = :id"""
        ),
        {"id": solicitud_id},
    ).mappings().first()
    if not row:
        return None
    if row["estado"] not in {"recibido_comite", "en_evaluacion", "enviado"}:
        raise ValueError("La solicitud no esta en un estado evaluable por comite")

    monto = data.get("monto_aprobado")
    if decision == "rechazado":
        monto = 0
    elif monto is None:
        monto = float(row["monto_solicitado"] or 0)

    db.execute(
        text(
            """UPDATE solicitudes_credito
               SET estado = :estado,
                   monto_aprobado = :monto,
                   condicion_adicional = :condicion,
                   motivo_rechazo = :motivo,
                   analista_asignado = COALESCE(:analista, analista_asignado),
                   pendiente_sync = TRUE,
                   updated_at = now()
               WHERE id = :id"""
        ),
        {
            "id": solicitud_id,
            "estado": decision,
            "monto": monto,
            "condicion": data.get("condicion_adicional"),
            "motivo": data.get("motivo_rechazo"),
            "analista": analista or data.get("analista_asignado"),
        },
    )
    _outbox(db, solicitud_id, "decision_comite", {
        "numero_expediente": row["numero_expediente"],
        "decision": decision,
        "monto_aprobado": float(monto or 0),
        "condicion_adicional": data.get("condicion_adicional"),
        "motivo_rechazo": data.get("motivo_rechazo"),
        "analista_asignado": analista or data.get("analista_asignado"),
    })
    db.commit()
    return {"id": solicitud_id, "numero_expediente": row["numero_expediente"], "estado": decision}


def agregar_documento(db: Session, solicitud_id: str, data: dict) -> dict:
    doc_id = str(uuid.uuid4())
    db.execute(
        text(
            """INSERT INTO solicitudes_documentos
                 (id, solicitud_id, tipo_documento, storage_url, tamanio_kb, nitidez_score)
               VALUES (:id, :sol, :tipo, :url, :kb, :nitidez)"""
        ),
        {
            "id": doc_id,
            "sol": solicitud_id,
            "tipo": data["tipo_documento"],
            "url": data.get("storage_url"),
            "kb": data.get("tamanio_kb"),
            "nitidez": data.get("nitidez_score"),
        },
    )
    db.commit()
    return {"id": doc_id, "solicitud_id": solicitud_id, **data}


def listar_documentos(db: Session, solicitud_id: str) -> list[dict]:
    rows = db.execute(
        text(
            """SELECT id, solicitud_id, tipo_documento, storage_url,
                      tamanio_kb, nitidez_score, created_at
               FROM solicitudes_documentos
               WHERE solicitud_id = :id
               ORDER BY created_at DESC"""
        ),
        {"id": solicitud_id},
    ).mappings().all()
    return [_serializar_documento(row) for row in rows]


def eliminar_documento(db: Session, documento_id: str) -> bool:
    result = db.execute(
        text("DELETE FROM solicitudes_documentos WHERE id = :id"),
        {"id": documento_id},
    )
    db.commit()
    return bool(result.rowcount)


def desembolsar(db: Session, solicitud_id: str, data: dict | None = None) -> dict | None:
    row = db.execute(
        text(
            """SELECT id, numero_expediente, cliente_id, estado,
                      monto_solicitado, monto_aprobado, plazo_meses,
                      cuota_estimada, tea_referencial
               FROM solicitudes_credito
               WHERE id = :id"""
        ),
        {"id": solicitud_id},
    ).mappings().first()
    if not row:
        return None
    if row["estado"] not in {"aprobado", "condicionado"}:
        raise ValueError("Solo se puede desembolsar una solicitud aprobada o condicionada")

    db.execute(
        text(
            """UPDATE solicitudes_credito
               SET estado = 'desembolsado',
                   pendiente_sync = TRUE,
                   updated_at = now()
               WHERE id = :id"""
        ),
        {"id": solicitud_id},
    )
    _materializar_desembolso_cliente(db, row)
    _outbox(db, solicitud_id, "desembolso", {
        "numero_expediente": row["numero_expediente"],
        "monto_desembolsado": float(row["monto_aprobado"] or 0),
        "observacion": (data or {}).get("observacion"),
    })
    db.commit()
    return {"id": solicitud_id, "numero_expediente": row["numero_expediente"], "estado": "desembolsado"}


def _materializar_desembolso_cliente(db: Session, solicitud) -> None:
    """Refleja un desembolso aprobado en productos, cuenta y movimientos del cliente."""
    cliente_id = str(solicitud["cliente_id"])
    cliente = db.execute(
        text("SELECT numero_documento FROM clientes WHERE id = :id"),
        {"id": cliente_id},
    ).mappings().first()
    if not cliente:
        raise ValueError("Cliente de la solicitud no encontrado")

    expediente = solicitud["numero_expediente"]
    monto = float(solicitud["monto_aprobado"] or solicitud["monto_solicitado"] or 0)
    if monto <= 0:
        raise ValueError("La solicitud no tiene monto aprobado para desembolsar")

    plazo = int(solicitud["plazo_meses"] or 12)
    plazo = max(plazo, 1)
    cuota = float(solicitud["cuota_estimada"] or (monto / plazo))
    tea = float(solicitud["tea_referencial"] or 43.92)
    cuenta = f"AHO-{str(cliente['numero_documento'])[-4:]}"
    cod_credito = f"CR-{expediente}"[:30]
    cod_operacion = f"OP-{expediente}"[:40]
    fecha = datetime.now(timezone.utc).date()

    db.execute(
        text(
            """INSERT INTO cr_cuentas_ahorro
                 (id, cod_cuenta_ahorro, cliente_id, tipo_cuenta, moneda,
                  saldo_capital, saldo_interes, tea, estado)
               VALUES (:id, :cod, :cliente_id, 'Ahorro Digital', 'PEN',
                       0, 0, 2.50, 'activa')
               ON CONFLICT (cod_cuenta_ahorro) DO NOTHING"""
        ),
        {"id": str(uuid.uuid4()), "cod": cuenta, "cliente_id": cliente_id},
    )

    db.execute(
        text(
            """INSERT INTO cr_creditos
                 (id, cod_cuenta_credito, cliente_id, producto,
                  monto_desembolsado, saldo_capital, saldo_total, dias_mora,
                  calificacion_interna, estado, fecha_desembolso, tea,
                  cuotas_total, cuotas_pagadas)
               VALUES (:id, :cod, :cliente_id, 'Credito Empresarial MYPE',
                       :monto, :monto, :saldo_total, 0, 'NORMAL', 'vigente',
                       :fecha, :tea, :plazo, 0)
               ON CONFLICT (cod_cuenta_credito)
               DO UPDATE SET monto_desembolsado=EXCLUDED.monto_desembolsado,
                             saldo_capital=EXCLUDED.saldo_capital,
                             saldo_total=EXCLUDED.saldo_total,
                             estado='vigente',
                             fecha_desembolso=EXCLUDED.fecha_desembolso,
                             tea=EXCLUDED.tea,
                             cuotas_total=EXCLUDED.cuotas_total,
                             sync_at=now()"""
        ),
        {
            "id": str(uuid.uuid4()),
            "cod": cod_credito,
            "cliente_id": cliente_id,
            "monto": monto,
            "saldo_total": round(cuota * plazo, 2),
            "fecha": fecha,
            "tea": tea,
            "plazo": plazo,
        },
    )

    saldo = monto
    for nro in range(1, plazo + 1):
        capital = round(monto / plazo, 2)
        interes = max(round(cuota - capital, 2), 0)
        if nro == plazo:
            capital = round(saldo, 2)
        saldo = max(round(saldo - capital, 2), 0)
        db.execute(
            text(
                """INSERT INTO cr_cronograma_pagos
                     (id, cod_cuenta_credito, nro_cuota, fecha_vencimiento,
                      monto_cuota, monto_capital, monto_interes, saldo, estado_cuota)
                   VALUES (:id, :cod, :nro, :fecha, :cuota, :capital,
                           :interes, :saldo, 'pendiente')
                   ON CONFLICT (cod_cuenta_credito, nro_cuota)
                   DO UPDATE SET fecha_vencimiento=EXCLUDED.fecha_vencimiento,
                                 monto_cuota=EXCLUDED.monto_cuota,
                                 monto_capital=EXCLUDED.monto_capital,
                                 monto_interes=EXCLUDED.monto_interes,
                                 saldo=EXCLUDED.saldo,
                                 estado_cuota='pendiente',
                                 sync_at=now()"""
            ),
            {
                "id": str(uuid.uuid4()),
                "cod": cod_credito,
                "nro": nro,
                "fecha": fecha + timedelta(days=30 * nro),
                "cuota": cuota,
                "capital": capital,
                "interes": interes,
                "saldo": saldo,
            },
        )

    movimiento_existia = db.execute(
        text("SELECT 1 FROM cr_movimientos WHERE cod_operacion = :cod"),
        {"cod": cod_operacion},
    ).first()
    db.execute(
        text(
            """INSERT INTO cr_movimientos
                 (id, cod_operacion, cliente_id, cod_cuenta, tipo, concepto,
                  canal, monto, moneda, fecha_operacion)
               VALUES (:id, :codop, :cliente_id, :cuenta, 'CRE',
                       'Desembolso credito empresarial MYPE', 'CORE', :monto,
                       'PEN', now())
               ON CONFLICT (cod_operacion) DO NOTHING"""
        ),
        {
            "id": str(uuid.uuid4()),
            "codop": cod_operacion,
            "cliente_id": cliente_id,
            "cuenta": cuenta,
            "monto": monto,
        },
    )
    if not movimiento_existia:
        db.execute(
            text(
                """UPDATE cr_cuentas_ahorro
                   SET saldo_capital = COALESCE(saldo_capital, 0) + :monto,
                       sync_at = now()
                   WHERE cliente_id = :cliente_id
                     AND cod_cuenta_ahorro = :cuenta"""
            ),
            {"cliente_id": cliente_id, "cuenta": cuenta, "monto": monto},
        )

    db.execute(
        text(
            """INSERT INTO notificaciones
                 (id, destinatario_tipo, cliente_id, titulo, cuerpo, tipo, data_json)
               SELECT :id, 'cliente', :cliente_id, 'Credito desembolsado',
                      :cuerpo, 'credito', CAST(:data AS jsonb)
               WHERE NOT EXISTS (
                   SELECT 1 FROM notificaciones
                   WHERE cliente_id = :cliente_id
                     AND data_json->>'numero_expediente' = :exp
               )"""
        ),
        {
            "id": str(uuid.uuid4()),
            "cliente_id": cliente_id,
            "cuerpo": f"Tu expediente {expediente} fue desembolsado por S/ {monto:.2f}.",
            "data": json.dumps({"numero_expediente": expediente}),
            "exp": expediente,
        },
    )


def _outbox(db: Session, solicitud_id: str, evento: str, payload: dict) -> None:
    db.execute(
        text(
            """INSERT INTO sync_outbox (id, entidad, entidad_id, operacion, payload, estado)
               VALUES (:id, 'solicitudes_credito', :eid, 'update',
                       CAST(:payload AS jsonb), 'pendiente')"""
        ),
        {
            "id": str(uuid.uuid4()),
            "eid": solicitud_id,
            "payload": json.dumps({"evento": evento, **payload}),
        },
    )


def _row_resumen(r) -> dict:
    return {
        "id": str(r["id"]),
        "numero_expediente": r["numero_expediente"],
        "cliente_nombre": f"{r['nombres']} {r['apellidos']}",
        "monto_solicitado": float(r["monto_solicitado"] or 0),
        "monto_aprobado": float(r["monto_aprobado"] or 0),
        "estado": r["estado"],
        "created_at": r["created_at"].isoformat() if r["created_at"] else None,
    }


def _serializar_documento(r) -> dict:
    return {
        "id": str(r["id"]),
        "solicitud_id": str(r["solicitud_id"]) if "solicitud_id" in r else None,
        "tipo_documento": r["tipo_documento"],
        "storage_url": r["storage_url"],
        "tamanio_kb": r["tamanio_kb"],
        "nitidez_score": float(r["nitidez_score"] or 0),
        "created_at": r["created_at"].isoformat() if r["created_at"] else None,
    }


def _safe_dict(row) -> dict:
    return {key: _safe_value(value) for key, value in dict(row).items()}


def _safe_value(value):
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    try:
        json.dumps(value)
        return value
    except TypeError:
        return str(value)


def _prioridad(monto: float) -> str:
    if monto >= 8000:
        return "alta"
    if monto >= 3000:
        return "media"
    return "normal"


def _score_prioridad(monto: float) -> int:
    if monto >= 10000:
        return 90
    if monto >= 5000:
        return 75
    if monto >= 3000:
        return 60
    return 40
