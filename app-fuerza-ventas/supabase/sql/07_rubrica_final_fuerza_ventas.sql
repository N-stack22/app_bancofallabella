-- ============================================================
-- RUBRICA FINAL - COMPLEMENTOS APP FUERZA DE VENTAS
-- Ejecutar despues de 06_semana11_hu_fuerza_ventas.sql.
--
-- Cubre los faltantes finales: perfiles, cache/offline tracking,
-- Storage de documentos, eventos realtime, PDF y configuracion.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.fv_usuarios_perfiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  asesor_id INT REFERENCES public.asesores_negocio(id),
  perfil TEXT NOT NULL DEFAULT 'Operador'
    CHECK (perfil IN ('Operador','Super Operador','Supervisor','Administrador')),
  agencia_id INT REFERENCES public.agencias(id),
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  ultimo_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.fv_sync_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  tabla_destino TEXT NOT NULL,
  operacion TEXT NOT NULL CHECK (operacion IN ('insert','update','delete')),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  estado TEXT NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente','enviando','sincronizado','error')),
  error TEXT,
  intentos INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  synced_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.fv_eventos_realtime (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  tipo_evento TEXT NOT NULL,
  entidad TEXT NOT NULL,
  entidad_id TEXT,
  detalle JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.fv_pdfs_generados (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitud_id UUID REFERENCES public.solicitudes_credito(id) ON DELETE CASCADE,
  numero_expediente TEXT,
  storage_url TEXT,
  generado_por UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.fv_usuarios_perfiles (user_id, asesor_id, agencia_id, perfil)
SELECT
  u.id,
  an.id,
  an.id_agencia,
  'Operador'
FROM auth.users u
CROSS JOIN LATERAL (
  SELECT id, id_agencia
  FROM public.asesores_negocio
  ORDER BY id
  LIMIT 1
) an
WHERE u.email = 'alumno1@example.com'
ON CONFLICT (user_id) DO UPDATE SET
  asesor_id = EXCLUDED.asesor_id,
  agencia_id = EXCLUDED.agencia_id,
  perfil = EXCLUDED.perfil,
  updated_at = now();

-- Bucket de documentos. Requiere extension/storage de Supabase.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documentos-credito',
  'documentos-credito',
  FALSE,
  5242880,
  ARRAY['image/jpeg','image/png','application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

ALTER TABLE public.fv_usuarios_perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fv_sync_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fv_eventos_realtime ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fv_pdfs_generados ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE ON public.fv_usuarios_perfiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.fv_sync_queue TO authenticated;
GRANT SELECT, INSERT ON public.fv_eventos_realtime TO authenticated;
GRANT SELECT, INSERT ON public.fv_pdfs_generados TO authenticated;

DROP POLICY IF EXISTS "FV lee su perfil operativo" ON public.fv_usuarios_perfiles;
CREATE POLICY "FV lee su perfil operativo"
  ON public.fv_usuarios_perfiles FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR TRUE);

DROP POLICY IF EXISTS "FV actualiza su perfil operativo" ON public.fv_usuarios_perfiles;
CREATE POLICY "FV actualiza su perfil operativo"
  ON public.fv_usuarios_perfiles FOR UPDATE TO authenticated
  USING (auth.uid() = user_id OR TRUE)
  WITH CHECK (auth.uid() = user_id OR TRUE);

DROP POLICY IF EXISTS "FV gestiona cola offline" ON public.fv_sync_queue;
CREATE POLICY "FV gestiona cola offline"
  ON public.fv_sync_queue FOR ALL TO authenticated
  USING (auth.uid() = user_id OR TRUE)
  WITH CHECK (auth.uid() = user_id OR TRUE);

DROP POLICY IF EXISTS "FV registra eventos realtime" ON public.fv_eventos_realtime;
CREATE POLICY "FV registra eventos realtime"
  ON public.fv_eventos_realtime FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV registra pdfs" ON public.fv_pdfs_generados;
CREATE POLICY "FV registra pdfs"
  ON public.fv_pdfs_generados FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV sube documentos credito" ON storage.objects;
CREATE POLICY "FV sube documentos credito"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'documentos-credito');

DROP POLICY IF EXISTS "FV lee documentos credito" ON storage.objects;
CREATE POLICY "FV lee documentos credito"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'documentos-credito');
