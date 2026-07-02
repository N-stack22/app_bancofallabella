from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Optional
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.core.cfg_auth import get_current_asesor
from app.core.cfg_database import get_db

router = APIRouter()


class BuroIn(BaseModel):
    dni: str
    cliente_id: Optional[str] = None
    solicitud_id: Optional[str] = None
    firma_consentimiento_base64: Optional[str] = None


class BuroOut(BaseModel):
    calificacion_sbs: str
    entidades_con_deuda: int
    deuda_total: float
    mayor_deuda: float
    dias_mayor_mora: int
    en_lista_negra: bool
    motivo_bloqueo: Optional[str] = None
    interpretacion: str


# Calificaciones simuladas por ultimo digito del DNI (deterministico).
_PERFILES = {
    0: ("NORMAL", 1, 4500, 4500, 0, False),
    1: ("NORMAL", 2, 12000, 8000, 0, False),
    2: ("CPP", 2, 18000, 12000, 15, False),
    3: ("NORMAL", 0, 0, 0, 0, False),
    4: ("DUDOSO", 3, 25000, 15000, 95, False),
    5: ("DEFICIENTE", 2, 16000, 10000, 45, False),
    6: ("NORMAL", 1, 6000, 6000, 0, False),
    7: ("PERDIDA", 4, 40000, 22000, 210, True),
    8: ("CPP", 1, 9000, 9000, 20, False),
    9: ("NORMAL", 2, 14000, 9000, 0, False),
}


@router.post("/consulta", response_model=BuroOut)
def consulta_buro(
    data: BuroIn,
    asesor: dict = Depends(get_current_asesor),
    db: Session = Depends(get_db),
):
    """Consulta de buro + listas negras simulada (M7 / RF-58, RF-60)."""
    ultimo = int(data.dni[-1]) if data.dni and data.dni[-1].isdigit() else 0
    sbs, entidades, deuda, mayor, mora, lista_negra = _PERFILES[ultimo]

    if lista_negra:
        interp = ("Cliente aparece en lista de inhabilitados. "
                  "No se puede iniciar solicitud.")
        motivo = "Registrado en lista de restriccion del sistema financiero."
    elif entidades == 0:
        interp = "Sin historial crediticio. Cliente nuevo en el sistema."
        motivo = None
    else:
        estado = "sin mora" if mora == 0 else f"con mora de {mora} dias"
        interp = (f"Cliente con historial en {entidades} entidad(es), deuda "
                  f"total de S/{deuda:,.0f}, {estado}. "
                  f"Calificacion SBS: {sbs}.")
        motivo = None

    result = BuroOut(
        calificacion_sbs=sbs,
        entidades_con_deuda=entidades,
        deuda_total=float(deuda),
        mayor_deuda=float(mayor),
        dias_mayor_mora=mora,
        en_lista_negra=lista_negra,
        motivo_bloqueo=motivo,
        interpretacion=interp,
    )
    if data.cliente_id:
        db.execute(
            text(
                """INSERT INTO consultas_buro
                     (id, asesor_id, cliente_id, dni_consultado,
                      calificacion_sbs, entidades_con_deuda, deuda_total_pen,
                      mayor_deuda, dias_mayor_mora, resultado_json,
                      firma_consentimiento_base64, solicitud_id)
                   VALUES
                     (gen_random_uuid(), CAST(:asesor AS uuid), CAST(:cliente AS uuid), :dni,
                      :sbs, :entidades, :deuda, :mayor, :mora,
                      CAST(:resultado AS jsonb), :firma,
                      CAST(:solicitud AS uuid))"""
            ),
            {
                "asesor": asesor["asesor_id"],
                "cliente": data.cliente_id,
                "dni": data.dni,
                "sbs": result.calificacion_sbs,
                "entidades": result.entidades_con_deuda,
                "deuda": result.deuda_total,
                "mayor": result.mayor_deuda,
                "mora": result.dias_mayor_mora,
                "resultado": result.model_dump_json(),
                "firma": data.firma_consentimiento_base64,
                "solicitud": data.solicitud_id,
            },
        )
        db.commit()
    return result
