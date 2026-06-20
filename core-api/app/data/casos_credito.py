from __future__ import annotations

from math import pow


CASOS_CREDITO = [
    (1, "Anaximandro", "Quispe", "40118120", "Bodega", "Bodega Don Anaxi", "El Tambo", 2200, 900, 1000, 12, 0.4392, "sin_garantia", "Capital de trabajo: compra de mercaderia", 100.95, "normal", -12.0581, -75.2027, "aprobado", 1000),
    (2, "Eulalia", "Mamani", "41223341", "Restaurante", "Picanteria La Eulalia", "Chilca", 3000, 1400, 3000, 12, 0.4092, "sin_garantia", "Compra de cocina industrial", 299.59, "media", -12.0921, -75.2105, "aprobado", 3000),
    (3, "Teofilo", "Huaman", "42330336", "Carpinteria", "Maderas Huaman", "Pilcomayo", 4200, 1800, 5000, 18, 0.4392, "sin_garantia", "Maquinaria: sierra y cepillo", 366.02, "media", -12.0496, -75.2486, "aprobado", 5000),
    (4, "Casandra", "Flores", "43440349", "Abarrotes", "Distribuidora Casandra", "Huancayo", 7000, 2600, 8000, 6, 0.4392, "sin_garantia", "Reposicion de stock por campana", 1480.73, "alta", -12.0651, -75.2049, "aprobado", 8000),
    (5, "Demostenes", "Rojas", "40556071", "Ferreteria", "Ferreteria El Constructor", "San Agustin de Cajas", 5200, 2100, 10000, 12, 0.4392, "hipotecaria", "Ampliacion de local", 1009.46, "alta", -12.0188, -75.2271, "aprobado", 10000),
    (6, "Hipatia", "Condori", "41669066", "Textil", "Confecciones Hipatia", "El Tambo", 6800, 2900, 12000, 24, 0.4092, "hipotecaria", "Compra de maquinas remalladoras", 700.94, "media", -12.0612, -75.2118, "aprobado", 12000),
    (7, "Anibal", "Vargas", "43773379", "Transporte", "Transportes Anibal", "Concepcion", 9500, 4200, 15000, 18, 0.4392, "vehicular", "Cuota inicial de vehiculo de carga", 1098.07, "alta", -11.9182, -75.3142, "aprobado", 15000),
    (8, "Penelope", "Apaza", "40886086", "Avicola", "Granja Penelope", "Sapallanga", 8800, 3600, 18000, 24, 0.4392, "hipotecaria", "Ampliacion de galpon", 1072.10, "alta", -12.1581, -75.1762, "aprobado", 18000),
    (9, "Heraclito", "Ccahua", "41990091", "Comercio", "Importaciones Heraclito", "Huancayo", 12000, 5000, 20000, 36, 0.4392, "hipotecaria", "Capital para nueva sucursal", 927.12, "alta", -12.0668, -75.2103, "aprobado", 20000),
    (10, "Cleopatra", "Soto", "43003039", "Farmacia", "Botica Cleopatra", "Chupaca", 11000, 4400, 25000, 24, 0.4092, "hipotecaria", "Equipamiento y stock farmaceutico", 1460.29, "alta", -12.0560, -75.2870, "aprobado", 25000),
    (11, "Esquilo", "Ramos", "40110010", "Bodega", "Minimarket Esquilo", "Huayucachi", 1900, 800, 2000, 12, 0.4392, "sin_garantia", "Compra de congeladora", 201.89, "normal", -12.1339, -75.2090, "aprobado", 2000),
    (12, "Ariadna", "Quispe", "41226021", "Peluqueria", "Estilos Ariadna", "El Tambo", 3300, 1300, 4000, 18, 0.4392, "sin_garantia", "Mobiliario y equipos de salon", 292.82, "media", -12.0573, -75.2161, "aprobado", 4000),
    (13, "Sofocles", "Huanca", "43336033", "Panaderia", "Panaderia Sofocles", "Sicaya", 5600, 2300, 6000, 12, 0.4092, "sin_garantia", "Horno rotativo", 599.17, "media", -12.0228, -75.3134, "aprobado", 6000),
    (14, "Casiopea", "Torres", "40550055", "Mecanica", "Taller Casiopea", "Pilcomayo", 7400, 3000, 7500, 6, 0.4392, "sin_garantia", "Herramienta neumatica", 1388.18, "media", -12.0512, -75.2451, "aprobado", 7500),
    (15, "Aristofanes", "Cruz", "41669166", "Agropecuario", "Insumos Aristofanes", "Orcotuna", 8200, 3300, 9000, 24, 0.4392, "hipotecaria", "Capital para campana agricola", 536.05, "alta", -11.9760, -75.3361, "aprobado", 9000),
    (16, "Calipso", "Mendoza", "43880088", "Calzado", "Calzados Calipso", "Huancayo", 7900, 3100, 11000, 18, 0.4092, "hipotecaria", "Compra de cuero y maquinaria", 793.03, "media", -12.0689, -75.2055, "aprobado", 11000),
    (17, "Demetrio", "Quispe", "40119019", "Comercio", "Mayorista Demetrio", "Jauja", 11500, 4700, 13500, 12, 0.4392, "hipotecaria", "Reposicion de inventario mayorista", 1362.77, "alta", -11.7752, -75.4995, "aprobado", 13500),
    (18, "Antigona", "Flores", "41226126", "Restaurante", "Recreo Antigona", "Concepcion", 9200, 3900, 16000, 36, 0.4392, "hipotecaria", "Ampliacion y remodelacion", 741.70, "alta", -11.9201, -75.3110, "aprobado", 16000),
    (19, "Pitagoras", "Rojas", "43339033", "Ferreteria", "Ferreteria Pitagoras", "El Tambo", 13000, 5200, 17000, 24, 0.4092, "hipotecaria", "Compra de stock estructural", 993.00, "alta", -12.0599, -75.2143, "aprobado", 17000),
    (20, "Berenice", "Apaza", "40556056", "Textil", "Tejidos Berenice", "San Jeronimo de Tunan", 8600, 3500, 19000, 18, 0.4392, "hipotecaria", "Maquinaria de tejido plano", 1390.89, "alta", -11.9871, -75.2899, "aprobado", 19000),
    (21, "Anaxagoras", "Huaman", "43889089", "Transporte", "Carga Anaxagoras", "Huancayo", 14000, 5800, 22000, 36, 0.4392, "vehicular", "Cuota inicial de camion", 1019.83, "alta", -12.0644, -75.2088, "aprobado", 22000),
    (22, "Climene", "Vargas", "41003001", "Avicola", "Avicola Climene", "Sapallanga", 13500, 5500, 24000, 24, 0.4092, "hipotecaria", "Equipamiento de planta", 1401.88, "alta", -12.1560, -75.1790, "aprobado", 24000),
    (23, "Epaminondas", "Soto", "40115011", "Bodega", "Bodega Epaminondas", "Pucara", 2600, 1000, 1500, 6, 0.4392, "sin_garantia", "Compra de vitrinas", 277.64, "normal", -12.1701, -75.1611, "aprobado", 1500),
    (24, "Lisistrata", "Ramos", "41336036", "Comercio", "Variedades Lisistrata", "Huancayo", 4100, 1700, 3500, 12, 0.4392, "sin_garantia", "Capital de trabajo", 353.31, "media", -12.0633, -75.2071, "aprobado", 3500),
    (25, "Filoctetes", "Cruz", "41552052", "Restaurante", "Cevicheria Filoctetes", "Chilca", 3800, 2200, 11000, 18, 0.4092, "sin_garantia", "Ampliacion de local nuevo", 793.03, "media", -12.0930, -75.2090, "condicionado", 7000),
    (26, "Calirroe", "Mendoza", "41888088", "Calzado", "Calzados Calirroe", "El Tambo", 5000, 2600, 16000, 24, 0.4392, "hipotecaria", "Maquinaria de mayor capacidad", 952.98, "media", -12.0588, -75.2129, "condicionado", 10000),
    (27, "Tucidides", "Quispe", "42220022", "Ferreteria", "Ferreteria Tucidides", "Concepcion", 6200, 2900, 20000, 24, 0.4092, "hipotecaria", "Compra de stock y montacarga", 1168.23, "alta", -11.9176, -75.3155, "condicionado", 14000),
    (28, "Aquiles", "Mamani", "43337037", "Comercio", "Comercial Aquiles", "Huancayo", 9000, 3600, 15000, 24, 0.4392, "hipotecaria", "Capital de trabajo", 893.42, "alta", -12.0657, -75.2099, "rechazado", 0),
    (29, "Medea", "Apaza", "41884084", "Bodega", "Bodega Medea", "Pilcomayo", 1800, 1100, 14000, 18, 0.4392, "sin_garantia", "Compra de camioneta para reparto", 1024.87, "media", -12.0489, -75.2470, "rechazado", 0),
    (30, "Esquines", "Rojas", "43334034", "Transporte", "Fletes Esquines", "Jauja", 7000, 3200, 30000, 24, 0.4392, "vehicular", "Compra de unidad de transporte", 1786.83, "alta", -11.7740, -75.5010, "rechazado", 0),
]


# Datos exactos del PDF de la practica: antiguedad del negocio y fechas de desembolso/pago.
ANTIGUEDAD_MESES = {
    1: 48, 2: 36, 3: 60, 4: 84, 5: 30, 6: 54, 7: 42, 8: 72, 9: 96, 10: 66,
    11: 24, 12: 40, 13: 58, 14: 50, 15: 78, 16: 62, 17: 90, 18: 70, 19: 100, 20: 46,
    21: 84, 22: 76, 23: 28, 24: 52, 25: 18, 26: 34, 27: 40, 28: 60, 29: 22, 30: 30,
}

FECHAS_DESEMBOLSO = {
    1: "2026-02-02", 2: "2026-02-05", 3: "2026-02-10", 4: "2026-02-15",
    5: "2026-03-01", 6: "2026-03-05", 7: "2026-03-10", 8: "2026-03-15",
    9: "2026-04-02", 10: "2026-04-05", 11: "2026-04-10", 12: "2026-04-15",
    13: "2026-05-02", 14: "2026-05-05", 15: "2026-05-10", 16: "2026-05-15",
    17: "2026-06-02", 18: "2026-06-05", 19: "2026-06-10", 20: "2026-06-15",
    21: "2026-07-02", 22: "2026-07-05", 23: "2026-07-10", 24: "2026-07-15",
    25: "2026-08-02", 26: "2026-08-05", 27: "2026-08-10",
}

DIA_PAGO = {
    1: 3, 2: 5, 3: 10, 4: 15, 5: 3, 6: 5, 7: 10, 8: 15, 9: 3, 10: 5,
    11: 10, 12: 15, 13: 3, 14: 5, 15: 10, 16: 15, 17: 3, 18: 5, 19: 10, 20: 15,
    21: 3, 22: 5, 23: 10, 24: 15, 25: 3, 26: 5, 27: 10,
}


BURO = {
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


def cuota_francesa(monto: float, tea: float, plazo: int) -> float:
    tem = pow(1 + tea, 1 / 12) - 1
    return round(monto * tem * pow(1 + tem, plazo) / (pow(1 + tem, plazo) - 1), 2)


def casos_completos() -> list[dict]:
    rows = []
    for raw in CASOS_CREDITO:
        (
            caso, nombres, apellidos, documento, tipo_negocio, nombre_negocio,
            distrito, ingresos, gastos, monto, plazo, tea, garantia, destino,
            cuota, prioridad, lat, lng, decision, aprobado,
        ) = raw
        if not str(documento).isdigit():
            documento = f"413360{caso:02d}"
        ultimo = int(str(documento)[-1])
        sbs, entidades, deuda, mayor, mora, bloqueado = BURO[ultimo]
        tea_decimal = float(tea)
        tea_porcentaje = round(tea_decimal * 100, 2)
        if caso == 29:
            pre_eval, pre_score = "REVISAR", 60
        else:
            pre_eval, pre_score = "APTO", 85
        rows.append({
            "caso": caso,
            "numero_expediente": f"BF-CASO-{caso:02d}",
            "numero_documento": str(documento),
            "nombres": nombres,
            "apellidos": apellidos,
            "telefono": f"964110{200 + caso:03d}",
            "tipo_negocio": tipo_negocio,
            "nombre_negocio": nombre_negocio,
            "distrito": distrito,
            "antiguedad_negocio_meses": ANTIGUEDAD_MESES[caso],
            "ingresos_estimados": ingresos,
            "gastos_mensuales": gastos,
            "monto_solicitado": monto,
            "plazo_meses": plazo,
            "tea_decimal": tea_decimal,
            "tea_referencial": tea_porcentaje,
            "garantia": garantia,
            "destino_credito": destino,
            "cuota_estimada": cuota,
            "prioridad": prioridad,
            "lat": lat,
            "lng": lng,
            "pre_evaluacion": pre_eval,
            "puntaje_pre_evaluacion": pre_score,
            "calificacion_sbs": sbs,
            "entidades_con_deuda": entidades,
            "deuda_total_pen": deuda,
            "mayor_deuda": mayor,
            "dias_mayor_mora": mora,
            "en_lista_negra": bloqueado,
            "decision_comite": decision,
            "monto_aprobado": aprobado,
            "cuota_final": cuota_francesa(aprobado, tea_decimal, plazo) if aprobado else 0,
            "fecha_desembolso": FECHAS_DESEMBOLSO.get(caso),
            "dia_pago": DIA_PAGO.get(caso),
            "estado_final": "desembolsado" if decision in ("aprobado", "condicionado") else "rechazado",
        })
    return rows
