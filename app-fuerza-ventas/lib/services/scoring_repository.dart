import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bancofalabella_app2/supabase_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  SalesDashboardData copyWith({
    int? pendingSync,
    String? lastSyncLabel,
    bool? online,
  }) {
    return SalesDashboardData(
      advisor: advisor,
      portfolio: portfolio,
      agencies: agencies,
      advisors: advisors,
      kpis: kpis,
      history: history,
      requests: requests,
      bureau: bureau,
      alerts: alerts,
      collections: collections,
      pendingSync: pendingSync ?? this.pendingSync,
      lastSyncLabel: lastSyncLabel ?? this.lastSyncLabel,
      role: role,
      online: online ?? this.online,
    );
  }

  Map<String, dynamic> toJson() => {
    'advisor': advisor,
    'portfolio': portfolio.map((client) => client.toJson()).toList(),
    'agencies': agencies,
    'advisors': advisors,
    'kpis': kpis,
    'history': history,
    'requests': requests,
    'bureau': bureau,
    'alerts': alerts,
    'collections': collections,
    'pendingSync': pendingSync,
    'lastSyncLabel': lastSyncLabel,
    'role': role,
    'online': online,
  };

  factory SalesDashboardData.fromJson(Map<String, dynamic> json) {
    return SalesDashboardData(
      advisor: _asMap(json['advisor']),
      portfolio: _asList(
        json['portfolio'],
      ).map(PreapprovedClient.fromJson).toList(),
      agencies: _asList(json['agencies']),
      advisors: _asList(json['advisors']),
      kpis: _asList(json['kpis']),
      history: _asList(json['history']),
      requests: _asList(json['requests']),
      bureau: _asList(json['bureau']),
      alerts: _asList(json['alerts']),
      collections: _asList(json['collections']),
      pendingSync: _number(json, 'pendingSync').toInt(),
      lastSyncLabel: _text(json, 'lastSyncLabel'),
      role: _text(json, 'role', fallback: 'Operador'),
      online: json['online'] == true,
    );
  }
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

  factory PreapprovedClient.fromJson(Map<String, dynamic> json) {
    return PreapprovedClient(
      credit: _asMap(json['credit']),
      profile: _asMap(json['profile']),
      score: _asMap(json['score']),
      fieldFile: _asMap(json['fieldFile']),
      assignment: _asMap(json['assignment']),
    );
  }

  Map<String, dynamic> toJson() => {
    'credit': credit,
    'profile': profile,
    'score': score,
    'fieldFile': fieldFile,
    'assignment': assignment,
  };

  String get id =>
      _text(credit, 'id', fallback: _text(assignment, 'id', fallback: userId));
  String get userId => _text(
    credit,
    'user_id',
    fallback: _text(
      credit,
      'cliente_id',
      fallback: _text(profile, 'id', fallback: _text(assignment, 'cliente_id')),
    ),
  );
  String get fullName {
    final name = _text(profile, 'nombres');
    final lastName = _text(profile, 'apellidos');
    return '$name $lastName'.trim().isEmpty
        ? 'Cliente preaprobado'
        : '$name $lastName'.trim();
  }

  String get business => _text(profile, 'tipo_negocio', fallback: 'Negocio');
  String get district => _text(
    profile,
    'distrito',
    fallback: _text(profile, 'direccion', fallback: 'Sin zona'),
  );
  String get segment => _text(
    credit,
    'segmento',
    fallback: _text(score, 'segmento_preliminar', fallback: 'PENDIENTE'),
  );
  String get status => _text(
    credit,
    'estado',
    fallback: credit['vigente'] == false ? 'vencido' : 'preaprobado',
  );
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
  num get approvedAmount => _number(
    credit,
    'monto_aprobado',
    fallback: _number(credit, 'monto_maximo', fallback: hypothesisAmount),
  );
  num get lat => _number(profile, 'lat_negocio');
  num get lng => _number(profile, 'lng_negocio');
  bool get isRouteReferenceDestination => userId.startsWith('ruta-');
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
    final dni = _text(
      profile,
      'dni',
      fallback: _text(profile, 'numero_documento', fallback: '00000000'),
    );
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

class _PortfolioBundle {
  const _PortfolioBundle({
    required this.clients,
    required this.assignments,
    required this.coreCredits,
    required this.clientsById,
    required this.preapprovalsByClientId,
  });

  final List<PreapprovedClient> clients;
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> coreCredits;
  final Map<String, Map<String, dynamic>> clientsById;
  final Map<String, Map<String, dynamic>> preapprovalsByClientId;
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
  static const _dashboardCacheKey = 'fv_dashboard_cache_v1';
  static const _pendingQueueKey = 'fv_pending_queue_v1';
  static const coreTokenKey = 'fv_core_access_token_v1';
  static const coreAdvisorKey = 'fv_core_advisor_v1';

  SalesDashboardData? _cachedDashboard;
  DateTime? _cachedAt;

  static Future<void> saveCoreSession({
    required String token,
    required Map<String, dynamic> advisor,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(coreTokenKey, token);
    await prefs.setString(coreAdvisorKey, jsonEncode(_jsonSafe(advisor)));
  }

  static Future<String?> readCoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(coreTokenKey);
    return token == null || token.trim().isEmpty ? null : token.trim();
  }

  static Future<Map<String, dynamic>?> readCoreAdvisor() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(coreAdvisorKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map ? Map<String, dynamic>.from(json) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(coreTokenKey);
    await prefs.remove(coreAdvisorKey);
    await prefs.remove(_dashboardCacheKey);
  }

  static Future<Map<String, dynamic>?> validateStoredCoreSession() async {
    final token = await readCoreToken();
    if (token == null || token.isEmpty) return null;
    try {
      final response = await http
          .get(
            Uri.parse('${SupabaseConfig.coreBaseUrl}/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await clearCoreSession();
        return null;
      }
      final body = jsonDecode(response.body);
      final payload = _asMap(_asMap(body)['asesor']);
      final advisor = _advisorFromCoreSession(
        stored: await readCoreAdvisor(),
        payload: payload,
      );
      await saveCoreSession(token: token, advisor: advisor);
      return advisor;
    } catch (_) {
      await clearCoreSession();
      return null;
    }
  }

  Future<SalesDashboardData> loadDashboard({bool forceRefresh = false}) async {
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
      unawaited(_saveDashboard(data));
      return data;
    }

    if (await readCoreToken() != null) {
      try {
        return remember(await _loadDashboardFromCore());
      } catch (error) {
        final cached = await _loadDashboard();
        if (cached != null) return remember(cached);
        throw StateError('No se pudo cargar datos desde el Core: $error');
      }
    }

    if (!SupabaseConfig.isConfigured) {
      final cached = await _loadDashboard();
      if (cached != null) return remember(cached);
      throw StateError('No hay sesion Core activa para cargar cartera real.');
    }

    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw StateError('No hay sesion Supabase activa para el asesor.');
    }

    try {
      final baseRows = await Future.wait<dynamic>([
        client.from('agencias').select().limit(50),
        client.from('asesores').select().limit(1000),
      ]);
      final rawAgencies = _asList(baseRows[0]);
      final rawAdvisors = _asList(baseRows[1]);
      final agencyById = _indexBy(rawAgencies, 'id');
      final advisor = _advisorForSession(
        email: client.auth.currentUser?.email,
        advisors: rawAdvisors,
        agenciesById: agencyById,
      );
      if (_text(advisor, 'id').isEmpty) {
        throw StateError(
          'No se encontro el asesor ${client.auth.currentUser?.email ?? ''} en la tabla asesores.',
        );
      }
      final advisorId = _text(advisor, 'id');
      await _flushQueuedMutations(client);

      final portfolioBundle = await _loadPortfolioFromCoreSchema(
        supabase: client,
        advisorId: advisorId,
      );
      final portfolio = portfolioBundle.clients;

      final rows = await Future.wait<dynamic>([
        client
            .from('solicitudes_credito')
            .select()
            .order('created_at', ascending: false)
            .limit(20),
        client
            .from('consultas_buro')
            .select()
            .order('created_at', ascending: false)
            .limit(20),
        client
            .from('alertas_cartera')
            .select()
            .order('created_at', ascending: false)
            .limit(20),
        client
            .from('acciones_cobranza')
            .select()
            .order('timestamp_gestion', ascending: false)
            .limit(20),
        client.from('sync_outbox').select().eq('estado', 'pendiente').limit(50),
      ]);
      final requests = await _enrichRequestsWithClients(
        client,
        _asList(rows[0]),
      );
      final bureau = _asList(rows[1]);
      final alerts = _asList(rows[2]);
      final collections = _asList(rows[3]);
      final pendingRows = _asList(rows[4]);
      final localPending = await _pendingQueueCount();

      return remember(
        SalesDashboardData(
          advisor: advisor,
          portfolio: portfolio,
          agencies: _normalisedAgencies(rawAgencies, rawAdvisors),
          advisors: _normalisedAdvisors(rawAdvisors, agencyById),
          kpis: _buildKpis(
            agencies: rawAgencies,
            assignments: portfolioBundle.assignments,
            requests: requests,
            credits: portfolioBundle.coreCredits,
          ),
          history: _historyFromAssignments(
            assignments: portfolioBundle.assignments,
            clientsById: portfolioBundle.clientsById,
            preapprovalsByClientId: portfolioBundle.preapprovalsByClientId,
          ),
          requests: requests,
          bureau: bureau,
          alerts: alerts,
          collections: collections,
          pendingSync:
              pendingRows.length +
              requests.where((item) => item['pendiente_sync'] == true).length +
              localPending,
          lastSyncLabel: 'hoy ${_timeLabel(DateTime.now())}',
          role: _text(advisor, 'perfil', fallback: 'Operador'),
          online: true,
        ),
      );
    } catch (error) {
      final cached = await _loadDashboard();
      if (cached != null) return remember(cached);
      throw StateError('No se pudo cargar datos desde Supabase: $error');
    }
  }

  Future<SalesDashboardData> _loadDashboardFromCore() async {
    final rows = await Future.wait<dynamic>([
      _getCoreJson('/auth/me'),
      _getCoreJson('/cartera'),
      _getCoreJson('/solicitudes'),
    ]);
    final me = _asMap(rows[0]);
    final cartera = _asList(rows[1]);
    final requests = _asList(rows[2]);
    final portfolio = cartera.map(_clientFromCoreCartera).toList();
    final visitados = portfolio
        .where((client) => client.visitStatus == 'visitado')
        .length;
    final conversion = portfolio.isEmpty
        ? 0
        : (visitados / portfolio.length) * 100;
    final advisor = _advisorFromCoreSession(
      stored: await readCoreAdvisor(),
      payload: _asMap(me['asesor']),
    );
    return SalesDashboardData(
      advisor: advisor,
      portfolio: portfolio,
      agencies: [
        {
          'id': _text(advisor, 'agencia_id', fallback: 'core-agencia'),
          'agencia': _text(advisor, 'agencia', fallback: 'Agencia asignada'),
          'nombre': _text(advisor, 'agencia', fallback: 'Agencia asignada'),
          'region': 'Produccion',
          'total_asesores': 1,
        },
      ],
      advisors: [advisor],
      kpis: [
        {
          'agencia': _text(advisor, 'agencia', fallback: 'Agencia asignada'),
          'desembolsos': requests
              .where((item) => _text(item, 'estado') == 'desembolsado')
              .length,
          'mora_30_pct': 0,
          'tasa_conversion_pct': conversion,
        },
      ],
      history: portfolio
          .map(
            (client) => {
              'cliente_nombre': client.fullName,
              'numero_expediente': _text(
                client.assignment,
                'numero_expediente',
              ),
              'estado_visita': client.visitStatus,
              'fecha_visita': _text(client.assignment, 'fecha_asignacion'),
              'recomendacion_asesor': client.priority,
              'score_final': client.finalScore,
            },
          )
          .toList(),
      requests: requests,
      bureau: const [],
      alerts: const [],
      collections: const [],
      pendingSync: 0,
      lastSyncLabel: 'Core ${_timeLabel(DateTime.now())}',
      role: _text(advisor, 'perfil', fallback: 'asesor'),
      online: true,
    );
  }

  Future<dynamic> _getCoreJson(String path) async {
    final response = await http
        .get(
          Uri.parse('${SupabaseConfig.coreBaseUrl}$path'),
          headers: await _coreHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Core ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  Future<dynamic> _postCoreJson(String path, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('${SupabaseConfig.coreBaseUrl}$path'),
          headers: await _coreHeaders(contentJson: true),
          body: jsonEncode(_jsonSafe(body)),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Core ${response.statusCode}: ${response.body}');
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  Future<Map<String, String>> _coreHeaders({bool contentJson = false}) async {
    final token = await readCoreToken();
    if (token == null || token.isEmpty) {
      throw StateError('No hay sesion Core activa.');
    }
    return {
      if (contentJson) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  PreapprovedClient _clientFromCoreCartera(Map<String, dynamic> item) {
    final fullName = _text(item, 'cliente_nombre', fallback: 'Cliente Core');
    final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final names = parts.take(max(1, (parts.length / 2).ceil())).join(' ');
    final lastNames = parts.skip(max(1, (parts.length / 2).ceil())).join(' ');
    final score = _number(item, 'score_prioridad');
    final amount = _number(item, 'monto_credito');
    final priority = _text(item, 'prioridad', fallback: 'normal');
    final visitStatus = _text(item, 'estado_visita', fallback: 'pendiente');
    return PreapprovedClient(
      assignment: {
        ...item,
        'cliente_id': _text(item, 'cliente_id'),
        'tipo_gestion': _text(
          item,
          'tipo_gestion',
          fallback: 'NUEVA_SOLICITUD',
        ),
        'prioridad': priority,
        'score_prioridad': score,
      },
      profile: {
        'id': _text(item, 'cliente_id'),
        'nombres': names.isEmpty ? fullName : names,
        'apellidos': lastNames,
        'numero_documento': _text(item, 'documento'),
        'dni': _text(item, 'documento'),
        'tipo_negocio': _text(item, 'tipo_gestion', fallback: 'Negocio'),
        'distrito': 'Cartera asignada',
        'direccion': 'Cartera asignada',
        'lat_negocio': _number(item, 'lat'),
        'lng_negocio': _number(item, 'lng'),
      },
      credit: {
        'id': _text(item, 'numero_expediente', fallback: _text(item, 'id')),
        'cliente_id': _text(item, 'cliente_id'),
        'estado': visitStatus == 'visitado'
            ? 'visita_realizada'
            : 'preaprobado',
        'segmento': _segmentFromPriority(priority),
        'monto_hipotesis': amount,
        'monto_aprobado': amount,
        'monto_maximo': amount,
        'score_transaccional': score,
      },
      score: {
        'score_transaccional': score,
        'score_confianza': score,
        'monto_hipotesis': amount,
        'segmento_preliminar': _segmentFromPriority(priority),
      },
      fieldFile: visitStatus == 'pendiente'
          ? const {}
          : {'estado_ficha': visitStatus, 'score_campo': max(0, score - 10)},
    );
  }

  String _segmentFromPriority(String priority) {
    return switch (priority.toLowerCase()) {
      'alta' => 'PREMIER',
      'media' => 'ESTANDAR',
      _ => 'BASICO',
    };
  }

  Future<void> submitFieldFile({
    required PreapprovedClient client,
    required FieldScoringInput input,
    required FieldScoringResult result,
    required String advisorName,
    required String agency,
  }) async {
    final estadoCredito = result.disqualified
        ? 'rechazado'
        : 'visita_realizada';
    final assignmentId = _text(client.assignment, 'id');

    if (await readCoreToken() != null) {
      if (assignmentId.isEmpty) {
        throw StateError('La cartera no tiene id de asignacion.');
      }
      await _postCoreJson('/cartera/$assignmentId/visita', {
        'resultado': result.disqualified ? 'no_encontrado' : 'visitado',
        'observacion':
            '$advisorName - $agency - ${input.recomendacion}: ${input.observaciones}',
        'lat': client.lat == 0 ? null : client.lat,
        'lng': client.lng == 0 ? null : client.lng,
      });
      await _postCoreJson('/cartera/$assignmentId/comite', {
        'asesor_nombre': advisorName,
        'agencia': agency,
        'score_transaccional': client.scoreValue.round(),
        'score_campo': result.scoreCampo,
        'score_final': result.scoreFinal,
        'segmento': result.segment,
        'monto_propuesto': result.disqualified ? 0 : result.maxAmount,
        'plazo_meses': result.suggestedTerm,
        'cuota_estimada': result.payment,
        'recomendacion': input.recomendacion,
        'observaciones': input.observaciones,
      });
      return;
    }

    if (!SupabaseConfig.isConfigured) {
      throw StateError('No hay conexion productiva para enviar la ficha.');
    }

    final supabase = Supabase.instance.client;
    if (assignmentId.isNotEmpty) {
      await supabase
          .from('cartera_diaria')
          .update({
            'estado_visita': result.disqualified ? 'no_encontrado' : 'visitado',
            'resultado_visita': estadoCredito,
            'observacion_visita':
                '$advisorName - $agency - ${input.recomendacion}: ${input.observaciones}',
            'timestamp_visita': DateTime.now().toIso8601String(),
            'lat_visita': client.lat,
            'lng_visita': client.lng,
          })
          .eq('id', assignmentId);
    }

    try {
      await supabase
          .from('creditos_preaprobados')
          .update({
            'score_confianza': (result.scoreFinal / 8).clamp(0, 100).round(),
            'monto_maximo': result.disqualified ? 0 : result.maxAmount,
            'plazo_sugerido_meses': result.suggestedTerm,
          })
          .eq('id', client.id);
    } catch (_) {
      // El cliente puede venir solo desde cartera_diaria sin preaprobado.
    }
  }

  Future<bool> updateBusinessLocation({
    required PreapprovedClient client,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    if (!SupabaseConfig.isConfigured || client.isRouteReferenceDestination) {
      return false;
    }
    final supabase = Supabase.instance.client;

    await supabase
        .from('clientes')
        .update({
          'lat': latitude,
          'lng': longitude,
          'direccion': address.isEmpty
              ? _text(client.profile, 'direccion_negocio')
              : address,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', client.userId);
    return true;
  }

  Future<void> registerVisitResult({
    required PreapprovedClient client,
    required String result,
    required String observation,
  }) async {
    final assignmentId = _text(client.assignment, 'id');
    if (assignmentId.isEmpty) return;

    if (await readCoreToken() != null) {
      await _postCoreJson('/cartera/$assignmentId/visita', {
        'resultado': result,
        'observacion': observation,
        'lat': client.lat == 0 ? null : client.lat,
        'lng': client.lng == 0 ? null : client.lng,
      });
      return;
    }

    if (!SupabaseConfig.isConfigured) {
      throw StateError('No hay conexion productiva para registrar la visita.');
    }
    final supabase = Supabase.instance.client;

    final payload = {
      'estado_visita': result == 'visitado' ? 'visitado' : result,
      'resultado_visita': result,
      'observacion_visita': observation,
      'timestamp_visita': DateTime.now().toIso8601String(),
      'lat_visita': client.lat,
      'lng_visita': client.lng,
    };
    try {
      await supabase
          .from('cartera_diaria')
          .update(payload)
          .eq('id', assignmentId);
    } catch (_) {
      await _queuePendingMutation({
        'type': 'visit_result',
        'assignment_id': assignmentId,
        'payload': payload,
      });
    }
  }

  Future<void> submitCreditApplication({
    required PreapprovedClient client,
    required Map<String, dynamic> advisor,
    required num amount,
    required int term,
    required String purpose,
    required String signature,
  }) async {
    final factor = paymentFactor(0.60, term);
    if (await readCoreToken() != null) {
      await _postCoreJson('/solicitudes', {
        'numero_documento': _text(
          client.profile,
          'numero_documento',
          fallback: _text(client.profile, 'dni'),
        ),
        'nombres': _text(client.profile, 'nombres'),
        'apellidos': _text(client.profile, 'apellidos'),
        'telefono': _nullableText(_text(client.profile, 'telefono')),
        'tipo_negocio': client.business,
        'nombre_negocio': _nullableText(
          _text(client.profile, 'nombre_negocio'),
        ),
        'ingresos_estimados': _number(
          client.score,
          'ingreso_promedio_ref',
          fallback: 3000,
        ),
        'monto_solicitado': amount,
        'plazo_meses': term,
        'moneda': 'PEN',
        'tipo_cuota': 'mensual',
        'garantia': 'sin_garantia',
        'destino_credito': purpose,
        'cuota_estimada': amount * factor,
        'tea_referencial': 0.60,
        'firma_cliente_base64': signature,
      });
      return;
    }

    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'No hay conexion productiva para transmitir la solicitud.',
      );
    }
    final supabase = Supabase.instance.client;
    final now = DateTime.now();
    final expediente =
        'BF-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';
    final advisorId = _text(advisor, 'id');
    if (advisorId.isEmpty || client.userId.isEmpty) {
      throw StateError('No se encontro asesor o cliente valido en Supabase.');
    }
    final payload = {
      'numero_expediente': expediente,
      'asesor_id': advisorId,
      'cliente_id': client.userId,
      'agencia_id': _nullableText(_text(client.assignment, 'agencia_id')),
      'canal': 'asesor',
      'tipo_negocio': client.business,
      'nombre_negocio': _text(client.profile, 'nombre_negocio'),
      'actividad_economica': client.business,
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
      'pendiente_sync': true,
    };
    try {
      await supabase.from('solicitudes_credito').insert(payload);
    } catch (_) {
      await _queuePendingMutation({
        'type': 'credit_application',
        'payload': payload,
      });
    }
  }

  Future<String> uploadDocument({
    required PreapprovedClient client,
    required String type,
    required Uint8List bytes,
    required String extension,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase no esta configurado para subir documentos.');
    }
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
    final hasCoreSession = await readCoreToken() != null;
    final solicitudId = _text(client.assignment, 'solicitud_id');
    if (solicitudId.isNotEmpty && hasCoreSession) {
      await _postCoreJson('/solicitudes/$solicitudId/documentos', {
        'tipo_documento': type,
        'storage_url': url,
        'tamanio_kb': (bytes.length / 1024).round(),
        'nitidez_score': min(100, bytes.length / 2048),
      });
    } else {
      final requests = await _optionalList(
        supabase
            .from('solicitudes_credito')
            .select('id')
            .eq('cliente_id', client.userId)
            .order('created_at', ascending: false)
            .limit(1),
      );
      if (requests.isNotEmpty) {
        await supabase.from('solicitudes_documentos').insert({
          'solicitud_id': _text(requests.first, 'id'),
          'tipo_documento': type,
          'storage_url': url,
          'tamanio_kb': (bytes.length / 1024).round(),
          'nitidez_score': min(100, bytes.length / 2048),
        });
      }
    }
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
    if (await readCoreToken() != null) {
      final solicitudes = _asList(await _getCoreJson('/solicitudes'));
      final solicitud = solicitudes.firstWhere(
        (item) => _text(item, 'numero_expediente') == expediente,
        orElse: () => const <String, dynamic>{},
      );
      final solicitudId = _text(solicitud, 'id');
      if (solicitudId.isNotEmpty) {
        await _postCoreJson('/solicitudes/$solicitudId/documentos', {
          'tipo_documento': 'pdf_expediente',
          'storage_url': url,
          'tamanio_kb': (bytes.length / 1024).round(),
          'nitidez_score': 100,
        });
      }
    } else {
      final requests = await _optionalList(
        supabase
            .from('solicitudes_credito')
            .select('id')
            .eq('numero_expediente', expediente)
            .limit(1),
      );
      if (requests.isNotEmpty) {
        await supabase.from('sync_outbox').insert({
          'entidad': 'pdf_expediente',
          'entidad_id': _text(requests.first, 'id'),
          'operacion': 'create',
          'payload': {'numero_expediente': expediente, 'storage_url': url},
        });
      }
    }
  }

  Future<void> signOut() async {
    if (SupabaseConfig.isConfigured) {
      await Supabase.instance.client.auth.signOut();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dashboardCacheKey);
    await prefs.remove(_pendingQueueKey);
    await prefs.remove(coreTokenKey);
    await prefs.remove(coreAdvisorKey);
  }

  Future<void> _saveDashboard(SalesDashboardData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _dashboardCacheKey,
      jsonEncode(_jsonSafe(data.toJson())),
    );
  }

  Future<SalesDashboardData?> _loadDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dashboardCacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final pending = await _pendingQueueCount();
      return SalesDashboardData.fromJson(
        Map<String, dynamic>.from(json),
      ).copyWith(
        online: false,
        pendingSync: pending,
        lastSyncLabel: 'cache local',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _queuePendingMutation(Map<String, dynamic> mutation) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _decodeQueue(prefs.getString(_pendingQueueKey));
    queue.add({...mutation, 'queued_at': DateTime.now().toIso8601String()});
    await prefs.setString(_pendingQueueKey, jsonEncode(_jsonSafe(queue)));
  }

  Future<int> _pendingQueueCount() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeQueue(prefs.getString(_pendingQueueKey)).length;
  }

  Future<void> _flushQueuedMutations(SupabaseClient supabase) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _decodeQueue(prefs.getString(_pendingQueueKey));
    if (queue.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final item in queue) {
      try {
        final type = _text(item, 'type');
        final payload = _asMap(item['payload']);
        if (type == 'visit_result') {
          await supabase
              .from('cartera_diaria')
              .update(payload)
              .eq('id', _text(item, 'assignment_id'));
        } else if (type == 'credit_application') {
          await supabase.from('solicitudes_credito').insert(payload);
        } else {
          remaining.add(item);
        }
      } catch (_) {
        remaining.add(item);
      }
    }
    await prefs.setString(_pendingQueueKey, jsonEncode(_jsonSafe(remaining)));
  }

  Future<_PortfolioBundle> _loadPortfolioFromCoreSchema({
    required SupabaseClient supabase,
    required String advisorId,
  }) async {
    final assignments = await _optionalList(
      advisorId.isEmpty
          ? supabase
                .from('cartera_diaria')
                .select()
                .order('score_prioridad', ascending: false)
                .limit(50)
          : supabase
                .from('cartera_diaria')
                .select()
                .eq('asesor_id', advisorId)
                .order('score_prioridad', ascending: false)
                .limit(50),
    );
    final assignedClientIds = _ids(assignments, 'cliente_id');
    final preapprovals = await _optionalList(
      assignedClientIds.isNotEmpty
          ? supabase
                .from('creditos_preaprobados')
                .select()
                .inFilter('cliente_id', assignedClientIds)
                .order('created_at', ascending: false)
                .limit(80)
          : advisorId.isEmpty
          ? supabase
                .from('creditos_preaprobados')
                .select()
                .order('created_at', ascending: false)
                .limit(80)
          : supabase
                .from('creditos_preaprobados')
                .select()
                .eq('asesor_id', advisorId)
                .order('created_at', ascending: false)
                .limit(80),
    );
    final preapprovedClientIds = _ids(preapprovals, 'cliente_id');
    final clientIds = {...assignedClientIds, ...preapprovedClientIds}.toList();

    final relatedRows = await Future.wait<dynamic>([
      clientIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : supabase.from('clientes').select().inFilter('id', clientIds),
      clientIds.isEmpty
          ? Future.value(<Map<String, dynamic>>[])
          : supabase
                .from('cr_creditos')
                .select()
                .inFilter('cliente_id', clientIds)
                .order('sync_at', ascending: false),
    ]);

    final clientsById = _indexBy(_asList(relatedRows[0]), 'id');
    final coreCredits = _asList(relatedRows[1]);
    final preapprovalsByClientId = _latestByKey(preapprovals, 'cliente_id');
    final coreCreditsByClientId = _latestByKey(coreCredits, 'cliente_id');
    final assignmentByClientId = _latestByKey(assignments, 'cliente_id');
    final portfolioClientIds =
        (assignments.isNotEmpty ? assignedClientIds : clientIds)
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

    final clients = portfolioClientIds.map((clientId) {
      final assignment = assignmentByClientId[clientId] ?? const {};
      final rawClient = clientsById[clientId] ?? const {};
      final preapproval = preapprovalsByClientId[clientId] ?? const {};
      final coreCredit = coreCreditsByClientId[clientId] ?? const {};
      return PreapprovedClient(
        credit: _creditFromCoreSchema(
          clientId: clientId,
          preapproval: preapproval,
          assignment: assignment,
          coreCredit: coreCredit,
        ),
        profile: _profileFromCoreSchema(rawClient),
        score: _scoreFromCoreSchema(
          preapproval: preapproval,
          assignment: assignment,
          rawClient: rawClient,
        ),
        fieldFile: _fieldFileFromAssignment(assignment, preapproval),
        assignment: assignment,
      );
    }).toList();
    clients.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    return _PortfolioBundle(
      clients: clients,
      assignments: assignments,
      coreCredits: coreCredits,
      clientsById: clientsById,
      preapprovalsByClientId: preapprovalsByClientId,
    );
  }

  static double paymentFactor(double tea, int months) {
    if (months <= 0) return 0;
    final tem = pow(1 + tea, 1 / 12) - 1;
    return tem * pow(1 + tem, months) / (pow(1 + tem, months) - 1);
  }

  static Map<String, dynamic> _advisorForSession({
    required String? email,
    required List<Map<String, dynamic>> advisors,
    required Map<String, Map<String, dynamic>> agenciesById,
  }) {
    final code = _advisorCodeFromEmail(email);
    Map<String, dynamic> row = const {};
    if (code.isNotEmpty) {
      for (final advisor in advisors) {
        if (_matchesAdvisorCode(advisor, code)) {
          row = advisor;
          break;
        }
      }
    }
    final agency = agenciesById[_text(row, 'agencia_id')] ?? const {};
    return _advisorFromCoreSchema(row: row, agency: agency, email: email);
  }

  static Map<String, dynamic> _advisorFromCoreSession({
    required Map<String, dynamic>? stored,
    required Map<String, dynamic> payload,
  }) {
    final row = stored ?? const <String, dynamic>{};
    final code = _text(
      row,
      'codigo_empleado',
      fallback: _text(payload, 'sub', fallback: _text(row, 'codigo')),
    );
    final fullName = '${_text(row, 'nombres')} ${_text(row, 'apellidos')}'
        .trim();
    final payloadName = _text(payload, 'nombre');
    final profile = _text(row, 'perfil', fallback: _text(payload, 'perfil'));
    return {
      ...row,
      'id': _text(row, 'id', fallback: _text(payload, 'asesor_id')),
      'codigo': code,
      'cod_asesor': code,
      'codigo_empleado': code,
      'nombre_completo': fullName.isNotEmpty
          ? fullName
          : (payloadName.isNotEmpty ? payloadName : 'Asesor Banco Falabella'),
      'email': code.isEmpty ? '' : 'asesor$code@bancofalabella.local',
      'agencia': 'Agencia asignada',
      'nivel': _prettyProfile(profile),
      'perfil': profile.isEmpty ? 'asesor' : profile,
      'agencia_id': _text(row, 'agencia_id'),
    };
  }

  static Map<String, dynamic> _advisorFromCoreSchema({
    required Map<String, dynamic> row,
    required Map<String, dynamic> agency,
    required String? email,
  }) {
    final fullName = '${_text(row, 'nombres')} ${_text(row, 'apellidos')}'
        .trim();
    final code = _text(
      row,
      'codigo_empleado',
      fallback: _text(
        row,
        'cod_asesor',
        fallback: _advisorCodeFromEmail(email),
      ),
    );
    return {
      'id': _text(row, 'id'),
      'nombre_completo': fullName.isEmpty ? 'Asesor Banco Falabella' : fullName,
      'email':
          email ?? (code.isEmpty ? '' : 'asesor$code@bancofalabella.local'),
      'agencia': _text(agency, 'nombre', fallback: 'Agencia asignada'),
      'nivel': _prettyProfile(_text(row, 'perfil', fallback: 'operador')),
      'perfil': _prettyProfile(_text(row, 'perfil', fallback: 'operador')),
      'codigo': code.isEmpty ? 'ASESOR' : code,
    };
  }

  static bool _matchesAdvisorCode(Map<String, dynamic> advisor, String code) {
    final expected = _normaliseAdvisorCode(code);
    final candidates = [
      _text(advisor, 'codigo_empleado'),
      _text(advisor, 'cod_asesor'),
    ];
    return candidates.any((candidate) {
      final normalised = _normaliseAdvisorCode(candidate);
      return normalised == expected ||
          normalised.endsWith(expected) ||
          expected.endsWith(normalised);
    });
  }

  static String _advisorCodeFromEmail(String? email) {
    final local = (email ?? '').split('@').first.toLowerCase();
    final digits = local.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return digits.padLeft(4, '0');
  }

  static String _normaliseAdvisorCode(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? value.trim().toLowerCase() : digits.padLeft(4, '0');
  }

  static String _prettyProfile(String value) {
    final text = value.replaceAll('_', ' ').trim();
    if (text.isEmpty) return 'Operador';
    return text
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static Map<String, dynamic> _profileFromCoreSchema(Map<String, dynamic> row) {
    return {
      ...row,
      'user_id': _text(row, 'id'),
      'dni': _text(row, 'numero_documento'),
      'direccion_negocio': _text(row, 'direccion'),
      'lat_negocio': _number(row, 'lat'),
      'lng_negocio': _number(row, 'lng'),
      'distrito': _text(row, 'direccion', fallback: 'Sin zona'),
    };
  }

  static Map<String, dynamic> _creditFromCoreSchema({
    required String clientId,
    required Map<String, dynamic> preapproval,
    required Map<String, dynamic> assignment,
    required Map<String, dynamic> coreCredit,
  }) {
    final confidence = _number(
      preapproval,
      'score_confianza',
      fallback: _number(assignment, 'score_prioridad', fallback: 50),
    );
    final score = confidence <= 100 ? confidence * 8 : confidence;
    final amount = _number(
      preapproval,
      'monto_maximo',
      fallback: _number(
        assignment,
        'monto_credito',
        fallback: _number(coreCredit, 'monto_desembolsado'),
      ),
    );
    return {
      ...preapproval,
      'id': _text(
        preapproval,
        'id',
        fallback: _text(assignment, 'id', fallback: clientId),
      ),
      'user_id': clientId,
      'cliente_id': clientId,
      'segmento': _segmentFromConfidence(confidence),
      'score_transaccional': score,
      'score_final': score,
      'monto_hipotesis': amount,
      'monto_aprobado': amount,
      'monto_maximo': amount,
      'plazo_meses': _number(preapproval, 'plazo_sugerido_meses', fallback: 6),
      'tasa_tea': _number(preapproval, 'tea_referencial', fallback: 0.60),
      'estado': _text(
        coreCredit,
        'estado',
        fallback: preapproval['vigente'] == false ? 'vencido' : 'preaprobado',
      ),
      'dias_mora': _number(coreCredit, 'dias_mora'),
      'estado_pago': _number(coreCredit, 'dias_mora') >= 30
          ? 'atraso_30'
          : 'al_dia',
    };
  }

  static Map<String, dynamic> _scoreFromCoreSchema({
    required Map<String, dynamic> preapproval,
    required Map<String, dynamic> assignment,
    required Map<String, dynamic> rawClient,
  }) {
    final confidence = _number(
      preapproval,
      'score_confianza',
      fallback: _number(assignment, 'score_prioridad', fallback: 50),
    );
    final score = confidence <= 100 ? confidence * 8 : confidence;
    return {
      'score_transaccional': score,
      'segmento_preliminar': _segmentFromConfidence(confidence),
      'monto_hipotesis': _number(
        preapproval,
        'monto_maximo',
        fallback: _number(assignment, 'monto_credito'),
      ),
      'ingreso_promedio_ref': _number(rawClient, 'ingresos_estimados'),
    };
  }

  static Map<String, dynamic> _fieldFileFromAssignment(
    Map<String, dynamic> assignment,
    Map<String, dynamic> preapproval,
  ) {
    final visitedAt = _text(assignment, 'timestamp_visita');
    if (visitedAt.isEmpty && _text(assignment, 'estado_visita') != 'visitado') {
      return const {};
    }
    final confidence = _number(
      preapproval,
      'score_confianza',
      fallback: _number(assignment, 'score_prioridad', fallback: 50),
    );
    return {
      'fecha_visita': visitedAt,
      'recomendacion_asesor': _text(
        assignment,
        'resultado_visita',
        fallback: 'visitado',
      ),
      'segmento_resultante': _segmentFromConfidence(confidence),
      'score_campo': 0,
    };
  }

  static String _segmentFromConfidence(num confidence) {
    final score = confidence <= 100 ? confidence : confidence / 8;
    if (score >= 80) return 'PREMIER';
    if (score >= 60) return 'ESTANDAR';
    if (score >= 35) return 'BASICO';
    return 'NO_APLICA';
  }

  static List<Map<String, dynamic>> _normalisedAgencies(
    List<Map<String, dynamic>> agencies,
    List<Map<String, dynamic>> advisors,
  ) {
    final counts = <String, int>{};
    for (final advisor in advisors) {
      final agencyId = _text(advisor, 'agencia_id');
      if (agencyId.isNotEmpty) counts[agencyId] = (counts[agencyId] ?? 0) + 1;
    }
    return agencies
        .map(
          (agency) => {
            ...agency,
            'codigo': _text(agency, 'cod_agencia'),
            'region': _text(agency, 'region'),
            'total_asesores': counts[_text(agency, 'id')] ?? 0,
          },
        )
        .toList();
  }

  static List<Map<String, dynamic>> _normalisedAdvisors(
    List<Map<String, dynamic>> advisors,
    Map<String, Map<String, dynamic>> agenciesById,
  ) {
    return advisors.map((advisor) {
      final agency = agenciesById[_text(advisor, 'agencia_id')] ?? const {};
      return {
        ...advisor,
        'nombre_completo':
            '${_text(advisor, 'nombres')} ${_text(advisor, 'apellidos')}'
                .trim(),
        'nivel': _prettyProfile(_text(advisor, 'perfil', fallback: 'operador')),
        'agencia': _text(agency, 'nombre', fallback: 'Sin agencia'),
        'creditos_meta': 0,
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _buildKpis({
    required List<Map<String, dynamic>> agencies,
    required List<Map<String, dynamic>> assignments,
    required List<Map<String, dynamic>> requests,
    required List<Map<String, dynamic>> credits,
  }) {
    final kpis = <Map<String, dynamic>>[];
    for (final agency in agencies.take(8)) {
      final agencyId = _text(agency, 'id');
      final assigned = assignments
          .where((row) => _text(row, 'agencia_id') == agencyId)
          .toList();
      final visited = assigned
          .where((row) => _text(row, 'estado_visita') == 'visitado')
          .length;
      final agencyRequests = requests
          .where((row) => _text(row, 'agencia_id') == agencyId)
          .toList();
      final disbursed = agencyRequests
          .where((row) => _text(row, 'estado') == 'desembolsado')
          .length;
      final overdue = credits.where((row) => _number(row, 'dias_mora') >= 30);
      final conversion = assigned.isEmpty
          ? 0
          : (visited / assigned.length) * 100;
      final mora30 = credits.isEmpty
          ? 0
          : (overdue.length / credits.length) * 100;
      kpis.add({
        'agencia': _text(agency, 'nombre', fallback: 'Piloto'),
        'desembolsos': disbursed,
        'mora_30_pct': mora30,
        'tasa_conversion_pct': conversion,
      });
    }
    if (kpis.isEmpty) {
      final visited = assignments
          .where((row) => _text(row, 'estado_visita') == 'visitado')
          .length;
      kpis.add({
        'agencia': 'Piloto',
        'desembolsos': requests
            .where((row) => _text(row, 'estado') == 'desembolsado')
            .length,
        'mora_30_pct': credits.isEmpty
            ? 0
            : credits.where((row) => _number(row, 'dias_mora') >= 30).length /
                  credits.length *
                  100,
        'tasa_conversion_pct': assignments.isEmpty
            ? 0
            : visited / assignments.length * 100,
      });
    }
    return kpis;
  }

  static List<Map<String, dynamic>> _historyFromAssignments({
    required List<Map<String, dynamic>> assignments,
    required Map<String, Map<String, dynamic>> clientsById,
    required Map<String, Map<String, dynamic>> preapprovalsByClientId,
  }) {
    return assignments
        .where(
          (assignment) =>
              _text(assignment, 'timestamp_visita').isNotEmpty ||
              _text(assignment, 'estado_visita') == 'visitado',
        )
        .map((assignment) {
          final clientId = _text(assignment, 'cliente_id');
          final rawClient = clientsById[clientId] ?? const {};
          final preapproval = preapprovalsByClientId[clientId] ?? const {};
          final fullName =
              '${_text(rawClient, 'nombres')} ${_text(rawClient, 'apellidos')}'
                  .trim();
          return {
            'nombre_cliente': fullName.isEmpty ? 'Cliente visitado' : fullName,
            'fecha_visita': _text(
              assignment,
              'timestamp_visita',
              fallback: _text(assignment, 'fecha_asignacion'),
            ),
            'recomendacion_asesor': _text(
              assignment,
              'resultado_visita',
              fallback: _text(assignment, 'estado_visita'),
            ),
            'segmento_resultante': _segmentFromConfidence(
              _number(preapproval, 'score_confianza', fallback: 50),
            ),
          };
        })
        .take(20)
        .toList();
  }

  static Map<String, Map<String, dynamic>> _indexBy(
    List<Map<String, dynamic>> rows,
    String key,
  ) {
    return {for (final row in rows) _text(row, key): row};
  }

  static List<String> _ids(List<Map<String, dynamic>> rows, String key) {
    return rows
        .map((row) => _text(row, key))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  static Map<String, Map<String, dynamic>> _latestByKey(
    List<Map<String, dynamic>> rows,
    String key,
  ) {
    final values = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = _text(row, key);
      if (id.isNotEmpty && !values.containsKey(id)) values[id] = row;
    }
    return values;
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

  static Future<List<Map<String, dynamic>>> _enrichRequestsWithClients(
    SupabaseClient supabase,
    List<Map<String, dynamic>> requests,
  ) async {
    final clientIds = _ids(requests, 'cliente_id');
    if (clientIds.isEmpty) return requests;

    final clients = await _optionalList(
      supabase
          .from('clientes')
          .select('id,numero_documento,nombres,apellidos')
          .inFilter('id', clientIds),
    );
    final clientsById = _indexBy(clients, 'id');
    return requests.map((request) {
      final client = clientsById[_text(request, 'cliente_id')] ?? const {};
      final fullName =
          '${_text(client, 'nombres')} ${_text(client, 'apellidos')}'.trim();
      return {
        ...request,
        'cliente_nombre': fullName,
        'cliente_documento': _text(client, 'numero_documento'),
      };
    }).toList();
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
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(dynamic value) {
  if (value is List) return value.map((item) => _asMap(item)).toList();
  return const <Map<String, dynamic>>[];
}

List<Map<String, dynamic>> _decodeQueue(String? raw) {
  if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
  try {
    final value = jsonDecode(raw);
    return _asList(value);
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
}

dynamic _jsonSafe(dynamic value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is List) return value.map(_jsonSafe).toList();
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _jsonSafe(entry.value),
    };
  }
  if (value is DateTime) return value.toIso8601String();
  return value.toString();
}

String _text(Map<String, dynamic> map, String key, {String fallback = ''}) {
  final value = map[key];
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableText(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

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
