# Integracion Supabase

Los archivos SQL del profesor se mantienen sin cambios en la carpeta anterior al proyecto.

## Orden de ejecucion sugerido

1. Ejecutar el setup base que cree `public.cuentas` y `public.transacciones`.
2. Ejecutar `supabase/sql/01_preparar_scoring_preaprobados.sql`.
3. Ejecutar `scoring_preaprobados.sql`.
4. Ejecutar `seed_agencias_asesores.sql`.
5. Ejecutar `supabase/sql/02_compatibilidad_antes_seed_1800.sql`.
6. Ejecutar `supabase/sql/03_seed_scoring_1800_compatible.sql`.
7. Ejecutar `supabase/sql/04_usuario_prueba_alumno1.sql`.
8. Ejecutar `supabase/sql/05_policies_fuerza_ventas.sql`.
9. Ejecutar `supabase/sql/06_semana11_hu_fuerza_ventas.sql`.
10. Ejecutar `supabase/sql/07_rubrica_final_fuerza_ventas.sql`.

## Conexion Supabase de la app

La app ya tiene configurado un proyecto Supabase por defecto en
`lib/supabase_config.dart`, por eso puede ejecutarse directamente:

```bash
flutter run
```

Si se necesita apuntar a otro proyecto Supabase, se pueden sobrescribir las
credenciales con `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

El modo demo existe en el codigo para pruebas del frontend, pero con la
configuracion actual la app intenta conectarse al Supabase configurado por
defecto.

## Tablas y vistas que consume la app

- `perfiles_clientes`
- `scores_transaccionales`
- `creditos_preaprobados`
- `fichas_campo`
- `vw_pbi_agencias`
- `vw_pbi_asesores`
- `vw_pbi_fichas_campo`
- `vw_pbi_kpis_piloto`
- `cartera_diaria`
- `solicitudes_credito`
- `solicitudes_documentos`
- `consultas_buro`
- `acciones_cobranza`
- `alertas_cartera`
- `fv_usuarios_perfiles`
- `fv_sync_queue`
- `fv_eventos_realtime`
- `fv_pdfs_generados`

## Observaciones sin editar los SQL originales

- Los scripts del profesor asumen que ya existen `public.cuentas` y `public.transacciones`.
- `scores_transaccionales` debe permitir conflicto por `user_id` para que funcione la funcion `calcular_score_transaccional`.
- El seed masivo crea datos simulados, pero depende de usuarios compatibles con `auth.users`.
- La app fuerza de ventas necesita politicas RLS mas amplias que la app cliente: leer cartera completa, insertar `fichas_campo` y actualizar estado en `creditos_preaprobados`.
- Si el profesor pide mantener los SQL intactos, esos ajustes deben manejarse como setup complementario o desde Supabase antes de cargar la data.
- `03_seed_scoring_1800_compatible.sql` es una copia del seed de 1,800 clientes con un casteo a `BIGINT` para evitar overflow al generar telefonos. El original del profesor no se modifica.
- `05_policies_fuerza_ventas.sql` es complementario: no cambia los SQL del profesor, solo habilita permisos para el usuario autenticado de la app de asesores.
- `06_semana11_hu_fuerza_ventas.sql` agrega las tablas operativas solicitadas en la guia S11 y genera datos demo desde la cartera ya cargada.
- `07_rubrica_final_fuerza_ventas.sql` agrega perfiles, cola offline, bucket `documentos-credito`, eventos y PDFs para cerrar la rubrica final.
