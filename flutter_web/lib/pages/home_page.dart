import 'package:flutter/material.dart';
import 'items_page.dart';
import 'products_page.dart';

class HomePage extends StatelessWidget {
  final String token;
  final Map<String, dynamic> me;
  final VoidCallback onLogout;

  const HomePage({
    super.key,
    required this.token,
    required this.me,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final email = (me['email'] ?? '').toString();
    final company = (me['company'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('HandmadeFactory'),
        actions: [
          Center(child: Text('$company  ', style: const TextStyle(fontSize: 13))),
          Center(child: Text('$email  ', style: const TextStyle(fontSize: 13))),
          IconButton(onPressed: onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _NavCard(
              title: 'Items',
              subtitle: 'Lista / dodawanie / usuwanie',
              icon: Icons.list_alt,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ItemsPage(token: token, me: me),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _NavCard(
              title: 'Products',
              subtitle: 'Lista / dodawanie / usuwanie',
              icon: Icons.inventory_2,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductsPage(token: token, me: me),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}