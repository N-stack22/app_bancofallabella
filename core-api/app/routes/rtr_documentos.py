from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.cfg_auth import get_current_asesor
from app.core.cfg_database import get_db
from app.repositories import rep_solicitudes

router = APIRouter()


@router.delete("/{documento_id}")
def eliminar_documento(
    documento_id: str,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Elimina el registro documental del expediente."""
    if not rep_solicitudes.eliminar_documento(db, documento_id):
        raise HTTPException(status_code=404, detail="Documento no encontrado")
    return {"status": "ok", "documento_id": documento_id}
