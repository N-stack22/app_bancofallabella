from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.core.cfg_database import get_db
from app.core.cfg_auth import get_current_asesor, require_roles
from app.schemas.sch_solicitudes import (
    DecisionComiteIn, DesembolsoIn, DocumentoSolicitudIn, EstadoSolicitudIn,
    SolicitudIn, SolicitudCreada, SolicitudResumen,
)
from app.repositories import rep_solicitudes, rep_casos

router = APIRouter()


class NotaIn(BaseModel):
    contenido: str


class NotaOut(BaseModel):
    contenido: str
    created_at: str | None = None


@router.post("", response_model=SolicitudCreada)
def crear_solicitud(
    data: SolicitudIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Registra una solicitud de credito (M5 / HU-17)."""
    return rep_solicitudes.crear(
        db, asesor["asesor_id"], asesor.get("agencia_id"), data.model_dump()
    )


@router.get("", response_model=list[SolicitudResumen])
def listar_solicitudes(
    fecha_desde: date | None = None,
    fecha_hasta: date | None = None,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Historial de solicitudes y tablero de estado (M9), con filtros opcionales."""
    backoffice = {"comite", "analista", "supervisor", "administrador"}
    asesor_id = None if asesor.get("perfil") in backoffice else asesor["asesor_id"]
    return rep_solicitudes.listar(db, asesor_id, fecha_desde, fecha_hasta)


@router.get("/detalle/{solicitud_id}")
def detalle_solicitud(
    solicitud_id: str,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Detalle completo del expediente: cliente, negocio, documentos, buro y notas."""
    result = rep_solicitudes.obtener_detalle(db, solicitud_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return result


@router.post("/{solicitud_id}/enviar")
def enviar_a_comite(
    solicitud_id: str,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Envia una solicitud borrador/enviada a bandeja de comite."""
    try:
        result = rep_solicitudes.enviar_comite(db, solicitud_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if result is None:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return result


@router.patch("/{solicitud_id}/estado")
def cambiar_estado(
    solicitud_id: str,
    data: EstadoSolicitudIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(require_roles("comite", "analista", "supervisor", "administrador")),
):
    """Cambia el estado de una solicitud con permisos de decision/control."""
    try:
        result = rep_solicitudes.actualizar_estado(
            db,
            solicitud_id,
            data.model_dump(),
            asesor.get("nombre") or asesor.get("sub"),
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if result is None:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return result


@router.patch("/{solicitud_id}/aprobar")
def aprobar(
    solicitud_id: str,
    data: DecisionComiteIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(require_roles("comite", "analista", "supervisor", "administrador")),
):
    payload = data.model_dump()
    payload["decision"] = "aprobado"
    try:
        result = rep_solicitudes.decidir_comite(
            db, solicitud_id, payload, asesor.get("nombre") or asesor.get("sub")
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if result is None:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return result


@router.patch("/{solicitud_id}/rechazar")
def rechazar(
    solicitud_id: str,
    data: DecisionComiteIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(require_roles("comite", "analista", "supervisor", "administrador")),
):
    payload = data.model_dump()
    payload["decision"] = "rechazado"
    try:
        result = rep_solicitudes.decidir_comite(
            db, solicitud_id, payload, asesor.get("nombre") or asesor.get("sub")
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if result is None:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return result


@router.patch("/{solicitud_id}/condicionar")
def condicionar(
    solicitud_id: str,
    data: DecisionComiteIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(require_roles("comite", "analista", "supervisor", "administrador")),
):
    payload = data.model_dump()
    payload["decision"] = "condicionado"
    try:
        result = rep_solicitudes.decidir_comite(
            db, solicitud_id, payload, asesor.get("nombre") or asesor.get("sub")
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if result is None:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return result


@router.post("/{solicitud_id}/documentos")
def agregar_documento(
    solicitud_id: str,
    data: DocumentoSolicitudIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Registra la URL/ruta de storage de un documento del expediente."""
    return rep_solicitudes.agregar_documento(db, solicitud_id, data.model_dump())


@router.get("/{solicitud_id}/documentos")
def listar_documentos(
    solicitud_id: str,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    return rep_solicitudes.listar_documentos(db, solicitud_id)


@router.get("/demo", response_model=list[SolicitudResumen])
def listar_solicitudes_demo(db: Session = Depends(get_db)):
    """Historial demo sin token para portal y Fuerza de Ventas web."""
    try:
        return rep_solicitudes.listar_demo(db)
    except Exception:
        return rep_casos.solicitudes_demo()


@router.get("/{solicitud_id}")
def detalle_solicitud_rest(
    solicitud_id: str,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Alias REST para detalle completo del expediente."""
    return detalle_solicitud(solicitud_id, db, asesor)


@router.post("/{solicitud_id}/comite")
def decidir_comite(
    solicitud_id: str,
    data: DecisionComiteIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(require_roles("comite", "analista", "supervisor", "administrador")),
):
    """Aprueba, condiciona o rechaza una solicitud autenticada."""
    try:
        result = rep_solicitudes.decidir_comite(
            db,
            solicitud_id,
            data.model_dump(),
            asesor.get("nombre") or asesor.get("sub"),
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if result is None:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return result


@router.post("/{solicitud_id}/desembolso")
def desembolsar(
    solicitud_id: str,
    data: DesembolsoIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(require_roles("comite", "analista", "supervisor", "administrador")),
):
    """Marca como desembolsada una solicitud autenticada."""
    try:
        result = rep_solicitudes.desembolsar(db, solicitud_id, data.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if result is None:
        raise HTTPException(status_code=404, detail="Solicitud no encontrada")
    return result


@router.post("/demo/{solicitud_id}/comite")
def decidir_comite_demo(
    solicitud_id: str,
    data: DecisionComiteIn,
    db: Session = Depends(get_db),
):
    """Aprueba, condiciona o rechaza una solicitud recibida por comite."""
    try:
        result = rep_solicitudes.decidir_comite(db, solicitud_id, data.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception:
        db.rollback()
        return _decision_demo_fallback(solicitud_id, data.decision)
    if result is None:
        return _decision_demo_fallback(solicitud_id, data.decision)
    return result


@router.post("/demo/{solicitud_id}/desembolso")
def desembolsar_demo(
    solicitud_id: str,
    data: DesembolsoIn,
    db: Session = Depends(get_db),
):
    """Marca como desembolsada y encola la sincronizacion al nucleo financiero."""
    try:
        result = rep_solicitudes.desembolsar(db, solicitud_id, data.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception:
        db.rollback()
        return _decision_demo_fallback(solicitud_id, "desembolsado")
    if result is None:
        return _decision_demo_fallback(solicitud_id, "desembolsado")
    return result


@router.post("/{solicitud_id}/notas")
def agregar_nota(
    solicitud_id: str,
    data: NotaIn,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Agrega una nota interna a la solicitud (RF-72)."""
    return rep_solicitudes.agregar_nota(
        db, solicitud_id, asesor["asesor_id"], data.contenido
    )


@router.get("/{solicitud_id}/notas", response_model=list[NotaOut])
def listar_notas(
    solicitud_id: str,
    db: Session = Depends(get_db),
    asesor: dict = Depends(get_current_asesor),
):
    """Notas internas de la solicitud (RF-72)."""
    return rep_solicitudes.listar_notas(db, solicitud_id)


def _decision_demo_fallback(solicitud_id: str, estado: str) -> dict:
    suffix = solicitud_id[-8:].upper() if solicitud_id else "DEMO"
    return {
        "id": solicitud_id,
        "numero_expediente": f"EXP-DEMO-{suffix}",
        "estado": estado,
    }
