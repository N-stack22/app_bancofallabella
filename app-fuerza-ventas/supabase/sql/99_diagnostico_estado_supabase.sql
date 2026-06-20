-- ============================================================
-- DIAGNOSTICO DE ESTADO SUPABASE
-- Ejecutar en Supabase SQL Editor y copiar el resultado.
-- Sirve para verificar que scripts/tablas/vistas/datos/policies
-- ya existen antes de continuar con la app fuerza de ventas.
-- ============================================================

-- 1) Tablas y vistas esperadas
SELECT
  'objeto' AS tipo_reporte,
  object_type,
  object_name,
  CASE WHEN exists_in_db THEN 'OK' ELSE 'FALTA' END AS estado
FROM (
  VALUES
    ('table', 'cuentas', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'cuentas')),
    ('table', 'transacciones', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'transacciones')),
    ('table', 'perfiles_clientes', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'perfiles_clientes')),
    ('table', 'movimientos_mensuales', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'movimientos_mensuales')),
    ('table', 'features_scoring', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'features_scoring')),
    ('table', 'scores_transaccionales', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'scores_transaccionales')),
    ('table', 'fichas_campo', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'fichas_campo')),
    ('table', 'creditos_preaprobados', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'creditos_preaprobados')),
    ('table', 'agencias', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'agencias')),
    ('table', 'asesores_negocio', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'asesores_negocio')),
    ('table', 'cartera_diaria', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'cartera_diaria')),
    ('table', 'solicitudes_credito', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'solicitudes_credito')),
    ('table', 'solicitudes_documentos', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'solicitudes_documentos')),
    ('table', 'consultas_buro', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'consultas_buro')),
    ('table', 'acciones_cobranza', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acciones_cobranza')),
    ('table', 'alertas_cartera', EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'alertas_cartera')),
    ('view', 'vw_pbi_agencias', EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'public' AND table_name = 'vw_pbi_agencias')),
    ('view', 'vw_pbi_asesores', EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'public' AND table_name = 'vw_pbi_asesores')),
    ('view', 'vw_pbi_fichas_campo', EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'public' AND table_name = 'vw_pbi_fichas_campo')),
    ('view', 'vw_pbi_kpis_piloto', EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'public' AND table_name = 'vw_pbi_kpis_piloto'))
) AS checks(object_type, object_name, exists_in_db)
ORDER BY object_type, object_name;

-- 2) Cantidad de datos cargados
SELECT 'conteo' AS tipo_reporte, 'cuentas' AS tabla, COUNT(*)::TEXT AS total FROM public.cuentas
UNION ALL SELECT 'conteo', 'transacciones', COUNT(*)::TEXT FROM public.transacciones
UNION ALL SELECT 'conteo', 'perfiles_clientes', COUNT(*)::TEXT FROM public.perfiles_clientes
UNION ALL SELECT 'conteo', 'scores_transaccionales', COUNT(*)::TEXT FROM public.scores_transaccionales
UNION ALL SELECT 'conteo', 'fichas_campo', COUNT(*)::TEXT FROM public.fichas_campo
UNION ALL SELECT 'conteo', 'creditos_preaprobados', COUNT(*)::TEXT FROM public.creditos_preaprobados
UNION ALL SELECT 'conteo', 'agencias', COUNT(*)::TEXT FROM public.agencias
UNION ALL SELECT 'conteo', 'asesores_negocio', COUNT(*)::TEXT FROM public.asesores_negocio
UNION ALL SELECT 'conteo', 'cartera_diaria', COUNT(*)::TEXT FROM public.cartera_diaria
UNION ALL SELECT 'conteo', 'solicitudes_credito', COUNT(*)::TEXT FROM public.solicitudes_credito
UNION ALL SELECT 'conteo', 'solicitudes_documentos', COUNT(*)::TEXT FROM public.solicitudes_documentos
UNION ALL SELECT 'conteo', 'consultas_buro', COUNT(*)::TEXT FROM public.consultas_buro
UNION ALL SELECT 'conteo', 'acciones_cobranza', COUNT(*)::TEXT FROM public.acciones_cobranza
UNION ALL SELECT 'conteo', 'alertas_cartera', COUNT(*)::TEXT FROM public.alertas_cartera;

-- 3) Usuario de prueba de la app
SELECT
  'usuario_prueba' AS tipo_reporte,
  email,
  id::TEXT AS user_id,
  CASE WHEN email_confirmed_at IS NULL THEN 'SIN CONFIRMAR' ELSE 'CONFIRMADO' END AS estado
FROM auth.users
WHERE email = 'alumno1@example.com';

-- 4) Estado de cartera para la app fuerza de ventas
SELECT
  'cartera_estado' AS tipo_reporte,
  estado,
  COUNT(*) AS total
FROM public.creditos_preaprobados
GROUP BY estado
ORDER BY estado;

-- 5) Politicas RLS relevantes
SELECT
  'policy' AS tipo_reporte,
  schemaname,
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'perfiles_clientes',
    'scores_transaccionales',
    'creditos_preaprobados',
    'fichas_campo'
  )
ORDER BY tablename, policyname;
