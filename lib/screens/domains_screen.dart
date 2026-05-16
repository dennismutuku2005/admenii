import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_blocker_provider.dart';

class DomainsScreen extends StatelessWidget {
  const DomainsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Domains')),
      body: Consumer<AdBlockerProvider>(
        builder: (context, provider, _) {
          if (provider.domains.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block_flipped, size: 64, color: theme.primaryColor.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text('No blocked domains', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.domains.length,
            itemBuilder: (context, index) {
              final domain = provider.domains[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFED5550),
                    child: Icon(Icons.security, color: Colors.white, size: 18),
                  ),
                  title: Text(domain['domain'] ?? 'Unknown', style: theme.textTheme.titleMedium),
                  subtitle: Text('Hits: ${domain['hit_count']} • ${domain['source']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFF717175)),
                    onPressed: () => provider.removeDomain(domain['domain']),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFED5550),
        onPressed: () => _showAddDomainDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddDomainDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Custom Domain'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g., ads.example.com', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Provider.of<AdBlockerProvider>(context, listen: false).addDomain(controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }
}
