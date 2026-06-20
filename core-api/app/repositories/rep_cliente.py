"""Repositorio del lado app de clientes — consultas sobre bd_core_mobile."""
import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import text
from sqlalchemy.orm import Session
from app.core.cfg_security import hash_password
from app.models.mdl_clientes import Cliente
from app.models.mdl_cliente_mobile import (
    UsuarioCliente, CrCuentaAhorro, CrCredito, CrCronogramaPago,
    CrMovimiento, Tarjeta, OperacionCliente, Notificacion,
)


def get_usuario_by_username(db: Session, username: str) -> UsuarioCliente | None:
    return db.query(UsuarioCliente).filter(
        UsuarioCliente.username == username
    ).first()


def get_cliente(db: Session, cliente_id: str) -> Cliente | None:
    return db.query(Cliente).filter(Cliente.id == cliente_id).first()


def cuentas_ahorro(db: Session, cliente_id: str) -> list[CrCuentaAhorro]:
    return db.query(CrCuentaAhorro).filter(
        CrCuentaAhorro.cliente_id == cliente_id
    ).order_by(CrCuentaAhorro.cod_cuenta_ahorro.asc()).all()


def creditos(db: Session, cliente_id: str) -> list[CrCredito]:
    return db.query(CrCredito).filter(
        CrCredito.cliente_id == cliente_id
    ).order_by(CrCredito.fecha_desembolso.desc().nullslast()).all()


def cronograma(db: Session, cod_cuenta_credito: str) -> list[CrCronogramaPago]:
    return db.query(CrCronogramaPago).filter(
        CrCronogramaPago.cod_cuenta_credito == cod_cuenta_credito
    ).order_by(CrCronogramaPago.nro_cuota.asc()).all()


def movimientos(db: Session, cliente_id: str, limit: int = 20) -> list[CrMovimiento]:
    return db.query(CrMovimiento).filter(
        CrMovimiento.cliente_id == cliente_id
    ).order_by(CrMovimiento.fecha_operacion.desc()).limit(limit).all()


def tarjetas(db: Session, cliente_id: str) -> list[Tarjeta]:
    return db.query(Tarjeta).filter(
        Tarjeta.cliente_id == cliente_id
    ).order_by(Tarjeta.created_at.asc()).all()


def notificaciones(db: Session, cliente_id: str, limit: int = 30) -> list[Notificacion]:
    return db.query(Notificacion).filter(
        Notificacion.destinatario_tipo == "cliente",
        Notificacion.cliente_id == cliente_id,
    ).order_by(Notificacion.created_at.desc()).limit(limit).all()


def crear_operacion(db: Session, cliente_id: str, data: dict) -> OperacionCliente:
    cod_operacion = f"APP-{uuid.uuid4().hex[:12].upper()}"
    tipo = data.get("tipo")
    monto = float(data.get("monto") or 0)
    cuenta_origen = data.get("cod_cuenta_origen")
    concepto = "Pago registrado desde App Clientes" if tipo == "pago_cuota" else "Transferencia desde App Clientes"
    op = OperacionCliente(
        cliente_id=cliente_id,
        cod_cuenta_origen=cuenta_origen,
        cod_cuenta_destino=data.get("cod_cuenta_destino"),
        tipo=tipo,
        monto=monto,
        moneda=data.get("moneda", "PEN"),
        estado="registrado",
        cod_operacion_core=cod_operacion,
    )
    db.add(op)
    db.execute(
        text(
            """INSERT INTO cr_movimientos
                 (id, cod_operacion, cliente_id, cod_cuenta, tipo, concepto,
                  canal, monto, moneda, fecha_operacion)
               VALUES (:id, :codop, :cliente_id, :cuenta, 'DEB',
                       :concepto, 'APP', :monto, :moneda, now())
               ON CONFLICT (cod_operacion) DO NOTHING"""
        ),
        {
            "id": str(uuid.uuid4()),
            "codop": cod_operacion,
            "cliente_id": cliente_id,
            "cuenta": cuenta_origen,
            "concepto": concepto,
            "monto": monto,
            "moneda": data.get("moneda", "PEN"),
        },
    )
    if cuenta_origen:
        db.execute(
            text(
                """UPDATE cr_cuentas_ahorro
                   SET saldo_capital = GREATEST(COALESCE(saldo_capital, 0) - :monto, 0),
                       sync_at = now()
                   WHERE cliente_id = :cliente_id
                     AND cod_cuenta_ahorro = :cuenta"""
            ),
            {"cliente_id": cliente_id, "cuenta": cuenta_origen, "monto": monto},
        )
    db.commit()
    db.refresh(op)
    return op


def resumen_demo_por_documento(db: Session, numero_documento: str) -> dict | None:
    """Resumen demo de homebanking con datos espejo cr_* materializados."""
    cliente = db.execute(
        text("SELECT * FROM clientes WHERE numero_documento = :doc"),
        {"doc": numero_documento},
    ).mappings().first()
    if not cliente:
        return None

    _materializar_productos_demo(db, cliente)
    cliente_id = str(cliente["id"])
    cuentas = [dict(r) for r in db.execute(
        text("SELECT * FROM cr_cuentas_ahorro WHERE cliente_id = :id ORDER BY cod_cuenta_ahorro"),
        {"id": cliente_id},
    ).mappings().all()]
    creditos = [dict(r) for r in db.execute(
        text("SELECT * FROM cr_creditos WHERE cliente_id = :id ORDER BY fecha_desembolso DESC NULLS LAST"),
        {"id": cliente_id},
    ).mappings().all()]
    cronogramas = {}
    for credito in creditos:
        cod = credito["cod_cuenta_credito"]
        cronogramas[cod] = [dict(r) for r in db.execute(
            text("SELECT * FROM cr_cronograma_pagos WHERE cod_cuenta_credito = :cod ORDER BY nro_cuota"),
            {"cod": cod},
        ).mappings().all()]
    return {
        "cliente": dict(cliente),
        "cuentas": cuentas,
        "creditos": creditos,
        "cronogramas": cronogramas,
        "movimientos": [dict(r) for r in db.execute(
            text("SELECT * FROM cr_movimientos WHERE cliente_id = :id ORDER BY fecha_operacion DESC LIMIT 20"),
            {"id": cliente_id},
        ).mappings().all()],
        "tarjetas": [dict(r) for r in db.execute(
            text("SELECT * FROM tarjetas WHERE cliente_id = :id ORDER BY created_at DESC"),
            {"id": cliente_id},
        ).mappings().all()],
        "notificaciones": [dict(r) for r in db.execute(
            text("SELECT * FROM notificaciones WHERE cliente_id = :id ORDER BY created_at DESC LIMIT 20"),
            {"id": cliente_id},
        ).mappings().all()],
        "solicitudes": [dict(r) for r in db.execute(
            text(
                """SELECT numero_expediente, monto_solicitado, monto_aprobado, estado, created_at
                   FROM solicitudes_credito
                   WHERE cliente_id = :id
                   ORDER BY created_at DESC"""
            ),
            {"id": cliente_id},
        ).mappings().all()],
    }


def asegurar_cliente_demo_login(db: Session, numero_documento: str) -> None:
    """Crea la credencial demo de App Clientes si aun no existe."""
    cliente = db.execute(
        text("SELECT * FROM clientes WHERE numero_documento = :doc"),
        {"doc": numero_documento},
    ).mappings().first()
    if not cliente:
        cliente_id = str(uuid.uuid4())
        db.execute(
            text(
                """INSERT INTO clientes
                     (id, cod_cliente, numero_documento, tipo_documento,
                      nombres, apellidos, telefono, email, direccion,
                      tipo_negocio, nombre_negocio, ingresos_estimados,
                      calificacion_sbs, es_prospecto)
                   VALUES
                     (:id, :cod, :doc, 'DNI', 'Jose', 'Demo Falabella',
                      '999888777', :email, 'Direccion demo Banco Falabella',
                      'Bodega', 'Bodega Demo Falabella', 3200.00,
                      'Normal', TRUE)"""
            ),
            {
                "id": cliente_id,
                "cod": f"CLI-{numero_documento[-4:]}",
                "doc": numero_documento,
                "email": f"{numero_documento}@cliente.falabella.pe",
            },
        )
        cliente = db.execute(
            text("SELECT * FROM clientes WHERE id = :id"),
            {"id": cliente_id},
        ).mappings().first()

    asesor = db.execute(
        text(
            """SELECT id, agencia_id
               FROM asesores
               WHERE activo = TRUE
               ORDER BY created_at NULLS LAST
               LIMIT 1"""
        )
    ).mappings().first()
    expediente = f"EXP-DEMO-{numero_documento[-4:]}"
    db.execute(
        text(
            """INSERT INTO solicitudes_credito
                 (id, numero_expediente, asesor_id, cliente_id, agencia_id,
                  canal, tipo_negocio, nombre_negocio, ingresos_estimados,
                  monto_solicitado, monto_aprobado, plazo_meses, moneda,
                  tipo_cuota, garantia, destino_credito, cuota_estimada,
                  tea_referencial, estado, firma_cliente_base64, pendiente_sync)
               SELECT :id, :exp, :asesor, :cliente_id, :agencia,
                      'cliente', 'Bodega', 'Bodega Demo Falabella', 3200.00,
                      2500.00, 2500.00, 12, 'PEN', 'mensual',
                      'sin_garantia', 'Capital de trabajo', 250.00,
                      43.92, 'desembolsado', 'firma_demo_cliente', TRUE
               WHERE NOT EXISTS (
                   SELECT 1 FROM solicitudes_credito
                   WHERE numero_expediente = :exp
               )"""
        ),
        {
            "id": str(uuid.uuid4()),
            "exp": expediente,
            "asesor": asesor["id"] if asesor else None,
            "agencia": asesor["agencia_id"] if asesor else None,
            "cliente_id": str(cliente["id"]),
        },
    )
    _materializar_productos_demo(db, cliente)


def _materializar_productos_demo(db: Session, cliente) -> None:
    cliente_id = str(cliente["id"])
    doc = cliente["numero_documento"]
    db.execute(
        text(
            """INSERT INTO usuarios_cliente (id, cliente_id, username, password_hash, activo)
               VALUES (:id, :cliente_id, :username, :password_hash, TRUE)
               ON CONFLICT (username) DO NOTHING"""
        ),
        {
            "id": str(uuid.uuid4()),
            "cliente_id": cliente_id,
            "username": doc,
            "password_hash": hash_password("12345"),
        },
    )
    cuenta = f"AHO-{doc[-4:]}"
    db.execute(
        text(
            """INSERT INTO cr_cuentas_ahorro
                 (id, cod_cuenta_ahorro, cliente_id, tipo_cuenta, moneda,
                  saldo_capital, saldo_interes, tea, estado)
               VALUES (:id, :cod, :cliente_id, 'Ahorro Digital', 'PEN',
                       2500.00, 12.50, 2.50, 'activa')
               ON CONFLICT (cod_cuenta_ahorro) DO NOTHING"""
        ),
        {"id": str(uuid.uuid4()), "cod": cuenta, "cliente_id": cliente_id},
    )
    db.execute(
        text(
            """INSERT INTO tarjetas
                 (id, cliente_id, numero_enmascarado, marca, linea_credito,
                  saldo_utilizado, fecha_corte, fecha_pago, estado)
               SELECT :id, :cliente_id, :numero, 'Visa', 3500.00, 420.00,
                      :corte, :pago, 'activa'
               WHERE NOT EXISTS (
                   SELECT 1 FROM tarjetas WHERE cliente_id = :cliente_id
               )"""
        ),
        {
            "id": str(uuid.uuid4()),
            "cliente_id": cliente_id,
            "numero": f"**** **** **** {doc[-4:]}",
            "corte": date.today().replace(day=20),
            "pago": date.today().replace(day=28),
        },
    )

    solicitudes = db.execute(
        text(
            """SELECT id, numero_expediente, monto_aprobado, monto_solicitado,
                      plazo_meses, cuota_estimada, tea_referencial
               FROM solicitudes_credito
               WHERE cliente_id = :cliente_id
                 AND estado = 'desembolsado'
                 AND COALESCE(monto_aprobado, 0) > 0"""
        ),
        {"cliente_id": cliente_id},
    ).mappings().all()
    for s in solicitudes:
        cod_credito = f"CR-{s['numero_expediente']}"[:30]
        monto = float(s["monto_aprobado"] or s["monto_solicitado"] or 0)
        plazo = int(s["plazo_meses"] or 12)
        cuota = float(s["cuota_estimada"] or (monto / plazo if plazo else monto))
        db.execute(
            text(
                """INSERT INTO cr_creditos
                     (id, cod_cuenta_credito, cliente_id, producto,
                      monto_desembolsado, saldo_capital, saldo_total, dias_mora,
                      calificacion_interna, estado, fecha_desembolso, tea,
                      cuotas_total, cuotas_pagadas)
                   VALUES (:id, :cod, :cliente_id, 'Credito Empresarial',
                           :monto, :monto, :saldo_total, 0, 'NORMAL', 'vigente',
                           :fecha, :tea, :plazo, 0)
                   ON CONFLICT (cod_cuenta_credito) DO NOTHING"""
            ),
            {
                "id": str(uuid.uuid4()),
                "cod": cod_credito,
                "cliente_id": cliente_id,
                "monto": monto,
                "saldo_total": round(cuota * plazo, 2),
                "fecha": datetime.now(timezone.utc).date(),
                "tea": float(s["tea_referencial"] or 43.92),
                "plazo": plazo,
            },
        )
        saldo = monto
        for nro in range(1, plazo + 1):
            capital = round(monto / plazo, 2)
            interes = max(round(cuota - capital, 2), 0)
            saldo = max(round(saldo - capital, 2), 0)
            db.execute(
                text(
                    """INSERT INTO cr_cronograma_pagos
                         (id, cod_cuenta_credito, nro_cuota, fecha_vencimiento,
                          monto_cuota, monto_capital, monto_interes, saldo, estado_cuota)
                       VALUES (:id, :cod, :nro, :fecha, :cuota, :capital,
                               :interes, :saldo, 'pendiente')
                       ON CONFLICT (cod_cuenta_credito, nro_cuota) DO NOTHING"""
                ),
                {
                    "id": str(uuid.uuid4()),
                    "cod": cod_credito,
                    "nro": nro,
                    "fecha": datetime.now(timezone.utc).date() + timedelta(days=30 * nro),
                    "cuota": cuota,
                    "capital": capital,
                    "interes": interes,
                    "saldo": saldo,
                },
            )
        db.execute(
            text(
                """INSERT INTO cr_movimientos
                     (id, cod_operacion, cliente_id, cod_cuenta, tipo, concepto,
                      canal, monto, moneda, fecha_operacion)
                   VALUES (:id, :codop, :cliente_id, :cuenta, 'CRE',
                           'Desembolso credito empresarial', 'CORE', :monto,
                           'PEN', now())
                   ON CONFLICT (cod_operacion) DO NOTHING"""
            ),
            {
                "id": str(uuid.uuid4()),
                "codop": f"OP-{s['numero_expediente']}",
                "cliente_id": cliente_id,
                "cuenta": cod_credito,
                "monto": monto,
            },
        )
        db.execute(
            text(
                """INSERT INTO notificaciones
                     (id, destinatario_tipo, cliente_id, titulo, cuerpo, tipo, data_json)
                   SELECT :id, 'cliente', :cliente_id, 'Credito desembolsado',
                          :cuerpo, 'credito', CAST(:data AS jsonb)
                   WHERE NOT EXISTS (
                       SELECT 1 FROM notificaciones
                       WHERE cliente_id = :cliente_id AND data_json->>'numero_expediente' = :exp
                   )"""
            ),
            {
                "id": str(uuid.uuid4()),
                "cliente_id": cliente_id,
                "cuerpo": f"Tu expediente {s['numero_expediente']} fue desembolsado por S/ {monto:.2f}.",
                "data": json_payload(s["numero_expediente"]),
                "exp": s["numero_expediente"],
            },
        )
    _recalcular_saldo_ahorro_demo(db, cliente_id, cuenta)
    db.commit()


def json_payload(numero_expediente: str) -> str:
    return '{"numero_expediente":"' + str(numero_expediente) + '"}'


def _recalcular_saldo_ahorro_demo(db: Session, cliente_id: str, cuenta: str) -> None:
    """Refleja desembolsos como abonos positivos en la cuenta demo del cliente."""
    db.execute(
        text(
            """UPDATE cr_cuentas_ahorro
               SET saldo_capital = GREATEST(
                     2500.00
                     + COALESCE((
                         SELECT SUM(monto)
                         FROM cr_movimientos
                         WHERE cliente_id = :cliente_id
                           AND tipo = 'CRE'
                           AND concepto ILIKE 'Desembolso credito%'
                       ), 0)
                     - COALESCE((
                         SELECT SUM(monto)
                         FROM cr_movimientos
                         WHERE cliente_id = :cliente_id
                           AND tipo = 'DEB'
                           AND cod_cuenta = :cuenta
                       ), 0),
                     0
                   ),
                   saldo_interes = COALESCE(saldo_interes, 12.50),
                   sync_at = now()
               WHERE cliente_id = :cliente_id
                 AND cod_cuenta_ahorro = :cuenta"""
        ),
        {"cliente_id": cliente_id, "cuenta": cuenta},
    )
