import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String lovelyApi = 'https://lovelysky.fastapicloud.dev';

class AuthGate extends StatefulWidget {
  final Widget home;

  const AuthGate({super.key, required this.home});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('lovely_token');

    if (token != null && token.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('$lovelyApi/me'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          if (!mounted) return;
          setState(() {
            loggedIn = true;
            loading = false;
          });
          return;
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          await prefs.remove('lovely_token');
        }
      } catch (_) {
        // Network unavailable: do not delete a saved session.
      }
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (loggedIn) return widget.home;

    return LoginScreen(
      onLoggedIn: () {
        if (mounted) setState(() => loggedIn = true);
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;

  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String> _deviceId(SharedPreferences prefs) async {
    var id = prefs.getString('lovely_device_id');

    if (id == null || id.length < 16) {
      final random = Random.secure();
      id = List.generate(
        32,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
      await prefs.setString('lovely_device_id', id);
    }

    return id;
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _deviceId(prefs);

      final response = await http
          .post(
            Uri.parse('$lovelyApi/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': _idController.text.trim(),
              'password': _passwordController.text,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 25));

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true &&
          data['token'] != null) {
        await prefs.setString('lovely_token', data['token'].toString());

        if (!mounted) return;
        widget.onLoggedIn();
        return;
      }

      final message = data['detail'] ??
          data['message'] ??
          'Login nahi hua. ID aur password check karein.';

      if (mounted) setState(() => _error = message.toString());
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Server se connection nahi ho saka. Internet check karke dobara try karein.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleLogin() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '122872274591-uuehmdgobp2hpl8a3ad09eqv08g0sise.apps.googleusercontent.com',
      );

      final account = await GoogleSignIn.instance.authenticate();
      final googleIdToken = account.authentication.idToken;

      if (googleIdToken == null || googleIdToken.isEmpty) {
        throw Exception('Google ID token nahi mila. Firebase OAuth configuration check karein.');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleIdToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseIdToken = await userCredential.user?.getIdToken();

      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw Exception('Firebase verification token nahi mila.');
      }

      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _deviceId(prefs);

      final response = await http
          .post(
            Uri.parse('$lovelyApi/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': firebaseIdToken,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true &&
          data['token'] != null) {
        await prefs.setString('lovely_token', data['token'].toString());
        if (!mounted) return;
        widget.onLoggedIn();
        return;
      }

      final message = data['detail'] ??
          data['message'] ??
          'Google Login nahi hua. Dobara try karein.';
      if (mounted) setState(() => _error = message.toString());
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = 'Firebase Login error: ${e.message ?? e.code}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Google Login nahi hua: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF8FF), Color(0xFFD6F1FF), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 94,
                        height: 94,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF168FFF),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF168FFF).withValues(alpha: 0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Lovely Sky',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF183B59),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome back! Apne account mein login karein.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Lovely ID',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF183B59),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _idController,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: 'Apni Lovely ID enter karein',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Lovely ID enter karein'
                                : null,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF183B59),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          hintText: 'Apna password enter karein',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _hidePassword = !_hidePassword,
                            ),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password enter karein';
                          }
                          if (value.length < 10) {
                            return 'Password kam az kam 10 characters ka ho';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _busy ? null : _login,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF168FFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Login with Lovely ID',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.blueGrey.shade100)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: TextStyle(color: Colors.blueGrey.shade500),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.blueGrey.shade100)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _googleLogin,
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                          label: const Text(
                            'Continue with Google',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF183B59),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFD8EAF5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Secure login • Lovely Sky',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey.shade400,
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
    );
  }
}
