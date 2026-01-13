import 'package:flutter/material.dart';
import '../widgets/entity_list.dart';
import '../models/entity_kind.dart';

class ItemsPage extends StatelessWidget {
  final String token;
  final Map<String, dynamic> me;

  const ItemsPage({
    super.key,
    required this.token,
    required this.me,
  });

  Set<String> get roles => Set<String>.from((me['roles'] as List).cast<String>());
  bool get canCreate => roles.contains('admin') || roles.contains('editor');
  bool get canDelete => roles.contains('admin');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: EntityList(
          kind: EntityKind.items,
          token: token,
          canCreate: canCreate,
          canDelete: canDelete,
        ),
      ),
    );
  }
}