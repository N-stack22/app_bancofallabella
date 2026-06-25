-- ============================================================
-- USUARIO ASESOR PARA APP FUERZA DE VENTAS
-- Email: asesor0001@bancofalabella.local
-- Ejecutar despues de crear agencias/asesores y tablas FV.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  v_user_id UUID;
  v_asesor_id INT;
  v_agencia_id INT;
BEGIN
  SELECT id
  INTO v_user_id
  FROM auth.users
  WHERE email = 'asesor0001@bancofalabella.local'
  LIMIT 1;

  IF v_user_id IS NULL THEN
    v_user_id := gen_random_uuid();

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
      v_user_id,
      'authenticated',
      'authenticated',
      'asesor0001@bancofalabella.local',
      crypt('1234', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"perfil":"Operador","codigo":"0001"}'::jsonb,
      now(),
      now(),
      '',
      '',
      '',
      ''
    );
  ELSE
    UPDATE auth.users
    SET
      encrypted_password = crypt('1234', gen_salt('bf')),
      email_confirmed_at = COALESCE(email_confirmed_at, now()),
      raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb)
        || '{"perfil":"Operador","codigo":"0001"}'::jsonb,
      updated_at = now()
    WHERE id = v_user_id;
  END IF;

  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_user_id,
    jsonb_build_object(
      'sub', v_user_id::TEXT,
      'email', 'asesor0001@bancofalabella.local',
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    'asesor0001@bancofalabella.local',
    now(),
    now(),
    now()
  )
  ON CONFLICT (provider, provider_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    identity_data = EXCLUDED.identity_data,
    updated_at = now();

  SELECT id, id_agencia
  INTO v_asesor_id, v_agencia_id
  FROM public.asesores_negocio
  WHERE codigo IN ('0001', 'A001', 'AG-001-01')
  ORDER BY id
  LIMIT 1;

  IF v_asesor_id IS NULL THEN
    SELECT id, id_agencia
    INTO v_asesor_id, v_agencia_id
    FROM public.asesores_negocio
    ORDER BY id
    LIMIT 1;
  END IF;

  IF v_asesor_id IS NOT NULL THEN
    INSERT INTO public.fv_usuarios_perfiles (user_id, asesor_id, agencia_id, perfil)
    VALUES (v_user_id, v_asesor_id, v_agencia_id, 'Operador')
    ON CONFLICT (user_id) DO UPDATE SET
      asesor_id = EXCLUDED.asesor_id,
      agencia_id = EXCLUDED.agencia_id,
      perfil = EXCLUDED.perfil,
      activo = TRUE,
      updated_at = now();
  END IF;
END $$;

SELECT
  'Asesor listo' AS estado,
  'asesor0001@bancofalabella.local' AS email,
  '1234' AS password;
