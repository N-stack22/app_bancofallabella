from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.mdl_asesores import Asesor

def get_by_codigo(db: Session, codigo_empleado: str) -> Asesor | None:
    codigo = normalizar_codigo_asesor(codigo_empleado)
    asesor = db.query(Asesor).filter(
        func.lower(Asesor.codigo_empleado) == codigo.lower()
    ).first()
    if asesor:
        return asesor
    try:
        return db.query(Asesor).filter(
            func.lower(Asesor.cod_asesor) == codigo.lower()
        ).first()
    except Exception:
        db.rollback()
        return None

def get_by_id(db: Session, asesor_id: str) -> Asesor | None:
    return db.query(Asesor).filter(Asesor.id == asesor_id).first()


def normalizar_codigo_asesor(codigo_empleado: str) -> str:
    raw = (codigo_empleado or "").strip().lower()
    digits = "".join(ch for ch in raw if ch.isdigit())
    if digits:
        return digits.zfill(4)
    return raw
