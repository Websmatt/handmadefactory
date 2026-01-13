import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'pages/home_page.dart';

const _tokenKey = 'token';

Future<String?> _loadToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_tokenKey);
}

Future<void> _saveToken(String? token) async {
  final prefs = await SharedPreferences.getInstance();
  if (token == null || token.isEmpty) {
    await prefs.remove(_tokenKey);
  } else {
    await prefs.setString(_tokenKey, token);
  }
}

void main() {
  runApp(const HandmadeFactory());
}

class HandmadeFactory extends StatelessWidget {
  const HandmadeFactory({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handmade Factory',
      theme: ThemeData(useMaterial3: true),
      home: const BootstrapPage(),
    );
  }
}

class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key});
  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  String? token;
  Map<String, dynamic>? me;
  String? err;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final t = await _loadToken();
    setState(() => token = t);
    if (t != null && t.isNotEmpty) {
      await _loadMe();
    }
  }

  Future<void> _loadMe() async {
    try {
      final dio = dioWithToken(token); // <-- z api.dart
      final res = await dio.get('/auth/me');
      setState(() {
        me = Map<String, dynamic>.from(res.data);
        err = null;
      });
    } catch (e) {
      setState(() {
        me = null;
        err = friendlyError(e); // <-- z api.dart
      });
    }
  }

  void _onLoggedIn(String newToken) async {
    await _saveToken(newToken);
    setState(() => token = newToken);
    await _loadMe();
  }

  void _logout() async {
    await _saveToken(null);
    setState(() {
      token = null;
      me = null;
      err = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (token == null || me == null) {
      return LoginPage(onLoggedIn: _onLoggedIn, error: err);
    }
    return HomePage(token: token!, me: me!, onLogout: _logout);
  }
}

class LoginPage extends StatefulWidget {
  final void Function(String token) onLoggedIn;
  final String? error;
  const LoginPage({super.key, required this.onLoggedIn, this.error});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController(text: 'mpalys@loluli.pl');
  final passCtrl = TextEditingController();
  bool loading = false;
  String? err;

  @override
  void initState() {
    super.initState();
    err = widget.error;
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final dio = Dio(BaseOptions(baseUrl: "/api"));
      final res = await dio.post(
        '/auth/login',
        data: jsonEncode({'email': emailCtrl.text.trim(), 'password': passCtrl.text}),
      );
      final token = res.data['access_token'] as String?;
      if (token == null || token.isEmpty) throw Exception('No token returned');
      widget.onLoggedIn(token);
    } catch (e) {
      setState(() => err = friendlyError(e)); // <-- z api.dart
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Handmade Factory', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 14),
                if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: loading ? null : _login,
                  child: Text(loading ? 'Logging in...' : 'Login'),
                ),
                const SizedBox(height: 10),
                const Text('Log in to app!', style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
