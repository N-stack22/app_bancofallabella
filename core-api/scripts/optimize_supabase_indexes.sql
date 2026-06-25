-- Indices recomendados para acelerar las pantallas principales del ecosistema.
-- Ejecutar una vez en Supabase SQL Editor o con psql conectado al proyecto.

CREATE INDEX IF NOT EXISTS idx_clientes_numero_documento
  ON clientes (numero_documento);

CREATE INDEX IF NOT EXISTS idx_asesores_activo_created
  ON asesores (activo, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_cartera_asesor_fecha_score
  ON cartera_diaria (asesor_id, fecha_asignacion, score_prioridad DESC);

CREATE INDEX IF NOT EXISTS idx_cartera_cliente_fecha
  ON cartera_diaria (cliente_id, fecha_asignacion DESC);

CREATE INDEX IF NOT EXISTS idx_solicitudes_asesor_created
  ON solicitudes_credito (asesor_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_solicitudes_cliente_created
  ON solicitudes_credito (cliente_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_solicitudes_estado_created
  ON solicitudes_credito (estado, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sync_outbox_estado_entidad
  ON sync_outbox (estado, entidad, created_at);

CREATE INDEX IF NOT EXISTS idx_usuarios_cliente_username
  ON usuarios_cliente (username);

CREATE INDEX IF NOT EXISTS idx_cr_cuentas_cliente
  ON cr_cuentas_ahorro (cliente_id, cod_cuenta_ahorro);

CREATE INDEX IF NOT EXISTS idx_cr_creditos_cliente_desembolso
  ON cr_creditos (cliente_id, fecha_desembolso DESC);

CREATE INDEX IF NOT EXISTS idx_cr_movimientos_cliente_fecha
  ON cr_movimientos (cliente_id, fecha_operacion DESC);

CREATE INDEX IF NOT EXISTS idx_cr_cronograma_credito_cuota
  ON cr_cronograma_pagos (cod_cuenta_credito, nro_cuota);

CREATE INDEX IF NOT EXISTS idx_notificaciones_cliente_fecha
  ON notificaciones (cliente_id, created_at DESC)
  WHERE destinatario_tipo = 'cliente';
