-- ============================================================
-- TARIFARIO REFERENCIAL TEA - BANCO FALABELLA PRESTAMO EFECTIVO
-- Seguro/idempotente: no borra datos existentes.
-- Ejecutar manualmente en Supabase SQL Editor si la BD aun no tiene
-- estos catalogos/columnas.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.catalogos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo TEXT NOT NULL,
  codigo TEXT NOT NULL,
  nombre TEXT NOT NULL,
  valor_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tipo, codigo)
);

CREATE TABLE IF NOT EXISTS public.solicitudes_auditoria (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitud_id UUID REFERENCES public.solicitudes_credito(id) ON DELETE CASCADE,
  estado_anterior TEXT,
  estado_nuevo TEXT NOT NULL,
  analista_asignado TEXT,
  motivo_rechazo TEXT,
  condicion_adicional TEXT,
  monto_aprobado NUMERIC(12,2),
  evento TEXT NOT NULL DEFAULT 'cambio_estado',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE IF EXISTS public.consultas_buro
  ADD COLUMN IF NOT EXISTS en_lista_negra BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE IF EXISTS public.creditos_preaprobados
  ADD COLUMN IF NOT EXISTS fecha_calculo DATE,
  ADD COLUMN IF NOT EXISTS fecha_vencimiento DATE,
  ADD COLUMN IF NOT EXISTS vigente BOOLEAN NOT NULL DEFAULT TRUE;

INSERT INTO public.catalogos (tipo, codigo, nombre, valor_json, activo)
VALUES
  (
    'tarifario_tea_banco_falabella',
    'NORMAL',
    'Normal',
    '{
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
      "decision": "aprobado"
    }'::jsonb,
    TRUE
  ),
  (
    'tarifario_tea_banco_falabella',
    'CPP',
    'CPP',
    '{
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
      "decision": "condicionado"
    }'::jsonb,
    TRUE
  ),
  (
    'tarifario_tea_banco_falabella',
    'DEFICIENTE',
    'Deficiente',
    '{
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
      "decision": "condicionado"
    }'::jsonb,
    TRUE
  ),
  (
    'tarifario_tea_banco_falabella',
    'DUDOSO',
    'Dudoso',
    '{
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
      "decision": "condicionado"
    }'::jsonb,
    TRUE
  ),
  (
    'tarifario_tea_banco_falabella',
    'PERDIDA',
    'Perdida',
    '{
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
      "decision": "rechazado"
    }'::jsonb,
    TRUE
  )
ON CONFLICT (tipo, codigo)
DO UPDATE SET
  nombre = EXCLUDED.nombre,
  valor_json = EXCLUDED.valor_json,
  activo = TRUE;
