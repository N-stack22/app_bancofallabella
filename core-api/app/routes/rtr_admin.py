import json
import uuid
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.core.cfg_auth import require_roles
from app.core.cfg_database import get_db
from app.core.cfg_security import hash_password

router = APIRouter()


class UsuarioIn(BaseModel):
    codigo_empleado: str
    nombres: str
    apellidos: str
    agencia_id: str | None = None
    perfil: str = "asesor"
    password: str | None = None
    activo: bool = True


class AgenciaIn(BaseModel):
    cod_agencia: str
    nombre: str
    region: str | None = None
    activa: bool = True


class CatalogoIn(BaseModel):
    tipo: str
    codigo: str
    nombre: str
    valor_json: dict | None = None
    activo: bool = True


@router.get("/roles")
def roles(admin: dict = Depends(require_roles("administrador"))):
    return [
        {"codigo": "asesor", "nombre": "Asesor / Operador"},
        {"codigo": "comite", "nombre": "Comite"},
        {"codigo": "analista", "nombre": "Analista de credito"},
        {"codigo": "supervisor", "nombre": "Supervisor"},
        {"codigo": "administrador", "nombre": "Administrador"},
    ]


@router.get("/usuarios")
def listar_usuarios(
    db: Session = Depends(get_db),
    admin: dict = Depends(require_roles("administrador")),
):
    rows = db.execute(
        text(
            """SELECT a.id, a.codigo_empleado, a.nombres, a.apellidos,
                      a.agencia_id, ag.nombre AS agencia, a.perfil, a.activo,
                      a.created_at
               FROM asesores a
               LEFT JOIN agencias ag ON ag.id = a.agencia_id
               ORDER BY a.created_at DESC NULLS LAST"""
        )
    ).mappings().all()
    return [_safe(row) for row in rows]


@router.post("/usuarios")
def crear_usuario(
    data: UsuarioIn,
    db: Session = Depends(get_db),
    admin: dict = Depends(require_roles("administrador")),
):
    usuario_id = str(uuid.uuid4())
    db.execute(
        text(
            """INSERT INTO asesores
                 (id, cod_asesor, codigo_empleado, nombres, apellidos,
                  agencia_id, perfil, password_hash, activo)
               VALUES
                 (:id, :cod, :codigo, :nombres, :apellidos,
                  CAST(:agencia AS uuid), :perfil, :password_hash, :activo)"""
        ),
        {
            "id": usuario_id,
            "cod": f"A{data.codigo_empleado}",
            "codigo": data.codigo_empleado,
            "nombres": data.nombres,
            "apellidos": data.apellidos,
            "agencia": data.agencia_id,
            "perfil": data.perfil,
            "password_hash": hash_password(data.password or data.codigo_empleado),
            "activo": data.activo,
        },
    )
    db.commit()
    return {"id": usuario_id, "status": "ok"}


@router.patch("/usuarios/{usuario_id}")
def actualizar_usuario(
    usuario_id: str,
    data: UsuarioIn,
    db: Session = Depends(get_db),
    admin: dict = Depends(require_roles("administrador")),
):
    result = db.execute(
        text(
            """UPDATE asesores
               SET codigo_empleado=:codigo,
                   nombres=:nombres,
                   apellidos=:apellidos,
                   agencia_id=CAST(:agencia AS uuid),
                   perfil=:perfil,
                   activo=:activo
               WHERE id=:id"""
        ),
        {
            "id": usuario_id,
            "codigo": data.codigo_empleado,
            "nombres": data.nombres,
            "apellidos": data.apellidos,
            "agencia": data.agencia_id,
            "perfil": data.perfil,
            "activo": data.activo,
        },
    )
    db.commit()
    if not result.rowcount:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {"status": "ok", "id": usuario_id}


@router.get("/agencias")
def listar_agencias(
    db: Session = Depends(get_db),
    admin: dict = Depends(require_roles("administrador")),
):
    rows = db.execute(
        text("SELECT * FROM agencias ORDER BY nombre ASC")
    ).mappings().all()
    return [_safe(row) for row in rows]


@router.post("/agencias")
def crear_agencia(
    data: AgenciaIn,
    db: Session = Depends(get_db),
    admin: dict = Depends(require_roles("administrador")),
):
    agencia_id = str(uuid.uuid4())
    db.execute(
        text(
            """INSERT INTO agencias (id, cod_agencia, nombre, region, activa)
               VALUES (:id, :cod, :nombre, :region, :activa)"""
        ),
        {
            "id": agencia_id,
            "cod": data.cod_agencia,
            "nombre": data.nombre,
            "region": data.region,
            "activa": data.activa,
        },
    )
    db.commit()
    return {"id": agencia_id, "status": "ok"}


@router.get("/catalogos")
def listar_catalogos(
    tipo: str | None = None,
    db: Session = Depends(get_db),
    admin: dict = Depends(require_roles("administrador")),
):
    rows = db.execute(
        text(
            """SELECT id, tipo, codigo, nombre, valor_json, activo, created_at
               FROM catalogos
               WHERE (:tipo IS NULL OR tipo = :tipo)
               ORDER BY tipo, nombre"""
        ),
        {"tipo": tipo},
    ).mappings().all()
    return [_safe(row) for row in rows]


@router.post("/catalogos")
def crear_catalogo(
    data: CatalogoIn,
    db: Session = Depends(get_db),
    admin: dict = Depends(require_roles("administrador")),
):
    catalogo_id = str(uuid.uuid4())
    db.execute(
        text(
            """INSERT INTO catalogos (id, tipo, codigo, nombre, valor_json, activo)
               VALUES (:id, :tipo, :codigo, :nombre, CAST(:valor AS jsonb), :activo)"""
        ),
        {
            "id": catalogo_id,
            "tipo": data.tipo,
            "codigo": data.codigo,
            "nombre": data.nombre,
            "valor": json.dumps(data.valor_json or {}),
            "activo": data.activo,
        },
    )
    db.commit()
    return {"id": catalogo_id, "status": "ok"}


def _safe(row) -> dict:
    out = {}
    for key, value in dict(row).items():
        if hasattr(value, "isoformat"):
            out[key] = value.isoformat()
        elif value.__class__.__name__ == "UUID":
            out[key] = str(value)
        else:
            out[key] = value
    return out
