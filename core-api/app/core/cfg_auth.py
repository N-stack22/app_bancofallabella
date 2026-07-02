from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.cfg_security import decode_token

bearer = HTTPBearer(auto_error=True)


ROLE_ALIASES = {
    "operador": "asesor",
    "asesor": "asesor",
    "asesor_negocios": "asesor",
    "asesor de negocios": "asesor",
    "super operador": "supervisor",
    "supervisor": "supervisor",
    "comite": "comite",
    "comité": "comite",
    "analista": "analista",
    "analista_credito": "analista",
    "analista de credito": "analista",
    "administrador": "administrador",
    "admin": "administrador",
    "cliente": "cliente",
}


def normalize_role(value: str | None) -> str:
    raw = (value or "").strip().lower().replace("-", "_")
    return ROLE_ALIASES.get(raw, raw or "asesor")

def get_current_asesor(
    cred: HTTPAuthorizationCredentials = Depends(bearer),
) -> dict:
    """Devuelve el payload del asesor autenticado a partir del token Bearer."""
    payload = decode_token(cred.credentials)
    if not payload or "asesor_id" not in payload:
        raise HTTPException(status_code=401, detail="Token invalido o expirado")
    payload["perfil"] = normalize_role(payload.get("perfil"))
    return payload


def get_current_cliente(
    cred: HTTPAuthorizationCredentials = Depends(bearer),
) -> dict:
    """Devuelve el payload del cliente autenticado (app de clientes)."""
    payload = decode_token(cred.credentials)
    if not payload or "cliente_id" not in payload:
        raise HTTPException(status_code=401, detail="Token invalido o expirado")
    payload["perfil"] = "cliente"
    return payload


def require_roles(*roles: str):
    allowed = {normalize_role(role) for role in roles}

    def dependency(payload: dict = Depends(get_current_asesor)) -> dict:
        role = normalize_role(payload.get("perfil"))
        if role not in allowed:
            raise HTTPException(
                status_code=403,
                detail=f"Perfil '{role}' no autorizado para esta operacion",
            )
        payload["perfil"] = role
        return payload

    return dependency
