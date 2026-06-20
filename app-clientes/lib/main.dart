import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const BancoFalabellaApp());
}

class BancoFalabellaApp extends StatelessWidget {
  const BancoFalabellaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banco Falabella Clientes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          primary: AppColors.green,
          secondary: AppColors.lime,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.ink,
          indicatorColor: AppColors.lime,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? Colors.white : const Color(0xFFC5D0D6),
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              fontSize: 12,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? AppColors.ink : const Color(0xFFC5D0D6),
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.green, width: 1.5),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class AppColors {
  static const green = Color(0xFF123D37);
  static const deepGreen = Color(0xFF071F1B);
  static const lime = Color(0xFFB8D932);
  static const softGreen = Color(0xFFE9F1EC);
  static const border = Color(0xFFCAD6D8);
  static const ink = Color(0xFF101820);
  static const blue = Color(0xFF1D5FA7);
  static const orange = Color(0xFFB76A00);
  static const red = Color(0xFFC9362B);
  static const teal = Color(0xFF006D75);
  static const purple = Color(0xFF6545A4);
  static const background = Color(0xFFEFF3F4);
}

const demoDni = '72028183';
const demoEmail = 'nathalie.rodriguez@cliente.falabella.pe';
const demoPassword = '12345';
const secureStorage = FlutterSecureStorage();
const configuredCoreBaseUrl = String.fromEnvironment(
  'CORE_BASE_URL',
  defaultValue: '',
);
const webCoreBaseUrl = String.fromEnvironment(
  'WEB_CORE_BASE_URL',
  defaultValue: 'http://127.0.0.1:8003',
);
const androidCoreBaseUrl = String.fromEnvironment(
  'ANDROID_CORE_BASE_URL',
  defaultValue: 'http://10.0.2.2:8003',
);
String get primaryCoreBaseUrl {
  if (configuredCoreBaseUrl.isNotEmpty) return configuredCoreBaseUrl;
  if (kIsWeb) return webCoreBaseUrl;
  if (defaultTargetPlatform == TargetPlatform.android) {
    return androidCoreBaseUrl;
  }
  return webCoreBaseUrl;
}

String get fallbackCoreBaseUrl => primaryCoreBaseUrl;

final demoProfile = UserProfile(
  name: 'Nathalie Tatiana Rodriguez Rios',
  email: demoEmail,
  phone: '987 654 321',
  document: 'DNI $demoDni',
  address: 'Av. La Marina 1250, San Miguel',
  customerSince: 'Cliente desde 2024',
);

final demoProducts = BankProducts(
  savings: SavingsAccount(
    name: 'Cuenta Ahorro Digital',
    number: '0011-0345-789012',
    balance: 3450.70,
    availableBalance: 3388.20,
    monthlyDeposits: 1850.00,
    cci: '002-001103457890123456-55',
    statements: const [
      AccountStatement('Mayo 2026', 'S/ 3,450.70', 'Disponible'),
      AccountStatement('Abril 2026', 'S/ 2,980.10', 'Disponible'),
      AccountStatement('Marzo 2026', 'S/ 2,540.00', 'Disponible'),
    ],
  ),
  credit: CreditProduct(
    name: 'Prestamo Personal',
    number: 'PRE-2026-0158',
    principal: 5000,
    pending: 3200,
    nextPayment: 468.30,
    dueDate: '15 Jun 2026',
    tea: '38.5%',
    installments: const [
      Installment(1, '15 Abr 2026', 468.30, 'Pagado'),
      Installment(2, '15 May 2026', 468.30, 'Pagado'),
      Installment(3, '15 Jun 2026', 468.30, 'Pendiente'),
      Installment(4, '15 Jul 2026', 468.30, 'Pendiente'),
      Installment(5, '15 Ago 2026', 468.30, 'Pendiente'),
    ],
  ),
  movements: const [
    Movement('Deposito sueldo', 'Hoy, 09:18', 1250.00, true),
    Movement('Pago tarjeta Falabella', 'Ayer, 19:44', 180.90, false),
    Movement('Transferencia recibida', '24 May, 14:10', 320.00, true),
    Movement('Pago servicios luz', '23 May, 08:40', 96.20, false),
    Movement('Compra Tottus', '22 May, 20:15', 143.60, false),
  ],
);

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.document,
    required this.address,
    required this.customerSince,
  });

  final String name;
  final String email;
  final String phone;
  final String document;
  final String address;
  final String customerSince;

  factory UserProfile.fromCoreSummary(Map<String, dynamic> json) {
    final cliente = _asMap(json['cliente']);
    final dni = _text(cliente['numero_documento'], demoDni);
    final coreName = [
      _text(cliente['nombres'], 'Cliente'),
      _text(cliente['apellidos'], 'Banco Falabella'),
    ].where((part) => part.trim().isNotEmpty).join(' ');
    final fullName = dni == demoDni ? demoProfile.name : coreName;
    return UserProfile(
      name: fullName,
      email: dni == demoDni
          ? demoProfile.email
          : _text(cliente['email'], '$dni@cliente.falabella.pe'),
      phone: _text(cliente['telefono'], '999 000 000'),
      document: 'DNI $dni',
      address: _text(cliente['direccion'], 'Direccion registrada en Core'),
      customerSince: 'Cliente Core desde 2026',
    );
  }
}

class BankProducts {
  const BankProducts({
    required this.savings,
    required this.credit,
    required this.movements,
  });

  final SavingsAccount savings;
  final CreditProduct credit;
  final List<Movement> movements;

  factory BankProducts.fromCoreSummary(Map<String, dynamic> json) {
    final cuentas = _asListOfMaps(json['cuentas']);
    final creditos = _asListOfMaps(json['creditos']);
    final movimientos = _asListOfMaps(json['movimientos']);
    final solicitudes = _asListOfMaps(json['solicitudes']);
    final cronogramas = _asMap(json['cronogramas']);

    final cuenta = cuentas.isEmpty ? <String, dynamic>{} : cuentas.first;
    final credito = creditos.isEmpty ? <String, dynamic>{} : creditos.first;
    final codCredito = _text(credito['cod_cuenta_credito'], '');
    final cuotas = _asListOfMaps(cronogramas[codCredito]);
    final nextInstallment = cuotas.firstWhere(
      (item) => _text(item['estado_cuota'], '').toLowerCase() != 'pagado',
      orElse: () => cuotas.isEmpty ? <String, dynamic>{} : cuotas.first,
    );

    final disbursedFromRequests = solicitudes
        .where(
          (item) => _text(item['estado'], '').toLowerCase() == 'desembolsado',
        )
        .fold<double>(
          0,
          (sum, item) =>
              sum +
              (_jsonDouble(item['monto_aprobado']) == 0
                  ? _jsonDouble(item['monto_solicitado'])
                  : _jsonDouble(item['monto_aprobado'])),
        );
    final disbursedInMovements = movimientos
        .where((item) {
          final type = _movementType(item);
          final concept = _text(item['concepto'], '').toLowerCase();
          return type == 'CRE' && concept.contains('desembolso');
        })
        .fold<double>(0, (sum, item) => sum + _jsonDouble(item['monto']));
    final missingDisbursement = max(
      0,
      disbursedFromRequests - disbursedInMovements,
    ).toDouble();
    final visibleDisbursement = max(
      disbursedFromRequests,
      disbursedInMovements,
    ).toDouble();
    final coreBalance =
        _jsonDouble(cuenta['saldo_capital']) +
        _jsonDouble(cuenta['saldo_interes']);
    final visibleBalance = coreBalance + visibleDisbursement;

    final monthlyDeposits = movimientos
        .where((item) => _movementType(item) == 'CRE')
        .fold<double>(0, (sum, item) => sum + _jsonDouble(item['monto']));
    final visibleDeposits = monthlyDeposits + missingDisbursement;
    final visibleMovements = [
      if (missingDisbursement > 0)
        Movement(
          'Desembolso credito empresarial',
          'Comite',
          missingDisbursement,
          true,
        ),
      ...movimientos.map(
        (item) => Movement(
          _text(item['concepto'], 'Movimiento Core'),
          _formatCoreDate(_text(item['fecha_operacion'], '')),
          _jsonDouble(item['monto']),
          _movementType(item) == 'CRE',
        ),
      ),
    ];

    return BankProducts(
      savings: SavingsAccount(
        name: _text(cuenta['tipo_cuenta'], 'Cuenta Ahorro Digital'),
        number: _text(cuenta['cod_cuenta_ahorro'], demoProducts.savings.number),
        balance: visibleBalance,
        availableBalance: visibleBalance,
        monthlyDeposits: visibleDeposits == 0
            ? demoProducts.savings.monthlyDeposits
            : visibleDeposits,
        cci: _text(
          cuenta['cci'],
          '002-${_text(cuenta['cod_cuenta_ahorro'], '000000000000000000')}',
        ),
        statements: [
          AccountStatement(
            'Junio 2026',
            money(_jsonDouble(cuenta['saldo_capital'])),
            'Core',
          ),
          const AccountStatement('Mayo 2026', 'Generado en BD', 'Disponible'),
          const AccountStatement('Abril 2026', 'Generado en BD', 'Disponible'),
        ],
      ),
      credit: CreditProduct(
        name: _text(credito['producto'], demoProducts.credit.name),
        number: _text(
          credito['cod_cuenta_credito'],
          demoProducts.credit.number,
        ),
        principal: _jsonDouble(credito['monto_desembolsado']) == 0
            ? demoProducts.credit.principal
            : _jsonDouble(credito['monto_desembolsado']),
        pending: _jsonDouble(credito['saldo_capital']) == 0
            ? demoProducts.credit.pending
            : _jsonDouble(credito['saldo_capital']),
        nextPayment: _jsonDouble(nextInstallment['monto_cuota']) == 0
            ? demoProducts.credit.nextPayment
            : _jsonDouble(nextInstallment['monto_cuota']),
        dueDate: _formatCoreDate(
          _text(
            nextInstallment['fecha_vencimiento'],
            demoProducts.credit.dueDate,
          ),
        ),
        tea: '${_jsonDouble(credito['tea']).toStringAsFixed(2)}%',
        installments: cuotas.isEmpty
            ? demoProducts.credit.installments
            : cuotas
                  .map(
                    (item) => Installment(
                      _jsonInt(item['nro_cuota']),
                      _formatCoreDate(_text(item['fecha_vencimiento'], '')),
                      _jsonDouble(item['monto_cuota']),
                      _titleCase(_text(item['estado_cuota'], 'Pendiente')),
                    ),
                  )
                  .toList(),
      ),
      movements: visibleMovements.isEmpty
          ? demoProducts.movements
          : visibleMovements,
    );
  }
}

class SavingsAccount {
  const SavingsAccount({
    required this.name,
    required this.number,
    required this.balance,
    required this.availableBalance,
    required this.monthlyDeposits,
    required this.cci,
    required this.statements,
  });

  final String name;
  final String number;
  final double balance;
  final double availableBalance;
  final double monthlyDeposits;
  final String cci;
  final List<AccountStatement> statements;
}

class AccountStatement {
  const AccountStatement(this.month, this.balance, this.status);

  final String month;
  final String balance;
  final String status;
}

class CreditProduct {
  const CreditProduct({
    required this.name,
    required this.number,
    required this.principal,
    required this.pending,
    required this.nextPayment,
    required this.dueDate,
    required this.tea,
    required this.installments,
  });

  final String name;
  final String number;
  final double principal;
  final double pending;
  final double nextPayment;
  final String dueDate;
  final String tea;
  final List<Installment> installments;
}

class Installment {
  const Installment(this.number, this.date, this.amount, this.status);

  final int number;
  final String date;
  final double amount;
  final String status;
}

class Movement {
  const Movement(this.title, this.date, this.amount, this.isIncome);

  final String title;
  final String date;
  final double amount;
  final bool isIncome;
}

class CreditApplicationData {
  const CreditApplicationData({
    required this.document,
    required this.names,
    required this.lastNames,
    required this.phone,
    required this.businessType,
    required this.businessName,
    required this.monthlyIncome,
    required this.amount,
    required this.termMonths,
    required this.tea,
    required this.guarantee,
    required this.purpose,
  });

  final String document;
  final String names;
  final String lastNames;
  final String phone;
  final String businessType;
  final String businessName;
  final double monthlyIncome;
  final double amount;
  final int termMonths;
  final double tea;
  final String guarantee;
  final String purpose;

  factory CreditApplicationData.fromCase(Map<String, dynamic> json) {
    return CreditApplicationData(
      document: (json['numero_documento'] ?? '').toString(),
      names: (json['nombres'] ?? '').toString(),
      lastNames: (json['apellidos'] ?? '').toString(),
      phone: (json['telefono'] ?? '').toString(),
      businessType: (json['tipo_negocio'] ?? '').toString(),
      businessName: (json['nombre_negocio'] ?? '').toString(),
      monthlyIncome: _jsonDouble(json['ingresos_estimados']),
      amount: _jsonDouble(json['monto_solicitado']),
      termMonths: _jsonInt(json['plazo_meses']),
      tea: _jsonDouble(json['tea_referencial']),
      guarantee: (json['garantia'] ?? 'sin_garantia').toString(),
      purpose: (json['destino_credito'] ?? '').toString(),
    );
  }

  double get monthlyPayment {
    final tem = pow(1 + tea, 1 / 12) - 1;
    return amount *
        tem *
        pow(1 + tem, termMonths) /
        (pow(1 + tem, termMonths) - 1);
  }

  Map<String, dynamic> toJson() => {
    'numero_documento': document,
    'nombres': names,
    'apellidos': lastNames,
    'telefono': phone,
    'tipo_negocio': businessType,
    'nombre_negocio': businessName,
    'ingresos_estimados': monthlyIncome,
    'monto_solicitado': amount,
    'plazo_meses': termMonths,
    'moneda': 'PEN',
    'tipo_cuota': 'mensual',
    'garantia': guarantee,
    'destino_credito': purpose,
    'cuota_estimada': double.parse(monthlyPayment.toStringAsFixed(2)),
    'tea_referencial': tea,
  };
}

class CreditApplicationResult {
  const CreditApplicationResult({
    required this.id,
    required this.fileNumber,
    required this.status,
  });

  factory CreditApplicationResult.fromJson(Map<String, dynamic> json) {
    return CreditApplicationResult(
      id: (json['id'] ?? '').toString(),
      fileNumber: (json['numero_expediente'] ?? '').toString(),
      status: (json['estado'] ?? 'enviado').toString(),
    );
  }

  final String id;
  final String fileNumber;
  final String status;
}

class CoreApiClient {
  const CoreApiClient();

  Future<CreditApplicationResult> submitApplication(
    CreditApplicationData data,
  ) async {
    final body = jsonEncode(data.toJson());
    try {
      return await _postApplication(primaryCoreBaseUrl, body);
    } catch (_) {
      return await _postApplication(fallbackCoreBaseUrl, body);
    }
  }

  Future<List<Map<String, dynamic>>> loadCases() async {
    try {
      return await _getCases(primaryCoreBaseUrl);
    } catch (_) {
      return await _getCases(fallbackCoreBaseUrl);
    }
  }

  Future<String> loginCliente(String document, String password) async {
    final body = jsonEncode({
      'numero_documento': document,
      'password': password,
    });
    try {
      return await _postLogin(primaryCoreBaseUrl, body);
    } catch (_) {
      return await _postLogin(fallbackCoreBaseUrl, body);
    }
  }

  Future<Map<String, dynamic>> loadCustomerSummary(String document) async {
    try {
      return await _getSummary(primaryCoreBaseUrl, document);
    } catch (_) {
      return await _getSummary(fallbackCoreBaseUrl, document);
    }
  }

  Future<void> createOperation({
    required String token,
    required String originAccount,
    required String destination,
    required String operation,
    required double amount,
  }) async {
    final type = operation == 'Pago' ? 'pago_cuota' : 'transferencia';
    final body = jsonEncode({
      'cod_cuenta_origen': originAccount,
      'cod_cuenta_destino': destination,
      'tipo': type,
      'monto': amount,
      'moneda': 'PEN',
      'descripcion': '$operation registrado desde App Clientes',
    });
    try {
      await _postOperation(primaryCoreBaseUrl, token, body);
    } catch (_) {
      await _postOperation(fallbackCoreBaseUrl, token, body);
    }
  }

  Future<List<Map<String, dynamic>>> _getCases(String baseUrl) async {
    final response = await _getJson('$baseUrl/casos');
    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<CreditApplicationResult> _postApplication(
    String baseUrl,
    String body,
  ) async {
    final response = await _postJson('$baseUrl/cliente/solicitudes', body);
    return CreditApplicationResult.fromJson(response);
  }

  Future<String> _postLogin(String baseUrl, String body) async {
    final response = await _postJson('$baseUrl/cliente/login', body);
    return _text(response['access_token'] ?? response['token'], '');
  }

  Future<Map<String, dynamic>> _getSummary(
    String baseUrl,
    String document,
  ) async {
    final response = await _getJson('$baseUrl/cliente/demo/$document/resumen');
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> _postOperation(String baseUrl, String token, String body) async {
    await _postJson('$baseUrl/cliente/operaciones', body, token: token);
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    String body, {
    String? token,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http
        .post(Uri.parse(url), headers: headers, body: body)
        .timeout(const Duration(seconds: 8));
    _ensureOk(response.statusCode, response.body);
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<dynamic> _getJson(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 8));
    _ensureOk(response.statusCode, response.body);
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    return jsonDecode(response.body);
  }

  void _ensureOk(int statusCode, String body) {
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception('Core $statusCode: $body');
    }
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController(text: demoDni);
  final passwordController = TextEditingController(text: demoPassword);
  final formKey = GlobalKey<FormState>();

  bool loading = false;
  bool hidePassword = true;
  bool documentEdited = false;

  @override
  void initState() {
    super.initState();
    restoreSecureSession();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final document = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      final api = const CoreApiClient();
      final token = await api.loginCliente(document, password);
      if (token.isEmpty) {
        throw Exception('Core no devolvio token JWT');
      }
      await secureStorage.write(key: 'cliente_token', value: token);
      await secureStorage.write(key: 'cliente_documento', value: document);
      final summary = await api.loadCustomerSummary(document);
      if (!mounted) return;
      _openSession(token: token, document: document, summary: summary);
    } catch (error) {
      if (!mounted) return;
      showMessage('No se pudo ingresar al Core: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> restoreSecureSession() async {
    final token = await secureStorage.read(key: 'cliente_token');
    final document = await secureStorage.read(key: 'cliente_documento');
    if (token == null ||
        token.isEmpty ||
        document == null ||
        document.isEmpty) {
      return;
    }
    try {
      final summary = await const CoreApiClient().loadCustomerSummary(document);
      if (!mounted) return;
      _openSession(token: token, document: document, summary: summary);
    } catch (_) {
      await secureStorage.deleteAll();
    }
  }

  void _openSession({
    required String token,
    required String document,
    required Map<String, dynamic> summary,
  }) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ClientShell(
          profile: UserProfile.fromCoreSummary(summary),
          products: BankProducts.fromCoreSummary(summary),
          token: token,
          document: document,
        ),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void openRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FBF4), Color(0xFFE6F3EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 0,
                  shadowColor: const Color(0x22004F2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FalabellaLogo(),
                          const SizedBox(height: 8),
                          const Text(
                            'Banca móvil · Clientes',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 28),
                          AppTextField(
                            controller: emailController,
                            label: 'Codigo del cliente',
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            onTap: () {
                              if (!documentEdited &&
                                  emailController.text == demoDni) {
                                emailController.clear();
                                documentEdited = true;
                              }
                            },
                            validator: (value) {
                              final dni = value?.trim() ?? '';
                              if (dni.isEmpty) return 'Ingrese su DNI';
                              if (dni.length != 8 ||
                                  int.tryParse(dni) == null) {
                                return 'Ingrese un DNI valido de 8 digitos';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: passwordController,
                            label: 'Contrasena',
                            icon: Icons.lock_outline,
                            obscureText: hidePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => signIn(),
                            suffix: IconButton(
                              tooltip: hidePassword
                                  ? 'Mostrar contrasena'
                                  : 'Ocultar contrasena',
                              onPressed: () {
                                setState(() => hidePassword = !hidePassword);
                              },
                              icon: Icon(
                                hidePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.isEmpty) {
                                return 'Ingrese su contrasena';
                              }
                              if (password.length < 5) {
                                return 'La contrasena debe tener minimo 5 caracteres';
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => showMessage(
                                'Recuperacion disponible en la proxima entrega.',
                              ),
                              child: const Text('Olvide mi clave'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: loading ? null : signIn,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: loading
                                    ? const LoadingButtonContent()
                                    : const Text(
                                        key: ValueKey('loginText'),
                                        'Ingresar',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: openRegister,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Registrarme'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final dniController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  @override
  void dispose() {
    dniController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void register() {
    if (!formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro demo validado correctamente.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de cliente')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const FalabellaLogo(compact: true),
          const SizedBox(height: 18),
          AppCard(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  AppTextField(
                    controller: dniController,
                    label: 'DNI',
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if ((value ?? '').trim().length != 8) {
                        return 'Ingrese un DNI de 8 digitos';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: emailController,
                    label: 'Correo',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (!((value ?? '').contains('@'))) {
                        return 'Ingrese un correo valido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: phoneController,
                    label: 'Celular',
                    icon: Icons.phone_android,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if ((value ?? '').trim().length < 9) {
                        return 'Ingrese un celular valido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: register,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Crear acceso demo'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClientShell extends StatefulWidget {
  const ClientShell({
    super.key,
    required this.profile,
    required this.products,
    required this.token,
    required this.document,
  });

  final UserProfile profile;
  final BankProducts products;
  final String token;
  final String document;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int selectedIndex = 0;
  late UserProfile profile;
  late BankProducts products;
  bool refreshingProducts = false;

  @override
  void initState() {
    super.initState();
    profile = widget.profile;
    products = widget.products;
  }

  Future<void> refreshCustomerSummary() async {
    setState(() => refreshingProducts = true);
    try {
      final summary = await const CoreApiClient().loadCustomerSummary(
        widget.document,
      );
      if (!mounted) return;
      setState(() {
        profile = UserProfile.fromCoreSummary(summary);
        products = BankProducts.fromCoreSummary(summary);
      });
    } finally {
      if (mounted) setState(() => refreshingProducts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(profile: profile, products: products),
      SavingsPage(products: products),
      CreditsPage(profile: profile, products: products),
      PaymentsPage(
        token: widget.token,
        accountNumber: products.savings.number,
        onOperationCompleted: refreshCustomerSummary,
      ),
      ProfilePage(profile: profile),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Banca Clientes'),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.ink, AppColors.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: refreshingProducts ? null : refreshCustomerSummary,
            icon: refreshingProducts
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: () async {
              await secureStorage.deleteAll();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: pages[selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        height: 72,
        backgroundColor: AppColors.ink,
        indicatorColor: AppColors.lime,
        surfaceTintColor: AppColors.ink,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Ahorros',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Creditos',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz),
            selectedIcon: Icon(Icons.swap_horizontal_circle),
            label: 'Pagos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.profile,
    required this.products,
  });

  final UserProfile profile;
  final BankProducts products;

  @override
  Widget build(BuildContext context) {
    final savings = products.savings;
    final credit = products.credit;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WelcomePanel(profile: profile),
          const SizedBox(height: 10),
          const CoreStatusCard(),
          const SizedBox(height: 16),
          BalanceHero(account: savings),
          const SizedBox(height: 16),
          SectionTitle('Accesos rapidos'),
          const QuickActionsGrid(),
          const SizedBox(height: 18),
          SectionTitle('Resumen de productos'),
          MetricStrip(
            metrics: [
              MetricItem(
                Icons.account_balance_wallet,
                'Disponible',
                money(savings.availableBalance),
                AppColors.green,
              ),
              MetricItem(
                Icons.credit_score,
                'Deuda prestamo',
                money(credit.pending),
                AppColors.blue,
              ),
              MetricItem(
                Icons.event_available,
                'Proxima cuota',
                credit.dueDate,
                AppColors.orange,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SectionTitle('Ultimos movimientos'),
          ...products.movements
              .take(4)
              .map((movement) => MovementTile(movement: movement)),
        ],
      ),
    );
  }
}

class SavingsPage extends StatelessWidget {
  const SavingsPage({super.key, required this.products});

  final BankProducts products;

  @override
  Widget build(BuildContext context) {
    final account = products.savings;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            icon: Icons.savings,
            title: 'Ahorros',
            subtitle: 'Saldo, depositos y estados de cuenta',
            color: AppColors.green,
          ),
          SectionIntro(
            icon: Icons.savings,
            title: 'Modulo de ahorros',
            description:
                'Consulta saldo, depositos, CCI y estados de cuenta de tu cuenta principal.',
            color: AppColors.green,
          ),
          const SizedBox(height: 6),
          BalanceHero(account: account),
          const SizedBox(height: 16),
          MetricStrip(
            metrics: [
              MetricItem(
                Icons.account_balance,
                'Saldo contable',
                money(account.balance),
                AppColors.green,
              ),
              MetricItem(
                Icons.download,
                'Depositos del mes',
                money(account.monthlyDeposits),
                AppColors.blue,
              ),
              MetricItem(Icons.numbers, 'CCI', 'Copiar', AppColors.teal),
            ],
          ),
          const SizedBox(height: 18),
          AppCard(
            accent: AppColors.teal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos de cuenta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                InfoRow('Numero', account.number),
                InfoRow('CCI', account.cci),
                InfoRow('Tipo', account.name),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionTitle('Estados de cuenta'),
          ...account.statements.map(
            (statement) => StatementTile(statement: statement),
          ),
        ],
      ),
    );
  }
}

class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key, required this.profile, required this.products});

  final UserProfile profile;
  final BankProducts products;

  @override
  Widget build(BuildContext context) {
    final credit = products.credit;
    final progress = 1 - (credit.pending / credit.principal);

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            icon: Icons.payments,
            title: 'Creditos',
            subtitle: 'Prestamos activos y cronograma de pagos',
            color: AppColors.blue,
          ),
          SectionIntro(
            icon: Icons.payments,
            title: 'Modulo de creditos',
            description:
                'Consulta prestamos activos, deuda pendiente y cronograma de pagos.',
            color: AppColors.blue,
          ),
          const SizedBox(height: 6),
          AppCard(
            accent: AppColors.blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFEAF2FF),
                      foregroundColor: AppColors.blue,
                      child: Icon(Icons.credit_score),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            credit.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            credit.number,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  money(credit.pending),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.green,
                  ),
                ),
                const Text('Saldo pendiente'),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(99),
                  color: AppColors.green,
                  backgroundColor: const Color(0xFFE3EBE6),
                ),
                const SizedBox(height: 12),
                InfoRow('Proxima cuota', money(credit.nextPayment)),
                InfoRow('Fecha de pago', credit.dueDate),
                InfoRow('TEA referencial', credit.tea),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreditApplicationPage(profile: profile),
                ),
              );
            },
            icon: const Icon(Icons.add_business),
            label: const Text('Solicitar credito empresarial'),
          ),
          const SizedBox(height: 18),
          SectionTitle('Cronograma de pagos'),
          ...credit.installments.map(
            (installment) => InstallmentTile(installment: installment),
          ),
        ],
      ),
    );
  }
}

class CreditApplicationPage extends StatefulWidget {
  const CreditApplicationPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<CreditApplicationPage> createState() => _CreditApplicationPageState();
}

class _CreditApplicationPageState extends State<CreditApplicationPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController documentController;
  late final TextEditingController namesController;
  late final TextEditingController lastNamesController;
  late final TextEditingController phoneController;
  late final TextEditingController businessController;
  late final TextEditingController incomeController;
  late final TextEditingController amountController;
  late final TextEditingController purposeController;

  String businessType = 'Bodega';
  String guarantee = 'sin_garantia';
  int termMonths = 12;
  double tea = 0.4392;
  bool sending = false;
  CreditApplicationResult? result;

  @override
  void initState() {
    super.initState();
    final fullName = widget.profile.name.trim().split(RegExp(r'\s+'));
    final names = fullName.take(max(1, (fullName.length / 2).ceil())).join(' ');
    final lastNames = fullName
        .skip(max(1, (fullName.length / 2).ceil()))
        .join(' ');
    documentController = TextEditingController(
      text: widget.profile.document.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    namesController = TextEditingController(text: names);
    lastNamesController = TextEditingController(
      text: lastNames.isEmpty ? 'Cliente Banco Falabella' : lastNames,
    );
    phoneController = TextEditingController(text: widget.profile.phone);
    businessController = TextEditingController();
    incomeController = TextEditingController();
    amountController = TextEditingController();
    purposeController = TextEditingController();
  }

  @override
  void dispose() {
    documentController.dispose();
    namesController.dispose();
    lastNamesController.dispose();
    phoneController.dispose();
    businessController.dispose();
    incomeController.dispose();
    amountController.dispose();
    purposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _buildData();

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud de credito')),
      body: AppPage(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                icon: Icons.request_page,
                title: 'Credito Empresarial',
                subtitle: 'Microempresa - flujo cliente hacia Core',
                color: AppColors.blue,
              ),
              SectionIntro(
                icon: Icons.person_pin_circle_outlined,
                title: 'Datos del cliente',
                description:
                    'Completa la solicitud con tus datos reales. La solicitud sera enviada al Core para evaluacion.',
                color: AppColors.blue,
              ),
              AppCard(
                accent: AppColors.blue,
                child: Column(
                  children: [
                    AppTextField(
                      controller: documentController,
                      label: 'Documento',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: namesController,
                      label: 'Nombres',
                      icon: Icons.person_outline,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: lastNamesController,
                      label: 'Apellidos',
                      icon: Icons.person,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: phoneController,
                      label: 'Telefono',
                      icon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                      validator: _required,
                    ),
                  ],
                ),
              ),
              AppCard(
                accent: AppColors.teal,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: businessType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de negocio',
                        prefixIcon: Icon(Icons.storefront),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Bodega',
                          child: Text('Bodega'),
                        ),
                        DropdownMenuItem(
                          value: 'Abarrotes',
                          child: Text('Abarrotes'),
                        ),
                        DropdownMenuItem(
                          value: 'Agropecuario',
                          child: Text('Agropecuario'),
                        ),
                        DropdownMenuItem(
                          value: 'Avicola',
                          child: Text('Avicola'),
                        ),
                        DropdownMenuItem(
                          value: 'Calzado',
                          child: Text('Calzado'),
                        ),
                        DropdownMenuItem(
                          value: 'Carpinteria',
                          child: Text('Carpinteria'),
                        ),
                        DropdownMenuItem(
                          value: 'Comercio',
                          child: Text('Comercio'),
                        ),
                        DropdownMenuItem(
                          value: 'Farmacia',
                          child: Text('Farmacia'),
                        ),
                        DropdownMenuItem(
                          value: 'Restaurante',
                          child: Text('Restaurante'),
                        ),
                        DropdownMenuItem(
                          value: 'Ferreteria',
                          child: Text('Ferreteria'),
                        ),
                        DropdownMenuItem(
                          value: 'Mecanica',
                          child: Text('Mecanica'),
                        ),
                        DropdownMenuItem(
                          value: 'Panaderia',
                          child: Text('Panaderia'),
                        ),
                        DropdownMenuItem(
                          value: 'Peluqueria',
                          child: Text('Peluqueria'),
                        ),
                        DropdownMenuItem(
                          value: 'Textil',
                          child: Text('Textil'),
                        ),
                        DropdownMenuItem(
                          value: 'Transporte',
                          child: Text('Transporte'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => businessType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: businessController,
                      label: 'Nombre del negocio',
                      icon: Icons.business,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: incomeController,
                      label: 'Ingreso mensual estimado',
                      icon: Icons.account_balance_wallet,
                      keyboardType: TextInputType.number,
                      validator: _positiveNumber,
                    ),
                  ],
                ),
              ),
              AppCard(
                accent: AppColors.orange,
                child: Column(
                  children: [
                    AppTextField(
                      controller: amountController,
                      label: 'Monto solicitado',
                      icon: Icons.payments,
                      keyboardType: TextInputType.number,
                      validator: _positiveNumber,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: termMonths,
                      decoration: const InputDecoration(
                        labelText: 'Plazo',
                        prefixIcon: Icon(Icons.calendar_month),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 6, child: Text('6 meses')),
                        DropdownMenuItem(value: 12, child: Text('12 meses')),
                        DropdownMenuItem(value: 18, child: Text('18 meses')),
                        DropdownMenuItem(value: 24, child: Text('24 meses')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => termMonths = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<double>(
                      initialValue: tea,
                      decoration: const InputDecoration(
                        labelText: 'TEA',
                        prefixIcon: Icon(Icons.percent),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 0.4092,
                          child: Text('40.92% con seguro'),
                        ),
                        DropdownMenuItem(
                          value: 0.4392,
                          child: Text('43.92% sin seguro'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => tea = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: guarantee,
                      decoration: const InputDecoration(
                        labelText: 'Garantia',
                        prefixIcon: Icon(Icons.verified_user),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'sin_garantia',
                          child: Text('Sin garantia'),
                        ),
                        DropdownMenuItem(
                          value: 'hipotecaria',
                          child: Text('Hipotecaria'),
                        ),
                        DropdownMenuItem(
                          value: 'vehicular',
                          child: Text('Vehicular'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => guarantee = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: purposeController,
                      label: 'Destino del credito',
                      icon: Icons.description_outlined,
                      validator: _required,
                    ),
                  ],
                ),
              ),
              MetricStrip(
                metrics: [
                  MetricItem(
                    Icons.receipt_long,
                    'Cuota referencial',
                    money(data.monthlyPayment),
                    AppColors.purple,
                  ),
                  MetricItem(
                    Icons.timeline,
                    'Estado inicial',
                    'ENVIADO',
                    AppColors.green,
                  ),
                  MetricItem(
                    Icons.cloud_upload,
                    'Core',
                    primaryCoreBaseUrl,
                    AppColors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: sending ? null : submit,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Enviar solicitud al Core'),
              ),
              if (result != null) ...[
                const SizedBox(height: 18),
                AppCard(
                  accent: AppColors.green,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expediente generado',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InfoRow('Numero', result!.fileNumber),
                      InfoRow('Estado', result!.status.toUpperCase()),
                      const Text(
                        'Ya debe aparecer en la cartera diaria de Fuerza de Ventas.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  CreditApplicationData _buildData() {
    return CreditApplicationData(
      document: documentController.text.trim(),
      names: namesController.text.trim(),
      lastNames: lastNamesController.text.trim(),
      phone: phoneController.text.trim(),
      businessType: businessType,
      businessName: businessController.text.trim(),
      monthlyIncome: double.tryParse(incomeController.text.trim()) ?? 0,
      amount: double.tryParse(amountController.text.trim()) ?? 0,
      termMonths: termMonths,
      tea: tea,
      guarantee: guarantee,
      purpose: purposeController.text.trim(),
    );
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => sending = true);
    try {
      final submitted = await const CoreApiClient().submitApplication(
        _buildData(),
      );
      if (!mounted) return;
      setState(() => result = submitted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Expediente ${submitted.fileNumber} enviado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo conectar al Core: $error'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Campo obligatorio';
    return null;
  }

  String? _positiveNumber(String? value) {
    final number = double.tryParse((value ?? '').trim());
    if (number == null || number <= 0) return 'Ingrese un monto valido';
    return null;
  }
}

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({
    super.key,
    required this.token,
    required this.accountNumber,
    this.onOperationCompleted,
  });

  final String token;
  final String accountNumber;
  final Future<void> Function()? onOperationCompleted;

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final amountController = TextEditingController();
  final accountController = TextEditingController();
  String operation = 'Transferencia';
  bool sending = false;

  @override
  void dispose() {
    amountController.dispose();
    accountController.dispose();
    super.dispose();
  }

  Future<void> confirmOperation() async {
    final amount = double.tryParse(amountController.text.trim());
    if (accountController.text.trim().isEmpty ||
        amount == null ||
        amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese destino y monto validos.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => sending = true);
    try {
      await const CoreApiClient().createOperation(
        token: widget.token,
        originAccount: widget.accountNumber,
        destination: accountController.text.trim(),
        operation: operation,
        amount: amount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$operation registrada en Core por ${money(amount)}.'),
        ),
      );
      amountController.clear();
      accountController.clear();
      try {
        await widget.onOperationCompleted?.call();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Operacion registrada. Actualiza para ver el nuevo saldo.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar en Core: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            icon: Icons.swap_horiz,
            title: 'Pagos y transferencias',
            subtitle: 'Operaciones demo desde tu cuenta principal',
            color: AppColors.orange,
          ),
          SectionIntro(
            icon: Icons.swap_horiz,
            title: 'Transferencias y pagos',
            description:
                'Realiza operaciones demo desde tu cuenta de ahorro principal.',
            color: AppColors.orange,
          ),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Transferencia',
                icon: Icon(Icons.swap_horiz),
                label: Text('Transferir'),
              ),
              ButtonSegment(
                value: 'Pago',
                icon: Icon(Icons.receipt_long),
                label: Text('Pagar'),
              ),
            ],
            selected: {operation},
            onSelectionChanged: (value) {
              setState(() => operation = value.first);
            },
          ),
          const SizedBox(height: 16),
          AppCard(
            accent: AppColors.orange,
            child: Column(
              children: [
                AppTextField(
                  controller: accountController,
                  label: operation == 'Transferencia'
                      ? 'Cuenta destino'
                      : 'Servicio o recibo',
                  icon: operation == 'Transferencia'
                      ? Icons.account_balance
                      : Icons.receipt,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: amountController,
                  label: 'Monto',
                  icon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: sending ? null : confirmOperation,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    sending ? 'Registrando en Core...' : 'Confirmar $operation',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionTitle('Pagos frecuentes'),
          const FrequentPaymentTile(
            icon: Icons.lightbulb_outline,
            title: 'Luz del Sur',
            subtitle: 'Ultimo pago S/ 96.20',
          ),
          const FrequentPaymentTile(
            icon: Icons.water_drop_outlined,
            title: 'Sedapal',
            subtitle: 'Ultimo pago S/ 42.80',
          ),
          const FrequentPaymentTile(
            icon: Icons.phone_android,
            title: 'Recarga celular',
            subtitle: 'Claro - Movistar - Entel',
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            icon: Icons.person,
            title: 'Perfil',
            subtitle: 'Datos de usuario, contacto y seguridad',
            color: AppColors.purple,
          ),
          SectionIntro(
            icon: Icons.person,
            title: 'Perfil de usuario',
            description:
                'Datos personales, canales de contacto y seguridad de la cuenta.',
            color: AppColors.purple,
          ),
          const SizedBox(height: 6),
          AppCard(
            accent: AppColors.purple,
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFEDE9FE),
                  foregroundColor: AppColors.purple,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  profile.customerSince,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                InfoRow('Correo', profile.email),
                InfoRow('Celular', profile.phone),
                InfoRow('Documento', profile.document),
                InfoRow('Direccion', profile.address),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionTitle('Seguridad'),
          const SecurityOption(
            icon: Icons.lock_outline,
            title: 'Cambiar clave',
            subtitle: 'Actualiza tu contrasena de banca movil',
          ),
          const SecurityOption(
            icon: Icons.fingerprint,
            title: 'Biometria',
            subtitle: 'Ingreso rapido con huella o rostro',
          ),
          const SecurityOption(
            icon: Icons.verified_user_outlined,
            title: 'Token digital',
            subtitle: 'Protege tus transferencias y pagos',
          ),
        ],
      ),
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: child,
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFFD8E0E3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FalabellaLogo extends StatelessWidget {
  const FalabellaLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 82 : 108,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: compact ? 70 : 92,
            height: compact ? 58 : 78,
            child: const CustomPaint(painter: FalabellaMarkPainter()),
          ),
          const SizedBox(width: 12),
          Text(
            'Banco\nFalabella',
            style: TextStyle(
              height: 0.95,
              fontSize: compact ? 24 : 30,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class FalabellaMarkPainter extends CustomPainter {
  const FalabellaMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final greenPaint = Paint()..color = AppColors.green;
    final limePaint = Paint()..color = AppColors.lime;
    final shadowPaint = Paint()..color = const Color(0x66004A25);

    canvas
      ..save()
      ..translate(size.width * 0.42, size.height * 0.64)
      ..rotate(-0.06)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 0.98,
          height: size.height * 0.56,
        ),
        greenPaint,
      )
      ..restore()
      ..save()
      ..translate(size.width * 0.48, size.height * 0.28)
      ..rotate(0.35)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 0.74,
          height: size.height * 0.42,
        ),
        limePaint,
      )
      ..restore()
      ..save()
      ..translate(size.width * 0.58, size.height * 0.47)
      ..rotate(0.25)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 0.38,
          height: size.height * 0.24,
        ),
        shadowPaint,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoadingButtonContent extends StatelessWidget {
  const LoadingButtonContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: ValueKey('loadingText'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.4,
          ),
        ),
        SizedBox(width: 12),
        Text(
          'Cargando...',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
    this.suffix,
    this.onFieldSubmitted,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.accent = AppColors.green,
  });

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.28,
                    ),
                    child: IconTheme(
                      data: IconThemeData(color: accent),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WelcomePanel extends StatelessWidget {
  const WelcomePanel({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.ink, AppColors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.20),
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
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bienvenida',
                  style: TextStyle(
                    color: Color(0xFFDBE8E4),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Hola ${profile.name.split(' ').first}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFCADBD7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CoreStatusCard extends StatelessWidget {
  const CoreStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.verified_user, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesion Core protegida',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'JWT guardado en almacenamiento seguro y productos desde BD.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BalanceHero extends StatelessWidget {
  const BalanceHero({super.key, required this.account});

  final SavingsAccount account;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.green, AppColors.deepGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.name,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            money(account.balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Disponible: ${money(account.availableBalance)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    const actions = [
      ActionItem(Icons.swap_horiz, 'Transferir'),
      ActionItem(Icons.receipt_long, 'Pagar'),
      ActionItem(Icons.credit_card, 'Tarjetas'),
      ActionItem(Icons.support_agent, 'Ayuda'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 640
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions.map((action) {
            return SizedBox(
              width: width,
              child: Container(
                height: 116,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        action.icon,
                        color: AppColors.green,
                        size: 25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class ActionItem {
  const ActionItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

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
              color: AppColors.green,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionIntro extends StatelessWidget {
  const SectionIntro({
    super.key,
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
    return AppCard(
      accent: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
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
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MetricStrip extends StatelessWidget {
  const MetricStrip({super.key, required this.metrics});

  final List<MetricItem> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 640;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics.map((metric) {
            final width = isWide
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return SizedBox(
              width: width,
              child: MetricCard(metric: metric),
            );
          }).toList(),
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.metric});

  final MetricItem metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(metric.icon, color: metric.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
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

class MetricItem {
  const MetricItem(this.icon, this.label, this.value, this.color);

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class MovementTile extends StatelessWidget {
  const MovementTile({super.key, required this.movement});

  final Movement movement;

  @override
  Widget build(BuildContext context) {
    final color = movement.isIncome ? AppColors.green : AppColors.red;
    final sign = movement.isIncome ? '+' : '-';

    return AppCard(
      accent: color,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(
              movement.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  movement.date,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(
            '$sign ${money(movement.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class StatementTile extends StatelessWidget {
  const StatementTile({super.key, required this.statement});

  final AccountStatement statement;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.green,
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE8F5E9),
            foregroundColor: AppColors.green,
            child: Icon(Icons.description_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statement.month,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(statement.balance),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download),
            label: const Text('PDF'),
          ),
        ],
      ),
    );
  }
}

class InstallmentTile extends StatelessWidget {
  const InstallmentTile({super.key, required this.installment});

  final Installment installment;

  @override
  Widget build(BuildContext context) {
    final paid = installment.status == 'Pagado';
    final color = paid ? AppColors.green : AppColors.orange;

    return AppCard(
      accent: color,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Text('${installment.number}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  installment.date,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(installment.status),
              ],
            ),
          ),
          Text(
            money(installment.amount),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class FrequentPaymentTile extends StatelessWidget {
  const FrequentPaymentTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.orange,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.orange.withValues(alpha: 0.12),
            foregroundColor: AppColors.orange,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class SecurityOption extends StatelessWidget {
  const SecurityOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.purple,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.purple.withValues(alpha: 0.12),
            foregroundColor: AppColors.purple,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration boxDecoration({Color accent = AppColors.green}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 12,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

String money(double value) {
  return 'S/ ${value.toStringAsFixed(2)}';
}

double _jsonDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _movementType(Map<String, dynamic> item) {
  return _text(item['tipo_movimiento'] ?? item['tipo'], '').toUpperCase();
}

int _jsonInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value.map((item) => _asMap(item)).toList();
}

String _text(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  final normalized = value.replaceAll('_', ' ').toLowerCase();
  return normalized
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _formatCoreDate(String value) {
  if (value.isEmpty) return 'Sin fecha';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.day.toString().padLeft(2, '0')}/'
      '${parsed.month.toString().padLeft(2, '0')}/'
      '${parsed.year}';
}
