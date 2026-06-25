from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from app.models.mdl_asesores import Asesor

def get_by_codigo(db: Session, codigo_empleado: str) -> Asesor | None:
    codigo = normalizar_codigo_asesor(codigo_empleado)
    return db.query(Asesor).filter(
        or_(
            func.lower(Asesor.codigo_empleado) == codigo.lower(),
            func.lower(Asesor.cod_asesor) == codigo.lower(),
        )
    ).first()

def get_by_id(db: Session, asesor_id: str) -> Asesor | None:
    return db.query(Asesor).filter(Asesor.id == asesor_id).first()


def normalizar_codigo_asesor(codigo_empleado: str) -> str:
    raw = (codigo_empleado or "").strip().lower()
    digits = "".join(ch for ch in raw if ch.isdigit())
    if digits:
        return digits.zfill(4)
    return raw
