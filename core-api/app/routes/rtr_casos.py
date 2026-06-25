from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.core.cfg_database import get_db
from app.repositories import rep_casos

router = APIRouter()


@router.get("")
def listar_casos():
    """Catalogo de los 30 casos del PDF aplicado a Banco Falabella."""
    return rep_casos.listar()


@router.get("/dashboard")
def dashboard_casos():
    """Resumen ejecutivo sin depender de autenticacion."""
    return rep_casos.resumen()


@router.get("/conexion")
def conexion(db: Session = Depends(get_db)):
    """Diagnostico rapido de API REST + PostgreSQL bd_core_mobile."""
    bd_status = "ok"
    try:
        db.execute(text("SELECT 1")).scalar()
    except Exception:
        bd_status = "pendiente"
    return {
        "api": "ok",
        "bd_core_mobile": bd_status,
        "core_financiero": "sync_outbox",
        "marca": "Banco Falabella",
        "fecha_hora": datetime.now().isoformat(timespec="seconds"),
    }


@router.post("/sembrar")
def sembrar_casos(db: Session = Depends(get_db)):
    """Crea los 30 expedientes del flujo movil en la BD."""
    return rep_casos.sembrar(db)
