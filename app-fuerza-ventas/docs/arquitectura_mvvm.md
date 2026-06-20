# Arquitectura MVVM - Fuerza de Ventas

La app separa responsabilidades siguiendo MVVM:

- `lib/views/`: entradas de pantallas usadas por `main.dart`.
- `lib/pages/`: widgets de UI. Renderizan datos y delegan acciones.
- `lib/viewmodels/`: estado de pantalla, filtros, seleccion de cliente, conectividad y preparacion de datos para la vista.
- `lib/models/`: contratos de datos usados por vistas y viewmodels.
- `lib/services/`: acceso a Supabase, persistencia, carga de dashboard y registro de operaciones.

Flujo principal:

1. `main.dart` abre `views/home_page.dart`.
2. `HomePage` crea `HomeViewModel`.
3. `HomeViewModel` consulta datos mediante `ScoringRepository`.
4. `ScoringRepository` lee y actualiza Supabase.
5. La vista escucha cambios del viewmodel con `AnimatedBuilder`.

Casos cubiertos para Semana 11:

- Cartera diaria y filtros.
- Planificacion de ruta con destino real de prueba.
- Navegacion externa con Waze/Google Maps.
- Captura GPS de negocio con confirmacion y direccion aproximada.
- Actualizacion de coordenadas del negocio en Supabase.
- Ficha de campo, solicitud, documentos, estados y seguimiento.
