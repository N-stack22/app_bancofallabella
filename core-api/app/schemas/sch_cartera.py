from pydantic import BaseModel
from typing import Optional

class CarteraItemOut(BaseModel):
    id: str
    cliente_id: str
    cliente_nombre: str
    documento: str
    numero_expediente: Optional[str] = None
    tipo_gestion: str
    prioridad: str
    score_prioridad: int
    monto_credito: float
    estado_visita: str
    orden_manual: Optional[int] = None
    fecha_asignacion: Optional[str] = None
    fecha_hora_solicitud: Optional[str] = None
    timestamp_visita: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None

class MarcarVisitaIn(BaseModel):
    resultado: str               # visitado / no_encontrado / reagendado / negocio_cerrado
    observacion: str = ""
    lat: Optional[float] = None
    lng: Optional[float] = None

class EnviarComiteIn(BaseModel):
    asesor_nombre: str = ""
    agencia: str = ""
    score_transaccional: int = 0
    score_campo: int = 0
    score_final: int = 0
    segmento: str = ""
    monto_propuesto: float = 0
    plazo_meses: int = 0
    cuota_estimada: float = 0
    recomendacion: str = ""
    observaciones: str = ""
