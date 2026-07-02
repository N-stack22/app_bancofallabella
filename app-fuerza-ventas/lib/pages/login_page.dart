import 'dart:convert';

import 'package:bancofalabella_app2/services/scoring_repository.dart';
import 'package:bancofalabella_app2/supabase_config.dart';
import 'package:bancofalabella_app2/views/home_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool loading = false;
  bool hidePassword = true;
  int failedAttempts = 0;
  DateTime? lockedUntil;

  static const defaultAdvisorEmail = 'asesor0001@bancofalabella.local';

  Future<void> signIn() async {
    final locked = lockedUntil;
    if (locked != null && DateTime.now().isBefore(locked)) {
      showMessage('Acceso bloqueado hasta ${_timeText(locked)}');
      return;
    }
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      await _signInWithCore(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
    } catch (error) {
      registerFailedAttempt();
      showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void registerFailedAttempt() {
    failedAttempts += 1;
    if (failedAttempts >= 5) {
      lockedUntil = DateTime.now().add(const Duration(minutes: 30));
    }
  }

  Future<void> _signInWithCore(String username, String password) async {
    final uri = Uri.parse('${SupabaseConfig.coreBaseUrl}/auth/login');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'codigo_empleado': username.trim().isEmpty ? '0001' : username,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_coreErrorMessage(response));
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['access_token'] == null) {
      throw StateError('El Core no devolvio una sesion valida.');
    }
    final advisor = body['asesor'] is Map
        ? Map<String, dynamic>.from(body['asesor'] as Map)
        : <String, dynamic>{};
    await ScoringRepository.saveCoreSession(
      token: body['access_token'].toString(),
      advisor: advisor,
    );
    failedAttempts = 0;
    lockedUntil = null;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(userEmail: _advisorEmail(advisor, username)),
      ),
    );
  }

  String _coreErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {}
    if (response.statusCode == 401) return 'Credenciales invalidas';
    if (response.statusCode == 423) return 'Cuenta bloqueada temporalmente';
    return 'No se pudo iniciar sesion contra el Core.';
  }

  String _advisorEmail(Map<String, dynamic> advisor, String username) {
    final code = (advisor['codigo_empleado'] ?? username).toString().trim();
    return _loginToEmail(code);
  }

  String _loginToEmail(String value) {
    if (value.contains('@')) return value;
    if (value.trim().isEmpty) return defaultAdvisorEmail;
    final code = value.padLeft(4, '0');
    return 'asesor$code@bancofalabella.local';
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF123D37);
    const ink = Color(0xFF101820);
    const border = Color(0xFFCAD6D8);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F4),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEFF3F4), Color(0xFFE9F1EC)],
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _FalabellaLogo(),
                          const SizedBox(height: 8),
                          const Text(
                            'App Fuerza de Ventas · Originación móvil',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF66727A),
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Codigo de empleado o correo',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Ingrese su codigo';
                              if (!email.contains('@') &&
                                  int.tryParse(email) == null) {
                                return 'Ingrese codigo numerico o correo valido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: passwordController,
                            obscureText: hidePassword,
                            decoration: InputDecoration(
                              labelText: 'Contrasena',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() => hidePassword = !hidePassword);
                                },
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.isEmpty) {
                                return 'Ingrese su contrasena';
                              }
                              if (password.length < 4) {
                                return 'La contrasena debe tener minimo 4 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: loading ? null : signIn,
                              style: FilledButton.styleFrom(
                                backgroundColor: green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: loading
                                    ? const _LoadingButtonContent()
                                    : const Text(
                                        key: ValueKey('loginText'),
                                        'Ingresar como asesor',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          if (failedAttempts > 0) ...[
                            const SizedBox(height: 12),
                            Text(
                              failedAttempts >= 5
                                  ? 'Cuenta bloqueada temporalmente'
                                  : 'Intentos fallidos: $failedAttempts/5',
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ],
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () => showMessage(
                              'Contacta al administrador de agencia para restablecer acceso.',
                            ),
                            icon: const Icon(Icons.help_outline),
                            label: const Text(
                              'Problemas para ingresar',
                              style: TextStyle(color: ink),
                            ),
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

class _FalabellaLogo extends StatelessWidget {
  const _FalabellaLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 92,
            height: 78,
            child: CustomPaint(painter: _FalabellaMarkPainter()),
          ),
          const SizedBox(width: 12),
          Text(
            'Banco\nFalabella',
            style: TextStyle(
              height: 0.95,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF17231F),
            ),
          ),
        ],
      ),
    );
  }
}

class _FalabellaMarkPainter extends CustomPainter {
  const _FalabellaMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final greenPaint = Paint()..color = const Color(0xFF123D37);
    final limePaint = Paint()..color = const Color(0xFFB8D932);
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

class _LoadingButtonContent extends StatelessWidget {
  const _LoadingButtonContent();

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

String _timeText(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
