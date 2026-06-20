import json
import uuid
from datetime import datetime, timezone, date
from sqlalchemy.orm import Session
from sqlalchemy import desc, text
from app.models.mdl_cartera import CarteraDiaria
from app.models.mdl_clientes import Cliente


def primer_asesor_activo(db: Session) -> str | None:
    row = db.execute(
        text(
            """SELECT id
               FROM asesores
               WHERE activo = TRUE
               ORDER BY created_at NULLS LAST
               LIMIT 1"""
        )
    ).first()
    return str(row[0]) if row else None

def listar_por_asesor(db: Session, asesor_id: str, fecha: date) -> list[dict]:
    """Cartera del asesor para una fecha, ordenada por score (RF-09)."""
    filas = (
        db.query(CarteraDiaria, Cliente)
        .join(Cliente, Cliente.id == CarteraDiaria.cliente_id)
        .filter(
            CarteraDiaria.asesor_id == asesor_id,
            CarteraDiaria.fecha_asignacion == fecha,
        )
        .order_by(desc(CarteraDiaria.score_prioridad))
        .all()
    )
    resultado = []
    for c, cli in filas:
        solicitud = db.execute(
            text(
                """SELECT numero_expediente, created_at
                   FROM solicitudes_credito
                   WHERE cliente_id = :cliente_id
                   ORDER BY created_at DESC
                   LIMIT 1"""
            ),
            {"cliente_id": str(c.cliente_id)},
        ).mappings().first()
        resultado.append(
            {
            "id": str(c.id),
            "cliente_id": str(c.cliente_id),
            "cliente_nombre": f"{cli.nombres} {cli.apellidos}",
            "documento": cli.numero_documento,
            "numero_expediente": solicitud["numero_expediente"] if solicitud else None,
            "tipo_gestion": c.tipo_gestion,
            "prioridad": c.prioridad,
            "score_prioridad": c.score_prioridad or 0,
            "monto_credito": float(c.monto_credito or 0),
            "estado_visita": c.estado_visita,
            "orden_manual": c.orden_manual,
            "fecha_asignacion": c.fecha_asignacion.isoformat() if c.fecha_asignacion else None,
            "fecha_hora_solicitud": solicitud["created_at"].isoformat() if solicitud and solicitud["created_at"] else None,
            "timestamp_visita": c.timestamp_visita.isoformat() if c.timestamp_visita else None,
            "lat": float(cli.lat) if cli.lat is not None else None,
            "lng": float(cli.lng) if cli.lng is not None else None,
        }
        )
    return resultado

def marcar_visita(db: Session, asesor_id: str, cartera_id: str, data: dict) -> bool:
    fila = (
        db.query(CarteraDiaria)
        .filter(CarteraDiaria.id == cartera_id, CarteraDiaria.asesor_id == asesor_id)
        .first()
    )
    if not fila:
        return False
    fila.estado_visita = "visitado" if data["resultado"] == "visitado" else data["resultado"]
    fila.resultado_visita = data["resultado"]
    fila.observacion_visita = data.get("observacion", "")
    fila.timestamp_visita = datetime.now(timezone.utc)
    fila.lat_visita = data.get("lat")
    fila.lng_visita = data.get("lng")
    db.commit()
    return True

def enviar_comite(db: Session, asesor_id: str, cartera_id: str, data: dict) -> bool:
    fila = (
        db.query(CarteraDiaria)
        .filter(CarteraDiaria.id == cartera_id, CarteraDiaria.asesor_id == asesor_id)
        .first()
    )
    if not fila:
        return False

    solicitud = db.execute(
        text(
            """SELECT id
               FROM solicitudes_credito
               WHERE cliente_id = :cliente_id
               ORDER BY created_at DESC
               LIMIT 1"""
        ),
        {"cliente_id": str(fila.cliente_id)},
    ).mappings().first()
    if not solicitud:
        return False

    db.execute(
        text(
            """UPDATE solicitudes_credito
               SET estado = 'recibido_comite',
                   monto_aprobado = :monto,
                   plazo_meses = :plazo,
                   cuota_estimada = :cuota,
                   pendiente_sync = TRUE,
                   updated_at = now()
               WHERE id = :solicitud_id"""
        ),
        {
            "solicitud_id": str(solicitud["id"]),
            "monto": data.get("monto_propuesto") or 0,
            "plazo": data.get("plazo_meses") or 0,
            "cuota": data.get("cuota_estimada") or 0,
        },
    )
    fila.estado_visita = "visitado"
    fila.resultado_visita = "enviado_comite"
    fila.observacion_visita = data.get("observaciones", "")
    fila.timestamp_visita = datetime.now(timezone.utc)
    db.execute(
        text(
            """INSERT INTO sync_outbox (id, entidad, entidad_id, operacion, payload, estado)
               VALUES (:id, 'solicitudes_credito', :eid, 'update',
                       CAST(:payload AS jsonb), 'pendiente')"""
        ),
        {
            "id": str(uuid.uuid4()),
            "eid": str(solicitud["id"]),
            "payload": json.dumps(data),
        },
    )
    db.commit()
    return True


def historial_demo(db: Session) -> list[dict]:
    asesor_id = primer_asesor_activo(db)
    if asesor_id is None:
        return []
    rows = db.execute(
        text(
            """SELECT c.timestamp_visita, c.resultado_visita, c.observacion_visita,
                      cli.nombres, cli.apellidos, s.numero_expediente
               FROM cartera_diaria c
               JOIN clientes cli ON cli.id = c.cliente_id
               LEFT JOIN LATERAL (
                   SELECT numero_expediente
                   FROM solicitudes_credito
                   WHERE cliente_id = c.cliente_id
                   ORDER BY created_at DESC
                   LIMIT 1
               ) s ON TRUE
               WHERE c.asesor_id = :asesor_id
                 AND c.resultado_visita IS NOT NULL
               ORDER BY c.timestamp_visita DESC NULLS LAST
               LIMIT 20"""
        ),
        {"asesor_id": asesor_id},
    ).mappings().all()
    return [
        {
            "nombre_cliente": f"{r['nombres']} {r['apellidos']}",
            "numero_expediente": r["numero_expediente"],
            "fecha_visita": r["timestamp_visita"].isoformat() if r["timestamp_visita"] else None,
            "recomendacion_asesor": r["resultado_visita"],
            "segmento_resultante": r["observacion_visita"] or "core",
        }
        for r in rows
    ]
