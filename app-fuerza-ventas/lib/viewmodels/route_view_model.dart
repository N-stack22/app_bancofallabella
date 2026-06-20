import 'dart:math';

import 'package:bancofalabella_app2/models/sales_models.dart';

class RouteViewModel {
  static List<PreapprovedClient> withDemoDestination(
    List<PreapprovedClient> clients,
  ) {
    return [_plazaVeaHuancayo, ...clients];
  }

  static List<PreapprovedClient> optimizeByNearestNeighbor({
    required List<PreapprovedClient> clients,
    required double startLat,
    required double startLng,
  }) {
    final pending = List<PreapprovedClient>.from(clients);
    final ordered = <PreapprovedClient>[];
    var currentLat = startLat;
    var currentLng = startLng;

    while (pending.isNotEmpty) {
      pending.sort(
        (a, b) => _distance(currentLat, currentLng, a.lat, a.lng).compareTo(
          _distance(currentLat, currentLng, b.lat, b.lng),
        ),
      );
      final next = pending.removeAt(0);
      ordered.add(next);
      currentLat = next.lat.toDouble();
      currentLng = next.lng.toDouble();
    }

    return ordered;
  }

  static double _distance(num fromLat, num fromLng, num toLat, num toLng) {
    final latDelta = fromLat - toLat;
    final lngDelta = fromLng - toLng;
    return sqrt((latDelta * latDelta) + (lngDelta * lngDelta));
  }

  static const PreapprovedClient _plazaVeaHuancayo = PreapprovedClient(
    credit: {
      'id': 'ruta-plaza-vea-huancayo',
      'user_id': 'ruta-plaza-vea-huancayo-user',
      'score_transaccional': 704,
      'score_final': 704,
      'monto_hipotesis': 5000,
      'monto_aprobado': 4200,
      'segmento': 'PREMIER',
      'estado': 'destino_ruta',
    },
    profile: {
      'user_id': 'ruta-plaza-vea-huancayo-user',
      'nombres': 'Plaza Vea',
      'apellidos': 'Huancayo',
      'dni': '00000678',
      'distrito': 'Huancayo',
      'departamento': 'Junin',
      'tipo_negocio': 'Supermercado',
      'nombre_negocio': 'Plaza Vea Huancayo',
      'direccion_negocio': 'Plaza Vea Huancayo',
      'lat_negocio': -12.057912,
      'lng_negocio': -75.2168002,
    },
    score: {
      'score_transaccional': 704,
      'segmento_preliminar': 'PREMIER',
      'monto_hipotesis': 5000,
    },
    fieldFile: {},
    assignment: {
      'prioridad': 'alta',
      'score_prioridad': 88,
      'estado_visita': 'pendiente',
      'tipo_gestion': 'DESTINO_RUTA',
    },
  );
}
