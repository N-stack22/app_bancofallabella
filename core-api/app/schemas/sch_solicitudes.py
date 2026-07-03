from pydantic import BaseModel
from typing import Any, Optional


class SolicitudIn(BaseModel):
    # Solicitante / negocio
    numero_documento: str
    nombres: str = ""
    apellidos: str = ""
    telefono: Optional[str] = None
    tipo_negocio: Optional[str] = None
    nombre_negocio: Optional[str] = None
    ingresos_estimados: Optional[float] = None
    gastos_mensuales: Optional[float] = None
    # Condiciones
    monto_solicitado: float
    plazo_meses: int
    moneda: str = "PEN"
    tipo_cuota: str = "mensual"
    garantia: str = "sin_garantia"
    destino_credito: Optional[str] = None
    cuota_estimada: Optional[float] = None
    tea_referencial: Optional[float] = None
    firma_cliente_base64: Optional[str] = None


class SolicitudCreada(BaseModel):
    id: str
    numero_expediente: str
    estado: str
    tea_referencial: Optional[float] = None
    cuota_estimada: Optional[float] = None
    monto_aprobado_sugerido: Optional[float] = None
    evaluacion_crediticia: Optional[dict[str, Any]] = None


class SolicitudResumen(BaseModel):
    id: str
    numero_expediente: str
    cliente_nombre: str
    monto_solicitado: float
    monto_aprobado: float
    tea_referencial: Optional[float] = None
    cuota_estimada: Optional[float] = None
    calificacion_sbs: Optional[str] = None
    score_confianza: Optional[int] = None
    perfil_riesgo: Optional[str] = None
    estado: str
    created_at: Optional[str] = None


class DecisionComiteIn(BaseModel):
    decision: str
    monto_aprobado: Optional[float] = None
    condicion_adicional: Optional[str] = None
    motivo_rechazo: Optional[str] = None
    analista_asignado: Optional[str] = None


class EstadoSolicitudIn(BaseModel):
    estado: str
    monto_aprobado: Optional[float] = None
    condicion_adicional: Optional[str] = None
    motivo_rechazo: Optional[str] = None
    analista_asignado: Optional[str] = None


class DocumentoSolicitudIn(BaseModel):
    tipo_documento: str
    storage_url: Optional[str] = None
    tamanio_kb: Optional[int] = None
    nitidez_score: Optional[float] = None


class DesembolsoIn(BaseModel):
    observacion: Optional[str] = None
