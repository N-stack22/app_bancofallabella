-- ============================================================
-- POLITICAS PARA APP FUERZA DE VENTAS
-- Ejecutar DESPUES de scoring_preaprobados.sql,
-- seed_agencias_asesores.sql y los seeds de clientes.
--
-- Motivo:
-- Los SQL del profesor dejan RLS pensado para la app cliente
-- (cada cliente ve solo su informacion). La app de fuerza de
-- ventas necesita que el asesor autenticado pueda leer cartera,
-- registrar fichas de campo y actualizar estados de solicitudes.
-- ============================================================

GRANT USAGE ON SCHEMA public TO authenticated;

GRANT SELECT ON public.perfiles_clientes TO authenticated;
GRANT UPDATE (direccion_negocio, lat_negocio, lng_negocio, updated_at)
  ON public.perfiles_clientes TO authenticated;
GRANT SELECT ON public.scores_transaccionales TO authenticated;
GRANT SELECT ON public.creditos_preaprobados TO authenticated;
GRANT SELECT, INSERT ON public.fichas_campo TO authenticated;
GRANT UPDATE (estado, fecha_contacto, fecha_visita, updated_at)
  ON public.creditos_preaprobados TO authenticated;

GRANT SELECT ON public.agencias TO authenticated;
GRANT SELECT ON public.asesores_negocio TO authenticated;
GRANT SELECT ON public.vw_pbi_agencias TO authenticated;
GRANT SELECT ON public.vw_pbi_asesores TO authenticated;
GRANT SELECT ON public.vw_pbi_fichas_campo TO authenticated;
GRANT SELECT ON public.vw_pbi_kpis_piloto TO authenticated;

DROP POLICY IF EXISTS "FV lee perfiles de cartera"
  ON public.perfiles_clientes;
CREATE POLICY "FV lee perfiles de cartera"
  ON public.perfiles_clientes FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV actualiza ubicacion de negocio"
  ON public.perfiles_clientes;
CREATE POLICY "FV actualiza ubicacion de negocio"
  ON public.perfiles_clientes FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV lee scores de cartera"
  ON public.scores_transaccionales;
CREATE POLICY "FV lee scores de cartera"
  ON public.scores_transaccionales FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV lee creditos de cartera"
  ON public.creditos_preaprobados;
CREATE POLICY "FV lee creditos de cartera"
  ON public.creditos_preaprobados FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV actualiza estado de creditos"
  ON public.creditos_preaprobados;
CREATE POLICY "FV actualiza estado de creditos"
  ON public.creditos_preaprobados FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "FV lee fichas de cartera"
  ON public.fichas_campo;
CREATE POLICY "FV lee fichas de cartera"
  ON public.fichas_campo FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "FV registra fichas de campo"
  ON public.fichas_campo;
CREATE POLICY "FV registra fichas de campo"
  ON public.fichas_campo FOR INSERT
  TO authenticated
  WITH CHECK (true);
