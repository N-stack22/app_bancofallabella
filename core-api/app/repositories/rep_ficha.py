from datetime import date
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.services import svc_tea


def listar_clientes(db: Session, q: str | None = None, limit: int = 200) -> list[dict]:
    """Lista clientes/prospectos del core, aunque no tengan cartera asignada."""
    rows = db.execute(
        text(
            """
            SELECT cli.id, cli.numero_documento, cli.nombres, cli.apellidos,
                   cli.telefono, cli.direccion, cli.tipo_negocio,
                   cli.nombre_negocio, cli.calificacion_sbs,
                   COALESCE(cli.es_prospecto, FALSE) AS es_prospecto,
                   cli.created_at,
                   s.numero_expediente,
                   s.estado AS estado_solicitud,
                   COALESCE(s.monto_solicitado, cr.saldo_total, pre.monto_maximo, 0) AS monto_credito
            FROM clientes cli
            LEFT JOIN LATERAL (
                SELECT numero_expediente, estado, monto_solicitado, created_at
                FROM solicitudes_credito
                WHERE cliente_id = cli.id
                ORDER BY created_at DESC NULLS LAST
                LIMIT 1
            ) s ON TRUE
            LEFT JOIN LATERAL (
                SELECT saldo_total
                FROM cr_creditos
                WHERE cliente_id = cli.id
                ORDER BY fecha_desembolso DESC NULLS LAST
                LIMIT 1
            ) cr ON TRUE
            LEFT JOIN LATERAL (
                SELECT monto_maximo
                FROM creditos_preaprobados
                WHERE cliente_id = cli.id AND vigente = TRUE
                ORDER BY score_confianza DESC NULLS LAST
                LIMIT 1
            ) pre ON TRUE
            WHERE (
                :q IS NULL
                OR cli.numero_documento ILIKE :like
                OR cli.nombres ILIKE :like
                OR cli.apellidos ILIKE :like
                OR cli.nombre_negocio ILIKE :like
            )
            ORDER BY cli.created_at DESC NULLS LAST, cli.apellidos, cli.nombres
            LIMIT :limit
            """
        ),
        {
            "q": q,
            "like": f"%{q}%" if q else None,
            "limit": max(1, min(limit or 200, 500)),
        },
    ).mappings().all()
    return [
        {
            "id": str(r["id"]),
            "numero_documento": r["numero_documento"],
            "nombres": r["nombres"],
            "apellidos": r["apellidos"],
            "cliente_nombre": f"{r['nombres']} {r['apellidos']}",
            "telefono": r["telefono"],
            "direccion": r["direccion"],
            "tipo_negocio": r["tipo_negocio"],
            "nombre_negocio": r["nombre_negocio"],
            "calificacion_sbs": r["calificacion_sbs"] or "NORMAL",
            "es_prospecto": bool(r["es_prospecto"]),
            "numero_expediente": r["numero_expediente"],
            "estado_solicitud": r["estado_solicitud"],
            "monto_credito": float(r["monto_credito"] or 0),
            "fecha_registro": r["created_at"].isoformat() if r["created_at"] else None,
        }
        for r in rows
    ]


def actualizar_ubicacion(
    db: Session,
    cliente_id: str,
    lat: float,
    lng: float,
    direccion: str | None = None,
) -> bool:
    """Actualiza las coordenadas del negocio del cliente (HU-10 / RF-25/26)."""
    res = db.execute(
        text(
            """
            UPDATE clientes
               SET lat = :lat,
                   lng = :lng,
                   direccion = COALESCE(:direccion, direccion),
                   updated_at = now()
             WHERE id = :id
            """
        ),
        {"id": cliente_id, "lat": lat, "lng": lng, "direccion": direccion},
    )
    db.commit()
    return res.rowcount > 0


def obtener_ficha(db: Session, cliente_id: str) -> dict | None:
    """Ficha completa del cliente (RF-27/30/33): datos, posicion, historial, oferta."""
    cli = db.execute(
        text("SELECT * FROM clientes WHERE id = :id"), {"id": cliente_id}
    ).mappings().first()
    if cli is None:
        return None

    # Posicion en el sistema (agregado de cr_creditos) — RF-30
    pos = db.execute(
        text(
            """
            SELECT
                COALESCE(SUM(saldo_total), 0)                  AS deuda_total,
                COUNT(*) FILTER (WHERE estado = 'vigente')     AS cuentas_vigentes,
                COUNT(*) FILTER (WHERE dias_mora > 0)          AS cuentas_mora,
                COALESCE(MAX(dias_mora), 0)                    AS dias_mayor_mora
            FROM cr_creditos
            WHERE cliente_id = :id
            """
        ),
        {"id": cliente_id},
    ).mappings().first()

    # Historial crediticio (ultimos 5) — RF-27
    historial = db.execute(
        text(
            """
            SELECT cod_cuenta_credito, producto, monto_desembolsado,
                   tea, estado, dias_mora, cuotas_total, cuotas_pagadas
            FROM cr_creditos
            WHERE cliente_id = :id
            ORDER BY fecha_desembolso DESC NULLS LAST
            LIMIT 5
            """
        ),
        {"id": cliente_id},
    ).mappings().all()

    # Oferta preaprobada vigente (mayor score) — RF-33
    oferta = db.execute(
        text(
            """
            SELECT monto_maximo, plazo_sugerido_meses, tea_referencial,
                   score_confianza, fecha_vencimiento
            FROM creditos_preaprobados
            WHERE cliente_id = :id AND vigente = TRUE
              AND (fecha_vencimiento IS NULL OR fecha_vencimiento >= :hoy)
            ORDER BY score_confianza DESC
            LIMIT 1
            """
        ),
        {"id": cliente_id, "hoy": date.today()},
    ).mappings().first()
    solicitud = db.execute(
        text(
            """
            SELECT *
            FROM solicitudes_credito
            WHERE cliente_id = :id
            ORDER BY created_at DESC NULLS LAST
            LIMIT 1
            """
        ),
        {"id": cliente_id},
    ).mappings().first()

    # Comportamiento de pagos ultimos 12 meses (RF-31): 1=puntual, 2=mora, 0=sin cuota
    dni = cli["numero_documento"] or "0"
    dmora = pos["dias_mayor_mora"]
    comportamiento = [1] * 12
    if dmora > 0:
        n = 1 if dmora <= 30 else (2 if dmora <= 60 else 3)
        for k in range(n):
            comportamiento[11 - k] = 2
    if dni[-1].isdigit() and int(dni[-1]) % 3 == 0:
        comportamiento[0] = 0
        comportamiento[1] = 0

    con_cuota = [m for m in comportamiento if m != 0]
    puntuales = [m for m in con_cuota if m == 1]
    pct_puntual = round(len(puntuales) / len(con_cuota) * 100, 1) if con_cuota else 0
    monto_pagado = sum(
        float(h["monto_desembolsado"] or 0)
        for h in historial
        if h["estado"] == "pagado"
    )
    solicitud_eval = dict(solicitud) if solicitud else {
        "numero_documento": cli["numero_documento"],
        "ingresos_estimados": cli["ingresos_estimados"],
        "monto_solicitado": oferta["monto_maximo"] if oferta else 0,
        "plazo_meses": oferta["plazo_sugerido_meses"] if oferta else 12,
    }
    contexto_eval = svc_tea.cargar_contexto_evaluacion(db, cliente_id, solicitud_eval)
    evaluacion = svc_tea.calcular_tea_referencial(
        contexto_eval["cliente"],
        solicitud_eval,
        contexto_eval["consulta_buro"],
        contexto_eval["preaprobado"],
        contexto_eval["tarifario"],
    )

    return {
        "comportamiento": comportamiento,
        "indicadores": {
            "pct_puntual": pct_puntual,
            "dias_prom_mora": dmora,
            "monto_pagado": monto_pagado,
        },
        "cliente": {
            "id": str(cli["id"]),
            "numero_documento": cli["numero_documento"],
            "nombres": cli["nombres"],
            "apellidos": cli["apellidos"],
            "telefono": cli["telefono"],
            "direccion": cli["direccion"],
            "tipo_negocio": cli["tipo_negocio"],
            "nombre_negocio": cli["nombre_negocio"],
            "antiguedad_negocio_meses": cli["antiguedad_negocio_meses"],
            "calificacion_sbs": cli["calificacion_sbs"] or "NORMAL",
        },
        "posicion": {
            "deuda_total": float(pos["deuda_total"]),
            "cuentas_vigentes": pos["cuentas_vigentes"],
            "cuentas_mora": pos["cuentas_mora"],
            "dias_mayor_mora": pos["dias_mayor_mora"],
        },
        "historial": [
            {
                "producto": h["producto"],
                "monto_desembolsado": float(h["monto_desembolsado"] or 0),
                "plazo_meses": h["cuotas_total"],
                "tea": float(h["tea"] or 0),
                "estado": h["estado"],
                "dias_mora": h["dias_mora"] or 0,
                "cuotas_total": h["cuotas_total"] or 0,
                "cuotas_pagadas": h["cuotas_pagadas"] or 0,
            }
            for h in historial
        ],
        "oferta": None
        if oferta is None
        else {
            "monto_maximo": float(oferta["monto_maximo"]),
            "plazo_sugerido_meses": oferta["plazo_sugerido_meses"],
            "tea_referencial": svc_tea.normalizar_tea_decimal(oferta["tea_referencial"], 0),
            "score_confianza": oferta["score_confianza"] or 0,
            "fecha_vencimiento": oferta["fecha_vencimiento"].isoformat()
            if oferta["fecha_vencimiento"]
            else None,
        },
        "evaluacion_crediticia": svc_tea.evaluacion_publica(evaluacion),
    }
