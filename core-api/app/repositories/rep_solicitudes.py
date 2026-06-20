import json
import uuid
from datetime import date, datetime, timezone
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


def listar(db: Session, asesor_id: str) -> list[dict]:
    """Solicitudes del asesor en el mes actual (HU-20), recientes primero."""
    rows = db.execute(
        text(
            """
            SELECT s.id, s.numero_expediente, s.monto_solicitado, s.monto_aprobado,
                   s.estado, s.created_at, c.nombres, c.apellidos
            FROM solicitudes_credito s
            JOIN clientes c ON c.id = s.cliente_id
            WHERE s.asesor_id = :asesor
              AND date_trunc('month', s.created_at) = date_trunc('month', now())
            ORDER BY s.created_at DESC
            """
        ),
        {"asesor": asesor_id},
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


def decidir_comite(db: Session, solicitud_id: str, data: dict) -> dict | None:
    decision = data.get("decision")
    if decision not in {"aprobado", "condicionado", "rechazado"}:
        raise ValueError("Decision de comite invalida")

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
        },
    )
    _outbox(db, solicitud_id, "decision_comite", {
        "numero_expediente": row["numero_expediente"],
        "decision": decision,
        "monto_aprobado": float(monto or 0),
        "condicion_adicional": data.get("condicion_adicional"),
        "motivo_rechazo": data.get("motivo_rechazo"),
    })
    db.commit()
    return {"id": solicitud_id, "numero_expediente": row["numero_expediente"], "estado": decision}


def desembolsar(db: Session, solicitud_id: str, data: dict | None = None) -> dict | None:
    row = db.execute(
        text(
            """SELECT id, numero_expediente, estado, monto_aprobado
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
    _outbox(db, solicitud_id, "desembolso", {
        "numero_expediente": row["numero_expediente"],
        "monto_desembolsado": float(row["monto_aprobado"] or 0),
        "observacion": (data or {}).get("observacion"),
    })
    db.commit()
    return {"id": solicitud_id, "numero_expediente": row["numero_expediente"], "estado": "desembolsado"}


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
