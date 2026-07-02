# Auditoria de cumplimiento - Banco Falabella

Fecha: 2026-07-02  
Auditor: Ingenieria de Sistemas senior  
Alcance revisado: `core-api`, `web-core`, `app-fuerza-ventas`, `app-clientes`, scripts Supabase y despliegue Firebase/Railway.

## Veredicto ejecutivo

Estado inicial auditado: **CUMPLE PARCIAL**.  
Estado posterior a correcciones aplicadas en esta rama: **CUMPLE MAYORITARIAMENTE**, pendiente de ejecutar la migracion SQL y redesplegar el core para que los nuevos endpoints queden activos en Railway.

El ecosistema tiene una base funcional importante: core FastAPI desplegado, web React compilable y publicada, app cliente, app fuerza de ventas, conexion Core -> BD validada y branding Banco Falabella consistente. Sin embargo, **no cumple completamente como solucion productiva/academica integral** porque faltan o son parciales estos puntos criticos:

- RBAC real para `comite`, `analista`, `supervisor` y `administrador`.
- Endpoints obligatorios de CRUD, documentos, reportes, sync offline y administracion.
- Seguridad de App Cliente: algunas rutas operan por DNI o demo sin Bearer token.
- Offline-first real en Fuerza de Ventas: no hay SQLite/Hive ni cola local persistente.
- Uso de mocks/demo/fallbacks en flujos que deberian ser reales.
- DDL fuente del core casi vacio: `core-api/sql/01_schema_bd_core_mobile.sql` mide 2 bytes.

### Correcciones implementadas despues de la auditoria

- RBAC backend con normalizacion de roles y dependencias por perfil.
- Endpoints faltantes: `/auth/me`, `/auth/logout`, detalle de solicitudes, estado/aprobar/rechazar/condicionar, documentos, reportes, sync bootstrap/pendientes, listas y administracion.
- App Cliente ahora usa endpoints protegidos con Bearer para resumen y solicitudes; cronograma valida pertenencia del credito.
- Web Backoffice filtra rutas/menu por rol e incorpora modulo Administrador.
- Fuerza de Ventas agrega cache local y cola persistente de operaciones con `shared_preferences`.
- Migracion SQL idempotente agregada en `core-api/sql/02_cumplimiento_rbac_admin_offline.sql` con tablas, constraints, indices, auditoria, notificaciones y RLS.
- Conexion productiva verificada el 2026-07-02: web publicada apunta al core nuevo, core responde OK, CORS preflight OK y `/casos/conexion` reporta `bd_core_mobile: ok`.

## Evidencia tecnica ejecutada

- `npm run build` en `web-core`: **OK**.
- `flutter analyze` en `app-fuerza-ventas`: **OK**.
- `flutter analyze` en `app-clientes`: **OK**.
- Core Railway verificado previamente: `/casos/conexion` responde `api: ok`, `bd_core_mobile: ok`.
- Firebase Hosting verificado previamente: bundle publicado apunta a `n-stack22-bancofallabela-production`.

## Actores y roles

| Actor requerido | Estado | Evidencia | Observacion |
|---|---:|---|---|
| Cliente | PARCIAL | `app-clientes/lib/main.dart`, `core-api/app/routes/rtr_cliente.py` | Existe app cliente, login y productos; usa resumen demo por DNI sin token. |
| Asesor / operador | PARCIAL | `app-fuerza-ventas/lib`, `/auth/login`, `/cartera` | Existe login, cartera, ficha, solicitud, documentos y cobranza; offline real incompleto. |
| Comite / analista | PARCIAL | `web-core/src/pages/SolicitudesPage.jsx`, `/solicitudes/{id}/comite` | Hay aprobar/rechazar/condicionar, pero cualquier asesor autenticado puede ejecutar decisiones. |
| Supervisor | PARCIAL | `web-core/src/pages/ReportesPage.jsx` | Solo productividad basica. Faltan filtros por agencia/fecha, supervision completa y permisos. |
| Administrador | NO CUMPLE | No hay modulo web ni endpoints admin | No existe gestion de usuarios, roles, agencias, catalogos ni parametros. |

Roles implementados: `cliente` y `asesor/operador` con campo `perfil`. No hay enforcement real para `comite`, `analista`, `supervisor`, `administrador`.

## Core / API FastAPI

| Requisito | Estado | Evidencia | Riesgo |
|---|---:|---|---|
| Arquitectura por rutas/schemas/repositorios | CUMPLE | `core-api/app/routes`, `schemas`, `repositories` | Bajo |
| Variables de entorno y PostgreSQL | CUMPLE | `cfg_config.py`, `cfg_database.py` | Bajo |
| CORS | CUMPLE | `main.py` permite `*` | Medio en produccion por ser abierto. |
| OpenAPI/Swagger | CUMPLE | FastAPI expone docs por defecto | Bajo |
| Manejo centralizado de errores | PARCIAL | Manejo por ruta con `try/except` | Medio |
| JWT asesor/cliente | PARCIAL | `cfg_auth.py`, `cfg_security.py` | No hay RBAC por rol. |
| Expiracion token | CUMPLE | `ACCESS_TOKEN_EXPIRE_MINUTES` | Bajo |
| Logout/invalidation | NO CUMPLE | No existe endpoint | Medio |
| Rutas restringidas por rol | NO CUMPLE | Solo `get_current_asesor` / `get_current_cliente` | Alto |

### Endpoints requeridos vs encontrados

| Area | Requerido | Estado | Evidencia / observacion |
|---|---|---:|---|
| Auth | `POST /auth/login` | CUMPLE | `rtr_auth.py` |
| Auth | `GET /auth/me`, `POST /auth/logout` | NO CUMPLE | No existen. |
| Cartera | `GET /cartera` | CUMPLE | `rtr_cartera.py` |
| Cartera | `GET /cartera/{id}` | NO CUMPLE | No existe detalle directo. |
| Cartera | `PUT/PATCH /cartera/{id}/visita` | PARCIAL | Existe `POST /cartera/{id}/visita`. |
| Cartera | Filtros completos | PARCIAL | Solo `fecha`; falta prioridad/tipo/estado. |
| Clientes | CRUD `GET/POST/PATCH /clientes` | NO CUMPLE | Solo `/clientes/{id}/ficha` y ubicacion. |
| Clientes | Ficha/creditos/preaprobados | PARCIAL | Ficha existe; creditos/preaprobados separados no como endpoints requeridos. |
| Solicitudes | `POST /solicitudes`, `GET /solicitudes` | CUMPLE | `rtr_solicitudes.py` |
| Solicitudes | `GET /solicitudes/{id}` | NO CUMPLE | Solo notas y listado resumido. |
| Solicitudes | PATCH estado/aprobar/rechazar/condicionar | PARCIAL | Existe `POST /{id}/comite`, no endpoints REST separados. |
| Documentos | POST/GET/DELETE documentos via API | NO CUMPLE | App FV escribe directo a Supabase/Storage; core no expone endpoints. |
| Buro/listas | `POST /buro/consulta` | PARCIAL | Existe mock deterministico; no persiste resultado/consentimiento en core. |
| Preevaluacion | `POST /preevaluacion` | PARCIAL | Existe `POST /pre-evaluar`; mock. |
| Cobranza | `GET /cobranza/mora`, `POST /cobranza/acciones` | PARCIAL | Existe `/mora` y `POST /accion`; falta cliente/{id}. |
| Reportes | productividad/cobertura/solicitudes | PARCIAL | Solo `/reportes/productividad`. |
| Sync | pendientes/bootstrap | NO CUMPLE | Existe `/sync/promover` y `/sync/outbox`; no bootstrap/offline app. |
| Alertas | listar y marcar leida | PARCIAL | `GET /alertas`, `POST /alertas/{id}/leer`; no PATCH. |
| App Cliente | creditos/notificaciones | PARCIAL | Existen protegidos, pero app usa `/cliente/demo/{dni}/resumen`. |

## Reglas de negocio backend

| Regla | Estado | Observacion |
|---|---:|---|
| Numero de expediente unico | PARCIAL | Se genera `EXP-...`; depende de unique en BD real. |
| Estados requeridos | PARCIAL | DDL Supabase los define, pero core inicia en `enviado`; no modela todas las transiciones. |
| Transiciones validas | PARCIAL | Solo desembolso valida aprobado/condicionado. |
| Motivo obligatorio al rechazar | NO CUMPLE | `decidir_comite` no obliga `motivo_rechazo`. |
| Condicion obligatoria al condicionar | NO CUMPLE | No obliga `condicion_adicional`. |
| Monto obligatorio al aprobar | PARCIAL | Si falta, usa monto solicitado automaticamente. |
| Auditoria/timestamps | PARCIAL | `created_at/updated_at`; falta trazabilidad formal de decision. |
| No duplicar cliente por documento | CUMPLE | `numero_documento` unique/modelos; upsert por documento. |
| No duplicar cartera del dia | PARCIAL | SQL Supabase tiene unique; core DDL fuente no lo documenta. |

## Base de datos

Estado: **PARCIAL**.

Fortalezas:
- Modelos SQLAlchemy cubren `agencias`, `asesores`, `clientes`, `cartera_diaria`, `usuarios_cliente`, `cr_*`, `notificaciones`.
- Scripts Supabase de Fuerza de Ventas cubren `cartera_diaria`, `solicitudes_credito`, `solicitudes_documentos`, `consultas_buro`, `acciones_cobranza`, `alertas_cartera`, `solicitudes_notas_internas`.
- Hay indices en `core-api/scripts/optimize_supabase_indexes.sql`.

Brechas:
- `core-api/sql/01_schema_bd_core_mobile.sql` esta vacio en la practica; no sirve para reconstruir la BD.
- RLS de `app-fuerza-ventas/supabase/sql/08_policies_esquema_core_mobile.sql` usa `USING (true)` / `WITH CHECK (true)` para muchas tablas: alto riesgo de acceso cruzado.
- No se ve modulo formal de roles/permisos administrativos para web/core.
- No hay DDL consolidado unico que garantice constraints de todos los campos esperados.

## App Fuerza de Ventas Flutter

Estado: **PARCIAL ALTO funcional, PARCIAL BAJO offline/seguridad**.

Cumple o aproxima:
- Login Supabase: `lib/pages/login_page.dart`.
- MVVM parcial: `viewmodels`, `services`, `models`, documentado en `docs/arquitectura_mvvm.md`.
- Cartera diaria, filtros, busqueda, KPI y progreso: `home_page.dart`.
- Ruta y navegacion externa: mapa operativo simulado y uso de geolocalizacion.
- Ficha 360/pre-evaluacion/simulador/solicitud en pasos: `home_page.dart`.
- Firma digital placeholder y documentos con camara/Storage: `image_picker`, `uploadDocument`.
- Buro/listas mock, cobranza, reportes y PDF.

No cumple:
- Offline-first real: no hay `sqflite`, `hive`, `isar` ni almacenamiento local persistente.
- Cache solo en memoria (`_cachedDashboard`) y por segundos; no sobrevive cierre de app.
- No hay cola local persistente de visitas/solicitudes/documentos; `sync_outbox` es remoto.
- La app consume Supabase directo, no el Core FastAPI/JWT. Esto rompe la arquitectura "app -> core -> BD" esperada para varios requisitos.
- RLS muy permisivo permite que un usuario autenticado vea/actualice mas de lo debido si la politica esta aplicada.

## App Cliente

Estado: **PARCIAL**.

Cumple:
- Existe implementacion Flutter en `app-clientes`.
- Login cliente con JWT y `flutter_secure_storage`.
- Dashboard, creditos, cronograma, pagos/transferencias demo, solicitud de credito.
- Branding Banco Falabella.

Brechas criticas:
- La carga principal usa `GET /cliente/demo/{numero_documento}/resumen` sin Bearer token.
- `POST /cliente/solicitudes` y `GET /cliente/solicitudes/{numero_documento}` no exigen `get_current_cliente`.
- Hay credenciales demo `12345` y fallbacks demo.
- No se garantiza "solo datos propios" en todos los endpoints usados por la app.

## Web / Backoffice React

Estado: **PARCIAL**.

Cumple:
- Login y rutas privadas (`PrivateRoute`).
- Pantallas esperadas: Login, Dashboard, Cartera, Ficha, Solicitudes, Nueva Solicitud, Evaluacion, Cobranza, Reportes, Casos.
- Servicios separados por entidad.
- API por env y token Bearer.
- Build correcto.

No cumple:
- No hay menu ni rutas por rol.
- No hay modulo Administrador.
- No hay gestion de usuarios, roles, agencias, catalogos ni parametros.
- Comite no esta separado: acciones de comite viven en `SolicitudesPage` y el backend acepta cualquier asesor autenticado.
- Falta detalle completo de expediente con documentos/firma/buro/linea de tiempo real.
- Reportes de supervisor son basicos y sin filtros completos.

## Flujo end-to-end

Estado: **PARCIAL / DEMO**.

El flujo demo funciona conceptualmente: cliente/asesor crean solicitudes, web decide comite, se marca desembolso y existe `sync_outbox`. Pero no cumple como flujo real completo porque:

- Admin no crea usuarios desde UI.
- App FV no opera offline con persistencia local.
- Documentos no pasan por endpoints Core.
- Comite no tiene rol propio.
- App Cliente ve informacion via endpoint demo por DNI.
- No hay notificacion robusta asesor/cliente ante cambios, solo registros/listados parciales.

## Branding Banco Falabella

Estado: **CUMPLE**.

No se encontraron referencias visibles a `Banco Andino` ni `Core Andino`. El codigo visible usa Banco Falabella, CMR/Rapicash y colores institucionales aproximados.

## Riesgos principales

1. **Alto - Autorizacion insuficiente:** usuarios asesores pueden ejecutar acciones de comite y ver reportes globales.
2. **Alto - Acceso cruzado en Supabase:** RLS con `USING (true)` y app movil directo a BD.
3. **Alto - App Cliente por DNI/demo:** riesgo de consultar datos ajenos si se conoce documento.
4. **Medio - Offline declarado pero no persistente:** perdida de operaciones al cerrar app o perder sesion.
5. **Medio - Replicabilidad de BD:** DDL del core vacio y scripts dispersos.
6. **Medio - Mocks en negocio critico:** buro, pre-evaluacion, firma y fallback demo no son trazabilidad productiva.

## Recomendaciones concretas

1. Implementar RBAC backend: dependencias `require_role("comite")`, `require_role("supervisor")`, `require_role("admin")`.
2. Separar usuarios web por perfiles y ocultar/denegar rutas segun rol.
3. Proteger `POST /cliente/solicitudes`, `GET /cliente/solicitudes`, resumen cliente y operaciones con `get_current_cliente`; eliminar consultas por DNI publico.
4. Crear endpoints faltantes: `/auth/me`, documentos, detalle solicitud, PATCH estado, reportes cobertura/solicitudes, sync bootstrap/pendientes.
5. Mover App FV de Supabase directo a Core API o endurecer RLS con `auth.uid()` y pertenencia asesor-cliente.
6. Implementar offline real en App FV con SQLite/Hive: cache cartera/ficha, borradores, cola local y reintentos.
7. Consolidar DDL oficial en `core-api/sql/01_schema_bd_core_mobile.sql` con PK/FK/UNIQUE/CHECK/INDEX.
8. Crear modulo Admin web: usuarios, roles, agencias, catalogos y parametros.
9. Registrar auditoria de decisiones de comite con analista, fecha, estado anterior/nuevo, motivo/condicion/monto.
10. Retirar endpoints `/demo` y credenciales fijas para entrega productiva; dejarlos solo bajo flag `DEMO_MODE`.
