from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.cfg_database import get_db
from app.core.cfg_auth import get_current_asesor
from app.schemas.sch_cartera import CarteraItemOut, EnviarComiteIn, MarcarVisitaIn
from app.repositories import rep_cartera

router = APIRouter()

@router.get("", response_model=list[CarteraItemOut])
def listar_cartera(
    fecha: date | None = None,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Cartera del dia del asesor autenticado (RF-04/RF-09)."""
    f = fecha or date.today()
    return rep_cartera.listar_por_asesor(db, asesor["asesor_id"], f)

@router.post("/{cartera_id}/visita")
def marcar_visita(
    cartera_id: str,
    data: MarcarVisitaIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Registra el resultado de una visita (RF-07/RF-17)."""
    ok = rep_cartera.marcar_visita(db, asesor["asesor_id"], cartera_id, data.model_dump())
    if not ok:
        raise HTTPException(status_code=404, detail="Item de cartera no encontrado")
    return {"status": "ok", "cartera_id": cartera_id, "estado_visita": data.resultado}


@router.get("/demo", response_model=list[CarteraItemOut])
def listar_cartera_demo(
    fecha: date | None = None,
    db: Session = Depends(get_db),
):
    """Cartera demo para integrar Flutter sin token durante la practica."""
    asesor = rep_cartera.primer_asesor_activo(db)
    if asesor is None:
        return []
    return rep_cartera.listar_por_asesor(db, asesor, fecha or date.today())


@router.post("/demo/{cartera_id}/visita")
def marcar_visita_demo(
    cartera_id: str,
    data: MarcarVisitaIn,
    db: Session = Depends(get_db),
):
    """Registra visita demo sin token para el flujo movil de examen."""
    asesor = rep_cartera.primer_asesor_activo(db)
    if asesor is None:
        raise HTTPException(status_code=404, detail="Asesor demo no encontrado")
    ok = rep_cartera.marcar_visita(db, asesor, cartera_id, data.model_dump())
    if not ok:
        raise HTTPException(status_code=404, detail="Item de cartera no encontrado")
    return {"status": "ok", "cartera_id": cartera_id, "estado_visita": data.resultado}


@router.post("/demo/{cartera_id}/comite")
def enviar_comite_demo(
    cartera_id: str,
    data: EnviarComiteIn,
    db: Session = Depends(get_db),
):
    """Envia la evaluacion de campo al comite para el flujo movil de examen."""
    asesor = rep_cartera.primer_asesor_activo(db)
    if asesor is None:
        raise HTTPException(status_code=404, detail="Asesor demo no encontrado")
    ok = rep_cartera.enviar_comite(db, asesor, cartera_id, data.model_dump())
    if not ok:
        raise HTTPException(status_code=404, detail="Item de cartera o solicitud no encontrado")
    return {"status": "ok", "cartera_id": cartera_id, "estado": "recibido_comite"}


@router.get("/demo/historial")
def historial_visitas_demo(db: Session = Depends(get_db)):
    """Historial demo de fichas/evaluaciones enviadas."""
    return rep_cartera.historial_demo(db)
