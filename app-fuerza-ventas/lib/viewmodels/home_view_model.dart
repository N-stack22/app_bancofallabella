import 'dart:async';

import 'package:bancofalabella_app2/services/scoring_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required this.demoMode, ScoringRepository? repository})
    : repository = repository ?? ScoringRepository() {
    dashboardFuture = this.repository.loadDashboard(forceDemo: demoMode);
    _watchConnectivity();
  }

  final bool demoMode;
  final ScoringRepository repository;
  late Future<SalesDashboardData> dashboardFuture;

  int selectedIndex = 0;
  int selectedClientIndex = 0;
  String segmentFilter = 'TODOS';
  String statusFilter = 'TODOS';
  String searchQuery = '';
  bool online = true;
  final Map<String, PreapprovedClient> _locationOverrides = {};

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _disposed = false;

  Future<void> refresh() async {
    dashboardFuture = repository.loadDashboard(forceDemo: demoMode);
    notifyListeners();
  }

  void updateClientLocation(PreapprovedClient client) {
    _locationOverrides[client.userId] = client;
    dashboardFuture = repository.loadDashboard(forceDemo: demoMode);
    notifyListeners();
  }

  Future<void> signOut() async {
    await repository.signOut();
  }

  void selectDestination(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  void openFieldFile(int index) {
    selectedClientIndex = index;
    selectedIndex = 2;
    notifyListeners();
  }

  void openRoute(int index) {
    selectedClientIndex = index;
    selectedIndex = 1;
    notifyListeners();
  }

  void selectClient(int index) {
    selectedClientIndex = index;
    notifyListeners();
  }

  void setSegmentFilter(String value) {
    segmentFilter = value;
    notifyListeners();
  }

  void setStatusFilter(String value) {
    statusFilter = value;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  SalesDashboardData withCurrentConnectivity(SalesDashboardData data) {
    final portfolio = data.portfolio
        .map((client) => _locationOverrides[client.userId] ?? client)
        .toList();

    return SalesDashboardData(
      advisor: data.advisor,
      portfolio: portfolio,
      agencies: data.agencies,
      advisors: data.advisors,
      kpis: data.kpis,
      history: data.history,
      requests: data.requests,
      bureau: data.bureau,
      alerts: data.alerts,
      collections: data.collections,
      pendingSync: data.pendingSync,
      lastSyncLabel: data.lastSyncLabel,
      role: data.role,
      online: online,
      isDemo: data.isDemo,
    );
  }

  List<PreapprovedClient> filteredClients(List<PreapprovedClient> clients) {
    return clients.where((client) {
      final bySegment =
          segmentFilter == 'TODOS' || client.segment == segmentFilter;
      final byStatus = switch (statusFilter) {
        'TODOS' => true,
        'visitado' => client.visitStatus == 'visitado',
        'pendiente' => client.visitStatus == 'pendiente',
        _ =>
          client.managementType == statusFilter ||
              client.status == statusFilter,
      };
      final query = searchQuery.trim().toLowerCase();
      final byQuery =
          query.isEmpty ||
          client.fullName.toLowerCase().contains(query) ||
          client.maskedDocument.toLowerCase().contains(query) ||
          _profileText(client, 'dni').endsWith(query);
      return bySegment && byStatus && byQuery;
    }).toList();
  }

  PreapprovedClient? selectedClient(List<PreapprovedClient> portfolio) {
    if (portfolio.isEmpty) return null;
    final safeIndex = selectedClientIndex
        .clamp(0, portfolio.length - 1)
        .toInt();
    return portfolio[safeIndex];
  }

  void _watchConnectivity() {
    Connectivity().checkConnectivity().then(_setConnectivity);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _setConnectivity,
    );
  }

  void _setConnectivity(List<ConnectivityResult> result) {
    if (_disposed) return;
    online = !result.contains(ConnectivityResult.none);
    notifyListeners();
  }

  String _profileText(PreapprovedClient client, String key) {
    final value = client.profile[key];
    return value == null ? '' : value.toString().trim().toLowerCase();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
