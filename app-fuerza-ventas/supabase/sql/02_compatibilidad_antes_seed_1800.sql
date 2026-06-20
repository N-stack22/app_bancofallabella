-- ============================================================
-- COMPATIBILIDAD PARA EJECUTAR seed_scoring_1800.sql SIN EDITARLO
-- Ejecutar DESPUES de scoring_preaprobados.sql y ANTES de seed_scoring_1800.sql.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'scores_transaccionales_user_id_key'
      AND conrelid = 'public.scores_transaccionales'::regclass
  ) THEN
    ALTER TABLE public.scores_transaccionales
      ADD CONSTRAINT scores_transaccionales_user_id_key UNIQUE (user_id);
  END IF;
END $$;

-- El seed del profesor crea public.auth_mock, pero las tablas del scoring
-- referencian auth.users. Este trigger crea usuarios demo automaticamente
-- cuando el seed inserta perfiles_clientes.
CREATE OR REPLACE FUNCTION public.ensure_demo_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_email TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users WHERE id = NEW.user_id) THEN
    RETURN NEW;
  END IF;

  SELECT email
  INTO v_email
  FROM public.auth_mock
  WHERE id = NEW.user_id;

  v_email := COALESCE(v_email, NEW.user_id::TEXT || '@cliente.demo');

  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    NEW.user_id,
    'authenticated',
    'authenticated',
    v_email,
    crypt('ClienteDemo123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_perfiles_clientes_auth_user
  ON public.perfiles_clientes;

CREATE TRIGGER trg_perfiles_clientes_auth_user
  BEFORE INSERT ON public.perfiles_clientes
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_demo_auth_user();
