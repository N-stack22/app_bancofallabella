"""
Seed completo para la entrega Banco Falabella.

Crea/actualiza en Supabase PostgreSQL:
- 1 agencia Banco Falabella Huancayo.
- 1 asesor demo: codigo_empleado=0001, clave=1234.
- 30 clientes/prospectos del PDF, con datos exactos de la práctica (DNI, negocio, antigüedad, montos, TEA, cuotas, buró, decisión y fechas).
- 30 usuarios de App Clientes: username=DNI del caso, clave=12345.
- 30 expedientes/solicitudes.
- cartera_diaria, consultas_buro, documentos demo, firma, sync_outbox.
- creditos/cronogramas/movimientos para aprobados y condicionados, usando las fechas de desembolso y días de pago del PDF.

Uso desde core-api, con .env apuntando a Supabase:
    python scripts/seed_30_casos_banco_falabella.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.cfg_database import SessionLocal
from app.repositories.rep_casos import sembrar


def run() -> None:
    db = SessionLocal()
    try:
        result = sembrar(db)
        print("Seed Banco Falabella OK")
        print(result)
    finally:
        db.close()


if __name__ == "__main__":
    run()
