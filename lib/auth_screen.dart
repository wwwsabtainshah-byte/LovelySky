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
  bool _showLovelyLogin = false;
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
    const navy = Color(0xFF183B59);
    const blue = Color(0xFF168FFF);
    const pale = Color(0xFFEAF8FF);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [pale, Color(0xFFD6F1FF), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [blue, Color(0xFF67D4FF)],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: blue.withValues(alpha: 0.25),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Lovely Sky',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: navy,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _showLovelyLogin
                          ? 'Apni Lovely ID se login karein'
                          : 'Your sky, your people, your world',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                    const SizedBox(height: 34),

                    if (!_showLovelyLogin) ...[
                      const Text(
                        'Welcome to Lovely Sky',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 60,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _googleLogin,
                          icon: const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 34,
                          ),
                          label: const Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: navy,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 60,
                        child: FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _showLovelyLogin = true;
                                    _error = null;
                                  }),
                          icon: const Icon(Icons.favorite_rounded),
                          label: const Text(
                            'Lovely Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: blue.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                            _showLovelyLogin = false;
                                            _error = null;
                                          }),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: navy,
                                  ),
                                ),
                                const Expanded(
                                  child: Text(
                                    'Lovely Login',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      color: navy,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Lovely ID',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _idController,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              decoration: InputDecoration(
                                hintText: 'Apni Lovely ID enter karein',
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
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
                                color: navy,
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
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
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
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Password enter karein'
                                      : null,
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
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 56,
                              child: FilledButton(
                                onPressed: _busy ? null : _login,
                                style: FilledButton.styleFrom(
                                  backgroundColor: blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
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
                                        'Confirm Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_busy && !_showLovelyLogin) ...[
                      const SizedBox(height: 20),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    const SizedBox(height: 30),
                    Text(
                      'Secure Login  •  Lovely Sky',
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
    );
  }

}
