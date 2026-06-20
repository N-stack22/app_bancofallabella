-- ============================================================
-- SEMANA 11 - HISTORIAS DE USUARIO APP FUERZA DE VENTAS
-- Ejecutar despues de 05_policies_fuerza_ventas.sql.
--
-- Crea las tablas operativas pedidas en la guia S11:
-- cartera_diaria, solicitudes_credito, documentos, buro,
-- cobranza, alertas y notas internas. Tambien genera una cartera
-- demo compatible desde los datos ya cargados en Semana 10.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.cartera_diaria (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asesor_id INT REFERENCES public.asesores_negocio(id),
  cliente_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  agencia_id INT REFERENCES public.agencias(id),
  fecha_asignacion DATE NOT NULL DEFAULT CURRENT_DATE,
  tipo_gestion TEXT NOT NULL CHECK (
    tipo_gestion IN (
      'RENOVACION',
      'AMPLIACION',
      'NUEVA_SOLICITUD',
      'SEGUIMIENTO',
      'RECUPERACION_MORA',
      'DESERTOR'
    )
  ),
  prioridad TEXT NOT NULL DEFAULT 'normal'
    CHECK (prioridad IN ('alta','media','normal')),
  score_prioridad INT NOT NULL DEFAULT 0 CHECK (score_prioridad BETWEEN 0 AND 100),
  estado_visita TEXT NOT NULL DEFAULT 'pendiente'
    CHECK (estado_visita IN ('pendiente','visitado','no_encontrado','reagendado','negocio_cerrado')),
  resultado_visita TEXT,
  observacion_visita TEXT,
  timestamp_visita TIMESTAMPTZ,
  lat_visita NUMERIC(10,7),
  lng_visita NUMERIC(10,7),
  orden_manual INT,
  pendiente_sync BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(asesor_id, cliente_user_id, fecha_asignacion)
);

CREATE TABLE IF NOT EXISTS public.solicitudes_credito (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero_expediente TEXT UNIQUE NOT NULL,
  asesor_id INT REFERENCES public.asesores_negocio(id),
  cliente_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  agencia_id INT REFERENCES public.agencias(id),
  tipo_negocio TEXT,
  nombre_negocio TEXT,
  actividad_economica TEXT,
  antiguedad_negocio_meses INT,
  ingresos_estimados NUMERIC(12,2),
  gastos_mensuales NUMERIC(12,2),
  patrimonio_estimado NUMERIC(12,2),
  tiene_conyuge BOOLEAN DEFAULT FALSE,
  conyuge_json JSONB DEFAULT '{}'::jsonb,
  tiene_garante BOOLEAN DEFAULT FALSE,
  garante_json JSONB DEFAULT '{}'::jsonb,
  monto_solicitado NUMERIC(12,2) NOT NULL DEFAULT 0,
  plazo_meses INT NOT NULL DEFAULT 12,
  moneda TEXT NOT NULL DEFAULT 'PEN',
  tipo_cuota TEXT DEFAULT 'mensual',
  garantia TEXT DEFAULT 'sin_garantia',
  destino_credito TEXT,
  cuota_estimada NUMERIC(10,2),
  tea_referencial NUMERIC(5,2) DEFAULT 60.00,
  estado TEXT NOT NULL DEFAULT 'borrador'
    CHECK (estado IN (
      'borrador',
      'enviado',
      'recibido_comite',
      'en_evaluacion',
      'aprobado',
      'condicionado',
      'rechazado',
      'desembolsado'
    )),
  monto_aprobado NUMERIC(12,2),
  motivo_rechazo TEXT,
  condicion_adicional TEXT,
  analista_asignado TEXT,
  firma_cliente_base64 TEXT,
  lat_captura NUMERIC(10,7),
  lng_captura NUMERIC(10,7),
  pendiente_sync BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.solicitudes_documentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitud_id UUID REFERENCES public.solicitudes_credito(id) ON DELETE CASCADE,
  tipo_documento TEXT NOT NULL CHECK (
    tipo_documento IN (
      'dni_anverso',
      'dni_reverso',
      'ruc',
      'recibo_servicios',
      'foto_negocio',
      'foto_visita',
      'contrato_arrendamiento'
    )
  ),
  storage_url TEXT,
  tamanio_kb INT,
  nitidez_score NUMERIC(5,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.consultas_buro (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asesor_id INT REFERENCES public.asesores_negocio(id),
  cliente_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
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
  asesor_id INT REFERENCES public.asesores_negocio(id),
  cliente_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  credito_id UUID REFERENCES public.creditos_preaprobados(id) ON DELETE SET NULL,
  tipo_gestion TEXT NOT NULL DEFAULT 'visita'
    CHECK (tipo_gestion IN ('visita','llamada','mensaje')),
  resultado TEXT NOT NULL CHECK (
    resultado IN ('compromiso_pago','pago_parcial','sin_contacto','se_niega')
  ),
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
  asesor_id INT REFERENCES public.asesores_negocio(id),
  cliente_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tipo_alerta TEXT NOT NULL,
  mensaje TEXT NOT NULL,
  leida BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.solicitudes_notas_internas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitud_id UUID REFERENCES public.solicitudes_credito(id) ON DELETE CASCADE,
  asesor_id INT REFERENCES public.asesores_negocio(id),
  contenido TEXT NOT NULL CHECK (length(contenido) <= 500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Cartera demo para el dia actual, reutilizando creditos ya cargados.
INSERT INTO public.cartera_diaria (
  asesor_id,
  cliente_user_id,
  agencia_id,
  fecha_asignacion,
  tipo_gestion,
  prioridad,
  score_prioridad,
  estado_visita,
  orden_manual
)
SELECT
  an.id AS asesor_id,
  cp.user_id AS cliente_user_id,
  ag.id AS agencia_id,
  CURRENT_DATE AS fecha_asignacion,
  CASE
    WHEN cp.dias_mora > 0 THEN 'RECUPERACION_MORA'
    WHEN cp.estado = 'desembolsado' THEN 'SEGUIMIENTO'
    WHEN cp.monto_aprobado >= 4000 THEN 'RENOVACION'
    WHEN cp.segmento = 'PREMIER' THEN 'AMPLIACION'
    ELSE 'NUEVA_SOLICITUD'
  END AS tipo_gestion,
  CASE
    WHEN cp.dias_mora >= 15 OR cp.monto_aprobado >= 4000 THEN 'alta'
    WHEN cp.segmento IN ('PREMIER','ESTANDAR') THEN 'media'
    ELSE 'normal'
  END AS prioridad,
  LEAST(
    100,
    CASE
      WHEN cp.dias_mora > 0 THEN 40 + LEAST(cp.dias_mora, 30)
      WHEN cp.monto_aprobado >= 5000 THEN 35
      WHEN cp.segmento = 'PREMIER' THEN 25
      WHEN cp.estado = 'desembolsado' THEN 10
      ELSE 5
    END + GREATEST(cp.score_final - 500, 0) / 20
  )::INT AS score_prioridad,
  CASE
    WHEN cp.fecha_visita IS NOT NULL THEN 'visitado'
    ELSE 'pendiente'
  END AS estado_visita,
  ROW_NUMBER() OVER (ORDER BY cp.score_final DESC)::INT AS orden_manual
FROM public.creditos_preaprobados cp
CROSS JOIN LATERAL (
  SELECT id, id_agencia
  FROM public.asesores_negocio
  WHERE activo = TRUE
  ORDER BY id
  LIMIT 1
) an
JOIN public.agencias ag ON ag.id = an.id_agencia
ON CONFLICT (asesor_id, cliente_user_id, fecha_asignacion) DO UPDATE SET
  tipo_gestion = EXCLUDED.tipo_gestion,
  prioridad = EXCLUDED.prioridad,
  score_prioridad = EXCLUDED.score_prioridad,
  updated_at = now();

-- Solicitudes demo para alimentar estados, transmision y reportes.
INSERT INTO public.solicitudes_credito (
  numero_expediente,
  asesor_id,
  cliente_user_id,
  agencia_id,
  tipo_negocio,
  nombre_negocio,
  antiguedad_negocio_meses,
  ingresos_estimados,
  gastos_mensuales,
  monto_solicitado,
  plazo_meses,
  cuota_estimada,
  estado,
  monto_aprobado,
  lat_captura,
  lng_captura
)
SELECT
  'BF-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(ROW_NUMBER() OVER (ORDER BY cp.created_at)::TEXT, 5, '0'),
  cd.asesor_id,
  cp.user_id,
  cd.agencia_id,
  pc.tipo_negocio,
  pc.nombre_negocio,
  pc.antiguedad_negocio_meses,
  st.ingreso_promedio_ref,
  st.ingreso_promedio_ref * 0.45,
  cp.monto_aprobado,
  cp.plazo_meses,
  cp.cuota_mensual,
  CASE
    WHEN cp.estado = 'desembolsado' THEN 'desembolsado'
    WHEN cp.estado = 'aprobado' THEN 'aprobado'
    WHEN cp.estado = 'rechazado' THEN 'rechazado'
    WHEN cp.estado = 'visita_realizada' THEN 'recibido_comite'
    ELSE 'borrador'
  END,
  CASE WHEN cp.estado IN ('desembolsado','aprobado') THEN cp.monto_aprobado ELSE NULL END,
  pc.lat_negocio,
  pc.lng_negocio
FROM public.creditos_preaprobados cp
JOIN public.cartera_diaria cd ON cd.cliente_user_id = cp.user_id
LEFT JOIN public.perfiles_clientes pc ON pc.user_id = cp.user_id
LEFT JOIN public.scores_transaccionales st ON st.id = cp.score_id
ORDER BY cp.created_at
LIMIT 60
ON CONFLICT (numero_expediente) DO NOTHING;

-- Buro mock desde los datos SBS existentes.
INSERT INTO public.consultas_buro (
  asesor_id,
  cliente_user_id,
  dni_consultado,
  calificacion_sbs,
  entidades_con_deuda,
  deuda_total_pen,
  mayor_deuda,
  dias_mayor_mora,
  resultado_json
)
SELECT
  cd.asesor_id,
  pc.user_id,
  COALESCE(pc.dni, '00000000'),
  COALESCE(pc.calificacion_sbs, 'Normal'),
  COALESCE(pc.num_entidades_sbs, 0),
  COALESCE(pc.deuda_total_sbs, 0),
  COALESCE(pc.deuda_total_sbs, 0),
  COALESCE(cp.dias_mora, 0),
  jsonb_build_object(
    'fuente', 'mock_sbs_semana11',
    'estado_pago', cp.estado_pago,
    'segmento', cp.segmento
  )
FROM public.perfiles_clientes pc
JOIN public.cartera_diaria cd ON cd.cliente_user_id = pc.user_id
LEFT JOIN public.creditos_preaprobados cp ON cp.user_id = pc.user_id
LIMIT 80;

-- Alertas para recuperacion y supervision.
INSERT INTO public.alertas_cartera (
  asesor_id,
  cliente_user_id,
  tipo_alerta,
  mensaje
)
SELECT
  cd.asesor_id,
  cd.cliente_user_id,
  CASE WHEN cp.dias_mora > 30 THEN 'mora_30d' ELSE 'primer_dia_mora' END,
  'Cliente con ' || cp.dias_mora || ' dias de mora. Priorizar gestion de cobranza.'
FROM public.cartera_diaria cd
JOIN public.creditos_preaprobados cp ON cp.user_id = cd.cliente_user_id
WHERE cp.dias_mora > 0
ON CONFLICT DO NOTHING;

ALTER TABLE public.cartera_diaria ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_credito ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_documentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultas_buro ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.acciones_cobranza ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alertas_cartera ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_notas_internas ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE ON public.cartera_diaria TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.solicitudes_credito TO authenticated;
GRANT SELECT, INSERT ON public.solicitudes_documentos TO authenticated;
GRANT SELECT, INSERT ON public.consultas_buro TO authenticated;
GRANT SELECT, INSERT ON public.acciones_cobranza TO authenticated;
GRANT SELECT, UPDATE ON public.alertas_cartera TO authenticated;
GRANT SELECT, INSERT ON public.solicitudes_notas_internas TO authenticated;

DROP POLICY IF EXISTS "FV gestiona cartera diaria" ON public.cartera_diaria;
CREATE POLICY "FV gestiona cartera diaria"
  ON public.cartera_diaria FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV gestiona solicitudes" ON public.solicitudes_credito;
CREATE POLICY "FV gestiona solicitudes"
  ON public.solicitudes_credito FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV gestiona documentos" ON public.solicitudes_documentos;
CREATE POLICY "FV gestiona documentos"
  ON public.solicitudes_documentos FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV consulta buro" ON public.consultas_buro;
CREATE POLICY "FV consulta buro"
  ON public.consultas_buro FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV gestiona cobranza" ON public.acciones_cobranza;
CREATE POLICY "FV gestiona cobranza"
  ON public.acciones_cobranza FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV lee alertas" ON public.alertas_cartera;
CREATE POLICY "FV lee alertas"
  ON public.alertas_cartera FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV actualiza alertas" ON public.alertas_cartera;
CREATE POLICY "FV actualiza alertas"
  ON public.alertas_cartera FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV gestiona notas internas" ON public.solicitudes_notas_internas;
CREATE POLICY "FV gestiona notas internas"
  ON public.solicitudes_notas_internas FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);
