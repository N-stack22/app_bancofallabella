-- ============================================================
-- POLITICAS FUERZA DE VENTAS - ESQUEMA CORE MOBILE REAL
-- Ejecutar en Supabase SQL Editor si la app inicia sesion pero
-- no carga datos de cartera.
--
-- Esquema objetivo: agencias, asesores, clientes, cartera_diaria,
-- creditos_preaprobados, solicitudes_credito y tablas operativas.
-- ============================================================

GRANT USAGE ON SCHEMA public TO authenticated;

GRANT SELECT ON public.agencias TO authenticated;
GRANT SELECT ON public.asesores TO authenticated;
GRANT SELECT, UPDATE ON public.clientes TO authenticated;
GRANT SELECT ON public.cr_creditos TO authenticated;
GRANT SELECT ON public.cr_cuentas_ahorro TO authenticated;
GRANT SELECT ON public.cr_movimientos TO authenticated;
GRANT SELECT ON public.cr_cronograma_pagos TO authenticated;
GRANT SELECT, UPDATE ON public.creditos_preaprobados TO authenticated;
GRANT SELECT, UPDATE ON public.cartera_diaria TO authenticated;
GRANT SELECT ON public.campanas_activas TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.solicitudes_credito TO authenticated;
GRANT SELECT, INSERT ON public.solicitudes_documentos TO authenticated;
GRANT SELECT, INSERT ON public.consultas_buro TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.acciones_cobranza TO authenticated;
GRANT SELECT, UPDATE ON public.alertas_cartera TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.solicitudes_notas_internas TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.sync_outbox TO authenticated;
GRANT SELECT, INSERT ON public.sync_log TO authenticated;

DROP POLICY IF EXISTS "FV lee agencias" ON public.agencias;
CREATE POLICY "FV lee agencias"
  ON public.agencias FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV lee asesores" ON public.asesores;
CREATE POLICY "FV lee asesores"
  ON public.asesores FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV lee clientes" ON public.clientes;
CREATE POLICY "FV lee clientes"
  ON public.clientes FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV actualiza clientes" ON public.clientes;
CREATE POLICY "FV actualiza clientes"
  ON public.clientes FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV lee cartera" ON public.cartera_diaria;
CREATE POLICY "FV lee cartera"
  ON public.cartera_diaria FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV actualiza cartera" ON public.cartera_diaria;
CREATE POLICY "FV actualiza cartera"
  ON public.cartera_diaria FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV lee preaprobados" ON public.creditos_preaprobados;
CREATE POLICY "FV lee preaprobados"
  ON public.creditos_preaprobados FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV actualiza preaprobados" ON public.creditos_preaprobados;
CREATE POLICY "FV actualiza preaprobados"
  ON public.creditos_preaprobados FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV lee solicitudes" ON public.solicitudes_credito;
CREATE POLICY "FV lee solicitudes"
  ON public.solicitudes_credito FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV registra solicitudes" ON public.solicitudes_credito;
CREATE POLICY "FV registra solicitudes"
  ON public.solicitudes_credito FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV actualiza solicitudes" ON public.solicitudes_credito;
CREATE POLICY "FV actualiza solicitudes"
  ON public.solicitudes_credito FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV lee documentos" ON public.solicitudes_documentos;
CREATE POLICY "FV lee documentos"
  ON public.solicitudes_documentos FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV registra documentos" ON public.solicitudes_documentos;
CREATE POLICY "FV registra documentos"
  ON public.solicitudes_documentos FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV lee consultas buro" ON public.consultas_buro;
CREATE POLICY "FV lee consultas buro"
  ON public.consultas_buro FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV registra consultas buro" ON public.consultas_buro;
CREATE POLICY "FV registra consultas buro"
  ON public.consultas_buro FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV lee cobranza" ON public.acciones_cobranza;
CREATE POLICY "FV lee cobranza"
  ON public.acciones_cobranza FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV registra cobranza" ON public.acciones_cobranza;
CREATE POLICY "FV registra cobranza"
  ON public.acciones_cobranza FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV actualiza cobranza" ON public.acciones_cobranza;
CREATE POLICY "FV actualiza cobranza"
  ON public.acciones_cobranza FOR UPDATE TO authenticated
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

DROP POLICY IF EXISTS "FV lee outbox" ON public.sync_outbox;
CREATE POLICY "FV lee outbox"
  ON public.sync_outbox FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV registra outbox" ON public.sync_outbox;
CREATE POLICY "FV registra outbox"
  ON public.sync_outbox FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV actualiza outbox" ON public.sync_outbox;
CREATE POLICY "FV actualiza outbox"
  ON public.sync_outbox FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV lee creditos core" ON public.cr_creditos;
CREATE POLICY "FV lee creditos core"
  ON public.cr_creditos FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV lee cuentas ahorro core" ON public.cr_cuentas_ahorro;
CREATE POLICY "FV lee cuentas ahorro core"
  ON public.cr_cuentas_ahorro FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV lee movimientos core" ON public.cr_movimientos;
CREATE POLICY "FV lee movimientos core"
  ON public.cr_movimientos FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV lee cronograma core" ON public.cr_cronograma_pagos;
CREATE POLICY "FV lee cronograma core"
  ON public.cr_cronograma_pagos FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV lee campanas" ON public.campanas_activas;
CREATE POLICY "FV lee campanas"
  ON public.campanas_activas FOR SELECT TO authenticated
  USING (true);

