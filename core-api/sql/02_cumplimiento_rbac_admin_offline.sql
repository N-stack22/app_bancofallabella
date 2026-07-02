-- ============================================================
-- MIGRACION DE CUMPLIMIENTO - BANCO FALABELLA
-- Ejecutar en Supabase SQL Editor / PostgreSQL despues del esquema base.
-- Es idempotente: puede ejecutarse mas de una vez.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------- Columnas requeridas / compatibilidad ----------
ALTER TABLE IF EXISTS public.asesores
  ADD COLUMN IF NOT EXISTS token_fcm TEXT,
  ADD COLUMN IF NOT EXISTS intentos_fallidos INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bloqueado_hasta TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE IF EXISTS public.solicitudes_credito
  ADD COLUMN IF NOT EXISTS canal TEXT NOT NULL DEFAULT 'asesor',
  ADD COLUMN IF NOT EXISTS actividad_economica TEXT,
  ADD COLUMN IF NOT EXISTS gastos_mensuales NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS patrimonio_estimado NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS monto_aprobado NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS motivo_rechazo TEXT,
  ADD COLUMN IF NOT EXISTS condicion_adicional TEXT,
  ADD COLUMN IF NOT EXISTS analista_asignado TEXT,
  ADD COLUMN IF NOT EXISTS firma_cliente_base64 TEXT,
  ADD COLUMN IF NOT EXISTS lat_captura NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS lng_captura NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS pendiente_sync BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE IF EXISTS public.cartera_diaria
  ADD COLUMN IF NOT EXISTS pendiente_sync BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- ---------- Tablas faltantes ----------
CREATE TABLE IF NOT EXISTS public.solicitudes_documentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitud_id UUID NOT NULL REFERENCES public.solicitudes_credito(id) ON DELETE CASCADE,
  tipo_documento TEXT NOT NULL,
  storage_url TEXT,
  tamanio_kb INT,
  nitidez_score NUMERIC(5,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.consultas_buro (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asesor_id UUID REFERENCES public.asesores(id),
  cliente_id UUID REFERENCES public.clientes(id) ON DELETE CASCADE,
  dni_consultado TEXT NOT NULL,
  calificacion_sbs TEXT,
  entidades_con_deuda INT DEFAULT 0,
  deuda_total_pen NUMERIC(12,2) DEFAULT 0,
  mayor_deuda NUMERIC(12,2) DEFAULT 0,
  dias_mayor_mora INT DEFAULT 0,
  resultado_json JSONB DEFAULT '{}'::jsonb,
  firma_consentimiento_base64 TEXT,
  solicitud_id UUID REFERENCES public.solicitudes_credito(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.acciones_cobranza (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asesor_id UUID REFERENCES public.asesores(id),
  cliente_id UUID NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  cod_cuenta_credito TEXT,
  tipo_gestion TEXT NOT NULL DEFAULT 'visita',
  resultado TEXT NOT NULL,
  monto_pagado NUMERIC(12,2) DEFAULT 0,
  fecha_compromiso DATE,
  monto_compromiso NUMERIC(12,2) DEFAULT 0,
  observaciones TEXT,
  lat NUMERIC(10,7),
  lng NUMERIC(10,7),
  timestamp_gestion TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.alertas_cartera (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asesor_id UUID REFERENCES public.asesores(id),
  cliente_id UUID NOT NULL REFERENCES public.clientes(id) ON DELETE CASCADE,
  tipo_alerta TEXT NOT NULL,
  mensaje TEXT NOT NULL,
  leida BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notificaciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  destinatario_tipo TEXT NOT NULL,
  asesor_id UUID REFERENCES public.asesores(id),
  cliente_id UUID REFERENCES public.clientes(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  cuerpo TEXT,
  tipo TEXT,
  data_json JSONB DEFAULT '{}'::jsonb,
  leida BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.solicitudes_notas_internas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitud_id UUID NOT NULL REFERENCES public.solicitudes_credito(id) ON DELETE CASCADE,
  asesor_id UUID REFERENCES public.asesores(id),
  contenido TEXT NOT NULL CHECK (length(contenido) <= 500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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

CREATE TABLE IF NOT EXISTS public.sync_outbox (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entidad TEXT NOT NULL,
  entidad_id UUID,
  operacion TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  estado TEXT NOT NULL DEFAULT 'pendiente',
  core_ref TEXT,
  intentos INT NOT NULL DEFAULT 0,
  ultimo_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  procesado_at TIMESTAMPTZ
);

-- ---------- Constraints ----------
ALTER TABLE IF EXISTS public.asesores
  DROP CONSTRAINT IF EXISTS asesores_perfil_check,
  DROP CONSTRAINT IF EXISTS ck_asesores_perfil;

ALTER TABLE IF EXISTS public.solicitudes_credito
  DROP CONSTRAINT IF EXISTS solicitudes_credito_estado_check,
  DROP CONSTRAINT IF EXISTS ck_solicitudes_estado;

ALTER TABLE IF EXISTS public.cartera_diaria
  DROP CONSTRAINT IF EXISTS cartera_diaria_prioridad_check,
  DROP CONSTRAINT IF EXISTS ck_cartera_prioridad;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'ck_asesores_perfil'
  ) THEN
    ALTER TABLE public.asesores
      ADD CONSTRAINT ck_asesores_perfil
      CHECK (perfil IN ('asesor','operador','comite','analista','supervisor','administrador'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'ck_solicitudes_estado'
  ) THEN
    ALTER TABLE public.solicitudes_credito
      ADD CONSTRAINT ck_solicitudes_estado
      CHECK (estado IN (
        'borrador','enviado','recibido_comite','en_evaluacion',
        'aprobado','condicionado','rechazado','desembolsado'
      ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'ck_cartera_prioridad'
  ) THEN
    ALTER TABLE public.cartera_diaria
      ADD CONSTRAINT ck_cartera_prioridad
      CHECK (prioridad IN ('alta','media','normal'));
  END IF;
END $$;

-- ---------- Indices ----------
CREATE UNIQUE INDEX IF NOT EXISTS ux_clientes_numero_documento
  ON public.clientes (numero_documento);
CREATE UNIQUE INDEX IF NOT EXISTS ux_asesores_codigo_empleado
  ON public.asesores (codigo_empleado);
CREATE UNIQUE INDEX IF NOT EXISTS ux_solicitudes_numero_expediente
  ON public.solicitudes_credito (numero_expediente);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cartera_asesor_cliente_fecha
  ON public.cartera_diaria (asesor_id, cliente_id, fecha_asignacion);

CREATE INDEX IF NOT EXISTS idx_cartera_asesor_fecha_score
  ON public.cartera_diaria (asesor_id, fecha_asignacion, score_prioridad DESC);
CREATE INDEX IF NOT EXISTS idx_solicitudes_estado_created
  ON public.solicitudes_credito (estado, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_solicitudes_asesor_created
  ON public.solicitudes_credito (asesor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_solicitudes_cliente_created
  ON public.solicitudes_credito (cliente_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_documentos_solicitud
  ON public.solicitudes_documentos (solicitud_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_outbox_estado
  ON public.sync_outbox (estado, created_at);
CREATE INDEX IF NOT EXISTS idx_notificaciones_cliente_fecha
  ON public.notificaciones (cliente_id, created_at DESC);

-- ---------- Auditoria y notificaciones ----------
CREATE OR REPLACE FUNCTION public.audit_solicitud_estado()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.estado IS DISTINCT FROM OLD.estado THEN
    INSERT INTO public.solicitudes_auditoria (
      solicitud_id, estado_anterior, estado_nuevo, analista_asignado,
      motivo_rechazo, condicion_adicional, monto_aprobado
    )
    VALUES (
      NEW.id, OLD.estado, NEW.estado, NEW.analista_asignado,
      NEW.motivo_rechazo, NEW.condicion_adicional, NEW.monto_aprobado
    );

    INSERT INTO public.notificaciones (
      id, destinatario_tipo, cliente_id, asesor_id, titulo, cuerpo, tipo, data_json
    )
    VALUES (
      gen_random_uuid(), 'cliente', NEW.cliente_id, NEW.asesor_id,
      'Estado de solicitud actualizado',
      'Tu expediente ' || NEW.numero_expediente || ' ahora esta en estado ' || NEW.estado || '.',
      'solicitud_estado',
      jsonb_build_object('numero_expediente', NEW.numero_expediente, 'estado', NEW.estado)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_solicitud_estado ON public.solicitudes_credito;
CREATE TRIGGER trg_audit_solicitud_estado
AFTER UPDATE ON public.solicitudes_credito
FOR EACH ROW
EXECUTE FUNCTION public.audit_solicitud_estado();

-- ---------- Usuario demo con permisos de backoffice ----------
UPDATE public.asesores
SET perfil = 'administrador'
WHERE codigo_empleado = '0001';

-- ---------- Catalogos base ----------
INSERT INTO public.catalogos (tipo, codigo, nombre, valor_json)
VALUES
  ('producto', 'credito_empresarial', 'Credito empresarial MYPE', '{"moneda":"PEN"}'),
  ('documento', 'dni_anverso', 'DNI anverso', '{"obligatorio":true}'),
  ('documento', 'dni_reverso', 'DNI reverso', '{"obligatorio":true}'),
  ('documento', 'foto_negocio', 'Foto del negocio', '{"obligatorio":true}'),
  ('estado_solicitud', 'recibido_comite', 'Recibido por comite', '{}')
ON CONFLICT (tipo, codigo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    valor_json = EXCLUDED.valor_json,
    activo = TRUE;

-- ---------- RLS seguro para acceso directo Supabase de Fuerza de Ventas ----------
CREATE OR REPLACE FUNCTION public.current_asesor_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT id
  FROM public.asesores
  WHERE codigo_empleado = lpad(regexp_replace(coalesce(auth.jwt()->>'email', ''), '\D', '', 'g'), 4, '0')
     OR lower(cod_asesor) = lower(split_part(coalesce(auth.jwt()->>'email', ''), '@', 1))
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.current_asesor_role()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(perfil, 'asesor')
  FROM public.asesores
  WHERE id = public.current_asesor_id()
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.is_backoffice_role()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT public.current_asesor_role() IN ('supervisor','administrador','comite','analista')
$$;

ALTER TABLE public.cartera_diaria ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_credito ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_documentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultas_buro ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.acciones_cobranza ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alertas_cartera ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "FV cartera por asesor o backoffice" ON public.cartera_diaria;
CREATE POLICY "FV cartera por asesor o backoffice"
  ON public.cartera_diaria FOR ALL TO authenticated
  USING (asesor_id = public.current_asesor_id() OR public.is_backoffice_role())
  WITH CHECK (asesor_id = public.current_asesor_id() OR public.is_backoffice_role());

DROP POLICY IF EXISTS "FV solicitudes por asesor o backoffice" ON public.solicitudes_credito;
CREATE POLICY "FV solicitudes por asesor o backoffice"
  ON public.solicitudes_credito FOR ALL TO authenticated
  USING (asesor_id = public.current_asesor_id() OR public.is_backoffice_role())
  WITH CHECK (asesor_id = public.current_asesor_id() OR public.is_backoffice_role());

DROP POLICY IF EXISTS "FV documentos de sus solicitudes" ON public.solicitudes_documentos;
CREATE POLICY "FV documentos de sus solicitudes"
  ON public.solicitudes_documentos FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.solicitudes_credito s
      WHERE s.id = solicitud_id
        AND (s.asesor_id = public.current_asesor_id() OR public.is_backoffice_role())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.solicitudes_credito s
      WHERE s.id = solicitud_id
        AND (s.asesor_id = public.current_asesor_id() OR public.is_backoffice_role())
    )
  );

DROP POLICY IF EXISTS "FV buro por asesor o backoffice" ON public.consultas_buro;
CREATE POLICY "FV buro por asesor o backoffice"
  ON public.consultas_buro FOR ALL TO authenticated
  USING (asesor_id = public.current_asesor_id() OR public.is_backoffice_role())
  WITH CHECK (asesor_id = public.current_asesor_id() OR public.is_backoffice_role());

DROP POLICY IF EXISTS "FV cobranza por asesor o backoffice" ON public.acciones_cobranza;
CREATE POLICY "FV cobranza por asesor o backoffice"
  ON public.acciones_cobranza FOR ALL TO authenticated
  USING (asesor_id = public.current_asesor_id() OR public.is_backoffice_role())
  WITH CHECK (asesor_id = public.current_asesor_id() OR public.is_backoffice_role());

DROP POLICY IF EXISTS "FV alertas por asesor o backoffice" ON public.alertas_cartera;
CREATE POLICY "FV alertas por asesor o backoffice"
  ON public.alertas_cartera FOR ALL TO authenticated
  USING (asesor_id = public.current_asesor_id() OR public.is_backoffice_role())
  WITH CHECK (asesor_id = public.current_asesor_id() OR public.is_backoffice_role());
