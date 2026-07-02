import json
import uuid
from datetime import date, datetime, timedelta, timezone
import calendar
from math import pow

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.cfg_security import hash_password
from app.data.casos_credito import casos_completos


def listar() -> list[dict]:
    return casos_completos()


def resumen() -> dict:
    casos = casos_completos()
    return {
        "marca": "Banco Falabella",
        "core": "FastAPI 8003",
        "bd_mobile": "bd_core_mobile",
        "bd_financiero": "bd_core_financiero",
        "total_casos": len(casos),
        "desembolsados": sum(1 for c in casos if c["decision_comite"] == "aprobado"),
        "condicionados": sum(1 for c in casos if c["decision_comite"] == "condicionado"),
        "rechazados": sum(1 for c in casos if c["decision_comite"] == "rechazado"),
        "monto_solicitado": sum(c["monto_solicitado"] for c in casos),
        "monto_aprobado": sum(c["monto_aprobado"] for c in casos),
        "usuario_cliente_demo": "DNI del caso + clave 1234",
        "usuario_asesor_demo": "0001 / 1234",
    }


def cartera_demo(limit: int = 12) -> list[dict]:
    """Cartera estable para el portal cuando la BD demo aun no fue sembrada."""
    estados = ["pendiente", "visitado", "pendiente", "reagendado"]
    items = []
    for idx, caso in enumerate(casos_completos()[:limit]):
        items.append(
            {
                "id": f"demo-cartera-{caso['caso']:02d}",
                "cliente_id": f"demo-cliente-{caso['caso']:02d}",
                "cliente_nombre": f"{caso['nombres']} {caso['apellidos']}",
                "documento": caso["numero_documento"],
                "numero_expediente": caso["numero_expediente"],
                "tipo_gestion": "NUEVA_SOLICITUD",
                "prioridad": _prioridad_demo(caso["monto_solicitado"]),
                "score_prioridad": _score_demo(caso["monto_solicitado"]),
                "monto_credito": float(caso["monto_solicitado"] or 0),
                "estado_visita": estados[idx % len(estados)],
                "orden_manual": idx + 1,
                "fecha_asignacion": date.today().isoformat(),
                "fecha_hora_solicitud": datetime.now(timezone.utc).isoformat(),
                "timestamp_visita": None,
                "lat": caso.get("lat"),
                "lng": caso.get("lng"),
            }
        )
    return items


def solicitudes_demo(limit: int = 12) -> list[dict]:
    """Solicitudes estables para el portal cuando la BD demo aun no fue sembrada."""
    return [
        {
            "id": f"demo-solicitud-{caso['caso']:02d}",
            "numero_expediente": caso["numero_expediente"],
            "cliente_nombre": f"{caso['nombres']} {caso['apellidos']}",
            "monto_solicitado": float(caso["monto_solicitado"] or 0),
            "monto_aprobado": float(caso["monto_aprobado"] or 0),
            "estado": caso["estado_final"],
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        for caso in casos_completos()[:limit]
    ]


def _prioridad_demo(monto: float) -> str:
    if monto >= 8000:
        return "alta"
    if monto >= 3000:
        return "media"
    return "normal"


def _score_demo(monto: float) -> int:
    if monto >= 10000:
        return 90
    if monto >= 5000:
        return 75
    if monto >= 3000:
        return 60
    return 40


def sembrar(db: Session) -> dict:
    """Crea el dataset completo de los 30 casos del PDF aplicado a Banco Falabella.

    Este seed deja listo:
    - 1 agencia Banco Falabella.
    - 1 asesor de negocio (login 0001 / clave 1234).
    - 30 clientes/prospectos con usuario de App Clientes (DNI / clave 1234).
    - 30 solicitudes/expedientes del flujo movil.
    - 30 asignaciones en cartera como NUEVA_SOLICITUD.
    - 30 consultas de buro/listas.
    - Documentos demo por expediente: DNI anverso, DNI reverso, sustento, foto negocio y foto visita.
    - Firma demo de cliente.
    - sync_outbox para promocion al nucleo.
    - Para aprobados y condicionados: credito espejo, cronograma y movimiento de desembolso.
    """
    asesor = _asegurar_agencia_y_asesor(db)

    creados = 0
    actualizados = 0
    omitidos = 0
    for caso in casos_completos():
        cliente_id = _upsert_cliente(db, caso)
        _crear_usuario_cliente(db, cliente_id, caso)
        _crear_productos_base_cliente(db, cliente_id, caso)

        row = db.execute(
            text("SELECT id FROM solicitudes_credito WHERE numero_expediente = :exp"),
            {"exp": caso["numero_expediente"]},
        ).first()

        solicitud_id = str(row[0]) if row else str(uuid.uuid4())
        estado = caso["estado_final"]
        motivo_rechazo = None
        condicion = None
        if caso["decision_comite"] == "condicionado":
            condicion = "Aprobado con monto reducido segun evaluacion del comite."
        if caso["decision_comite"] == "rechazado":
            motivo_rechazo = _motivo_rechazo(caso)

        params = {
            "id": solicitud_id,
            "exp": caso["numero_expediente"],
            "asesor": asesor["id"],
            "cli": cliente_id,
            "ag": asesor["agencia_id"],
            "tn": caso["tipo_negocio"],
            "nn": caso["nombre_negocio"],
            "ant": caso["antiguedad_negocio_meses"],
            "ing": caso["ingresos_estimados"],
            "gastos": caso["gastos_mensuales"],
            "monto": caso["monto_solicitado"],
            "plazo": caso["plazo_meses"],
            "gar": caso["garantia"],
            "dest": caso["destino_credito"],
            "cuota": caso["cuota_final"] or caso["cuota_estimada"],
            "tea": caso["tea_referencial"],
            "estado": estado,
            "aprobado": caso["monto_aprobado"] or None,
            "motivo": motivo_rechazo,
            "condicion": condicion,
            "firma": f"firma_demo_caso_{caso['caso']:02d}",
            "lat": caso["lat"],
            "lng": caso["lng"],
        }

        if row:
            db.execute(
                text(
                    """UPDATE solicitudes_credito
                       SET asesor_id=:asesor, cliente_id=:cli, agencia_id=:ag,
                           canal='cliente', tipo_negocio=:tn, nombre_negocio=:nn,
                           antiguedad_negocio_meses=:ant, ingresos_estimados=:ing,
                           gastos_mensuales=:gastos, monto_solicitado=:monto,
                           plazo_meses=:plazo, moneda='PEN', tipo_cuota='mensual',
                           garantia=:gar, destino_credito=:dest, cuota_estimada=:cuota,
                           tea_referencial=:tea, estado=:estado, monto_aprobado=:aprobado,
                           motivo_rechazo=:motivo, condicion_adicional=:condicion,
                           firma_cliente_base64=:firma, lat_captura=:lat, lng_captura=:lng,
                           pendiente_sync=TRUE, updated_at=now()
                     WHERE id=:id"""
                ),
                params,
            )
            actualizados += 1
        else:
            db.execute(
                text(
                    """INSERT INTO solicitudes_credito
                         (id, numero_expediente, asesor_id, cliente_id, agencia_id,
                          canal, tipo_negocio, nombre_negocio, antiguedad_negocio_meses,
                          ingresos_estimados, gastos_mensuales, monto_solicitado,
                          plazo_meses, moneda, tipo_cuota, garantia, destino_credito,
                          cuota_estimada, tea_referencial, estado, monto_aprobado,
                          motivo_rechazo, condicion_adicional, firma_cliente_base64,
                          lat_captura, lng_captura, pendiente_sync)
                       VALUES
                         (:id,:exp,:asesor,:cli,:ag,'cliente',:tn,:nn,:ant,:ing,
                          :gastos,:monto,:plazo,'PEN','mensual',:gar,:dest,:cuota,
                          :tea,:estado,:aprobado,:motivo,:condicion,:firma,:lat,
                          :lng,TRUE)"""
                ),
                params,
            )
            creados += 1

        _upsert_cartera(db, asesor, cliente_id, caso)
        _upsert_buro(db, asesor, cliente_id, solicitud_id, caso)
        _crear_documentos_demo(db, solicitud_id, caso)
        _crear_outbox(db, solicitud_id, caso, estado)
        if caso["decision_comite"] in ("aprobado", "condicionado"):
            _crear_credito_cronograma(db, cliente_id, caso)
        else:
            _crear_notificacion_cliente(
                db,
                cliente_id,
                "Solicitud no aprobada",
                f"Tu expediente {caso['numero_expediente']} fue rechazado: {_motivo_rechazo(caso)}",
                "rechazado",
                caso,
            )

    db.commit()
    return {
        "ok": True,
        "creados": creados,
        "actualizados": actualizados,
        "omitidos": omitidos,
        "usuarios_cliente": 30,
        "clave_clientes": "1234",
        "asesor": "0001 / 1234",
        **resumen(),
    }


def _asegurar_agencia_y_asesor(db: Session) -> dict:
    agencia = db.execute(
        text("SELECT id FROM agencias WHERE cod_agencia = '0001' LIMIT 1")
    ).mappings().first()
    if agencia is None:
        agencia_id = str(uuid.uuid4())
        db.execute(
            text(
                """INSERT INTO agencias (id, cod_agencia, nombre, region, lat, lng, activa)
                   VALUES (:id, '0001', 'Agencia Banco Falabella Huancayo', 'Junin', -12.0667, -75.2131, TRUE)"""
            ),
            {"id": agencia_id},
        )
    else:
        agencia_id = str(agencia["id"])

    asesor = db.execute(
        text("SELECT id, agencia_id FROM asesores WHERE codigo_empleado = '0001' LIMIT 1")
    ).mappings().first()
    if asesor is None:
        asesor_id = str(uuid.uuid4())
        db.execute(
            text(
                """INSERT INTO asesores
                     (id, cod_asesor, codigo_empleado, nombres, apellidos,
                      agencia_id, perfil, password_hash, activo)
                   VALUES
                     (:id, 'A001', '0001', 'Carlos', 'Ramirez', :agencia,
                      'operador', :hash, TRUE)"""
            ),
            {
                "id": asesor_id,
                "agencia": agencia_id,
                "hash": hash_password("1234"),
            },
        )
        return {"id": asesor_id, "agencia_id": agencia_id}
    return {"id": str(asesor["id"]), "agencia_id": str(asesor["agencia_id"])}


def _upsert_cliente(db: Session, caso: dict) -> str:
    row = db.execute(
        text("SELECT id FROM clientes WHERE numero_documento = :doc"),
        {"doc": caso["numero_documento"]},
    ).first()
    if row:
        cliente_id = str(row[0])
        db.execute(
            text(
                """UPDATE clientes
                   SET telefono=:tel, direccion=:dir, tipo_negocio=:tn,
                       nombre_negocio=:nn, antiguedad_negocio_meses=:ant,
                       ingresos_estimados=:ing, lat=:lat, lng=:lng,
                       calificacion_sbs=:sbs, es_prospecto=TRUE,
                       updated_at=now()
                   WHERE id=:id"""
            ),
            {
                "id": cliente_id,
                "tel": caso["telefono"],
                "dir": caso["distrito"],
                "tn": caso["tipo_negocio"],
                "nn": caso["nombre_negocio"],
                "ant": caso["antiguedad_negocio_meses"],
                "ing": caso["ingresos_estimados"],
                "lat": caso["lat"],
                "lng": caso["lng"],
                "sbs": caso["calificacion_sbs"],
            },
        )
        return cliente_id

    cliente_id = str(uuid.uuid4())
    db.execute(
        text(
            """INSERT INTO clientes
                 (id, numero_documento, nombres, apellidos, telefono, direccion,
                  tipo_negocio, nombre_negocio, antiguedad_negocio_meses,
                  ingresos_estimados, lat, lng, calificacion_sbs, es_prospecto)
               VALUES
                 (:id,:doc,:nom,:ape,:tel,:dir,:tn,:nn,:ant,:ing,:lat,:lng,:sbs,TRUE)"""
        ),
        {
            "id": cliente_id,
            "doc": caso["numero_documento"],
            "nom": caso["nombres"],
            "ape": caso["apellidos"],
            "tel": caso["telefono"],
            "dir": caso["distrito"],
            "tn": caso["tipo_negocio"],
            "nn": caso["nombre_negocio"],
            "ant": caso["antiguedad_negocio_meses"],
            "ing": caso["ingresos_estimados"],
            "lat": caso["lat"],
            "lng": caso["lng"],
            "sbs": caso["calificacion_sbs"],
        },
    )
    return cliente_id


def _crear_usuario_cliente(db: Session, cliente_id: str, caso: dict) -> None:
    db.execute(
        text(
            """INSERT INTO usuarios_cliente
                 (id, cliente_id, username, password_hash, activo, bloqueado, intentos_fallidos)
               VALUES (:id, :cliente_id, :username, :password_hash, TRUE, FALSE, 0)
               ON CONFLICT (username) DO UPDATE
               SET password_hash = EXCLUDED.password_hash,
                   activo = TRUE,
                   bloqueado = FALSE,
                   intentos_fallidos = 0"""
        ),
        {
            "id": str(uuid.uuid4()),
            "cliente_id": cliente_id,
            "username": caso["numero_documento"],
            "password_hash": hash_password("1234"),
        },
    )


def _crear_productos_base_cliente(db: Session, cliente_id: str, caso: dict) -> None:
    doc = caso["numero_documento"]
    cuenta = f"AHO-{doc[-4:]}"
    db.execute(
        text(
            """INSERT INTO cr_cuentas_ahorro
                 (id, cod_cuenta_ahorro, cliente_id, tipo_cuenta, moneda,
                  saldo_capital, saldo_interes, tea, estado)
               VALUES (:id, :cod, :cliente_id, 'Cuenta Banco Falabella', 'PEN',
                       :saldo, 0.00, 2.50, 'activa')
               ON CONFLICT (cod_cuenta_ahorro) DO NOTHING"""
        ),
        {
            "id": str(uuid.uuid4()),
            "cod": cuenta,
            "cliente_id": cliente_id,
            "saldo": max(float(caso["ingresos_estimados"]) * 0.35, 350),
        },
    )
    db.execute(
        text(
            """INSERT INTO tarjetas
                 (id, cliente_id, numero_enmascarado, marca, linea_credito,
                  saldo_utilizado, fecha_corte, fecha_pago, estado)
               SELECT :id, :cliente_id, :numero, 'Visa', :linea, :utilizado,
                      :corte, :pago, 'activa'
               WHERE NOT EXISTS (SELECT 1 FROM tarjetas WHERE cliente_id = :cliente_id)"""
        ),
        {
            "id": str(uuid.uuid4()),
            "cliente_id": cliente_id,
            "numero": f"**** **** **** {doc[-4:]}",
            "linea": max(float(caso["ingresos_estimados"]) * 1.5, 1500),
            "utilizado": max(float(caso["gastos_mensuales"]) * 0.2, 100),
            "corte": date.today().replace(day=20),
            "pago": date.today().replace(day=28),
        },
    )


def _upsert_cartera(db: Session, asesor: dict, cliente_id: str, caso: dict) -> None:
    db.execute(
        text(
            """INSERT INTO cartera_diaria
                 (id, asesor_id, cliente_id, agencia_id, fecha_asignacion,
                  tipo_gestion, prioridad, score_prioridad, monto_credito,
                  estado_visita, resultado_visita, observacion_visita,
                  timestamp_visita, lat_visita, lng_visita)
               VALUES
                 (:id,:asesor,:cli,:ag,:fecha,'NUEVA_SOLICITUD',:prioridad,
                  :score,:monto,'visitado','visitado',:obs,now(),:lat,:lng)
               ON CONFLICT (asesor_id, cliente_id, fecha_asignacion)
               DO UPDATE SET tipo_gestion='NUEVA_SOLICITUD', prioridad=EXCLUDED.prioridad,
                             score_prioridad=EXCLUDED.score_prioridad,
                             monto_credito=EXCLUDED.monto_credito,
                             estado_visita='visitado', resultado_visita='visitado',
                             observacion_visita=EXCLUDED.observacion_visita,
                             timestamp_visita=now(), lat_visita=EXCLUDED.lat_visita,
                             lng_visita=EXCLUDED.lng_visita"""
        ),
        {
            "id": str(uuid.uuid4()),
            "asesor": asesor["id"],
            "cli": cliente_id,
            "ag": asesor["agencia_id"],
            "fecha": date.today(),
            "prioridad": caso["prioridad"],
            "score": _score_prioridad(caso),
            "monto": caso["monto_solicitado"],
            "obs": f"Caso {caso['caso']} evaluado en campo. Negocio: {caso['nombre_negocio']}",
            "lat": caso["lat"],
            "lng": caso["lng"],
        },
    )


def _upsert_buro(db: Session, asesor: dict, cliente_id: str, solicitud_id: str, caso: dict) -> None:
    existe = db.execute(
        text("SELECT id FROM consultas_buro WHERE solicitud_id = :sol LIMIT 1"),
        {"sol": solicitud_id},
    ).first()
    params = {
        "id": str(uuid.uuid4()),
        "asesor": asesor["id"],
        "cli": cliente_id,
        "sol": solicitud_id,
        "dni": caso["numero_documento"],
        "sbs": caso["calificacion_sbs"],
        "ent": caso["entidades_con_deuda"],
        "deuda": caso["deuda_total_pen"],
        "mayor": caso["mayor_deuda"],
        "mora": caso["dias_mayor_mora"],
        "lista": caso["en_lista_negra"],
        "motivo": _motivo_rechazo(caso) if caso["en_lista_negra"] else None,
        "json": json.dumps(caso),
        "firma": f"consentimiento_caso_{caso['caso']:02d}",
    }
    if existe:
        db.execute(
            text(
                """UPDATE consultas_buro
                   SET asesor_id=:asesor, cliente_id=:cli, dni_consultado=:dni,
                       calificacion_sbs=:sbs, entidades_con_deuda=:ent,
                       deuda_total_pen=:deuda, mayor_deuda=:mayor,
                       dias_mayor_mora=:mora, en_lista_negra=:lista,
                       motivo_bloqueo=:motivo, resultado_json=CAST(:json AS jsonb),
                       firma_consentimiento_base64=:firma
                 WHERE solicitud_id=:sol"""
            ),
            params,
        )
    else:
        db.execute(
            text(
                """INSERT INTO consultas_buro
                     (id, asesor_id, cliente_id, solicitud_id, dni_consultado,
                      calificacion_sbs, entidades_con_deuda, deuda_total_pen,
                      mayor_deuda, dias_mayor_mora, en_lista_negra,
                      motivo_bloqueo, resultado_json, firma_consentimiento_base64)
                   VALUES
                     (:id,:asesor,:cli,:sol,:dni,:sbs,:ent,:deuda,:mayor,:mora,
                      :lista,:motivo,CAST(:json AS jsonb),:firma)"""
            ),
            params,
        )


def _crear_documentos_demo(db: Session, solicitud_id: str, caso: dict) -> None:
    documentos = [
        "dni_anverso",
        "dni_reverso",
        "sustento_negocio",
        "foto_negocio",
        "foto_visita",
    ]
    for tipo in documentos:
        existe = db.execute(
            text(
                """SELECT id FROM solicitudes_documentos
                   WHERE solicitud_id = :sol AND tipo_documento = :tipo LIMIT 1"""
            ),
            {"sol": solicitud_id, "tipo": tipo},
        ).first()
        if existe:
            continue
        db.execute(
            text(
                """INSERT INTO solicitudes_documentos
                     (id, solicitud_id, tipo_documento, storage_url, tamanio_kb, nitidez_score)
                   VALUES (:id, :sol, :tipo, :url, :kb, 92.50)"""
            ),
            {
                "id": str(uuid.uuid4()),
                "sol": solicitud_id,
                "tipo": tipo,
                "url": f"supabase://documentos-credito/{caso['numero_expediente']}/{tipo}.jpg",
                "kb": 350,
            },
        )


def _crear_outbox(db: Session, solicitud_id: str, caso: dict, estado: str) -> None:
    existe = db.execute(
        text(
            """SELECT id FROM sync_outbox
               WHERE entidad = 'solicitudes_credito'
                 AND entidad_id = :eid
                 AND operacion = 'create'
               LIMIT 1"""
        ),
        {"eid": solicitud_id},
    ).first()
    payload = json.dumps(
        {
            "numero_expediente": caso["numero_expediente"],
            "numero_documento": caso["numero_documento"],
            "monto_solicitado": caso["monto_solicitado"],
            "monto_aprobado": caso["monto_aprobado"],
            "estado": estado,
            "marca": "Banco Falabella",
        }
    )
    if existe:
        db.execute(
            text(
                """UPDATE sync_outbox
                   SET payload=CAST(:payload AS jsonb), estado='pendiente', intentos=0,
                       ultimo_error=NULL
                 WHERE entidad='solicitudes_credito' AND entidad_id=:eid AND operacion='create'"""
            ),
            {"eid": solicitud_id, "payload": payload},
        )
    else:
        db.execute(
            text(
                """INSERT INTO sync_outbox (id, entidad, entidad_id, operacion, payload, estado)
                   VALUES (:id, 'solicitudes_credito', :eid, 'create', CAST(:payload AS jsonb), 'pendiente')"""
            ),
            {"id": str(uuid.uuid4()), "eid": solicitud_id, "payload": payload},
        )


def _crear_credito_cronograma(db: Session, cliente_id: str, caso: dict) -> None:
    cod_credito = f"CR-{caso['numero_expediente']}"[:30]
    monto = float(caso["monto_aprobado"] or caso["monto_solicitado"])
    plazo = int(caso["plazo_meses"])
    tea_decimal = float(caso.get("tea_decimal", caso["tea_referencial"] / 100))
    cuota = float(caso["cuota_final"] or caso["cuota_estimada"])
    saldo_total = round(cuota * plazo, 2)

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
                             tea=EXCLUDED.tea,
                             cuotas_total=EXCLUDED.cuotas_total,
                             estado='vigente'"""
        ),
        {
            "id": str(uuid.uuid4()),
            "cod": cod_credito,
            "cliente_id": cliente_id,
            "monto": monto,
            "saldo_total": saldo_total,
            "fecha": date.fromisoformat(caso["fecha_desembolso"]) if caso.get("fecha_desembolso") else datetime.now(timezone.utc).date(),
            "tea": caso["tea_referencial"],
            "plazo": plazo,
        },
    )

    saldo = monto
    tem = pow(1 + tea_decimal, 1 / 12) - 1
    for nro in range(1, plazo + 1):
        interes = round(saldo * tem, 2)
        capital = round(cuota - interes, 2)
        if nro == plazo:
            capital = round(saldo, 2)
            cuota_real = round(capital + interes, 2)
            saldo = 0.0
        else:
            cuota_real = cuota
            saldo = max(round(saldo - capital, 2), 0.0)
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
                                 estado_cuota='pendiente'"""
            ),
            {
                "id": str(uuid.uuid4()),
                "cod": cod_credito,
                "nro": nro,
                "fecha": _fecha_cuota(caso, nro),
                "cuota": cuota_real,
                "capital": capital,
                "interes": interes,
                "saldo": saldo,
            },
        )

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
            "codop": f"OP-{caso['numero_expediente']}",
            "cliente_id": cliente_id,
            "cuenta": cod_credito,
            "monto": monto,
        },
    )
    titulo = "Credito desembolsado" if caso["decision_comite"] == "aprobado" else "Credito condicionado desembolsado"
    cuerpo = f"Tu expediente {caso['numero_expediente']} fue desembolsado por S/ {monto:.2f}."
    _crear_notificacion_cliente(db, cliente_id, titulo, cuerpo, "desembolsado", caso)


def _fecha_cuota(caso: dict, nro_cuota: int) -> date:
    """Fecha exacta de cuota segun el PDF: mes siguiente al desembolso y dia de pago indicado."""
    fecha_desembolso = caso.get("fecha_desembolso")
    dia_pago = caso.get("dia_pago")
    if not fecha_desembolso or not dia_pago:
        return datetime.now(timezone.utc).date() + timedelta(days=30 * nro_cuota)

    base = date.fromisoformat(fecha_desembolso)
    mes_objetivo = base.month + nro_cuota
    anio = base.year + (mes_objetivo - 1) // 12
    mes = ((mes_objetivo - 1) % 12) + 1
    ultimo_dia = calendar.monthrange(anio, mes)[1]
    return date(anio, mes, min(int(dia_pago), ultimo_dia))


def _crear_notificacion_cliente(db: Session, cliente_id: str, titulo: str, cuerpo: str, tipo: str, caso: dict) -> None:
    db.execute(
        text(
            """INSERT INTO notificaciones
                 (id, destinatario_tipo, cliente_id, titulo, cuerpo, tipo, data_json)
               SELECT :id, 'cliente', :cliente_id, :titulo, :cuerpo, :tipo, CAST(:data AS jsonb)
               WHERE NOT EXISTS (
                   SELECT 1 FROM notificaciones
                   WHERE cliente_id = :cliente_id
                     AND data_json->>'numero_expediente' = :exp
                     AND tipo = :tipo
               )"""
        ),
        {
            "id": str(uuid.uuid4()),
            "cliente_id": cliente_id,
            "titulo": titulo,
            "cuerpo": cuerpo,
            "tipo": tipo,
            "data": json.dumps({"numero_expediente": caso["numero_expediente"]}),
            "exp": caso["numero_expediente"],
        },
    )


def _score_prioridad(caso: dict) -> int:
    if caso["prioridad"] == "alta" or caso["monto_solicitado"] >= 10000:
        return 90
    if caso["prioridad"] == "media" or caso["monto_solicitado"] >= 3000:
        return 65
    return 40


def _motivo_rechazo(caso: dict) -> str:
    if caso["en_lista_negra"]:
        return "Registrado en lista de inhabilitados del sistema financiero."
    if caso["pre_evaluacion"] != "APTO":
        return "Capacidad de pago insuficiente para el monto solicitado."
    return "Calificacion SBS con mora vigente no procede para otorgamiento."
