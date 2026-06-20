-- ============================================================
-- USUARIO DE PRUEBA PARA LA APP
-- Email: alumno1@example.com
-- Password: 12345
-- Ejecutar despues de cargar las tablas del scoring.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  v_user_id UUID;
  v_cuenta_id UUID := '11111111-1111-1111-1111-111111111111';
  v_score_id UUID := '22222222-2222-2222-2222-222222222222';
  v_ficha_id UUID := '33333333-3333-3333-3333-333333333333';
BEGIN
  SELECT id
  INTO v_user_id
  FROM auth.users
  WHERE email = 'alumno1@example.com'
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
      'alumno1@example.com',
      crypt('12345', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{}'::jsonb,
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
      encrypted_password = crypt('12345', gen_salt('bf')),
      email_confirmed_at = COALESCE(email_confirmed_at, now()),
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
      'email', 'alumno1@example.com',
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    'alumno1@example.com',
    now(),
    now(),
    now()
  )
  ON CONFLICT (provider, provider_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    identity_data = EXCLUDED.identity_data,
    updated_at = now();

  INSERT INTO public.auth_mock (id, email)
  VALUES (v_user_id, 'alumno1@example.com')
  ON CONFLICT (email) DO UPDATE SET id = EXCLUDED.id;

  INSERT INTO public.perfiles_clientes (
    user_id,
    dni,
    nombres,
    apellidos,
    fecha_nacimiento,
    telefono,
    distrito,
    provincia,
    departamento,
    nombre_negocio,
    tipo_negocio,
    direccion_negocio,
    lat_negocio,
    lng_negocio,
    antiguedad_negocio_meses,
    tenencia_local,
    num_entidades_sbs,
    calificacion_sbs,
    deuda_total_sbs,
    estado_cliente
  ) VALUES (
    v_user_id,
    '12345678',
    'Alumno',
    'Uno Demo',
    DATE '1998-05-20',
    '999888777',
    'Huancayo',
    'Huancayo',
    'Junin',
    'Bodega Alumno Uno',
    'Bodega',
    'Jr. Real 123, Huancayo',
    -12.0650000,
    -75.2050000,
    42,
    'alquilado_con_contrato',
    1,
    'Normal',
    2500.00,
    'activo'
  )
  ON CONFLICT (user_id) DO UPDATE SET
    dni = EXCLUDED.dni,
    nombres = EXCLUDED.nombres,
    apellidos = EXCLUDED.apellidos,
    fecha_nacimiento = EXCLUDED.fecha_nacimiento,
    telefono = EXCLUDED.telefono,
    distrito = EXCLUDED.distrito,
    provincia = EXCLUDED.provincia,
    departamento = EXCLUDED.departamento,
    nombre_negocio = EXCLUDED.nombre_negocio,
    tipo_negocio = EXCLUDED.tipo_negocio,
    direccion_negocio = EXCLUDED.direccion_negocio,
    lat_negocio = EXCLUDED.lat_negocio,
    lng_negocio = EXCLUDED.lng_negocio,
    antiguedad_negocio_meses = EXCLUDED.antiguedad_negocio_meses,
    tenencia_local = EXCLUDED.tenencia_local,
    num_entidades_sbs = EXCLUDED.num_entidades_sbs,
    calificacion_sbs = EXCLUDED.calificacion_sbs,
    deuda_total_sbs = EXCLUDED.deuda_total_sbs,
    estado_cliente = EXCLUDED.estado_cliente,
    updated_at = now();

  INSERT INTO public.cuentas (
    id,
    user_id,
    tipo,
    numero_cuenta,
    saldo,
    moneda,
    created_at
  ) VALUES (
    v_cuenta_id,
    v_user_id,
    'ahorro',
    '019-ALUMNO1',
    3250.00,
    'PEN',
    now() - INTERVAL '24 months'
  )
  ON CONFLICT (id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    tipo = EXCLUDED.tipo,
    numero_cuenta = EXCLUDED.numero_cuenta,
    saldo = EXCLUDED.saldo,
    moneda = EXCLUDED.moneda,
    updated_at = now();

  INSERT INTO public.movimientos_mensuales (
    user_id,
    cuenta_id,
    periodo,
    abonos_mes,
    cargos_mes,
    saldo_fin_mes,
    num_transacciones
  ) VALUES (
    v_user_id,
    v_cuenta_id,
    TO_CHAR(now() - INTERVAL '1 month', 'YYYY-MM'),
    3600.00,
    2400.00,
    3250.00,
    8
  )
  ON CONFLICT (user_id, cuenta_id, periodo) DO UPDATE SET
    abonos_mes = EXCLUDED.abonos_mes,
    cargos_mes = EXCLUDED.cargos_mes,
    saldo_fin_mes = EXCLUDED.saldo_fin_mes,
    num_transacciones = EXCLUDED.num_transacciones;

  INSERT INTO public.features_scoring (
    user_id,
    saldo_promedio,
    saldo_minimo,
    meses_saldo_positivo,
    ingreso_promedio,
    meses_con_abono,
    volatilidad_ingresos,
    ratio_ahorro_neto,
    depositos_recurrentes,
    antiguedad_cuenta_meses,
    meses_activos,
    edad,
    num_entidades_sbs,
    cuota_max_estimada,
    monto_max_por_ingreso,
    periodos_analizados
  ) VALUES (
    v_user_id,
    3250.00,
    1200.00,
    12,
    3600.00,
    11,
    420.00,
    0.32,
    9,
    24,
    12,
    28,
    1,
    1080.00,
    7200.00,
    12
  )
  ON CONFLICT (user_id) DO UPDATE SET
    saldo_promedio = EXCLUDED.saldo_promedio,
    saldo_minimo = EXCLUDED.saldo_minimo,
    meses_saldo_positivo = EXCLUDED.meses_saldo_positivo,
    ingreso_promedio = EXCLUDED.ingreso_promedio,
    meses_con_abono = EXCLUDED.meses_con_abono,
    volatilidad_ingresos = EXCLUDED.volatilidad_ingresos,
    ratio_ahorro_neto = EXCLUDED.ratio_ahorro_neto,
    depositos_recurrentes = EXCLUDED.depositos_recurrentes,
    antiguedad_cuenta_meses = EXCLUDED.antiguedad_cuenta_meses,
    meses_activos = EXCLUDED.meses_activos,
    edad = EXCLUDED.edad,
    num_entidades_sbs = EXCLUDED.num_entidades_sbs,
    cuota_max_estimada = EXCLUDED.cuota_max_estimada,
    monto_max_por_ingreso = EXCLUDED.monto_max_por_ingreso,
    periodos_analizados = EXCLUDED.periodos_analizados,
    updated_at = now();

  INSERT INTO public.scores_transaccionales (
    id,
    user_id,
    pts_saldo,
    pts_regularidad,
    pts_disciplina,
    pts_vinculo,
    pts_riesgo,
    monto_hipotesis,
    ingreso_promedio_ref,
    cuota_max_ref,
    es_valido
  ) VALUES (
    v_score_id,
    v_user_id,
    160,
    160,
    160,
    120,
    90,
    5000.00,
    3600.00,
    1080.00,
    TRUE
  )
  ON CONFLICT (user_id) DO UPDATE SET
    id = EXCLUDED.id,
    pts_saldo = EXCLUDED.pts_saldo,
    pts_regularidad = EXCLUDED.pts_regularidad,
    pts_disciplina = EXCLUDED.pts_disciplina,
    pts_vinculo = EXCLUDED.pts_vinculo,
    pts_riesgo = EXCLUDED.pts_riesgo,
    monto_hipotesis = EXCLUDED.monto_hipotesis,
    ingreso_promedio_ref = EXCLUDED.ingreso_promedio_ref,
    cuota_max_ref = EXCLUDED.cuota_max_ref,
    es_valido = EXCLUDED.es_valido,
    updated_at = now();

  INSERT INTO public.fichas_campo (
    id,
    user_id,
    score_id,
    asesor_nombre,
    agencia,
    fecha_visita,
    hora_inicio,
    hora_fin,
    negocio_verificado,
    antiguedad_negocio,
    pts_antiguedad,
    tenencia_local,
    pts_tenencia,
    direccion_verificada,
    ventas_diarias_rango,
    pts_ventas,
    ventas_mensuales_est,
    gastos_fijos_mes,
    ratio_gastos,
    pts_gastos,
    ingreso_consistente,
    tiene_deuda_informal,
    pts_deuda_informal,
    monto_deuda_informal,
    participa_pandero,
    pts_pandero,
    stock_visible,
    pts_stock,
    activos_hogar,
    pts_activos,
    caracter_resultado,
    score_transaccional_ref,
    monto_aprobado_propuesto,
    plazo_propuesto_meses,
    cuota_estimada,
    recomendacion_asesor,
    comite_resolucion,
    comite_monto_final,
    comite_plazo_final,
    jefe_agencia,
    fecha_comite,
    estado_ficha
  ) VALUES (
    v_ficha_id,
    v_user_id,
    v_score_id,
    'Marco Sulca Vera',
    'Agencia Huancayo Centro',
    CURRENT_DATE - 3,
    TIME '09:00',
    TIME '09:50',
    TRUE,
    'mas_3_anios',
    40,
    'alquilado_con_contrato',
    10,
    'Jr. Real 123, Huancayo',
    '151_a_300',
    30,
    5720.00,
    2173.60,
    'menos_50pct',
    15,
    TRUE,
    'no',
    20,
    0.00,
    'no',
    20,
    'abundante',
    20,
    'al_menos_uno',
    20,
    'sin_penalidad',
    690,
    4200.00,
    12,
    475.50,
    'aprobar',
    'aprobado',
    4200.00,
    12,
    'Lic. Rosa Meza Quispe',
    CURRENT_DATE - 2,
    'completada'
  )
  ON CONFLICT (id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    score_id = EXCLUDED.score_id,
    asesor_nombre = EXCLUDED.asesor_nombre,
    agencia = EXCLUDED.agencia,
    fecha_visita = EXCLUDED.fecha_visita,
    negocio_verificado = EXCLUDED.negocio_verificado,
    score_transaccional_ref = EXCLUDED.score_transaccional_ref,
    monto_aprobado_propuesto = EXCLUDED.monto_aprobado_propuesto,
    comite_resolucion = EXCLUDED.comite_resolucion,
    comite_monto_final = EXCLUDED.comite_monto_final,
    estado_ficha = EXCLUDED.estado_ficha,
    updated_at = now();

  INSERT INTO public.creditos_preaprobados (
    id,
    user_id,
    ficha_id,
    score_id,
    segmento,
    score_transaccional,
    score_campo,
    score_final,
    monto_hipotesis,
    monto_aprobado,
    plazo_meses,
    tasa_tea,
    cuota_mensual,
    estado,
    fecha_preaprobacion,
    fecha_contacto,
    fecha_visita,
    fecha_aprobacion,
    fecha_desembolso,
    dias_mora,
    estado_pago
  ) VALUES (
    '44444444-4444-4444-4444-444444444444',
    v_user_id,
    v_ficha_id,
    v_score_id,
    'PREMIER',
    690,
    155,
    845,
    5000.00,
    4200.00,
    12,
    0.60,
    475.50,
    'desembolsado',
    CURRENT_DATE - 5,
    CURRENT_DATE - 4,
    CURRENT_DATE - 3,
    CURRENT_DATE - 2,
    CURRENT_DATE - 1,
    0,
    'al_dia'
  )
  ON CONFLICT (id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    ficha_id = EXCLUDED.ficha_id,
    score_id = EXCLUDED.score_id,
    segmento = EXCLUDED.segmento,
    score_transaccional = EXCLUDED.score_transaccional,
    score_campo = EXCLUDED.score_campo,
    score_final = EXCLUDED.score_final,
    monto_hipotesis = EXCLUDED.monto_hipotesis,
    monto_aprobado = EXCLUDED.monto_aprobado,
    plazo_meses = EXCLUDED.plazo_meses,
    cuota_mensual = EXCLUDED.cuota_mensual,
    estado = EXCLUDED.estado,
    dias_mora = EXCLUDED.dias_mora,
    estado_pago = EXCLUDED.estado_pago,
    updated_at = now();
END $$;

SELECT
  'Usuario listo' AS estado,
  'alumno1@example.com' AS email,
  '12345' AS password;
