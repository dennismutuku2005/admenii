import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_blocker_provider.dart';

class DomainsScreen extends StatelessWidget {
  const DomainsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blacklist Management')),
      body: Consumer<AdBlockerProvider>(
        builder: (context, provider, _) {
          return ListView.builder(
            padding: const EdgeInsets.all(32),
            itemCount: provider.domains.length,
            itemBuilder: (context, index) {
              final domain = provider.domains[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.block_rounded, color: Color(0xFF536B74), size: 18),
                  title: Text(domain['domain'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('Source: ${domain['source']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => provider.removeDomain(domain['domain']),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF47ACAF),
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Block Domain', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manually Block Domain'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'ads.example.com', border: OutlineInputBorder()),
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
