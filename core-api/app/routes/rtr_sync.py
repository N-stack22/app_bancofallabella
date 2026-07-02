import json
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.core.cfg_database import get_db
from app.core.cfg_auth import get_current_asesor
from app.services import svc_promocion

router = APIRouter()


class SyncOperacionIn(BaseModel):
    entidad: str
    entidad_id: str | None = None
    operacion: str
    payload: dict


class SyncPendientesIn(BaseModel):
    operaciones: list[SyncOperacionIn]


@router.get("/bootstrap")
def bootstrap(
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Descarga inicial para cache offline de la app movil del asesor."""
    cartera = db.execute(
        text(
            """
            SELECT c.*, cli.numero_documento, cli.nombres, cli.apellidos,
                   cli.telefono, cli.direccion, cli.tipo_negocio,
                   cli.nombre_negocio, cli.lat, cli.lng
            FROM cartera_diaria c
            JOIN clientes cli ON cli.id = c.cliente_id
            WHERE c.asesor_id = CAST(:asesor AS uuid)
              AND c.fecha_asignacion >= CURRENT_DATE - INTERVAL '7 days'
            ORDER BY c.fecha_asignacion DESC, c.score_prioridad DESC
            """
        ),
        {"asesor": asesor["asesor_id"]},
    ).mappings().all()
    solicitudes = db.execute(
        text(
            """
            SELECT s.id, s.numero_expediente, s.cliente_id, s.estado,
                   s.monto_solicitado, s.monto_aprobado, s.created_at,
                   c.nombres, c.apellidos, c.numero_documento
            FROM solicitudes_credito s
            JOIN clientes c ON c.id = s.cliente_id
            WHERE s.asesor_id = CAST(:asesor AS uuid)
            ORDER BY s.created_at DESC
            LIMIT 100
            """
        ),
        {"asesor": asesor["asesor_id"]},
    ).mappings().all()
    return {
        "asesor": asesor,
        "cartera": [_safe_dict(r) for r in cartera],
        "solicitudes": [_safe_dict(r) for r in solicitudes],
    }


@router.post("/pendientes")
def recibir_pendientes(
    data: SyncPendientesIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Recibe cola offline del movil y la guarda en sync_outbox."""
    creadas = 0
    for op in data.operaciones:
        db.execute(
            text(
                """INSERT INTO sync_outbox
                     (id, entidad, entidad_id, operacion, payload, estado)
                   VALUES
                     (gen_random_uuid(), :entidad, :entidad_id, :operacion,
                      CAST(:payload AS jsonb), 'pendiente')"""
            ),
            {
                "entidad": op.entidad,
                "entidad_id": op.entidad_id,
                "operacion": op.operacion,
                "payload": json.dumps({
                    "asesor_id": asesor["asesor_id"],
                    **op.payload,
                }),
            },
        )
        creadas += 1
    db.commit()
    return {"status": "ok", "recibidas": creadas}


@router.post("/promover")
def promover(
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Promueve las solicitudes pendientes al nucleo bancario (bd_core_financiero)."""
    return svc_promocion.promover(db)


@router.get("/outbox")
def outbox(
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Estado de la cola de sincronizacion al core."""
    rows = db.execute(
        text(
            """SELECT entidad, operacion, estado, core_ref, intentos, ultimo_error,
                      created_at, procesado_at
               FROM sync_outbox ORDER BY created_at DESC LIMIT 50"""
        )
    ).mappings().all()
    return [dict(r) for r in rows]


@router.get("/outbox/demo")
def outbox_demo(db: Session = Depends(get_db)):
    """Vista demo de la cola de sincronizacion sin token para la practica."""
    rows = db.execute(
        text(
            """SELECT entidad, entidad_id, operacion, estado, payload,
                      created_at, procesado_at
               FROM sync_outbox ORDER BY created_at DESC LIMIT 20"""
        )
    ).mappings().all()
    return [dict(r) for r in rows]


def _safe_dict(row) -> dict:
    result = {}
    for key, value in dict(row).items():
        if hasattr(value, "isoformat"):
            result[key] = value.isoformat()
        else:
            result[key] = str(value) if value.__class__.__name__ == "UUID" else value
    return result
