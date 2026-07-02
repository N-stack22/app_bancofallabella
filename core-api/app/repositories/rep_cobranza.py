from datetime import datetime, timezone
import uuid
from sqlalchemy import text
from sqlalchemy.orm import Session


def listar_mora(db: Session, asesor_id: str | None = None) -> list[dict]:
    """Clientes con cuotas vencidas, ordenados por dias de mora desc (RF-75)."""
    rows = db.execute(
        text(
            """
            SELECT DISTINCT cr.id, cr.cod_cuenta_credito, cr.cliente_id, cr.dias_mora,
                   cr.saldo_total, c.nombres, c.apellidos, c.numero_documento,
                   c.telefono
            FROM cr_creditos cr
            JOIN clientes c ON c.id = cr.cliente_id
            LEFT JOIN cartera_diaria cd ON cd.cliente_id = c.id
            WHERE cr.dias_mora > 0
              AND (:asesor_id IS NULL OR cd.asesor_id = CAST(:asesor_id AS uuid))
            ORDER BY cr.dias_mora DESC
            """
        ),
        {"asesor_id": asesor_id},
    ).mappings().all()
    return [
        {
            "id": str(r["id"]),
            "cod_cuenta_credito": r["cod_cuenta_credito"],
            "cliente_id": str(r["cliente_id"]),
            "cliente_nombre": f"{r['nombres']} {r['apellidos']}",
            "documento": r["numero_documento"],
            "telefono": r["telefono"],
            "dias_mora": r["dias_mora"],
            "monto_vencido": float(r["saldo_total"] or 0),
        }
        for r in rows
    ]


def listar_por_cliente(db: Session, cliente_id: str) -> list[dict]:
    rows = db.execute(
        text(
            """
            SELECT id, asesor_id, cliente_id, cod_cuenta_credito, tipo_gestion,
                   resultado, monto_pagado, fecha_compromiso, monto_compromiso,
                   observaciones, lat, lng, timestamp_gestion
            FROM acciones_cobranza
            WHERE cliente_id = :cliente_id
            ORDER BY timestamp_gestion DESC
            """
        ),
        {"cliente_id": cliente_id},
    ).mappings().all()
    return [
        {
            "id": str(r["id"]),
            "asesor_id": str(r["asesor_id"]) if r["asesor_id"] else None,
            "cliente_id": str(r["cliente_id"]),
            "cod_cuenta_credito": r["cod_cuenta_credito"],
            "tipo_gestion": r["tipo_gestion"],
            "resultado": r["resultado"],
            "monto_pagado": float(r["monto_pagado"] or 0),
            "fecha_compromiso": r["fecha_compromiso"].isoformat() if r["fecha_compromiso"] else None,
            "monto_compromiso": float(r["monto_compromiso"] or 0),
            "observaciones": r["observaciones"],
            "lat": float(r["lat"]) if r["lat"] is not None else None,
            "lng": float(r["lng"]) if r["lng"] is not None else None,
            "timestamp_gestion": r["timestamp_gestion"].isoformat()
            if r["timestamp_gestion"]
            else None,
        }
        for r in rows
    ]


def registrar_accion(db: Session, asesor_id: str, d: dict) -> None:
    """Registra una gestion de cobranza (RF-77)."""
    db.execute(
        text(
            """
            INSERT INTO acciones_cobranza
              (id, asesor_id, cliente_id, cod_cuenta_credito, tipo_gestion,
               resultado, monto_pagado, fecha_compromiso, monto_compromiso,
               observaciones, lat, lng, timestamp_gestion)
            VALUES (:id,:asesor,:cli,:cod,:tipo,:res,:mp,:fc,:mc,:obs,:lat,:lng,:ts)
            """
        ),
        {
            "id": str(uuid.uuid4()),
            "asesor": asesor_id,
            "cli": d["cliente_id"],
            "cod": d.get("cod_cuenta_credito"),
            "tipo": d["tipo_gestion"],
            "res": d["resultado"],
            "mp": d.get("monto_pagado"),
            "fc": d.get("fecha_compromiso"),
            "mc": d.get("monto_compromiso"),
            "obs": d.get("observaciones", ""),
            "lat": d.get("lat"),
            "lng": d.get("lng"),
            "ts": datetime.now(timezone.utc),
        },
    )
    db.commit()
