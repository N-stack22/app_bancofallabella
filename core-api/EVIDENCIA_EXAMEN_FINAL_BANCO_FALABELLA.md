# Evidencia Examen Final - Banco Falabella

Fecha de verificacion: 2026-06-17

## Flujo principal implementado

1. App Clientes registra solicitud de credito empresarial desde un caso del PDF.
2. Core FastAPI recibe la solicitud, genera expediente y guarda en `bd_core_mobile`.
3. Core inserta `sync_outbox` y asigna la solicitud a `cartera_diaria`.
4. App Fuerza de Ventas lee `/cartera/demo` desde el Core.
5. Asesor abre ficha, registra evaluacion de campo y envia al comite.
6. Core cambia la solicitud a `recibido_comite`.
7. Portal web `/solicitudes` permite decidir comite: aprobar, condicionar o rechazar.
8. Si se aprueba o condiciona, el portal permite desembolsar.
9. Core cambia a `desembolsado` y registra evento en `sync_outbox`.

## Evidencia 30 casos

Endpoint:

```text
GET http://127.0.0.1:8003/casos/dashboard
```

Resultado verificado:

```text
total_casos: 30
desembolsados: 24
condicionados: 3
rechazados: 3
monto_solicitado: 379000
monto_aprobado: 304000
```

## Rutas de prueba

Core:

```text
GET  /casos
GET  /casos/dashboard
POST /casos/sembrar
GET  /cartera/demo
POST /cartera/demo/{cartera_id}/comite
GET  /solicitudes/demo
POST /solicitudes/demo/{solicitud_id}/comite
POST /solicitudes/demo/{solicitud_id}/desembolso
GET  /sync/outbox/demo
GET  /cliente/demo/{numero_documento}/resumen
```

Portal web:

```text
http://127.0.0.1:5173/inicio
http://127.0.0.1:5173/casos
http://127.0.0.1:5173/cartera
http://127.0.0.1:5173/solicitudes
```

Fuerza de Ventas Flutter Web:

```text
http://localhost:57610
flutter run -d chrome --web-port 57610 --dart-define=CORE_BASE_URL=http://127.0.0.1:8003
```

## Rubrica - autoevaluacion

| Criterio | Estado | Evidencia |
| --- | --- | --- |
| Integracion end-to-end | Cubierto en flujo demo | Cliente -> Core -> BD -> Fuerza de Ventas -> Comite -> Desembolso -> sync_outbox |
| Fuerza de Ventas | Cubierto | Cartera, filtros, ficha, evaluacion, envio a comite, estados |
| App Clientes | Bueno | Solicitud real al Core con 30 casos; endpoint demo materializa productos reales espejo `cr_*`: cuenta, credito, cronograma, movimiento, tarjeta y notificacion por DNI |
| Seguridad/RBAC | Parcial/Bueno | Core tiene JWT para asesor y cliente; login cliente probado con DNI 77889911 / clave 12345 y endpoints protegidos `/cliente/creditos`, `/cliente/cuentas`; flujo demo usa endpoints `/demo` para facilitar examen |
| Calidad/datos/docs | Cubierto/Bueno | SQL versionado, tablas `cr_*`, `sync_outbox`, repositorios/rutas, evidencia documentada |

## Recomendacion para sustentacion

Mostrar este orden:

1. `/casos`: confirmar 30 casos y conexion BD.
2. App Clientes: enviar una solicitud al Core.
3. Fuerza de Ventas: actualizar cartera y filtrar pendientes.
4. Ficha: evaluar y enviar al comite.
5. `/solicitudes`: aprobar o condicionar.
6. `/solicitudes`: desembolsar.
7. `/sync/outbox/demo`: mostrar eventos `decision_comite` y `desembolso`.
8. `/cliente/demo/{DNI}/resumen`: mostrar que el desembolso aparece como producto del cliente en tablas `cr_*`.

## Evidencia App Clientes / cr_*

Ejemplo probado:

```text
GET http://127.0.0.1:8003/cliente/demo/77889911/resumen
```

Resultado esperado:

```text
cuentas: AHO-9911
creditos: CR-EXP-A00E51A8
cronograma: 12 cuotas
movimientos: Desembolso credito empresarial
tarjetas: Visa ****9911
notificaciones: Credito desembolsado
```

Login cliente protegido probado:

```text
POST http://127.0.0.1:8003/cliente/login
body: {"numero_documento":"77889911","password":"12345"}

GET /cliente/creditos con Bearer token -> 1 credito
GET /cliente/cuentas con Bearer token -> 1 cuenta
```
