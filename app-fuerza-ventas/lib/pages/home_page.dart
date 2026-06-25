import 'package:bancofalabella_app2/services/scoring_repository.dart';
import 'package:bancofalabella_app2/viewmodels/home_view_model.dart';
import 'package:bancofalabella_app2/viewmodels/route_view_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

class _AppColors {
  static const green = Color(0xFF123D37);
  static const deepGreen = Color(0xFF071F1B);
  static const lime = Color(0xFFB8D932);
  static const border = Color(0xFFCAD6D8);
  static const ink = Color(0xFF101820);
  static const blue = Color(0xFF1D5FA7);
  static const orange = Color(0xFFB76A00);
  static const red = Color(0xFFC9362B);
  static const teal = Color(0xFF006D75);
  static const purple = Color(0xFF6545A4);
  static const background = Color(0xFFEFF3F4);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.userEmail});

  final String? userEmail;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = HomeViewModel();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) => Scaffold(
        backgroundColor: _AppColors.background,
        appBar: AppBar(
          backgroundColor: _AppColors.ink,
          foregroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 16,
          flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_AppColors.deepGreen, _AppColors.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text('Fuerza de Ventas · Banco Falabella'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: viewModel.refresh,
              icon: const Icon(Icons.sync),
            ),
            IconButton(
              tooltip: 'Cerrar sesion',
              onPressed: viewModel.signOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: FutureBuilder<SalesDashboardData>(
          future: viewModel.dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingDashboard();
            }

            if (snapshot.hasError) {
              return _StateMessage(
                icon: Icons.cloud_off,
                title: 'No se pudo cargar Supabase',
                message: snapshot.error.toString(),
              );
            }

            final effectiveData = viewModel.withCurrentConnectivity(
              snapshot.data!,
            );
            final filtered = viewModel.filteredClients(effectiveData.portfolio);
            final selectedClient = viewModel.selectedClient(
              effectiveData.portfolio,
            );

            final pages = [
              _PortfolioTab(
                data: effectiveData,
                clients: filtered,
                segmentFilter: viewModel.segmentFilter,
                statusFilter: viewModel.statusFilter,
                searchQuery: viewModel.searchQuery,
                onSegmentChanged: viewModel.setSegmentFilter,
                onStatusChanged: viewModel.setStatusFilter,
                onSearchChanged: viewModel.setSearchQuery,
                onOpenFieldFile: (client) => viewModel.openFieldFile(
                  effectiveData.portfolio.indexOf(client),
                ),
                onOpenRoute: (client) => viewModel.openRoute(
                  effectiveData.portfolio.indexOf(client),
                ),
              ),
              _RouteTab(
                clients: effectiveData.portfolio,
                selected: selectedClient,
                repository: viewModel.repository,
                onSelect: viewModel.selectClient,
                onLocationUpdated: viewModel.updateClientLocation,
              ),
              _FieldFileTab(
                client: selectedClient,
                data: effectiveData,
                repository: viewModel.repository,
                onSubmitted: viewModel.refresh,
              ),
              _ApplicationTab(
                client: selectedClient,
                data: effectiveData,
                repository: viewModel.repository,
                onSubmitted: viewModel.refresh,
              ),
              _TrackingTab(
                data: effectiveData,
                repository: viewModel.repository,
              ),
              _MoreTab(
                data: effectiveData,
                selected: selectedClient,
                repository: viewModel.repository,
              ),
            ];

            return DefaultTextStyle(
              style: const TextStyle(
                color: _AppColors.ink,
                fontSize: 14,
                height: 1.28,
              ),
              child: IconTheme(
                data: const IconThemeData(color: _AppColors.green),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: pages[viewModel.selectedIndex],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: NavigationBar(
          height: 72,
          backgroundColor: _AppColors.ink,
          indicatorColor: _AppColors.lime,
          surfaceTintColor: _AppColors.ink,
          selectedIndex: viewModel.selectedIndex,
          onDestinationSelected: viewModel.selectDestination,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Clientes',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: 'Ruta',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Evaluar',
            ),
            NavigationDestination(
              icon: Icon(Icons.request_page_outlined),
              selectedIcon: Icon(Icons.request_page),
              label: 'Solicitud',
            ),
            NavigationDestination(
              icon: Icon(Icons.rule_outlined),
              selectedIcon: Icon(Icons.rule),
              label: 'Comite',
            ),
            NavigationDestination(
              icon: Icon(Icons.dashboard_customize_outlined),
              selectedIcon: Icon(Icons.dashboard_customize),
              label: 'Mas',
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioTab extends StatelessWidget {
  const _PortfolioTab({
    required this.data,
    required this.clients,
    required this.segmentFilter,
    required this.statusFilter,
    required this.searchQuery,
    required this.onSegmentChanged,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onOpenFieldFile,
    required this.onOpenRoute,
  });

  final SalesDashboardData data;
  final List<PreapprovedClient> clients;
  final String segmentFilter;
  final String statusFilter;
  final String searchQuery;
  final ValueChanged<String> onSegmentChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<PreapprovedClient> onOpenFieldFile;
  final ValueChanged<PreapprovedClient> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final pending = data.portfolio
        .where((client) => client.visitStatus == 'pendiente')
        .length;
    final visits = data.portfolio
        .where((client) => client.visitStatus == 'visitado')
        .length;
    final amount = data.portfolio.fold<num>(
      0,
      (sum, client) => sum + client.hypothesisAmount,
    );

    return _PagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdvisorHeader(advisor: data.advisor),
          const SizedBox(height: 16),
          _SyncBanner(
            lastSync: data.lastSyncLabel,
            pendingSync: data.pendingSync,
            online: data.online,
          ),
          const SizedBox(height: 16),
          _MetricStrip(
            metrics: [
              _MetricItem(
                Icons.people,
                'Cartera diaria',
                '${data.portfolio.length}',
                _AppColors.green,
              ),
              _MetricItem(
                Icons.pending_actions,
                'Pendientes',
                '$pending',
                _AppColors.orange,
              ),
              _MetricItem(
                Icons.assignment_turned_in,
                'Visitados',
                '$visits',
                _AppColors.teal,
              ),
              _MetricItem(
                Icons.payments,
                'Hipotesis',
                _money(amount),
                _AppColors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: data.portfolio.isEmpty ? 0 : visits / data.portfolio.length,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            color: _AppColors.green,
            backgroundColor: const Color(0xFFDCE8E0),
          ),
          const SizedBox(height: 18),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar cliente o ultimos digitos de DNI',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: onSearchChanged,
          ),
          if (searchQuery.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Filtro activo: $searchQuery',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          _FilterBar(
            segmentFilter: segmentFilter,
            statusFilter: statusFilter,
            onSegmentChanged: onSegmentChanged,
            onStatusChanged: onStatusChanged,
          ),
          const SizedBox(height: 14),
          _SectionTitle('Cartera diaria'),
          if (clients.isEmpty)
            const _StateMessage(
              icon: Icons.search_off,
              title: 'Sin clientes con este filtro',
              message: 'Cambia el segmento o estado para ver mas candidatos.',
            )
          else
            ...clients.map(
              (client) => _ClientCard(
                client: client,
                onOpenFieldFile: () => onOpenFieldFile(client),
                onOpenRoute: () => onOpenRoute(client),
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteTab extends StatefulWidget {
  const _RouteTab({
    required this.clients,
    required this.selected,
    required this.repository,
    required this.onSelect,
    required this.onLocationUpdated,
  });

  final List<PreapprovedClient> clients;
  final PreapprovedClient? selected;
  final ScoringRepository repository;
  final ValueChanged<int> onSelect;
  final ValueChanged<PreapprovedClient> onLocationUpdated;

  @override
  State<_RouteTab> createState() => _RouteTabState();
}

class _RouteTabState extends State<_RouteTab> {
  PreapprovedClient? routeSelected;
  List<PreapprovedClient>? optimizedRoute;
  final Map<String, PreapprovedClient> locationOverrides = {};

  @override
  void didUpdateWidget(covariant _RouteTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      routeSelected = _clientWithLocalLocation(widget.selected);
    }
    if (widget.clients != oldWidget.clients) {
      optimizedRoute = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseRouteClients =
        optimizedRoute ??
        RouteViewModel.withReferenceDestination(widget.clients);
    final routeClients = _clientsWithLocalLocations(baseRouteClients);
    final selected = routeSelected ?? widget.selected;
    final activeClient =
        _matchingClient(selected, routeClients) ??
        _clientWithLocalLocation(selected) ??
        routeClients.first;

    return _PagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionIntro(
            icon: Icons.route,
            title: 'Planificacion de ruta',
            description:
                'Mapa operativo con pins simulados, coordenadas y orden sugerido de visita.',
            color: _AppColors.teal,
          ),
          _RouteMap(clients: routeClients, selected: activeClient),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _optimizeRoute(context, routeClients),
            icon: const Icon(Icons.alt_route),
            label: const Text('Optimizar ruta'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openNavigation(context, activeClient),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navegar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final updated = await _captureBusinessLocation(
                      context: context,
                      repository: widget.repository,
                      client: activeClient,
                      onUpdated: () {},
                    );
                    if (updated == null || !mounted) return;
                    setState(() {
                      locationOverrides[updated.userId] = updated;
                      routeSelected = updated;
                      optimizedRoute = routeClients
                          .map(
                            (client) => client.userId == updated.userId
                                ? updated
                                : client,
                          )
                          .toList();
                    });
                    widget.onLocationUpdated(updated);
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text('GPS negocio'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionTitle('Visitas del dia'),
          for (var i = 0; i < routeClients.length; i++)
            _DataTile(
              icon: Icons.location_on,
              title: routeClients[i].fullName,
              subtitle:
                  '${routeClients[i].business} - ${routeClients[i].district}',
              trailing: '${routeClients[i].scoreValue.toStringAsFixed(0)}/800',
              color: _segmentColor(routeClients[i].segment),
              onTap: () {
                setState(() => routeSelected = routeClients[i]);
                if (i > 0) widget.onSelect(i - 1);
              },
            ),
        ],
      ),
    );
  }

  List<PreapprovedClient> _clientsWithLocalLocations(
    List<PreapprovedClient> clients,
  ) {
    return clients.map((client) => _clientWithLocalLocation(client)!).toList();
  }

  PreapprovedClient? _clientWithLocalLocation(PreapprovedClient? client) {
    if (client == null) return null;
    return locationOverrides[client.userId] ?? client;
  }

  PreapprovedClient? _matchingClient(
    PreapprovedClient? selected,
    List<PreapprovedClient> clients,
  ) {
    if (selected == null) return null;
    for (final client in clients) {
      if (client.userId == selected.userId) return client;
    }
    return null;
  }

  Future<void> _openNavigation(
    BuildContext context,
    PreapprovedClient client,
  ) async {
    final wazeUri = Uri.parse(
      'waze://?ll=${client.lat},${client.lng}&navigate=yes',
    );
    final mapsAppUri = Uri.parse(
      'google.navigation:q=${client.lat},${client.lng}&mode=d',
    );
    final mapsWebUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${client.lat},${client.lng}&travelmode=driving',
    );

    final opened =
        await _tryOpenNavigationApp(wazeUri) ||
        await _tryOpenNavigationApp(mapsAppUri) ||
        await _tryOpenNavigationApp(mapsWebUri);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la navegacion')),
      );
    }
  }

  Future<bool> _tryOpenNavigationApp(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _optimizeRoute(
    BuildContext context,
    List<PreapprovedClient> routeClients,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Optimizando ruta desde tu GPS...')),
      );

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de ubicacion requerido para optimizar'),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final optimized = RouteViewModel.optimizeByNearestNeighbor(
        clients: routeClients,
        startLat: position.latitude,
        startLng: position.longitude,
      );
      if (!context.mounted || !mounted) return;
      setState(() {
        optimizedRoute = optimized;
        routeSelected = optimized.first;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta optimizada por cercania')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo optimizar: $error')));
    }
  }
}

Future<PreapprovedClient?> _captureBusinessLocation({
  required BuildContext context,
  required ScoringRepository repository,
  required PreapprovedClient client,
  required VoidCallback onUpdated,
}) async {
  try {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Obteniendo senal GPS...')));

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de ubicacion denegado')),
      );
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    final address = await _reverseGeocode(position);
    if (!context.mounted) return null;

    final confirmedAddress = await _confirmBusinessLocation(
      context: context,
      client: client,
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
    );
    if (confirmedAddress == null) return null;

    final saved = await repository.updateBusinessLocation(
      client: client,
      latitude: position.latitude,
      longitude: position.longitude,
      address: confirmedAddress,
    );
    if (!context.mounted) return null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Ubicacion actualizada: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'
              : 'Ubicacion capturada para destino de prueba: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
        ),
      ),
    );
    onUpdated();
    return client.withBusinessLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      address: confirmedAddress,
    );
  } catch (error) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('GPS no disponible: $error')));
    return null;
  }
}

Future<String> _reverseGeocode(Position position) async {
  try {
    final places = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (places.isEmpty) return 'Direccion no encontrada';
    final place = places.first;
    return [
      place.street,
      place.subLocality,
      place.locality,
      place.administrativeArea,
    ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
  } catch (_) {
    return 'Direccion no encontrada';
  }
}

Future<String?> _confirmBusinessLocation({
  required BuildContext context,
  required PreapprovedClient client,
  required double latitude,
  required double longitude,
  required String address,
}) {
  final controller = TextEditingController(text: address);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirmar ubicacion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            client.fullName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            'GPS: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Direccion aproximada',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Descartar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class _FieldFileTab extends StatefulWidget {
  const _FieldFileTab({
    required this.client,
    required this.data,
    required this.repository,
    required this.onSubmitted,
  });

  final PreapprovedClient? client;
  final SalesDashboardData data;
  final ScoringRepository repository;
  final VoidCallback onSubmitted;

  @override
  State<_FieldFileTab> createState() => _FieldFileTabState();
}

class _FieldFileTabState extends State<_FieldFileTab> {
  bool negocioVerificado = true;
  String antiguedadNegocio = 'mas_3_anios';
  String tenenciaLocal = 'alquilado_con_contrato';
  String ventasDiariasRango = '151_a_300';
  String ratioGastos = 'menos_50pct';
  String tieneDeudaInformal = 'no';
  String participaPandero = 'no';
  String stockVisible = 'abundante';
  String activosHogar = 'al_menos_uno';
  String caracterResultado = 'sin_penalidad';
  String recomendacion = 'aprobar';
  bool dniCaptured = false;
  bool businessDocCaptured = false;
  bool sending = false;
  final amountController = TextEditingController(text: '1800');
  final observationsController = TextEditingController();
  int plazoMeses = 12;

  @override
  void dispose() {
    amountController.dispose();
    observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    if (client == null) {
      return const _StateMessage(
        icon: Icons.assignment_late_outlined,
        title: 'Selecciona un cliente',
        message:
            'Desde Cartera puedes iniciar la ficha de evaluacion de campo.',
      );
    }

    final amount =
        num.tryParse(amountController.text.replaceAll(',', '.')) ??
        client.hypothesisAmount;
    final input = FieldScoringInput(
      negocioVerificado: negocioVerificado,
      antiguedadNegocio: antiguedadNegocio,
      tenenciaLocal: tenenciaLocal,
      ventasDiariasRango: ventasDiariasRango,
      ratioGastos: ratioGastos,
      tieneDeudaInformal: tieneDeudaInformal,
      participaPandero: participaPandero,
      stockVisible: stockVisible,
      activosHogar: activosHogar,
      caracterResultado: caracterResultado,
      montoPropuesto: amount,
      plazoMeses: plazoMeses,
      recomendacion: recomendacion,
      observaciones: observationsController.text,
    );
    final result = input.calculate(
      client.scoreValue,
      _number(client.score, 'ingreso_promedio_ref', fallback: 3000),
    );

    return _PagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClientSummary(client: client),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _captureBusinessLocation(
              context: context,
              repository: widget.repository,
              client: client,
              onUpdated: widget.onSubmitted,
            ),
            icon: const Icon(Icons.my_location),
            label: const Text('Actualizar ubicacion del negocio'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16),
          _ScoreSummary(result: result, transactionalScore: client.scoreValue),
          const SizedBox(height: 18),
          _SectionTitle('F1 Verificacion del negocio'),
          _SwitchRow(
            title: 'Negocio verificado fisicamente',
            value: negocioVerificado,
            onChanged: (value) => setState(() => negocioVerificado = value),
          ),
          _OptionSelect(
            label: 'Antiguedad',
            value: antiguedadNegocio,
            options: const {
              'menos_1_anio': 'Menos de 1 ano',
              '1_a_3_anios': '1 a 3 anos',
              'mas_3_anios': 'Mas de 3 anos',
            },
            onChanged: (value) => setState(() => antiguedadNegocio = value),
          ),
          _OptionSelect(
            label: 'Tenencia del local',
            value: tenenciaLocal,
            options: const {
              'alquilado_sin_contrato': 'Alquilado sin contrato',
              'alquilado_con_contrato': 'Alquilado con contrato',
              'propio': 'Propio',
            },
            onChanged: (value) => setState(() => tenenciaLocal = value),
          ),
          const SizedBox(height: 18),
          _SectionTitle('F2 Capacidad de pago'),
          _OptionSelect(
            label: 'Ventas diarias',
            value: ventasDiariasRango,
            options: const {
              'menos_50': 'Menos de S/ 50',
              '50_a_150': 'S/ 50 a S/ 150',
              '151_a_300': 'S/ 151 a S/ 300',
              'mas_300': 'Mas de S/ 300',
            },
            onChanged: (value) => setState(() => ventasDiariasRango = value),
          ),
          _OptionSelect(
            label: 'Gastos fijos',
            value: ratioGastos,
            options: const {
              'mas_80pct': 'Mas del 80%',
              '50_a_80pct': '50% a 80%',
              'menos_50pct': 'Menos del 50%',
            },
            onChanged: (value) => setState(() => ratioGastos = value),
          ),
          const SizedBox(height: 18),
          _SectionTitle('F3 Deuda informal'),
          _OptionSelect(
            label: 'Prestamos informales',
            value: tieneDeudaInformal,
            options: const {
              'si_significativa': 'Si, significativa',
              'si_menor': 'Si, menor',
              'no': 'No',
            },
            onChanged: (value) => setState(() => tieneDeudaInformal = value),
          ),
          _OptionSelect(
            label: 'Pandero o junta',
            value: participaPandero,
            options: const {
              'si_mayor_cuota': 'Si, cuota mayor',
              'si_menor_cuota': 'Si, cuota menor',
              'no': 'No',
            },
            onChanged: (value) => setState(() => participaPandero = value),
          ),
          const SizedBox(height: 18),
          _SectionTitle('F4 Activos y documentos'),
          _OptionSelect(
            label: 'Stock visible',
            value: stockVisible,
            options: const {
              'escaso': 'Escaso',
              'moderado': 'Moderado',
              'abundante': 'Abundante',
            },
            onChanged: (value) => setState(() => stockVisible = value),
          ),
          _OptionSelect(
            label: 'Activos del hogar',
            value: activosHogar,
            options: const {
              'ninguno': 'Ninguno',
              'al_menos_uno': 'Al menos uno',
            },
            onChanged: (value) => setState(() => activosHogar = value),
          ),
          Row(
            children: [
              Expanded(
                child: _CaptureButton(
                  label: 'DNI',
                  captured: dniCaptured,
                  onPressed: () => setState(() => dniCaptured = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CaptureButton(
                  label: 'Documento negocio',
                  captured: businessDocCaptured,
                  onPressed: () => setState(() => businessDocCaptured = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionTitle('F5 Caracter y propuesta'),
          _OptionSelect(
            label: 'Caracter del cliente',
            value: caracterResultado,
            options: const {
              'sin_penalidad': 'Sin penalidad',
              'alerta': 'Alerta',
              'veto': 'Veto',
            },
            onChanged: (value) => setState(() => caracterResultado = value),
          ),
          _ProposalForm(
            amountController: amountController,
            plazoMeses: plazoMeses,
            recomendacion: recomendacion,
            observationsController: observationsController,
            onChanged: () => setState(() {}),
            onTermChanged: (value) => setState(() => plazoMeses = value),
            onRecommendationChanged: (value) =>
                setState(() => recomendacion = value),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: sending ? null : () => _submit(client, input, result),
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Enviar al comite'),
            style: FilledButton.styleFrom(
              backgroundColor: _AppColors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(
    PreapprovedClient client,
    FieldScoringInput input,
    FieldScoringResult result,
  ) async {
    setState(() => sending = true);
    try {
      await widget.repository.submitFieldFile(
        client: client,
        input: input,
        result: result,
        advisorName: _text(
          widget.data.advisor,
          'nombre_completo',
          fallback: 'Asesor',
        ),
        agency: _text(
          widget.data.advisor,
          'agencia',
          fallback: 'Agencia Huancayo Centro',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ficha enviada al comite')));
      widget.onSubmitted();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar: $error'),
          backgroundColor: _AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
}

class _ApplicationTab extends StatefulWidget {
  const _ApplicationTab({
    required this.client,
    required this.data,
    required this.repository,
    required this.onSubmitted,
  });

  final PreapprovedClient? client;
  final SalesDashboardData data;
  final ScoringRepository repository;
  final VoidCallback onSubmitted;

  @override
  State<_ApplicationTab> createState() => _ApplicationTabState();
}

class _ApplicationTabState extends State<_ApplicationTab> {
  final amountController = TextEditingController(text: '1800');
  final purposeController = TextEditingController(
    text: 'Capital de trabajo para abastecimiento de mercaderia',
  );
  int term = 12;
  bool conyuge = false;
  bool garante = false;
  bool signed = false;
  bool sending = false;

  @override
  void dispose() {
    amountController.dispose();
    purposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    if (client == null) {
      return const _StateMessage(
        icon: Icons.request_page,
        title: 'Selecciona un cliente',
        message: 'Desde Cartera puedes iniciar una solicitud de credito.',
      );
    }

    final amount =
        num.tryParse(amountController.text.replaceAll(',', '.')) ??
        client.hypothesisAmount;
    final factor = ScoringRepository.paymentFactor(0.60, term);
    final payment = amount * factor;

    return _PagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionIntro(
            icon: Icons.request_page,
            title: 'Solicitud de credito',
            description:
                'Stepper operativo: cliente, negocio, condiciones, firma y transmision electronica.',
            color: _AppColors.blue,
          ),
          _ClientSummary(client: client),
          const SizedBox(height: 18),
          _SectionTitle('Paso 1 Cliente y negocio'),
          _InfoGrid(
            items: [
              _InfoItem(Icons.badge, 'DNI', client.maskedDocument),
              _InfoItem(Icons.store, 'Negocio', client.business),
              _InfoItem(
                Icons.calendar_month,
                'Antiguedad',
                '${_number(client.profile, 'antiguedad_negocio_meses').toStringAsFixed(0)} meses',
              ),
              _InfoItem(Icons.location_on, 'Distrito', client.district),
            ],
          ),
          const SizedBox(height: 18),
          _SectionTitle('Paso 2 Condiciones'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _boxDecoration(accent: _AppColors.blue),
            child: Column(
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto solicitado',
                    prefixIcon: Icon(Icons.payments),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _OptionSelect(
                  label: 'Plazo solicitado',
                  value: term.toString(),
                  options: const {
                    '3': '3 meses',
                    '6': '6 meses',
                    '12': '12 meses',
                  },
                  onChanged: (value) => setState(() => term = int.parse(value)),
                ),
                TextField(
                  controller: purposeController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Destino del credito',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle('Paso 3 Evaluacion familiar'),
          _SwitchRow(
            title: 'Declara conyuge',
            value: conyuge,
            onChanged: (value) => setState(() => conyuge = value),
          ),
          _SwitchRow(
            title: 'Incluye garante',
            value: garante,
            onChanged: (value) => setState(() => garante = value),
          ),
          const SizedBox(height: 18),
          _SectionTitle('Paso 4 Simulador y firma'),
          _MetricStrip(
            metrics: [
              _MetricItem(Icons.percent, 'TEA ref.', '60%', _AppColors.orange),
              _MetricItem(
                Icons.receipt,
                'Cuota',
                _money(payment),
                _AppColors.purple,
              ),
              _MetricItem(
                Icons.verified,
                'Estado',
                signed ? 'FIRMADO' : 'PENDIENTE',
                signed ? _AppColors.green : _AppColors.red,
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => signed = true),
            icon: Icon(signed ? Icons.draw : Icons.gesture),
            label: Text(
              signed ? 'Firma digital capturada' : 'Capturar firma digital',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: sending || !signed
                ? null
                : () => _submit(client, amount, purposeController.text),
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload),
            label: const Text('Transmitir solicitud'),
            style: FilledButton.styleFrom(
              backgroundColor: _AppColors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(
    PreapprovedClient client,
    num amount,
    String purpose,
  ) async {
    setState(() => sending = true);
    try {
      await widget.repository.submitCreditApplication(
        client: client,
        advisor: widget.data.advisor,
        amount: amount,
        term: term,
        purpose: purpose,
        signature: 'firma_digital_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud transmitida al comite')),
      );
      widget.onSubmitted();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo transmitir: $error'),
          backgroundColor: _AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
}

class _TrackingTab extends StatelessWidget {
  const _TrackingTab({required this.data, required this.repository});

  final SalesDashboardData data;
  final ScoringRepository repository;

  @override
  Widget build(BuildContext context) {
    final states = <String, int>{};
    for (final request in data.requests) {
      final state = _text(request, 'estado', fallback: 'borrador');
      states.update(state, (value) => value + 1, ifAbsent: () => 1);
    }
    if (states.isEmpty) {
      for (final client in data.portfolio) {
        states.update(client.status, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    return _PagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionIntro(
            icon: Icons.rule,
            title: 'Estado de solicitudes',
            description:
                'Seguimiento del flujo enviado, comite, aprobado y desembolsado.',
            color: _AppColors.purple,
          ),
          _MetricStrip(
            metrics: states.entries
                .map(
                  (entry) => _MetricItem(
                    Icons.timeline,
                    _pretty(entry.key),
                    '${entry.value}',
                    _AppColors.purple,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          _SectionTitle('Transmision electronica'),
          ...data.requests
              .take(6)
              .map(
                (request) => _DataTile(
                  icon: Icons.cloud_upload,
                  title: _text(
                    request,
                    'numero_expediente',
                    fallback: 'Expediente sin numero',
                  ),
                  subtitle:
                      '${_pretty(_text(request, 'estado'))} - ${_money(_number(request, 'monto_solicitado'))}',
                  trailing:
                      '${_number(request, 'plazo_meses').toStringAsFixed(0)}m',
                  color: _AppColors.blue,
                ),
              ),
          OutlinedButton.icon(
            onPressed: data.requests.isEmpty
                ? null
                : () => _generatePdf(context, data.requests.first),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generar PDF de expediente'),
          ),
          const SizedBox(height: 18),
          _SectionTitle('Historial de visitas'),
          if (data.history.isEmpty)
            const _StateMessage(
              icon: Icons.history,
              title: 'Sin historial',
              message: 'Las fichas enviadas apareceran en esta seccion.',
            )
          else
            ...data.history.map(
              (visit) => _DataTile(
                icon: Icons.fact_check,
                title: _text(
                  visit,
                  'nombre_cliente',
                  fallback: 'Cliente visitado',
                ),
                subtitle:
                    '${_text(visit, 'fecha_visita')} - ${_pretty(_text(visit, 'recomendacion_asesor'))}',
                trailing: _text(
                  visit,
                  'segmento_resultante',
                  fallback: 'PENDIENTE',
                ),
                color: _segmentColor(_text(visit, 'segmento_resultante')),
              ),
            ),
          const SizedBox(height: 18),
          _SectionTitle('KPIs piloto'),
          ...data.kpis.map((kpi) => _KpiTile(kpi: kpi)),
        ],
      ),
    );
  }

  Future<void> _generatePdf(
    BuildContext context,
    Map<String, dynamic> request,
  ) async {
    final expediente = _text(
      request,
      'numero_expediente',
      fallback: 'EXP-DEMO',
    );
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Banco Falabella - Expediente de credito'),
            pw.SizedBox(height: 12),
            pw.Text('Numero: $expediente'),
            pw.Text('Estado: ${_pretty(_text(request, 'estado'))}'),
            pw.Text('Monto: ${_money(_number(request, 'monto_solicitado'))}'),
          ],
        ),
      ),
    );
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: '$expediente.pdf');
    await repository.registerPdf(expediente: expediente, bytes: bytes);
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab({
    required this.data,
    required this.selected,
    required this.repository,
  });

  final SalesDashboardData data;
  final PreapprovedClient? selected;
  final ScoringRepository repository;

  @override
  Widget build(BuildContext context) {
    return _PagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionIntro(
            icon: Icons.dashboard_customize,
            title: 'Modulos Semana 11',
            description:
                'Documentos, buro, cobranza, reportes, supervision y red comercial.',
            color: _AppColors.teal,
          ),
          _DocumentsPanel(selected: selected, repository: repository),
          const SizedBox(height: 18),
          _BureauPanel(data: data, selected: selected),
          const SizedBox(height: 18),
          _CollectionsPanel(data: data),
          const SizedBox(height: 18),
          _ReportsPanel(data: data),
          const SizedBox(height: 18),
          _NetworkPanel(data: data),
        ],
      ),
    );
  }
}

class _NetworkPanel extends StatelessWidget {
  const _NetworkPanel({required this.data});

  final SalesDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Red comercial'),
        ...data.agencies
            .take(4)
            .map(
              (agency) => _DataTile(
                icon: Icons.account_balance,
                title: _text(agency, 'nombre'),
                subtitle:
                    '${_text(agency, 'codigo')} - ${_text(agency, 'region')}',
                trailing:
                    '${_number(agency, 'total_asesores').toStringAsFixed(0)} asesores',
                color: _AppColors.green,
              ),
            ),
        ...data.advisors
            .take(4)
            .map(
              (advisor) => _DataTile(
                icon: Icons.badge,
                title: _text(advisor, 'nombre_completo'),
                subtitle:
                    '${_text(advisor, 'nivel')} - ${_text(advisor, 'agencia')}',
                trailing:
                    '${_number(advisor, 'creditos_meta').toStringAsFixed(0)} metas',
                color: _AppColors.blue,
              ),
            ),
      ],
    );
  }
}

class _DocumentsPanel extends StatelessWidget {
  const _DocumentsPanel({required this.selected, required this.repository});

  final PreapprovedClient? selected;
  final ScoringRepository repository;

  @override
  Widget build(BuildContext context) {
    final docs = const [
      ('dni_anverso', 'DNI anverso'),
      ('dni_reverso', 'DNI reverso'),
      ('ruc', 'RUC'),
      ('recibo_servicios', 'Recibo servicios'),
      ('foto_negocio', 'Foto negocio'),
      ('contrato_arrendamiento', 'Contrato alquiler'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Captura de documentos'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _boxDecoration(accent: _AppColors.blue),
          child: Column(
            children: [
              if (selected != null)
                Text(
                  selected!.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              const SizedBox(height: 10),
              ...docs.map(
                (doc) => _DataTile(
                  icon: Icons.photo_camera,
                  title: doc.$2,
                  subtitle:
                      'Camara real, subida a Storage y registro documental',
                  trailing: 'SUBIR',
                  color: _AppColors.blue,
                  onTap: selected == null
                      ? null
                      : () => _captureDocument(context, selected!, doc.$1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _captureDocument(
    BuildContext context,
    PreapprovedClient client,
    String type,
  ) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 72,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final extension = image.name.split('.').last;
      final url = await repository.uploadDocument(
        client: client,
        type: type,
        bytes: bytes,
        extension: extension,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Documento subido: $url')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo capturar/subir: $error'),
          backgroundColor: _AppColors.red,
        ),
      );
    }
  }
}

class _BureauPanel extends StatelessWidget {
  const _BureauPanel({required this.data, required this.selected});

  final SalesDashboardData data;
  final PreapprovedClient? selected;

  @override
  Widget build(BuildContext context) {
    final bureau = data.bureau.isNotEmpty
        ? data.bureau.first
        : const <String, dynamic>{};
    final rating = selected == null
        ? _text(bureau, 'calificacion_sbs', fallback: 'Normal')
        : _text(selected!.profile, 'calificacion_sbs', fallback: 'Normal');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Consulta de buro y listas'),
        _DataTile(
          icon: Icons.verified_user,
          title: 'Semaforo SBS: ${_pretty(rating)}',
          subtitle:
              'Entidades: ${_number(bureau, 'entidades_con_deuda').toStringAsFixed(0)} - Deuda: ${_money(_number(bureau, 'deuda_total_pen'))}',
          trailing: _number(bureau, 'dias_mayor_mora').toStringAsFixed(0),
          color: _riskColor(rating),
        ),
        _PaymentBehaviorChart(client: selected),
      ],
    );
  }
}

class _PaymentBehaviorChart extends StatelessWidget {
  const _PaymentBehaviorChart({required this.client});

  final PreapprovedClient? client;

  @override
  Widget build(BuildContext context) {
    final values = [
      0,
      0,
      2,
      0,
      5,
      0,
      0,
      0,
      3,
      0,
      0,
      client == null ? 0 : _number(client!.credit, 'dias_mora').toInt(),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(accent: _AppColors.purple),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comportamiento de pagos 12 meses',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(),
                  rightTitles: AxisTitles(),
                  topTitles: AxisTitles(),
                  bottomTitles: AxisTitles(),
                ),
                barGroups: [
                  for (var i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i] == 0 ? 4 : values[i].toDouble(),
                          width: 14,
                          color: values[i] == 0
                              ? _AppColors.green
                              : _AppColors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Pago puntual: 83% - Mora promedio: 2 dias - Total pagado: S/ 4,850',
          ),
        ],
      ),
    );
  }
}

class _CollectionsPanel extends StatelessWidget {
  const _CollectionsPanel({required this.data});

  final SalesDashboardData data;

  @override
  Widget build(BuildContext context) {
    final overdue = data.portfolio
        .where((client) => _number(client.credit, 'dias_mora') > 0)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Recuperacion de cartera vencida'),
        if (overdue.isEmpty)
          const _DataTile(
            icon: Icons.check_circle,
            title: 'Sin cartera vencida critica',
            subtitle: 'No hay clientes con mora activa en la muestra cargada.',
            trailing: 'OK',
            color: _AppColors.green,
          )
        else
          ...overdue.map(
            (client) => _DataTile(
              icon: Icons.warning_amber,
              title: client.fullName,
              subtitle:
                  '${client.district} - ${_number(client.credit, 'dias_mora').toStringAsFixed(0)} dias de mora',
              trailing: _money(client.approvedAmount),
              color: _AppColors.red,
            ),
          ),
        ...data.collections.map(
          (item) => _DataTile(
            icon: Icons.handshake,
            title: _pretty(_text(item, 'resultado')),
            subtitle: _text(
              item,
              'observaciones',
              fallback: 'Gestion registrada',
            ),
            trailing: _money(_number(item, 'monto_compromiso')),
            color: _AppColors.orange,
          ),
        ),
      ],
    );
  }
}

class _ReportsPanel extends StatelessWidget {
  const _ReportsPanel({required this.data});

  final SalesDashboardData data;

  @override
  Widget build(BuildContext context) {
    final sent = data.requests
        .where((item) => _text(item, 'estado') != 'borrador')
        .length;
    final approved = data.requests
        .where(
          (item) =>
              _text(item, 'estado') == 'aprobado' ||
              _text(item, 'estado') == 'desembolsado',
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Reportes y supervision'),
        _MetricStrip(
          metrics: [
            _MetricItem(
              Icons.request_page,
              'Solicitudes',
              '${data.requests.length}',
              _AppColors.blue,
            ),
            _MetricItem(
              Icons.cloud_upload,
              'Transmitidas',
              '$sent',
              _AppColors.teal,
            ),
            _MetricItem(
              Icons.verified,
              'Aprobadas',
              '$approved',
              _AppColors.green,
            ),
            _MetricItem(
              Icons.notifications,
              'Alertas',
              '${data.alerts.length}',
              _AppColors.orange,
            ),
          ],
        ),
      ],
    );
  }
}

class _AdvisorHeader extends StatelessWidget {
  const _AdvisorHeader({required this.advisor});

  final Map<String, dynamic> advisor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_AppColors.ink, _AppColors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _AppColors.green.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.support_agent,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(advisor, 'nombre_completo', fallback: 'Carlos Ramirez'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${_text(advisor, 'agencia')} - ${_text(advisor, 'nivel')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFCADBD7)),
                ),
                Text(
                  'Perfil: ${_text(advisor, 'perfil', fallback: 'Operador')}',
                  style: const TextStyle(
                    color: Color(0xFFCADBD7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _StatusPill(
            text: _text(advisor, 'codigo', fallback: 'AG-001'),
            color: _AppColors.lime,
          ),
        ],
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({
    required this.lastSync,
    required this.pendingSync,
    required this.online,
  });

  final String lastSync;
  final int pendingSync;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = !online
        ? _AppColors.red
        : (pendingSync > 0 ? _AppColors.orange : _AppColors.teal);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(accent: color),
      child: Row(
        children: [
          Icon(
            !online
                ? Icons.cloud_off
                : (pendingSync > 0 ? Icons.cloud_upload : Icons.cloud_done),
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pendingSync > 0
                  ? 'Ultima actualizacion: $lastSync - $pendingSync pendientes de sincronizar'
                  : !online
                  ? 'Modo offline activo - se usara cache local y cola pendiente'
                  : lastSync.toLowerCase().contains('core')
                  ? 'Ultima actualizacion: $lastSync - conectado al Core FastAPI'
                  : 'Ultima actualizacion: $lastSync - cartera sincronizada',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.segmentFilter,
    required this.statusFilter,
    required this.onSegmentChanged,
    required this.onStatusChanged,
  });

  final String segmentFilter;
  final String statusFilter;
  final ValueChanged<String> onSegmentChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _boxDecoration(accent: _AppColors.blue),
      child: Column(
        children: [
          _OptionSelect(
            label: 'Segmento',
            value: segmentFilter,
            options: const {
              'TODOS': 'Todos',
              'PREMIER': 'Premier',
              'ESTANDAR': 'Estandar',
              'BASICO': 'Basico',
            },
            onChanged: onSegmentChanged,
          ),
          _OptionSelect(
            label: 'Gestion / visita',
            value: statusFilter,
            options: const {
              'TODOS': 'Todos',
              'RENOVACION': 'Renovaciones',
              'AMPLIACION': 'Ampliaciones',
              'NUEVA_SOLICITUD': 'Nuevas',
              'RECUPERACION_MORA': 'En mora',
              'visitado': 'Visitados',
              'pendiente': 'Pendientes',
            },
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.onOpenFieldFile,
    required this.onOpenRoute,
  });

  final PreapprovedClient client;
  final VoidCallback onOpenFieldFile;
  final VoidCallback onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final color = _segmentColor(client.segment);
    final isVisited = client.visitStatus == 'visitado';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: isVisited
          ? _boxDecoration(
              accent: Colors.blueGrey,
            ).copyWith(color: const Color(0xFFF0F3F2))
          : _boxDecoration(accent: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${client.maskedDocument} - ${client.business} - ${client.district}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF66727A)),
                    ),
                  ],
                ),
              ),
              _StatusPill(text: client.segment, color: color),
            ],
          ),
          const SizedBox(height: 12),
          _MetricStrip(
            metrics: [
              _MetricItem(
                Icons.speed,
                'Score',
                '${client.scoreValue.toStringAsFixed(0)}/800',
                color,
              ),
              _MetricItem(
                Icons.payments,
                'Hipotesis',
                _money(client.hypothesisAmount),
                _AppColors.blue,
              ),
              _MetricItem(
                Icons.local_offer,
                'Gestion',
                _pretty(client.managementType),
                _managementColor(client.managementType),
              ),
              _MetricItem(
                Icons.priority_high,
                'Prioridad',
                '${_pretty(client.priority)} ${client.priorityScore.toStringAsFixed(0)}',
                _priorityColor(client.priority),
              ),
              _MetricItem(
                Icons.task_alt,
                'Visita',
                _pretty(client.visitStatus),
                isVisited ? _AppColors.teal : _AppColors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenFieldFile,
                  icon: const Icon(Icons.assignment),
                  label: const Text('Iniciar ficha'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _AppColors.green,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Ver en ruta',
                onPressed: onOpenRoute,
                icon: const Icon(Icons.route),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.clients, required this.selected});

  final List<PreapprovedClient> clients;
  final PreapprovedClient? selected;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE5EFE9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD2E1D8)),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
            for (var i = 0; i < clients.length; i++)
              Positioned(
                left: 32.0 + (i * 74) % 260,
                top: 34.0 + (i * 58) % 210,
                child: Tooltip(
                  message:
                      '${clients[i].fullName} - ${_money(clients[i].hypothesisAmount)}',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _segmentColor(clients[i].segment),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: clients[i] == selected
                            ? Colors.white
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(Icons.store, size: 17, color: Colors.white),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selected == null
                      ? 'Selecciona un cliente para ver su ubicacion'
                      : '${selected!.fullName} - ${selected!.lat.toStringAsFixed(5)}, ${selected!.lng.toStringAsFixed(5)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final thinRoadPaint = Paint()
      ..color = const Color(0xFFBCD5C7)
      ..strokeWidth = 2;

    for (var y = 36.0; y < size.height; y += 58) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 24), roadPaint);
    }
    for (var x = 34.0; x < size.width; x += 72) {
      canvas.drawLine(Offset(x, 0), Offset(x + 24, size.height), thinRoadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ClientSummary extends StatelessWidget {
  const _ClientSummary({required this.client});

  final PreapprovedClient client;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(accent: _segmentColor(client.segment)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  client.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(
                text: client.segment,
                color: _segmentColor(client.segment),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${client.business} - ${client.district}'),
          Text(
            _text(
              client.profile,
              'direccion_negocio',
              fallback: 'Direccion por confirmar',
            ),
          ),
          const SizedBox(height: 12),
          _MetricStrip(
            metrics: [
              _MetricItem(
                Icons.speed,
                'Score transaccional',
                '${client.scoreValue.toStringAsFixed(0)}/800',
                _AppColors.green,
              ),
              _MetricItem(
                Icons.payments,
                'Monto hipotesis',
                _money(client.hypothesisAmount),
                _AppColors.blue,
              ),
              _MetricItem(
                Icons.account_balance,
                'SBS',
                _text(client.profile, 'calificacion_sbs', fallback: 'Normal'),
                _AppColors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary({required this.result, required this.transactionalScore});

  final FieldScoringResult result;
  final num transactionalScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(
        accent: result.disqualified
            ? _AppColors.red
            : _segmentColor(result.segment),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.disqualified ? result.reason : result.segment,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                result.disqualified ? '0' : '${result.scoreFinal}/1000',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetricStrip(
            metrics: [
              _MetricItem(
                Icons.analytics,
                'Campo',
                '${result.scoreCampo}/200',
                _AppColors.orange,
              ),
              _MetricItem(
                Icons.scoreboard,
                'Final',
                result.disqualified ? 'DESC' : '${result.scoreFinal}',
                _AppColors.green,
              ),
              _MetricItem(
                Icons.payments,
                'Monto max.',
                _money(result.maxAmount),
                _AppColors.blue,
              ),
              _MetricItem(
                Icons.receipt_long,
                'Cuota',
                _money(result.payment),
                _AppColors.purple,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Base transaccional: ${transactionalScore.toStringAsFixed(0)}/800',
          ),
        ],
      ),
    );
  }
}

class _ProposalForm extends StatelessWidget {
  const _ProposalForm({
    required this.amountController,
    required this.plazoMeses,
    required this.recomendacion,
    required this.observationsController,
    required this.onChanged,
    required this.onTermChanged,
    required this.onRecommendationChanged,
  });

  final TextEditingController amountController;
  final int plazoMeses;
  final String recomendacion;
  final TextEditingController observationsController;
  final VoidCallback onChanged;
  final ValueChanged<int> onTermChanged;
  final ValueChanged<String> onRecommendationChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(accent: _AppColors.purple),
      child: Column(
        children: [
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monto propuesto',
              prefixIcon: Icon(Icons.payments),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          _OptionSelect(
            label: 'Plazo',
            value: plazoMeses.toString(),
            options: const {'3': '3 meses', '6': '6 meses', '12': '12 meses'},
            onChanged: (value) => onTermChanged(int.parse(value)),
          ),
          _OptionSelect(
            label: 'Recomendacion',
            value: recomendacion,
            options: const {
              'aprobar': 'Aprobar',
              'aprobar_monto_reducido': 'Aprobar monto reducido',
              'elevar_comite': 'Elevar comite',
              'rechazar': 'Rechazar',
            },
            onChanged: onRecommendationChanged,
          ),
          TextField(
            controller: observationsController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Observaciones',
              prefixIcon: Icon(Icons.notes),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.label,
    required this.captured,
    required this.onPressed,
  });

  final String label;
  final bool captured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(captured ? Icons.check_circle : Icons.photo_camera),
      label: Text(captured ? '$label listo' : label),
    );
  }
}

class _OptionSelect extends StatelessWidget {
  const _OptionSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        items: options.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _boxDecoration(
        accent: value ? _AppColors.green : _AppColors.red,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: _boxDecoration(accent: color),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 4,
                  style: const TextStyle(color: Color(0xFF66727A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.metrics});

  final List<_MetricItem> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 760
            ? 4
            : (constraints.maxWidth > 520 ? 2 : 1);
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricCard(metric: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricItem metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(12),
      decoration: _boxDecoration(accent: metric.color),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, color: metric.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF66727A),
                    fontSize: 12,
                  ),
                ),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem(this.icon, this.label, this.value, this.color);

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 680 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _MetricCard(
                    metric: _MetricItem(
                      item.icon,
                      item.label,
                      item.value,
                      _AppColors.teal,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _InfoItem {
  const _InfoItem(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        _pretty(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.kpi});

  final Map<String, dynamic> kpi;

  @override
  Widget build(BuildContext context) {
    return _DataTile(
      icon: Icons.analytics,
      title: _text(kpi, 'agencia', fallback: 'Piloto'),
      subtitle:
          '${_number(kpi, 'desembolsos').toStringAsFixed(0)} desembolsos - Mora 30: ${_number(kpi, 'mora_30_pct').toStringAsFixed(1)}%',
      trailing: '${_number(kpi, 'tasa_conversion_pct').toStringAsFixed(1)}%',
      color: _AppColors.teal,
    );
  }
}

class _DataTile extends StatelessWidget {
  const _DataTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: _boxDecoration(accent: color),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? '-' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF66727A)),
                  ),
                ],
              ),
            ),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  trailing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PagePadding extends StatelessWidget {
  const _PagePadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: child,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 24,
            decoration: BoxDecoration(
              color: _AppColors.green,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: _AppColors.green),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingDashboard extends StatelessWidget {
  const _LoadingDashboard();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

BoxDecoration _boxDecoration({Color accent = _AppColors.green}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _AppColors.border),
    boxShadow: [
      BoxShadow(
        color: accent.withValues(alpha: 0.10),
        blurRadius: 12,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

Color _segmentColor(String segment) {
  return switch (segment.toUpperCase()) {
    'PREMIER' => _AppColors.green,
    'ESTANDAR' => _AppColors.blue,
    'BASICO' => _AppColors.orange,
    'DESCALIFICADO' => _AppColors.red,
    _ => _AppColors.teal,
  };
}

Color _managementColor(String type) {
  return switch (type.toUpperCase()) {
    'RENOVACION' => _AppColors.blue,
    'AMPLIACION' => _AppColors.green,
    'NUEVA_SOLICITUD' => _AppColors.orange,
    'SEGUIMIENTO' => Colors.blueGrey,
    'RECUPERACION_MORA' => _AppColors.red,
    'DESERTOR' => _AppColors.purple,
    _ => _AppColors.teal,
  };
}

Color _priorityColor(String priority) {
  return switch (priority.toLowerCase()) {
    'alta' => _AppColors.red,
    'media' => _AppColors.orange,
    _ => _AppColors.green,
  };
}

Color _riskColor(String rating) {
  return switch (rating.toLowerCase()) {
    'normal' => _AppColors.green,
    'cpp' => _AppColors.orange,
    'deficiente' => _AppColors.orange,
    'dudoso' => _AppColors.red,
    'perdida' || 'pérdida' => Colors.blueGrey,
    _ => _AppColors.teal,
  };
}

String _text(Map<String, dynamic> map, String key, {String fallback = ''}) {
  final value = map[key];
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

num _number(Map<String, dynamic> map, String key, {num fallback = 0}) {
  final value = map[key];
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? fallback;
  return fallback;
}

String _money(num value) {
  return 'S/ ${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
}

String _pretty(String value) {
  if (value.isEmpty) return '-';
  return value.replaceAll('_', ' ').toUpperCase();
}
