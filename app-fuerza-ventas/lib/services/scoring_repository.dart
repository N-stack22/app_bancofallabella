import 'dart:convert';
import 'dart:math';

import 'package:bancofalabella_app2/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const configuredCoreBaseUrl = String.fromEnvironment(
  'CORE_BASE_URL',
  defaultValue: '',
);
const productionCoreBaseUrl =
    'https://n-stack22-sistemagestionacademica-production.up.railway.app';
const webCoreBaseUrl = String.fromEnvironment(
  'WEB_CORE_BASE_URL',
  defaultValue: productionCoreBaseUrl,
);
const androidCoreBaseUrl = String.fromEnvironment(
  'ANDROID_CORE_BASE_URL',
  defaultValue: productionCoreBaseUrl,
);
const fallbackCoreBaseUrl = webCoreBaseUrl;

String get coreBaseUrl {
  if (configuredCoreBaseUrl.isNotEmpty) return configuredCoreBaseUrl;
  return kIsWeb ? webCoreBaseUrl : androidCoreBaseUrl;
}

class SalesDashboardData {
  const SalesDashboardData({
    required this.advisor,
    required this.portfolio,
    required this.agencies,
    required this.advisors,
    required this.kpis,
    required this.history,
    required this.requests,
    required this.bureau,
    required this.alerts,
    required this.collections,
    required this.pendingSync,
    required this.lastSyncLabel,
    required this.role,
    required this.online,
    required this.isDemo,
  });

  final Map<String, dynamic> advisor;
  final List<PreapprovedClient> portfolio;
  final List<Map<String, dynamic>> agencies;
  final List<Map<String, dynamic>> advisors;
  final List<Map<String, dynamic>> kpis;
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> bureau;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> collections;
  final int pendingSync;
  final String lastSyncLabel;
  final String role;
  final bool online;
  final bool isDemo;
}

class PreapprovedClient {
  const PreapprovedClient({
    required this.credit,
    required this.profile,
    required this.score,
    required this.fieldFile,
    this.assignment = const {},
  });

  final Map<String, dynamic> credit;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> score;
  final Map<String, dynamic> fieldFile;
  final Map<String, dynamic> assignment;

  String get id => _text(credit, 'id');
  String get userId => _text(credit, 'user_id');
  String get fullName {
    final name = _text(profile, 'nombres');
    final lastName = _text(profile, 'apellidos');
    return '$name $lastName'.trim().isEmpty
        ? 'Cliente preaprobado'
        : '$name $lastName'.trim();
  }

  String get business => _text(profile, 'tipo_negocio', fallback: 'Negocio');
  String get district => _text(profile, 'distrito', fallback: 'Sin distrito');
  String get segment => _text(
    credit,
    'segmento',
    fallback: _text(score, 'segmento_preliminar', fallback: 'PENDIENTE'),
  );
  String get status => _text(credit, 'estado', fallback: 'preaprobado');
  String get visitStatus => _text(
    assignment,
    'estado_visita',
    fallback: hasVisit ? 'visitado' : 'pendiente',
  );
  String get managementType =>
      _text(assignment, 'tipo_gestion', fallback: _managementTypeFromCredit());
  String get priority =>
      _text(assignment, 'prioridad', fallback: _priorityFromCredit());
  num get priorityScore => _number(
    assignment,
    'score_prioridad',
    fallback: _priorityScoreFromCredit(),
  );
  num get scoreValue => _number(
    credit,
    'score_transaccional',
    fallback: _number(score, 'score_transaccional'),
  );
  num get finalScore => _number(
    credit,
    'score_final',
    fallback: scoreValue + _number(fieldFile, 'score_campo'),
  );
  num get hypothesisAmount => _number(
    credit,
    'monto_hipotesis',
    fallback: _number(score, 'monto_hipotesis'),
  );
  num get approvedAmount =>
      _number(credit, 'monto_aprobado', fallback: hypothesisAmount);
  num get lat => _number(profile, 'lat_negocio');
  num get lng => _number(profile, 'lng_negocio');
  bool get isRouteDemoDestination => userId.startsWith('ruta-');
  bool get hasVisit => fieldFile.isNotEmpty;

  PreapprovedClient withBusinessLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) {
    return PreapprovedClient(
      credit: credit,
      profile: {
        ...profile,
        'lat_negocio': latitude,
        'lng_negocio': longitude,
        if (address.isNotEmpty) 'direccion_negocio': address,
      },
      score: score,
      fieldFile: fieldFile,
      assignment: assignment,
    );
  }

  String get maskedDocument {
    final dni = _text(profile, 'dni', fallback: '00000000');
    if (dni.length <= 3) return '***';
    return '***${dni.substring(dni.length - 3)}';
  }

  String _managementTypeFromCredit() {
    if (_number(credit, 'dias_mora') > 0) return 'RECUPERACION_MORA';
    if (status == 'desembolsado') return 'SEGUIMIENTO';
    if (approvedAmount >= 4000) return 'RENOVACION';
    if (segment == 'PREMIER') return 'AMPLIACION';
    return 'NUEVA_SOLICITUD';
  }

  String _priorityFromCredit() {
    if (_number(credit, 'dias_mora') >= 15 || approvedAmount >= 4000) {
      return 'alta';
    }
    if (segment == 'PREMIER' || segment == 'ESTANDAR') return 'media';
    return 'normal';
  }

  int _priorityScoreFromCredit() {
    final mora = _number(credit, 'dias_mora').toInt();
    if (mora > 0) return min(100, 40 + min(mora, 30));
    if (approvedAmount >= 5000) return 90;
    if (approvedAmount >= 4000) return 78;
    if (segment == 'PREMIER') return 70;
    if (segment == 'ESTANDAR') return 52;
    return 35;
  }
}

class FieldScoringInput {
  const FieldScoringInput({
    required this.negocioVerificado,
    required this.antiguedadNegocio,
    required this.tenenciaLocal,
    required this.ventasDiariasRango,
    required this.ratioGastos,
    required this.tieneDeudaInformal,
    required this.participaPandero,
    required this.stockVisible,
    required this.activosHogar,
    required this.caracterResultado,
    required this.montoPropuesto,
    required this.plazoMeses,
    required this.recomendacion,
    required this.observaciones,
  });

  final bool negocioVerificado;
  final String antiguedadNegocio;
  final String tenenciaLocal;
  final String ventasDiariasRango;
  final String ratioGastos;
  final String tieneDeudaInformal;
  final String participaPandero;
  final String stockVisible;
  final String activosHogar;
  final String caracterResultado;
  final num montoPropuesto;
  final int plazoMeses;
  final String recomendacion;
  final String observaciones;

  FieldScoringResult calculate(num scoreTransaccional, num ingresoPromedio) {
    if (!negocioVerificado) {
      return FieldScoringResult.disqualified('Negocio no verificado');
    }
    if (caracterResultado == 'veto') {
      return FieldScoringResult.disqualified('Veto por caracter del cliente');
    }

    final ptsAntiguedad = switch (antiguedadNegocio) {
      'mas_3_anios' => 40,
      '1_a_3_anios' => 20,
      _ => 0,
    };
    final ptsTenencia = switch (tenenciaLocal) {
      'propio' => 20,
      'alquilado_con_contrato' => 10,
      _ => 0,
    };
    final ptsVentas = switch (ventasDiariasRango) {
      'mas_300' => 45,
      '151_a_300' => 30,
      '50_a_150' => 15,
      _ => 0,
    };
    final ptsGastos = switch (ratioGastos) {
      'menos_50pct' => 15,
      '50_a_80pct' => 5,
      _ => 0,
    };
    final ptsDeuda = switch (tieneDeudaInformal) {
      'no' => 20,
      'si_menor' => -20,
      'si_significativa' => -50,
      _ => 0,
    };
    final ptsPandero = switch (participaPandero) {
      'no' => 20,
      'si_menor_cuota' => 0,
      'si_mayor_cuota' => -20,
      _ => 0,
    };
    final ptsStock = switch (stockVisible) {
      'abundante' => 20,
      'moderado' => 10,
      _ => 0,
    };
    final ptsActivos = activosHogar == 'al_menos_uno' ? 20 : 0;
    final scoreCampo =
        ptsAntiguedad +
        ptsTenencia +
        ptsVentas +
        ptsGastos +
        ptsDeuda +
        ptsPandero +
        ptsStock +
        ptsActivos;
    final scoreFinal = scoreTransaccional.toInt() + scoreCampo;
    final segment = _segmentForScore(scoreFinal);
    final segmentCap = switch (segment) {
      'PREMIER' => 5000.0,
      'ESTANDAR' => 2500.0,
      'BASICO' => 1000.0,
      _ => 0.0,
    };
    final term = switch (segment) {
      'PREMIER' => 12,
      'ESTANDAR' => 6,
      'BASICO' => 3,
      _ => plazoMeses,
    };
    final factor = ScoringRepository.paymentFactor(0.60, plazoMeses);
    final incomeCap = ingresoPromedio * 2;
    final paymentCap = factor == 0 ? 0 : (ingresoPromedio * 0.30) / factor;
    final maxAmount = [segmentCap, incomeCap, paymentCap]
        .where((value) => value > 0)
        .fold<double>(
          segmentCap,
          (previous, current) => min(previous, current.toDouble()),
        );
    final proposed = montoPropuesto <= 0
        ? maxAmount
        : min(montoPropuesto.toDouble(), maxAmount);

    return FieldScoringResult(
      disqualified: false,
      reason: '',
      ptsF1: ptsAntiguedad + ptsTenencia,
      ptsF2: ptsVentas + ptsGastos,
      ptsF3: ptsDeuda + ptsPandero,
      ptsF4: ptsStock + ptsActivos,
      scoreCampo: scoreCampo,
      scoreFinal: scoreFinal,
      segment: segment,
      maxAmount: maxAmount,
      suggestedTerm: term,
      payment: proposed * factor,
      ptsAntiguedad: ptsAntiguedad,
      ptsTenencia: ptsTenencia,
      ptsVentas: ptsVentas,
      ptsGastos: ptsGastos,
      ptsDeuda: ptsDeuda,
      ptsPandero: ptsPandero,
      ptsStock: ptsStock,
      ptsActivos: ptsActivos,
    );
  }
}

class FieldScoringResult {
  const FieldScoringResult({
    required this.disqualified,
    required this.reason,
    required this.ptsF1,
    required this.ptsF2,
    required this.ptsF3,
    required this.ptsF4,
    required this.scoreCampo,
    required this.scoreFinal,
    required this.segment,
    required this.maxAmount,
    required this.suggestedTerm,
    required this.payment,
    required this.ptsAntiguedad,
    required this.ptsTenencia,
    required this.ptsVentas,
    required this.ptsGastos,
    required this.ptsDeuda,
    required this.ptsPandero,
    required this.ptsStock,
    required this.ptsActivos,
  });

  factory FieldScoringResult.disqualified(String reason) => FieldScoringResult(
    disqualified: true,
    reason: reason,
    ptsF1: 0,
    ptsF2: 0,
    ptsF3: 0,
    ptsF4: 0,
    scoreCampo: 0,
    scoreFinal: 0,
    segment: 'DESCALIFICADO',
    maxAmount: 0,
    suggestedTerm: 0,
    payment: 0,
    ptsAntiguedad: 0,
    ptsTenencia: 0,
    ptsVentas: 0,
    ptsGastos: 0,
    ptsDeuda: 0,
    ptsPandero: 0,
    ptsStock: 0,
    ptsActivos: 0,
  );

  final bool disqualified;
  final String reason;
  final int ptsF1;
  final int ptsF2;
  final int ptsF3;
  final int ptsF4;
  final int scoreCampo;
  final int scoreFinal;
  final String segment;
  final double maxAmount;
  final int suggestedTerm;
  final double payment;
  final int ptsAntiguedad;
  final int ptsTenencia;
  final int ptsVentas;
  final int ptsGastos;
  final int ptsDeuda;
  final int ptsPandero;
  final int ptsStock;
  final int ptsActivos;
}

class ScoringRepository {
  SalesDashboardData? _cachedDashboard;
  DateTime? _cachedAt;

  Future<SalesDashboardData> loadDashboard({
    bool forceDemo = false,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedDashboard != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!).inSeconds < 25) {
      return _cachedDashboard!;
    }

    SalesDashboardData remember(SalesDashboardData data) {
      _cachedDashboard = data;
      _cachedAt = DateTime.now();
      return data;
    }

    if (!forceDemo) {
      final coreData = await _tryLoadCoreDashboard();
      if (coreData != null) return remember(coreData);
    }

    if (forceDemo || !SupabaseConfig.isConfigured) {
      return remember(_demoData);
    }

    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return remember(_demoData);

    try {
      final results = await Future.wait<dynamic>([
        client
            .from('creditos_preaprobados')
            .select()
            .order('score_final', ascending: false)
            .limit(30),
        client.from('vw_pbi_agencias').select().limit(8),
        client.from('vw_pbi_asesores').select().limit(12),
        client.from('vw_pbi_kpis_piloto').select().limit(8),
        client.from('vw_pbi_fichas_campo').select().limit(12),
      ]);

      final credits = _asList(results[0]);
      if (credits.isEmpty) return _demoData;

      final userIds = credits
          .map((item) => _text(item, 'user_id'))
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final scoreIds = credits
          .map((item) => _text(item, 'score_id'))
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final related = await Future.wait<dynamic>([
        userIds.isEmpty
            ? Future.value(<Map<String, dynamic>>[])
            : client
                  .from('perfiles_clientes')
                  .select()
                  .inFilter('user_id', userIds),
        scoreIds.isEmpty
            ? Future.value(<Map<String, dynamic>>[])
            : client
                  .from('scores_transaccionales')
                  .select()
                  .inFilter('id', scoreIds),
        userIds.isEmpty
            ? Future.value(<Map<String, dynamic>>[])
            : client
                  .from('fichas_campo')
                  .select()
                  .inFilter('user_id', userIds)
                  .order('fecha_visita', ascending: false),
      ]);

      final profiles = _indexBy(_asList(related[0]), 'user_id');
      final scores = _indexBy(_asList(related[1]), 'id');
      final fieldFiles = _latestByUser(_asList(related[2]));
      final assignments = _indexBy(
        await _optionalList(
          client
              .from('cartera_diaria')
              .select()
              .inFilter('cliente_user_id', userIds)
              .order('score_prioridad', ascending: false),
        ),
        'cliente_user_id',
      );
      final portfolio = credits
          .map(
            (credit) => PreapprovedClient(
              credit: credit,
              profile: profiles[_text(credit, 'user_id')] ?? const {},
              score: scores[_text(credit, 'score_id')] ?? const {},
              fieldFile: fieldFiles[_text(credit, 'user_id')] ?? const {},
              assignment: assignments[_text(credit, 'user_id')] ?? const {},
            ),
          )
          .toList();
      portfolio.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

      final requests = await _optionalList(
        client
            .from('solicitudes_credito')
            .select()
            .order('created_at', ascending: false)
            .limit(20),
      );
      final bureau = await _optionalList(
        client
            .from('consultas_buro')
            .select()
            .order('created_at', ascending: false)
            .limit(20),
      );
      final alerts = await _optionalList(
        client
            .from('alertas_cartera')
            .select()
            .order('created_at', ascending: false)
            .limit(20),
      );
      final collections = await _optionalList(
        client
            .from('acciones_cobranza')
            .select()
            .order('timestamp_gestion', ascending: false)
            .limit(20),
      );
      final roleRows = await _optionalList(
        client.from('fv_usuarios_perfiles').select().limit(1),
      );
      final pendingRows = await _optionalList(
        client
            .from('fv_sync_queue')
            .select()
            .eq('estado', 'pendiente')
            .limit(50),
      );

      return remember(
        SalesDashboardData(
          advisor: {
            ..._advisorFromSession(client.auth.currentUser?.email),
            'perfil': roleRows.isEmpty
                ? 'Operador'
                : _text(roleRows.first, 'perfil', fallback: 'Operador'),
            'id': roleRows.isEmpty
                ? 1
                : _number(roleRows.first, 'asesor_id', fallback: 1).toInt(),
          },
          portfolio: portfolio,
          agencies: _asList(results[1]),
          advisors: _asList(results[2]),
          kpis: _asList(results[3]),
          history: _asList(results[4]),
          requests: requests,
          bureau: bureau,
          alerts: alerts,
          collections: collections,
          pendingSync:
              pendingRows.length +
              requests.where((item) => item['pendiente_sync'] == true).length,
          lastSyncLabel: 'hoy ${_timeLabel(DateTime.now())}',
          role: roleRows.isEmpty
              ? 'Operador'
              : _text(roleRows.first, 'perfil', fallback: 'Operador'),
          online: true,
          isDemo: false,
        ),
      );
    } catch (_) {
      return remember(_demoData);
    }
  }

  Future<SalesDashboardData?> _tryLoadCoreDashboard() async {
    try {
      final rows = await _getCoreList('/cartera/demo');
      if (rows.isEmpty) return null;
      final requests = await _optionalList(_getCoreList('/solicitudes/demo'));
      final history = await _optionalList(
        _getCoreList('/cartera/demo/historial'),
      );
      final portfolio = rows.map(_clientFromCoreCartera).toList()
        ..sort((a, b) {
          final statusCompare = _visitOrder(
            a.visitStatus,
          ).compareTo(_visitOrder(b.visitStatus));
          if (statusCompare != 0) return statusCompare;
          return b.priorityScore.compareTo(a.priorityScore);
        });
      return SalesDashboardData(
        advisor: _advisorFromSession('asesor0001@bancofalabella.local'),
        portfolio: portfolio,
        agencies: const [],
        advisors: const [],
        kpis: [
          {
            'agencia': 'Core FastAPI 8003',
            'visitas_totales': portfolio.length,
            'desembolsos': portfolio
                .where((client) => client.status == 'desembolsado')
                .length,
            'monto_desembolsado': portfolio.fold<num>(
              0,
              (sum, client) => sum + client.approvedAmount,
            ),
            'mora_30_pct': 0,
            'tasa_conversion_pct': portfolio.isEmpty ? 0 : 100,
          },
        ],
        history: history,
        requests: requests.isEmpty
            ? portfolio
                  .map(
                    (client) => {
                      'numero_expediente': _text(
                        client.credit,
                        'numero_expediente',
                        fallback: client.id,
                      ),
                      'cliente_nombre': client.fullName,
                      'estado': client.status,
                      'monto_solicitado': client.hypothesisAmount,
                      'monto_aprobado': client.approvedAmount,
                      'plazo_meses': _number(
                        client.credit,
                        'plazo_meses',
                        fallback: 12,
                      ),
                      'created_at': DateTime.now().toIso8601String(),
                    },
                  )
                  .toList()
            : requests,
        bureau: const [],
        alerts: const [],
        collections: const [],
        pendingSync: 0,
        lastSyncLabel: 'core ${_timeLabel(DateTime.now())}',
        role: 'Operador',
        online: true,
        isDemo: false,
      );
    } catch (_) {
      return null;
    }
  }

  PreapprovedClient _clientFromCoreCartera(Map<String, dynamic> row) {
    final document = _text(row, 'documento', fallback: '00000000');
    final clienteId = _text(row, 'cliente_id', fallback: 'core-cliente');
    final fullName = _text(row, 'cliente_nombre', fallback: 'Cliente Core');
    final parts = fullName.split(' ');
    final name = parts.isEmpty ? fullName : parts.first;
    final lastName = parts.length <= 1 ? '' : parts.skip(1).join(' ');
    final amount = _number(row, 'monto_credito');
    final priorityScore = _number(row, 'score_prioridad', fallback: 40);
    final visitStatus = _visitStatus(row);
    final segment = amount >= 8000
        ? 'PREMIER'
        : (amount >= 3000 ? 'ESTANDAR' : 'BASICO');
    return PreapprovedClient(
      credit: {
        'id': _text(row, 'id', fallback: clienteId),
        'user_id': clienteId,
        'score_id': '$clienteId-core-score',
        'numero_expediente': _text(
          row,
          'numero_expediente',
          fallback: _text(row, 'id', fallback: clienteId),
        ),
        'segmento': segment,
        'score_transaccional': 500 + priorityScore,
        'score_campo': 0,
        'score_final': 500 + priorityScore,
        'monto_hipotesis': amount,
        'monto_aprobado': amount,
        'plazo_meses': 12,
        'cuota_mensual': amount * paymentFactor(0.4392, 12),
        'estado': 'enviado',
        'fecha_preaprobacion': DateTime.now().toIso8601String(),
        'dias_mora': 0,
        'estado_pago': 'al_dia',
      },
      profile: {
        'user_id': clienteId,
        'nombres': name,
        'apellidos': lastName,
        'dni': document,
        'telefono': '',
        'distrito': 'Por visitar',
        'departamento': 'Junin',
        'tipo_negocio': 'Microempresa',
        'nombre_negocio': 'Negocio de $name',
        'direccion_negocio': 'Direccion pendiente',
        'lat_negocio': _number(row, 'lat', fallback: -12.065),
        'lng_negocio': _number(row, 'lng', fallback: -75.205),
        'antiguedad_negocio_meses': 48,
        'tenencia_local': 'alquilado_con_contrato',
        'num_entidades_sbs': 1,
        'calificacion_sbs': 'Normal',
      },
      score: {
        'id': '$clienteId-core-score',
        'user_id': clienteId,
        'score_transaccional': 500 + priorityScore,
        'segmento_preliminar': segment,
        'monto_hipotesis': amount,
        'ingreso_promedio_ref': 3000,
        'cuota_max_ref': 900,
      },
      fieldFile: const {},
      assignment: {
        'id': _text(row, 'id'),
        'source': 'core',
        'cliente_user_id': clienteId,
        'tipo_gestion': _text(row, 'tipo_gestion', fallback: 'NUEVA_SOLICITUD'),
        'prioridad': _text(row, 'prioridad', fallback: 'normal'),
        'score_prioridad': priorityScore,
        'estado_visita': visitStatus,
        'fecha_asignacion': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> submitFieldFile({
    required PreapprovedClient client,
    required FieldScoringInput input,
    required FieldScoringResult result,
    required String advisorName,
    required String agency,
  }) async {
    if (_text(client.assignment, 'source') == 'core') {
      final assignmentId = _text(client.assignment, 'id');
      if (assignmentId.isEmpty) return;
      await _postCore('/cartera/demo/$assignmentId/comite', {
        'asesor_nombre': advisorName,
        'agencia': agency,
        'score_transaccional': client.scoreValue.toInt(),
        'score_campo': result.scoreCampo,
        'score_final': result.scoreFinal,
        'segmento': result.segment,
        'monto_propuesto': result.disqualified
            ? 0
            : min(input.montoPropuesto.toDouble(), result.maxAmount),
        'plazo_meses': input.plazoMeses,
        'cuota_estimada': result.payment,
        'recomendacion': result.disqualified ? 'rechazar' : input.recomendacion,
        'observaciones': input.observaciones,
      });
      return;
    }

    if (!SupabaseConfig.isConfigured) return;

    final supabase = Supabase.instance.client;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final estadoCredito = result.disqualified
        ? 'rechazado'
        : 'visita_realizada';
    final ventasMensuales = switch (input.ventasDiariasRango) {
      'mas_300' => 10500,
      '151_a_300' => 5720,
      '50_a_150' => 2700,
      _ => 1200,
    };
    final gastos = switch (input.ratioGastos) {
      'menos_50pct' => ventasMensuales * 0.42,
      '50_a_80pct' => ventasMensuales * 0.65,
      _ => ventasMensuales * 0.88,
    };

    await supabase.from('fichas_campo').insert({
      'user_id': client.userId,
      'score_id': _text(client.credit, 'score_id').isEmpty
          ? null
          : _text(client.credit, 'score_id'),
      'asesor_nombre': advisorName,
      'agencia': agency,
      'fecha_visita': today,
      'hora_inicio': '09:00',
      'hora_fin': '09:45',
      'negocio_verificado': input.negocioVerificado,
      'motivo_no_verificado': result.disqualified ? result.reason : null,
      'antiguedad_negocio': input.antiguedadNegocio,
      'pts_antiguedad': result.ptsAntiguedad,
      'tenencia_local': input.tenenciaLocal,
      'pts_tenencia': result.ptsTenencia,
      'direccion_verificada': _text(client.profile, 'direccion_negocio'),
      'ventas_diarias_rango': input.ventasDiariasRango,
      'pts_ventas': result.ptsVentas,
      'ventas_mensuales_est': ventasMensuales,
      'gastos_fijos_mes': gastos,
      'ratio_gastos': input.ratioGastos,
      'pts_gastos': result.ptsGastos,
      'ingreso_consistente': true,
      'tiene_deuda_informal': input.tieneDeudaInformal,
      'pts_deuda_informal': result.ptsDeuda,
      'monto_deuda_informal': input.tieneDeudaInformal == 'no' ? 0 : 600,
      'participa_pandero': input.participaPandero,
      'pts_pandero': result.ptsPandero,
      'stock_visible': input.stockVisible,
      'pts_stock': result.ptsStock,
      'activos_hogar': input.activosHogar,
      'pts_activos': result.ptsActivos,
      'caracter_resultado': input.caracterResultado,
      'obs_caracter': input.observaciones,
      'score_transaccional_ref': client.scoreValue.toInt(),
      'monto_aprobado_propuesto': result.disqualified
          ? 0
          : min(input.montoPropuesto.toDouble(), result.maxAmount),
      'plazo_propuesto_meses': input.plazoMeses,
      'cuota_estimada': result.payment,
      'recomendacion_asesor': result.disqualified
          ? 'rechazar'
          : input.recomendacion,
      'obs_finales': input.observaciones,
      'estado_ficha': 'completada',
    });

    await supabase
        .from('creditos_preaprobados')
        .update({'estado': estadoCredito, 'fecha_visita': today})
        .eq('id', client.id);
  }

  Future<bool> updateBusinessLocation({
    required PreapprovedClient client,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    if (!SupabaseConfig.isConfigured || client.isRouteDemoDestination) {
      return false;
    }
    final supabase = Supabase.instance.client;

    await supabase
        .from('perfiles_clientes')
        .update({
          'lat_negocio': latitude,
          'lng_negocio': longitude,
          'direccion_negocio': address.isEmpty
              ? _text(client.profile, 'direccion_negocio')
              : address,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', client.userId);
    return true;
  }

  Future<void> registerVisitResult({
    required PreapprovedClient client,
    required String result,
    required String observation,
  }) async {
    if (_text(client.assignment, 'source') == 'core') {
      final assignmentId = _text(client.assignment, 'id');
      if (assignmentId.isEmpty) return;
      await _postCore('/cartera/demo/$assignmentId/visita', {
        'resultado': result,
        'observacion': observation,
        'lat': client.lat,
        'lng': client.lng,
      });
      return;
    }

    if (!SupabaseConfig.isConfigured) return;
    final supabase = Supabase.instance.client;
    final assignmentId = _text(client.assignment, 'id');
    if (assignmentId.isEmpty) return;

    await supabase
        .from('cartera_diaria')
        .update({
          'estado_visita': result == 'visitado' ? 'visitado' : result,
          'resultado_visita': result,
          'observacion_visita': observation,
          'timestamp_visita': DateTime.now().toIso8601String(),
          'lat_visita': client.lat,
          'lng_visita': client.lng,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', assignmentId);
  }

  Future<void> submitCreditApplication({
    required PreapprovedClient client,
    required Map<String, dynamic> advisor,
    required num amount,
    required int term,
    required String purpose,
    required String signature,
  }) async {
    if (!SupabaseConfig.isConfigured) return;
    final supabase = Supabase.instance.client;
    final now = DateTime.now();
    final expediente =
        'BF-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';
    final factor = paymentFactor(0.60, term);
    await supabase.from('solicitudes_credito').insert({
      'numero_expediente': expediente,
      'asesor_id': _number(advisor, 'id').toInt() == 0
          ? null
          : _number(advisor, 'id').toInt(),
      'cliente_user_id': client.userId,
      'tipo_negocio': client.business,
      'nombre_negocio': _text(client.profile, 'nombre_negocio'),
      'antiguedad_negocio_meses': _number(
        client.profile,
        'antiguedad_negocio_meses',
      ).toInt(),
      'ingresos_estimados': _number(
        client.score,
        'ingreso_promedio_ref',
        fallback: 3000,
      ),
      'gastos_mensuales':
          _number(client.score, 'ingreso_promedio_ref', fallback: 3000) * 0.45,
      'monto_solicitado': amount,
      'plazo_meses': term,
      'cuota_estimada': amount * factor,
      'destino_credito': purpose,
      'estado': 'enviado',
      'firma_cliente_base64': signature,
      'lat_captura': client.lat,
      'lng_captura': client.lng,
    });
  }

  Future<String> uploadDocument({
    required PreapprovedClient client,
    required String type,
    required Uint8List bytes,
    required String extension,
  }) async {
    if (!SupabaseConfig.isConfigured) return 'demo://$type.$extension';
    final supabase = Supabase.instance.client;
    final safeExtension = extension.replaceAll('.', '').toLowerCase();
    final path =
        '${client.userId}/$type-${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await supabase.storage
        .from(SupabaseConfig.documentsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: safeExtension == 'png' ? 'image/png' : 'image/jpeg',
            upsert: true,
          ),
        );

    final url = supabase.storage
        .from(SupabaseConfig.documentsBucket)
        .getPublicUrl(path);
    await supabase.from('solicitudes_documentos').insert({
      'tipo_documento': type,
      'storage_url': url,
      'tamanio_kb': (bytes.length / 1024).round(),
      'nitidez_score': min(100, bytes.length / 2048),
    });
    return url;
  }

  Future<void> registerPdf({
    required String expediente,
    required Uint8List bytes,
  }) async {
    if (!SupabaseConfig.isConfigured) return;
    final supabase = Supabase.instance.client;
    final path =
        'pdfs/$expediente-${DateTime.now().millisecondsSinceEpoch}.pdf';
    await supabase.storage
        .from(SupabaseConfig.documentsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
    final url = supabase.storage
        .from(SupabaseConfig.documentsBucket)
        .getPublicUrl(path);
    await supabase.from('fv_pdfs_generados').insert({
      'numero_expediente': expediente,
      'storage_url': url,
    });
  }

  Future<void> signOut() async {
    if (SupabaseConfig.isConfigured) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  static double paymentFactor(double tea, int months) {
    if (months <= 0) return 0;
    final tem = pow(1 + tea, 1 / 12) - 1;
    return tem * pow(1 + tem, months) / (pow(1 + tem, months) - 1);
  }

  static Map<String, dynamic> _advisorFromSession(String? email) => {
    'id': 1,
    'nombre_completo': 'Nathalie Tatiana Rodriguez Rios',
    'email': email ?? 'asesor0001@bancofalabella.local',
    'agencia': 'Agencia Huancayo Centro',
    'nivel': 'Senior II',
    'codigo': 'AG-001-01',
  };

  static Map<String, Map<String, dynamic>> _indexBy(
    List<Map<String, dynamic>> rows,
    String key,
  ) {
    return {for (final row in rows) _text(row, key): row};
  }

  static Future<List<Map<String, dynamic>>> _optionalList(
    Future<dynamic> request,
  ) async {
    try {
      return _asList(await request);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  static Future<List<Map<String, dynamic>>> _getCoreList(String path) async {
    try {
      return _asList(await _coreRequest('GET', path));
    } catch (_) {
      if (coreBaseUrl == fallbackCoreBaseUrl) rethrow;
      return _asList(await _coreRequest('GET', path, fallback: true));
    }
  }

  static Future<void> _postCore(String path, Map<String, dynamic> body) async {
    try {
      await _coreRequest('POST', path, body: body);
    } catch (_) {
      if (coreBaseUrl == fallbackCoreBaseUrl) rethrow;
      await _coreRequest('POST', path, body: body, fallback: true);
    }
  }

  static Future<dynamic> _coreRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool fallback = false,
  }) async {
    final baseUrl = fallback ? fallbackCoreBaseUrl : coreBaseUrl;
    final uri = Uri.parse('$baseUrl$path');
    final response = method == 'POST'
        ? await http
              .post(
                uri,
                headers: const {'Content-Type': 'application/json'},
                body: jsonEncode(body ?? const <String, dynamic>{}),
              )
              .timeout(const Duration(seconds: 8))
        : await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Core ${response.statusCode}: ${response.body}');
    }
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Map<String, Map<String, dynamic>> _latestByUser(
    List<Map<String, dynamic>> rows,
  ) {
    final values = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final userId = _text(row, 'user_id');
      if (userId.isNotEmpty && !values.containsKey(userId)) {
        values[userId] = row;
      }
    }
    return values;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) return value.map((item) => _asMap(item)).toList();
    return const <Map<String, dynamic>>[];
  }

  static String _timeLabel(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  SalesDashboardData get _demoData {
    final clients = [
      _demoClient(
        id: '44444444-4444-4444-4444-444444444444',
        name: 'Alumno',
        lastName: 'Uno Demo',
        business: 'Bodega',
        district: 'Huancayo',
        segment: 'PREMIER',
        score: 690,
        finalScore: 845,
        status: 'desembolsado',
        amount: 5000,
        approved: 4200,
        lat: -12.065,
        lng: -75.205,
        hasVisit: true,
      ),
      _demoClient(
        id: '55555555-5555-5555-5555-555555555555',
        name: 'Rosa',
        lastName: 'Quispe Flores',
        business: 'Puesto de abarrotes',
        district: 'El Tambo',
        segment: 'ESTANDAR',
        score: 562,
        finalScore: 0,
        status: 'preaprobado',
        amount: 2500,
        approved: 1800,
        lat: -12.055,
        lng: -75.215,
      ),
      _demoClient(
        id: '66666666-6666-6666-6666-666666666666',
        name: 'Marco',
        lastName: 'Palian Rojas',
        business: 'Ferreteria',
        district: 'Chilca',
        segment: 'BASICO',
        score: 438,
        finalScore: 0,
        status: 'contactado',
        amount: 1000,
        approved: 900,
        lat: -12.078,
        lng: -75.197,
      ),
    ];

    return SalesDashboardData(
      isDemo: true,
      advisor: const {
        'id': 1,
        'nombre_completo': 'Nathalie Tatiana Rodriguez Rios',
        'email': 'asesor0001@bancofalabella.local',
        'agencia': 'Agencia Huancayo Centro',
        'nivel': 'Senior II',
        'codigo': 'AG-001-01',
        'perfil': 'Operador',
      },
      portfolio: clients,
      agencies: const [
        {
          'codigo': 'AG-001',
          'nombre': 'Agencia Huancayo Centro',
          'region': 'Centro',
          'total_asesores': 12,
          'meta_creditos_agencia': 117,
          'meta_monto_agencia': 210600,
        },
        {
          'codigo': 'AG-013',
          'nombre': 'Agencia Arequipa Centro',
          'region': 'Sur',
          'total_asesores': 12,
          'meta_creditos_agencia': 117,
          'meta_monto_agencia': 210600,
        },
      ],
      advisors: const [
        {
          'codigo': 'AG-001-01',
          'nombre_completo': 'Nathalie Tatiana Rodriguez Rios',
          'nivel': 'Senior II',
          'agencia': 'Agencia Huancayo Centro',
          'creditos_meta': 16,
          'monto_meta': 28800,
        },
        {
          'codigo': 'AG-001-10',
          'nombre_completo': 'Ana Flores Poma',
          'nivel': 'Junior I',
          'agencia': 'Agencia Huancayo Centro',
          'creditos_meta': 4,
          'monto_meta': 7200,
        },
      ],
      kpis: const [
        {
          'agencia': 'Agencia Huancayo Centro',
          'visitas_totales': 60,
          'desembolsos': 44,
          'monto_desembolsado': 184800,
          'mora_30_pct': 3.8,
          'tasa_conversion_pct': 73.3,
          'semaforo_mora_30': 'OK',
        },
      ],
      history: const [
        {
          'fecha_visita': '2026-05-24',
          'asesor_nombre': 'Nathalie Tatiana Rodriguez Rios',
          'agencia': 'Agencia Huancayo Centro',
          'nombre_cliente': 'Alumno Uno Demo',
          'score_final': 845,
          'segmento_resultante': 'PREMIER',
          'recomendacion_asesor': 'aprobar',
          'estado_ficha': 'completada',
        },
      ],
      requests: const [
        {
          'numero_expediente': 'BF-20260526-00001',
          'estado': 'recibido_comite',
          'monto_solicitado': 4200,
          'plazo_meses': 12,
          'cuota_estimada': 475.50,
          'created_at': '2026-05-26',
        },
        {
          'numero_expediente': 'BF-20260526-00002',
          'estado': 'borrador',
          'monto_solicitado': 1800,
          'plazo_meses': 6,
          'cuota_estimada': 338.20,
          'created_at': '2026-05-26',
        },
      ],
      bureau: const [
        {
          'dni_consultado': '12345678',
          'calificacion_sbs': 'Normal',
          'entidades_con_deuda': 1,
          'deuda_total_pen': 2500,
          'dias_mayor_mora': 0,
        },
      ],
      alerts: const [
        {
          'tipo_alerta': 'primer_dia_mora',
          'mensaje': 'Revisar compromiso de pago de cliente con atraso leve.',
          'leida': false,
        },
      ],
      collections: const [
        {
          'resultado': 'compromiso_pago',
          'monto_compromiso': 350,
          'fecha_compromiso': '2026-05-30',
          'observaciones': 'Cliente confirma pago por Yape.',
        },
      ],
      pendingSync: 1,
      lastSyncLabel: 'hoy 22:03',
      role: 'Operador',
      online: true,
    );
  }

  PreapprovedClient _demoClient({
    required String id,
    required String name,
    required String lastName,
    required String business,
    required String district,
    required String segment,
    required int score,
    required int finalScore,
    required String status,
    required num amount,
    required num approved,
    required num lat,
    required num lng,
    bool hasVisit = false,
  }) {
    final userId = '$id-user';
    return PreapprovedClient(
      credit: {
        'id': id,
        'user_id': userId,
        'score_id': '$id-score',
        'segmento': segment,
        'score_transaccional': score,
        'score_campo': hasVisit ? finalScore - score : 0,
        'score_final': finalScore == 0 ? score : finalScore,
        'monto_hipotesis': amount,
        'monto_aprobado': approved,
        'plazo_meses': 12,
        'cuota_mensual': 475.5,
        'estado': status,
        'fecha_preaprobacion': '2026-05-24',
        'dias_mora': 0,
        'estado_pago': 'al_dia',
      },
      profile: {
        'user_id': userId,
        'nombres': name,
        'apellidos': lastName,
        'dni': '12345678',
        'telefono': '999888777',
        'distrito': district,
        'departamento': 'Junin',
        'tipo_negocio': business,
        'nombre_negocio': '$business $name',
        'direccion_negocio': 'Jr. Real 123',
        'lat_negocio': lat,
        'lng_negocio': lng,
        'antiguedad_negocio_meses': 42,
        'tenencia_local': 'alquilado_con_contrato',
        'num_entidades_sbs': 1,
        'calificacion_sbs': 'Normal',
      },
      score: {
        'id': '$id-score',
        'user_id': userId,
        'pts_saldo': 160,
        'pts_regularidad': 128,
        'pts_disciplina': 120,
        'pts_vinculo': 160,
        'pts_riesgo': 90,
        'score_transaccional': score,
        'segmento_preliminar': segment,
        'monto_hipotesis': amount,
        'ingreso_promedio_ref': 3600,
        'cuota_max_ref': 1080,
      },
      fieldFile: hasVisit
          ? {
              'asesor_nombre': 'Nathalie Tatiana Rodriguez Rios',
              'agencia': 'Agencia Huancayo Centro',
              'fecha_visita': '2026-05-24',
              'negocio_verificado': true,
              'score_campo': finalScore - score,
              'score_final': finalScore,
              'segmento_resultante': segment,
              'recomendacion_asesor': 'aprobar',
              'estado_ficha': 'completada',
            }
          : const {},
      assignment: {
        'id': '$id-assignment',
        'cliente_user_id': userId,
        'tipo_gestion': hasVisit
            ? 'SEGUIMIENTO'
            : (segment == 'PREMIER' ? 'AMPLIACION' : 'NUEVA_SOLICITUD'),
        'prioridad': segment == 'PREMIER' ? 'alta' : 'media',
        'score_prioridad': segment == 'PREMIER' ? 88 : 64,
        'estado_visita': hasVisit ? 'visitado' : 'pendiente',
        'fecha_asignacion': '2026-05-26',
      },
    );
  }
}

String _text(Map<String, dynamic> map, String key, {String fallback = ''}) {
  final value = map[key];
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _visitStatus(Map<String, dynamic> row) {
  final raw = _text(
    row,
    'estado_visita',
    fallback: 'pendiente',
  ).toLowerCase().replaceAll(' ', '_');
  if (raw.contains('pend')) return 'pendiente';
  if (raw.contains('visit')) return 'visitado';
  return raw.isEmpty ? 'pendiente' : raw;
}

int _visitOrder(String status) => status == 'pendiente' ? 0 : 1;

num _number(Map<String, dynamic> map, String key, {num fallback = 0}) {
  final value = map[key];
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? fallback;
  return fallback;
}

String _segmentForScore(int score) {
  if (score >= 750) return 'PREMIER';
  if (score >= 550) return 'ESTANDAR';
  if (score >= 350) return 'BASICO';
  return 'NO_APLICA';
}
