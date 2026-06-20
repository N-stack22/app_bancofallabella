-- ============================================================
-- SETUP BASE PARA LA APP BANCO FALABELLA + SCORING
-- Ejecutar ANTES de los 3 SQL del profesor.
-- No reemplaza ni modifica los scripts originales.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.cuentas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN ('ahorro', 'corriente', 'sueldo')),
  numero_cuenta TEXT NOT NULL UNIQUE,
  saldo NUMERIC(14,2) NOT NULL DEFAULT 0,
  moneda TEXT NOT NULL DEFAULT 'PEN',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.transacciones (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  cuenta_id UUID NOT NULL REFERENCES public.cuentas(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN ('credito', 'debito')),
  descripcion TEXT NOT NULL,
  monto NUMERIC(14,2) NOT NULL CHECK (monto >= 0),
  fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cuentas_user_id
  ON public.cuentas(user_id);

CREATE INDEX IF NOT EXISTS idx_transacciones_user_id_fecha
  ON public.transacciones(user_id, fecha DESC);

CREATE INDEX IF NOT EXISTS idx_transacciones_cuenta_id
  ON public.transacciones(cuenta_id);

ALTER TABLE public.cuentas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transacciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Cliente ve sus cuentas" ON public.cuentas;
CREATE POLICY "Cliente ve sus cuentas"
  ON public.cuentas FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Cliente ve sus transacciones" ON public.transacciones;
CREATE POLICY "Cliente ve sus transacciones"
  ON public.transacciones FOR SELECT
  USING (auth.uid() = user_id);
