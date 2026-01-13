import 'dart:convert';
import 'package:flutter/material.dart';

import '../api.dart';
import '../models/entity_kind.dart';

class EntityList extends StatefulWidget {
  final EntityKind kind;
  final String token;
  final bool canCreate;
  final bool canDelete;

  const EntityList({
    super.key,
    required this.kind,
    required this.token,
    required this.canCreate,
    required this.canDelete,
  });

  @override
  State<EntityList> createState() => _EntityListState();
}

class _EntityListState extends State<EntityList> {
  List data = [];
  bool loading = true;
  String? err;

  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final dio = dioWithToken(widget.token);
      final res = await dio.get(widget.kind.endpoint);
      setState(() => data = res.data as List);
    } catch (e) {
      setState(() => err = friendlyError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    try {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;

      final dio = dioWithToken(widget.token);
      await dio.post(
        widget.kind.endpoint,
        data: jsonEncode({
          'name': name,
          'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        }),
      );

      nameCtrl.clear();
      descCtrl.clear();
      await _refresh();
    } catch (e) {
      setState(() => err = friendlyError(e));
    }
  }

  Future<void> _delete(int id) async {
    try {
      final dio = dioWithToken(widget.token);
      await dio.delete('${widget.kind.endpoint}/$id');
      await _refresh();
    } catch (e) {
      setState(() => err = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (err != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(err!, style: const TextStyle(color: Colors.red)),
        ),

      if (widget.canCreate)
        Row(children: [
          Expanded(
            child: TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nazwa'),
              onChanged: (_) => setState(() {}), // żeby przycisk "Dodaj" reagował
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Opis'),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: nameCtrl.text.trim().isEmpty ? null : _add,
            child: const Text('Dodaj'),
          ),
          const SizedBox(width: 6),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ]),

      const SizedBox(height: 12),

      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Card(
                child: ListView.separated(
                  itemCount: data.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = data[i] as Map<String, dynamic>;
                    final id = it['id'] as int;

                    return ListTile(
                      leading: Text('$id'),
                      title: Text('${it['name']}'),
                      subtitle: Text('${it['description'] ?? ''}'),
                      trailing: widget.canDelete
                          ? IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _delete(id),
                            )
                          : null,
                    );
                  },
                ),
              ),
      ),
    ]);
  }
}
