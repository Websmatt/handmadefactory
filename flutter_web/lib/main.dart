import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'token';

Dio _dioWithToken(String? token) {
  final dio = Dio(BaseOptions(baseUrl: "/api"));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Content-Type'] = 'application/json';
    return handler.next(options);
  }));
  return dio;
}

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
    if (t != null) {
      await _loadMe();
    }
  }

  Future<void> _loadMe() async {
    try {
      final dio = _dioWithToken(token);
      final res = await dio.get('/auth/me');
      setState(() {
        me = Map<String, dynamic>.from(res.data);
        err = null;
      });
    } catch (e) {
      setState(() {
        me = null;
        err = _friendlyError(e);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    if (token == null || me == null) {
      return LoginPage(onLoggedIn: _onLoggedIn, error: err);
    }
    return ItemsPage(token: token!, me: me!, onLogout: _logout);
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
      final res = await dio.post('/auth/login',
          data: jsonEncode({'email': emailCtrl.text.trim(), 'password': passCtrl.text}));
      final token = res.data['access_token'] as String?;
      if (token == null || token.isEmpty) throw Exception('No token returned');
      widget.onLoggedIn(token);
    } catch (e) {
      setState(() => err = _friendlyError(e));
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

class ItemsPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> me;
  final VoidCallback onLogout;
  const ItemsPage({super.key, required this.token, required this.me, required this.onLogout});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  List items = [];
  String? err;
  bool loading = true;

  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  Set<String> get roles => Set<String>.from((widget.me['roles'] as List).cast<String>());

  bool get canCreate => roles.contains('admin') || roles.contains('editor');
  bool get canDelete => roles.contains('admin');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final dio = _dioWithToken(widget.token);
      final res = await dio.get('/items');
      setState(() => items = res.data as List);
    } catch (e) {
      setState(() => err = _friendlyError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    try {
      final dio = _dioWithToken(widget.token);
      await dio.post('/items', data: jsonEncode({'name': nameCtrl.text.trim(), 'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim()}));
      nameCtrl.clear();
      descCtrl.clear();
      await _refresh();
    } catch (e) {
      setState(() => err = _friendlyError(e));
    }
  }

  Future<void> _delete(int id) async {
    try {
      final dio = _dioWithToken(widget.token);
      await dio.delete('/items/$id');
      await _refresh();
    } catch (e) {
      setState(() => err = _friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.me['email'] ?? '';
    final company = widget.me['company'] ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('HandmadeFactory'),
        actions: [
          Center(child: Text('$company  ', style: const TextStyle(fontSize: 13))),
          Center(child: Text('$email  ', style: const TextStyle(fontSize: 13))),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (err != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(err!, style: const TextStyle(color: Colors.red))),
          if (canCreate)
            Row(children: [
              Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nazwa'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Opis'))),
              const SizedBox(width: 10),
              FilledButton(onPressed: nameCtrl.text.trim().isEmpty ? null : _add, child: const Text('Dodaj')),
            ]),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final it = items[i] as Map<String, dynamic>;
                        final id = it['id'] as int;
                        return ListTile(
                          title: Text('${it['name']}'),
                          subtitle: Text('${it['description'] ?? ''}'),
                          leading: Text('$id'),
                          trailing: canDelete ? IconButton(icon: const Icon(Icons.delete), onPressed: () => _delete(id)) : null,
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          const Text('Handmade Facroty ©', style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}

String _friendlyError(Object e) {
  if (e is DioException) {
    final r = e.response;
    if (r != null) {
      if (r.data is Map && (r.data as Map).containsKey('detail')) return '${r.data['detail']}';
      return 'HTTP ${r.statusCode}: ${r.data}';
    }
    return e.message ?? e.toString();
  }
  return e.toString();
}
