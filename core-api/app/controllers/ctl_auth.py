from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
from app.core.cfg_security import verify_password, create_access_token
from app.repositories import rep_asesores

MAX_INTENTOS = 5
BLOQUEO_MIN = 30

def login(db: Session, codigo_empleado: str, password: str) -> dict | None:
    codigo = rep_asesores.normalizar_codigo_asesor(codigo_empleado)
    asesor = rep_asesores.get_by_codigo(db, codigo)
    if not asesor or not asesor.activo:
        return None

    # Bloqueo por intentos fallidos (RF-04)
    ahora = datetime.now(timezone.utc)
    bloqueado_hasta = asesor.bloqueado_hasta
    if bloqueado_hasta and bloqueado_hasta.tzinfo is None:
        bloqueado_hasta = bloqueado_hasta.replace(tzinfo=timezone.utc)
    if bloqueado_hasta and bloqueado_hasta > ahora:
        return {"_bloqueado": True, "hasta": bloqueado_hasta.isoformat()}

    if not verify_password(password, asesor.password_hash):
        asesor.intentos_fallidos = (asesor.intentos_fallidos or 0) + 1
        if asesor.intentos_fallidos >= MAX_INTENTOS:
            asesor.bloqueado_hasta = ahora + timedelta(minutes=BLOQUEO_MIN)
        db.commit()
        return None

    # Login correcto: resetea contador
    asesor.intentos_fallidos = 0
    asesor.bloqueado_hasta = None
    db.commit()

    token = create_access_token({
        "sub": asesor.codigo_empleado,
        "asesor_id": str(asesor.id),
        "perfil": asesor.perfil,
        "nombre": f"{asesor.nombres} {asesor.apellidos}",
    })
    return {
        "access_token": token,
        "token_type": "bearer",
        "asesor": {
            "id": str(asesor.id),
            "codigo_empleado": asesor.codigo_empleado,
            "nombres": asesor.nombres,
            "apellidos": asesor.apellidos,
            "perfil": asesor.perfil,
            "agencia_id": str(asesor.agencia_id) if asesor.agencia_id else None,
        },
    }
