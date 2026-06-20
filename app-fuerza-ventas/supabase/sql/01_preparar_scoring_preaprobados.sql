-- ============================================================
-- PREPARACION PARA scoring_preaprobados.sql SIN EDITARLO
-- Ejecutar DESPUES de 00_supabase_setup_base.sql
-- y ANTES de scoring_preaprobados.sql.
--
-- Motivo:
-- El SQL original usa AGE() en una columna GENERATED.
-- PostgreSQL/Supabase lo rechaza porque AGE() no es immutable.
-- Precreamos la tabla con edad como columna normal para que el
-- CREATE TABLE IF NOT EXISTS del profesor la omita.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.perfiles_clientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  dni TEXT,
  nombres TEXT,
  apellidos TEXT,
  fecha_nacimiento DATE,
  edad INT,
  telefono TEXT,
  distrito TEXT,
  provincia TEXT,
  departamento TEXT,
  nombre_negocio TEXT,
  tipo_negocio TEXT,
  direccion_negocio TEXT,
  lat_negocio NUMERIC(10,7),
  lng_negocio NUMERIC(10,7),
  antiguedad_negocio_meses INT DEFAULT 0,
  tenencia_local TEXT CHECK (
    tenencia_local IN (
      'alquilado_sin_contrato',
      'alquilado_con_contrato',
      'propio'
    )
  ),
  num_entidades_sbs SMALLINT DEFAULT 0,
  calificacion_sbs TEXT DEFAULT 'Normal',
  deuda_total_sbs NUMERIC(12,2) DEFAULT 0,
  estado_cliente TEXT DEFAULT 'activo'
    CHECK (estado_cliente IN ('activo','bloqueado','inactivo')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.set_perfil_cliente_edad()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.fecha_nacimiento IS NOT NULL THEN
    NEW.edad := EXTRACT(YEAR FROM AGE(NEW.fecha_nacimiento))::INT;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_perfil_cliente_edad
  ON public.perfiles_clientes;

CREATE TRIGGER trg_set_perfil_cliente_edad
  BEFORE INSERT OR UPDATE OF fecha_nacimiento
  ON public.perfiles_clientes
  FOR EACH ROW
  EXECUTE FUNCTION public.set_perfil_cliente_edad();
