from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.core.cfg_database import get_db
from app.core.cfg_auth import get_current_asesor
from app.schemas.sch_solicitudes import (
    DecisionComiteIn, DesembolsoIn, SolicitudIn, SolicitudCreada, SolicitudResumen,
)
from app.repositories import rep_solicitudes

router = APIRouter()


class NotaIn(BaseModel):
    contenido: str


class NotaOut(BaseModel):
    contenido: str
    created_at: str | None = None


@router.post("", response_model=SolicitudCreada)
def crear_solicitud(
    data: SolicitudIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Registra una solicitud de credito (M5 / HU-17)."""
    return rep_solicitudes.crear(
        db, asesor["asesor_id"], asesor.get("agencia_id"), data.model_dump()
    )


@router.get("", response_model=list[SolicitudResumen])
def listar_solicitudes(
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Historial de solicitudes del mes (HU-20) y tablero de estado (M9)."""
    return rep_solicitudes.listar(db, asesor["asesor_id"])


@router.get("/demo", response_model=list[SolicitudResumen])
def listar_solicitudes_demo(db: Session = Depends(get_db)):
    """Historial demo sin token para portal y Fuerza de Ventas web."""
    return rep_solicitudes.listar_demo(db)


@router.post("/demo/{solicitud_id}/comite")
def decidir_comite_demo(
    solicitud_id: str,
    data: DecisionComiteIn,
    db: Session = Depends(get_db),
):
    """Aprueba, condiciona o rechaza una solicitud recibida por comite."""
    try:
        result = rep_solicitudes.decidir_comite(db, solicitud_id, data.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if result is None:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return result


@router.post("/demo/{solicitud_id}/desembolso")
def desembolsar_demo(
    solicitud_id: str,
    data: DesembolsoIn,
    db: Session = Depends(get_db),
):
    """Marca como desembolsada y encola la sincronizacion al nucleo financiero."""
    try:
        result = rep_solicitudes.desembolsar(db, solicitud_id, data.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if result is None:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return result


@router.post("/{solicitud_id}/notas")
def agregar_nota(
    solicitud_id: str,
    data: NotaIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Agrega una nota interna a la solicitud (RF-72)."""
    return rep_solicitudes.agregar_nota(
        db, solicitud_id, asesor["asesor_id"], data.contenido
    )


@router.get("/{solicitud_id}/notas", response_model=list[NotaOut])
def listar_notas(
    solicitud_id: str,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Notas internas de la solicitud (RF-72)."""
    return rep_solicitudes.listar_notas(db, solicitud_id)
