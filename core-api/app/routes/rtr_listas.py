from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.cfg_auth import get_current_asesor
from app.core.cfg_database import get_db
from app.routes.rtr_buro import BuroIn, consulta_buro

router = APIRouter()


@router.post("/verificar")
def verificar_listas(
    data: BuroIn,
    asesor: dict = Depends(get_current_asesor),
    db: Session = Depends(get_db),
):
    """Alias de verificacion de listas negras usando el motor mock de buro."""
    return consulta_buro(data, asesor, db)
