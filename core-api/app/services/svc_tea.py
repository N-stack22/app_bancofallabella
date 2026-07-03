from __future__ import annotations

import json
import math
import uuid
from datetime import date, timedelta
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session


TARIFARIO_TIPO = "tarifario_tea_banco_falabella"

TARIFARIO_DEFAULT: dict[str, dict[str, Any]] = {
    "NORMAL": {
        "categoria_sbs": "Normal",
        "riesgo": "bajo",
        "score_min": 85,
        "score_max": 100,
        "tea_min": 0.1003,
        "tea_max": 0.25,
        "monto_min": 1000,
        "monto_max": 140000,
        "plazo_min": 2,
        "plazo_max": 60,
        "decision": "aprobado",
    },
    "CPP": {
        "categoria_sbs": "CPP",
        "riesgo": "moderado",
        "score_min": 65,
        "score_max": 84,
        "tea_min": 0.2501,
        "tea_max": 0.45,
        "monto_min": 1000,
        "monto_max": 140000,
        "plazo_min": 2,
        "plazo_max": 60,
        "decision": "condicionado",
    },
    "DEFICIENTE": {
        "categoria_sbs": "Deficiente",
        "riesgo": "alto",
        "score_min": 45,
        "score_max": 64,
        "tea_min": 0.4501,
        "tea_max": 0.70,
        "monto_min": 1000,
        "monto_max": 80000,
        "plazo_min": 2,
        "plazo_max": 48,
        "decision": "condicionado",
    },
    "DUDOSO": {
        "categoria_sbs": "Dudoso",
        "riesgo": "muy alto",
        "score_min": 25,
        "score_max": 44,
        "tea_min": 0.7001,
        "tea_max": 0.99,
        "monto_min": 1000,
        "monto_max": 40000,
        "plazo_min": 2,
        "plazo_max": 36,
        "decision": "condicionado",
    },
    "PERDIDA": {
        "categoria_sbs": "Perdida",
        "riesgo": "rechazo",
        "score_min": 0,
        "score_max": 24,
        "tea_min": 0.99,
        "tea_max": 0.99,
        "monto_min": 0,
        "monto_max": 0,
        "plazo_min": 2,
        "plazo_max": 12,
        "decision": "rechazado",
    },
}


def calcular_cuota_mensual(monto: float, tea: float, plazo_meses: int) -> float:
    """Cuota francesa con TEA decimal: 0.18 equivale a 18% anual."""
    monto = max(float(monto or 0), 0)
    tea = normalizar_tea_decimal(tea)
    plazo = max(int(plazo_meses or 0), 1)
    if monto <= 0:
        return 0
    tem = math.pow(1 + tea, 1 / 12) - 1
    if tem <= 0:
        return round(monto / plazo, 2)
    return round((monto * tem) / (1 - math.pow(1 + tem, -plazo)), 2)


def normalizar_tea_decimal(value: Any, default: float = 0.4392) -> float:
    tea = _num(value, default)
    if tea > 1:
        tea = tea / 100
    return round(min(max(tea, 0), 0.99), 4)


def cargar_contexto_evaluacion(
    db: Session,
    cliente_id: str,
    solicitud: dict,
) -> dict[str, Any]:
    cliente = db.execute(
        text("SELECT * FROM clientes WHERE id = CAST(:id AS uuid)"),
        {"id": cliente_id},
    ).mappings().first()
    consulta = db.execute(
        text(
            """SELECT *
               FROM consultas_buro
               WHERE cliente_id = CAST(:cliente_id AS uuid)
                  OR dni_consultado = :dni
               ORDER BY created_at DESC NULLS LAST
               LIMIT 1"""
        ),
        {"cliente_id": cliente_id, "dni": solicitud.get("numero_documento")},
    ).mappings().first()
    preaprobado = _ultimo_preaprobado(db, cliente_id)
    tarifario = cargar_tarifario(db)
    return {
        "cliente": dict(cliente) if cliente else {},
        "consulta_buro": dict(consulta) if consulta else {},
        "preaprobado": preaprobado,
        "tarifario": tarifario,
    }


def calcular_tea_referencial_db(
    db: Session,
    cliente_id: str,
    solicitud: dict,
) -> dict[str, Any]:
    contexto = cargar_contexto_evaluacion(db, cliente_id, solicitud)
    resultado = calcular_tea_referencial(
        contexto["cliente"],
        solicitud,
        contexto["consulta_buro"],
        contexto["preaprobado"],
        contexto["tarifario"],
    )
    guardar_preaprobado(db, cliente_id, resultado)
    return resultado


def calcular_tea_referencial(
    cliente: dict | None,
    solicitud: dict | None,
    consulta_buro: dict | None = None,
    preaprobado: dict | None = None,
    tarifario: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    cliente = cliente or {}
    solicitud = solicitud or {}
    consulta_buro = consulta_buro or {}
    preaprobado = preaprobado or {}
    tarifario = tarifario or TARIFARIO_DEFAULT

    categoria = normalizar_categoria_sbs(
        consulta_buro.get("calificacion_sbs")
        or cliente.get("calificacion_sbs")
        or "NORMAL"
    )
    regla = tarifario.get(categoria, TARIFARIO_DEFAULT[categoria])
    motivos: list[str] = []

    ingresos = _num(solicitud.get("ingresos_estimados"), _num(cliente.get("ingresos_estimados")))
    gastos = _num(solicitud.get("gastos_mensuales"))
    if gastos <= 0 and ingresos > 0:
        gastos = round(ingresos * 0.45, 2)
    deuda_total = _num(consulta_buro.get("deuda_total_pen"))
    entidades = int(_num(consulta_buro.get("entidades_con_deuda")))
    dias_mora = int(_num(consulta_buro.get("dias_mayor_mora")))
    lista_negra = _bool(
        consulta_buro.get("en_lista_negra")
        or _json_value(consulta_buro.get("resultado_json"), "en_lista_negra")
    )
    monto_solicitado = _num(solicitud.get("monto_solicitado"))
    plazo = int(_num(solicitud.get("plazo_meses"), 12))
    plazo = int(_clamp(plazo, int(regla["plazo_min"]), int(regla["plazo_max"])))

    score_confianza = _score_confianza(
        categoria=categoria,
        regla=regla,
        preaprobado=preaprobado,
        ingresos=ingresos,
        deuda_total=deuda_total,
        entidades=entidades,
        dias_mora=dias_mora,
        lista_negra=lista_negra,
        monto_solicitado=monto_solicitado,
    )
    tea = _tea_por_score(score_confianza, regla)
    cuota_solicitada = calcular_cuota_mensual(monto_solicitado, tea, plazo)

    deuda_mensual_estimada = deuda_total / 12 if deuda_total > 0 else 0
    ingreso_disponible = max(ingresos - gastos - deuda_mensual_estimada, 0)
    pct_capacidad = 0.40 if categoria in {"NORMAL", "CPP"} else 0.30
    cuota_maxima = ingreso_disponible * pct_capacidad
    factor = cuota_solicitada / monto_solicitado if monto_solicitado > 0 else 0
    monto_por_capacidad = cuota_maxima / factor if factor > 0 else 0

    monto_maximo = min(_num(regla.get("monto_max"), 140000), 140000)
    monto_aprobado = min(monto_solicitado, monto_maximo)
    if ingresos > 0 and cuota_maxima > 0:
        monto_aprobado = min(monto_aprobado, monto_por_capacidad)
    monto_aprobado = max(0, round(monto_aprobado, 2))
    cuota_estimada = calcular_cuota_mensual(monto_aprobado, tea, plazo)

    decision = str(regla.get("decision") or "aprobado")
    if lista_negra:
        decision = "rechazado"
        motivos.append("Cliente registrado en lista negra.")
    if categoria == "PERDIDA":
        decision = "rechazado"
        motivos.append("Calificacion SBS Perdida no recomendable para aprobacion.")
    if dias_mora > 120:
        decision = "rechazado"
        motivos.append("Dias de mora mayor a 120.")
    if ingresos <= 0:
        if decision != "rechazado":
            decision = "condicionado"
        motivos.append("Ingresos no declarados o insuficientes para validar capacidad de pago.")
    elif decision != "rechazado" and cuota_solicitada > cuota_maxima > 0:
        if monto_aprobado >= _num(regla.get("monto_min"), 1000):
            decision = "condicionado"
            motivos.append(
                "Cuota solicitada supera la capacidad de pago; se sugiere reducir el monto."
            )
        else:
            decision = "rechazado"
            motivos.append("Capacidad de pago insuficiente para el monto minimo.")
    if categoria in {"DEFICIENTE", "DUDOSO"} and decision == "aprobado":
        decision = "condicionado"
        motivos.append("Riesgo SBS requiere sustento adicional.")
    if categoria == "DUDOSO" and decision == "condicionado" and not motivos:
        motivos.append("Riesgo SBS muy alto; requiere observacion del comite.")
    if categoria == "DEFICIENTE" and decision == "condicionado" and not motivos:
        motivos.append("Riesgo SBS alto; requiere sustento o reduccion de monto.")
    if categoria == "CPP" and score_confianza < 75 and decision == "aprobado":
        decision = "condicionado"
        motivos.append("Cliente CPP requiere evaluacion adicional.")

    if decision == "rechazado":
        monto_aprobado = 0
        cuota_estimada = 0
    condicion = None
    rechazo = None
    if decision == "condicionado":
        condicion = "; ".join(motivos) or "Evaluacion crediticia requiere sustento adicional."
    elif decision == "rechazado":
        rechazo = "; ".join(motivos) or "No cumple politica de riesgo."

    estado_inicial = "enviado" if decision == "aprobado" else decision
    return {
        "calificacion_sbs": regla["categoria_sbs"],
        "score_confianza": int(round(score_confianza)),
        "perfil_riesgo": regla["riesgo"],
        "tea_referencial": round(tea, 4),
        "monto_aprobado_sugerido": round(monto_aprobado, 2),
        "plazo_sugerido_meses": plazo,
        "cuota_estimada": round(cuota_estimada, 2),
        "cuota_solicitada": round(cuota_solicitada, 2),
        "cuota_maxima": round(cuota_maxima, 2),
        "ingreso_disponible": round(ingreso_disponible, 2),
        "decision": decision,
        "estado_inicial": estado_inicial,
        "motivo_rechazo": rechazo,
        "condicion_adicional": condicion,
        "motivos": motivos,
    }


def cargar_tarifario(db: Session) -> dict[str, dict[str, Any]]:
    rows = db.execute(
        text(
            """SELECT codigo, nombre, valor_json
               FROM catalogos
               WHERE tipo = :tipo AND activo = TRUE"""
        ),
        {"tipo": TARIFARIO_TIPO},
    ).mappings().all()
    if not rows:
        return TARIFARIO_DEFAULT
    tarifario = dict(TARIFARIO_DEFAULT)
    for row in rows:
        codigo = normalizar_categoria_sbs(row["codigo"])
        valor = row["valor_json"] or {}
        if isinstance(valor, str):
            valor = json.loads(valor)
        tarifario[codigo] = {**tarifario.get(codigo, {}), **valor}
    return tarifario


def guardar_preaprobado(db: Session, cliente_id: str, evaluacion: dict[str, Any]) -> None:
    if evaluacion["decision"] == "rechazado":
        return
    try:
        with db.begin_nested():
            params = {
                "id": str(uuid.uuid4()),
                "cliente_id": cliente_id,
                "monto": evaluacion["monto_aprobado_sugerido"],
                "plazo": evaluacion["plazo_sugerido_meses"],
                "tea": evaluacion["tea_referencial"],
                "score": evaluacion["score_confianza"],
                "vencimiento": date.today() + timedelta(days=30),
            }
            updated = db.execute(
                text(
                    """UPDATE creditos_preaprobados
                       SET monto_maximo = :monto,
                           plazo_sugerido_meses = :plazo,
                           tea_referencial = :tea,
                           score_confianza = :score,
                           fecha_calculo = CURRENT_DATE,
                           fecha_vencimiento = :vencimiento,
                           vigente = TRUE
                       WHERE id = (
                         SELECT id
                         FROM creditos_preaprobados
                         WHERE cliente_id = CAST(:cliente_id AS uuid)
                         ORDER BY fecha_calculo DESC NULLS LAST, fecha_vencimiento DESC NULLS LAST
                         LIMIT 1
                       )"""
                ),
                params,
            )
            if updated.rowcount == 0:
                db.execute(
                    text(
                        """INSERT INTO creditos_preaprobados
                             (id, cliente_id, monto_maximo, plazo_sugerido_meses,
                              tea_referencial, score_confianza, fecha_calculo,
                              fecha_vencimiento, vigente)
                           VALUES
                             (:id, CAST(:cliente_id AS uuid), :monto, :plazo,
                              :tea, :score, CURRENT_DATE, :vencimiento, TRUE)"""
                    ),
                    params,
                )
    except Exception:
        # Algunos entornos antiguos no tienen creditos_preaprobados completo.
        # La solicitud sigue siendo la fuente de verdad de la TEA calculada.
        pass


def registrar_auditoria(
    db: Session,
    solicitud_id: str,
    estado_anterior: str | None,
    estado_nuevo: str,
    evento: str,
    evaluacion: dict[str, Any] | None = None,
    analista: str | None = None,
) -> None:
    evaluacion = evaluacion or {}
    try:
        with db.begin_nested():
            db.execute(
                text(
                    """UPDATE solicitudes_auditoria
                       SET evento = :evento
                       WHERE solicitud_id = CAST(:solicitud_id AS uuid)
                         AND estado_anterior IS NOT DISTINCT FROM :estado_anterior
                         AND estado_nuevo = :estado_nuevo
                         AND created_at >= now() - interval '5 seconds'"""
                ),
                {
                    "solicitud_id": solicitud_id,
                    "estado_anterior": estado_anterior,
                    "estado_nuevo": estado_nuevo,
                    "evento": evento,
                },
            )
            db.execute(
                text(
                    """INSERT INTO solicitudes_auditoria
                         (id, solicitud_id, estado_anterior, estado_nuevo,
                          analista_asignado, motivo_rechazo,
                          condicion_adicional, monto_aprobado, evento)
                       SELECT
                         :id, CAST(:solicitud_id AS uuid), :estado_anterior,
                         :estado_nuevo, :analista, :motivo, :condicion,
                         :monto, :evento
                       WHERE NOT EXISTS (
                         SELECT 1
                         FROM solicitudes_auditoria
                         WHERE solicitud_id = CAST(:solicitud_id AS uuid)
                           AND estado_anterior IS NOT DISTINCT FROM :estado_anterior
                           AND estado_nuevo = :estado_nuevo
                           AND created_at >= now() - interval '5 seconds'
                       )"""
                ),
                {
                    "id": str(uuid.uuid4()),
                    "solicitud_id": solicitud_id,
                    "estado_anterior": estado_anterior,
                    "estado_nuevo": estado_nuevo,
                    "analista": analista,
                    "motivo": evaluacion.get("motivo_rechazo"),
                    "condicion": evaluacion.get("condicion_adicional"),
                    "monto": evaluacion.get("monto_aprobado_sugerido"),
                    "evento": evento,
                },
            )
    except Exception:
        pass


def evaluacion_publica(evaluacion: dict[str, Any] | None) -> dict[str, Any] | None:
    if not evaluacion:
        return None
    return {
        "calificacion_sbs": evaluacion.get("calificacion_sbs"),
        "score_confianza": evaluacion.get("score_confianza"),
        "perfil_riesgo": evaluacion.get("perfil_riesgo"),
        "tea_referencial": evaluacion.get("tea_referencial"),
        "monto_aprobado_sugerido": evaluacion.get("monto_aprobado_sugerido"),
        "plazo_sugerido_meses": evaluacion.get("plazo_sugerido_meses"),
        "cuota_estimada": evaluacion.get("cuota_estimada"),
        "decision": evaluacion.get("decision"),
        "motivos": evaluacion.get("motivos") or [],
    }


def normalizar_categoria_sbs(value: Any) -> str:
    raw = str(value or "NORMAL").strip().upper()
    raw = (
        raw.replace("É", "E")
        .replace("Í", "I")
        .replace("Á", "A")
        .replace("Ó", "O")
        .replace("Ú", "U")
    )
    if "PERD" in raw:
        return "PERDIDA"
    if "DUD" in raw:
        return "DUDOSO"
    if "DEF" in raw:
        return "DEFICIENTE"
    if "CPP" in raw:
        return "CPP"
    return "NORMAL"


def _ultimo_preaprobado(db: Session, cliente_id: str) -> dict[str, Any]:
    try:
        row = db.execute(
            text(
                """SELECT *
                   FROM creditos_preaprobados
                   WHERE cliente_id = CAST(:cliente_id AS uuid)
                   ORDER BY vigente DESC NULLS LAST,
                            fecha_calculo DESC NULLS LAST,
                            fecha_vencimiento DESC NULLS LAST
                   LIMIT 1"""
            ),
            {"cliente_id": cliente_id},
        ).mappings().first()
        return dict(row) if row else {}
    except Exception:
        return {}


def _score_confianza(
    *,
    categoria: str,
    regla: dict[str, Any],
    preaprobado: dict[str, Any],
    ingresos: float,
    deuda_total: float,
    entidades: int,
    dias_mora: int,
    lista_negra: bool,
    monto_solicitado: float,
) -> float:
    score_pre = _num(preaprobado.get("score_confianza"))
    if score_pre > 0:
        return _clamp(score_pre, regla["score_min"], regla["score_max"])
    base = {
        "NORMAL": 92,
        "CPP": 74,
        "DEFICIENTE": 55,
        "DUDOSO": 35,
        "PERDIDA": 10,
    }[categoria]
    if lista_negra:
        base = 0
    if ingresos >= 8000:
        base += 4
    elif ingresos >= 3000:
        base += 2
    elif ingresos > 0 and ingresos < 1500:
        base -= 8
    if entidades >= 4:
        base -= 8
    elif entidades >= 2:
        base -= 4
    if dias_mora > 120:
        base -= 30
    elif dias_mora > 60:
        base -= 15
    elif dias_mora > 30:
        base -= 8
    elif dias_mora > 0:
        base -= 4
    if ingresos > 0:
        ratio_monto = monto_solicitado / max(ingresos * 12, 1)
        ratio_deuda = deuda_total / max(ingresos * 12, 1)
        if ratio_monto > 1.2:
            base -= 10
        elif ratio_monto > 0.6:
            base -= 5
        if ratio_deuda > 2:
            base -= 15
        elif ratio_deuda > 1:
            base -= 8
        elif ratio_deuda > 0.5:
            base -= 4
    return _clamp(base, regla["score_min"], regla["score_max"])


def _tea_por_score(score: float, regla: dict[str, Any]) -> float:
    min_score = _num(regla["score_min"])
    max_score = _num(regla["score_max"])
    tea_min = _num(regla["tea_min"])
    tea_max = _num(regla["tea_max"])
    if max_score <= min_score:
        return round(tea_max, 4)
    posicion_riesgo = (max_score - score) / (max_score - min_score)
    return round(tea_min + (tea_max - tea_min) * _clamp(posicion_riesgo, 0, 1), 4)


def _json_value(value: Any, key: str) -> Any:
    if isinstance(value, dict):
        return value.get(key)
    if isinstance(value, str) and value:
        try:
            return json.loads(value).get(key)
        except Exception:
            return None
    return None


def _num(value: Any, default: float = 0) -> float:
    if value is None or value == "":
        return float(default or 0)
    try:
        return float(value)
    except (TypeError, ValueError):
        return float(default or 0)


def _bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    return str(value or "").strip().lower() in {"true", "t", "1", "si", "yes"}


def _clamp(value: float, minimum: float, maximum: float) -> float:
    return min(max(float(value), float(minimum)), float(maximum))
