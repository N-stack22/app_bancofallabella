from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.cfg_database import get_db
from app.core.cfg_auth import get_current_asesor
from app.schemas.sch_ficha import ClienteResumenOut, FichaOut, UbicacionIn
from app.repositories import rep_ficha

router = APIRouter()


@router.get("", response_model=list[ClienteResumenOut])
def listar_clientes(
    q: str | None = None,
    limit: int = 200,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Lista clientes del core para reflejar la tabla public.clientes en backoffice."""
    return rep_ficha.listar_clientes(db, q=q, limit=limit)


@router.get("/{cliente_id}/ficha", response_model=FichaOut)
def ficha_cliente(
    cliente_id: str,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Ficha completa del cliente (M3 / HU-11)."""
    ficha = rep_ficha.obtener_ficha(db, cliente_id)
    if ficha is None:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    return ficha


@router.post("/{cliente_id}/ubicacion")
def actualizar_ubicacion(
    cliente_id: str,
    body: UbicacionIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Actualiza las coordenadas del negocio del cliente (HU-10 / RF-25/26)."""
    ok = rep_ficha.actualizar_ubicacion(
        db, cliente_id, body.lat, body.lng, body.direccion
    )
    if not ok:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    return {"ok": True, "lat": body.lat, "lng": body.lng}
