from datetime import date
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.core.cfg_database import get_db
from app.core.cfg_auth import require_roles

router = APIRouter()


class ProductividadAsesor(BaseModel):
    asesor_nombre: str
    enviadas: int
    aprobadas: int
    desembolsadas: int
    monto_total: float
    tasa_aprobacion: float


@router.get("/productividad", response_model=list[ProductividadAsesor])
def productividad(
    agencia_id: str | None = None,
    asesor_id: str | None = None,
    fecha_desde: date | None = None,
    fecha_hasta: date | None = None,
    db: Session = Depends(get_db),
    asesor: dict = Depends(require_roles("supervisor", "administrador", "comite", "analista")),
):
    """Reporte historico de productividad por asesor (M11 / RF-80)."""
    rows = db.execute(
        text(
            """
            SELECT a.nombres || ' ' || a.apellidos AS asesor_nombre,
                   COUNT(*)                                            AS enviadas,
                   COUNT(*) FILTER (WHERE s.estado IN ('aprobado','desembolsado')) AS aprobadas,
                   COUNT(*) FILTER (WHERE s.estado = 'desembolsado')   AS desembolsadas,
                   COALESCE(SUM(s.monto_solicitado), 0)                AS monto_total
            FROM solicitudes_credito s
            JOIN asesores a ON a.id = s.asesor_id
            WHERE (:agencia_id IS NULL OR s.agencia_id = CAST(:agencia_id AS uuid))
              AND (:asesor_id IS NULL OR s.asesor_id = CAST(:asesor_id AS uuid))
              AND (:fecha_desde IS NULL OR s.created_at::date >= :fecha_desde)
              AND (:fecha_hasta IS NULL OR s.created_at::date <= :fecha_hasta)
            GROUP BY a.nombres, a.apellidos
            ORDER BY enviadas DESC
            """
        ),
        {
            "agencia_id": agencia_id,
            "asesor_id": asesor_id,
            "fecha_desde": fecha_desde,
            "fecha_hasta": fecha_hasta,
        },
    ).mappings().all()
    return [
        ProductividadAsesor(
            asesor_nombre=r["asesor_nombre"],
            enviadas=r["enviadas"],
            aprobadas=r["aprobadas"],
            desembolsadas=r["desembolsadas"],
            monto_total=float(r["monto_total"]),
            tasa_aprobacion=round(
                (r["aprobadas"] / r["enviadas"] * 100) if r["enviadas"] else 0, 1
            ),
        )
        for r in rows
    ]


@router.get("/cobertura")
def cobertura(
    agencia_id: str | None = None,
    asesor_id: str | None = None,
    fecha_desde: date | None = None,
    fecha_hasta: date | None = None,
    db: Session = Depends(get_db),
    asesor: dict = Depends(require_roles("supervisor", "administrador")),
):
    """Cobertura de visitas por asesor/agencia y rango de fechas."""
    rows = db.execute(
        text(
            """
            SELECT a.nombres || ' ' || a.apellidos AS asesor_nombre,
                   COUNT(*) AS asignados,
                   COUNT(*) FILTER (WHERE c.estado_visita <> 'pendiente') AS gestionados,
                   COUNT(*) FILTER (WHERE c.estado_visita = 'visitado') AS visitados
            FROM cartera_diaria c
            JOIN asesores a ON a.id = c.asesor_id
            WHERE (:agencia_id IS NULL OR c.agencia_id = CAST(:agencia_id AS uuid))
              AND (:asesor_id IS NULL OR c.asesor_id = CAST(:asesor_id AS uuid))
              AND (:fecha_desde IS NULL OR c.fecha_asignacion >= :fecha_desde)
              AND (:fecha_hasta IS NULL OR c.fecha_asignacion <= :fecha_hasta)
            GROUP BY a.nombres, a.apellidos
            ORDER BY gestionados DESC
            """
        ),
        {
            "agencia_id": agencia_id,
            "asesor_id": asesor_id,
            "fecha_desde": fecha_desde,
            "fecha_hasta": fecha_hasta,
        },
    ).mappings().all()
    return [
        {
            "asesor_nombre": r["asesor_nombre"],
            "asignados": r["asignados"],
            "gestionados": r["gestionados"],
            "visitados": r["visitados"],
            "cobertura_pct": round((r["gestionados"] / r["asignados"] * 100) if r["asignados"] else 0, 1),
        }
        for r in rows
    ]


@router.get("/solicitudes")
def solicitudes(
    agencia_id: str | None = None,
    asesor_id: str | None = None,
    estado: str | None = None,
    fecha_desde: date | None = None,
    fecha_hasta: date | None = None,
    db: Session = Depends(get_db),
    asesor: dict = Depends(require_roles("supervisor", "administrador", "comite", "analista")),
):
    """Resumen de solicitudes por estado con filtros operativos."""
    rows = db.execute(
        text(
            """
            SELECT estado, COUNT(*) AS total,
                   COALESCE(SUM(monto_solicitado), 0) AS monto_solicitado,
                   COALESCE(SUM(monto_aprobado), 0) AS monto_aprobado
            FROM solicitudes_credito
            WHERE (:agencia_id IS NULL OR agencia_id = CAST(:agencia_id AS uuid))
              AND (:asesor_id IS NULL OR asesor_id = CAST(:asesor_id AS uuid))
              AND (:estado IS NULL OR estado = :estado)
              AND (:fecha_desde IS NULL OR created_at::date >= :fecha_desde)
              AND (:fecha_hasta IS NULL OR created_at::date <= :fecha_hasta)
            GROUP BY estado
            ORDER BY total DESC
            """
        ),
        {
            "agencia_id": agencia_id,
            "asesor_id": asesor_id,
            "estado": estado,
            "fecha_desde": fecha_desde,
            "fecha_hasta": fecha_hasta,
        },
    ).mappings().all()
    return [
        {
            "estado": r["estado"],
            "total": r["total"],
            "monto_solicitado": float(r["monto_solicitado"] or 0),
            "monto_aprobado": float(r["monto_aprobado"] or 0),
        }
        for r in rows
    ]
