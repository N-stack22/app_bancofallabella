from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.cfg_database import get_db
from app.schemas.sch_auth import LoginIn, TokenOut
from app.controllers import ctl_auth

router = APIRouter()

@router.post("/login", response_model=TokenOut)
def login(data: LoginIn, db: Session = Depends(get_db)):
    try:
        result = ctl_auth.login(db, data.codigo_empleado, data.password)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=503,
            detail="No se pudo validar el codigo en el Core publicado.",
        )
    if result and result.get("_bloqueado"):
        raise HTTPException(
            status_code=423,
            detail=f"Cuenta bloqueada por intentos fallidos hasta {result['hasta']}",
        )
    if not result:
        raise HTTPException(status_code=401, detail="Credenciales invalidas")
    return result
