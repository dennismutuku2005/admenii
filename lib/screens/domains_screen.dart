import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_blocker_provider.dart';

class DomainsScreen extends StatelessWidget {
  const DomainsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Blacklist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), toolbarHeight: 60),
      body: Consumer<AdBlockerProvider>(
        builder: (context, provider, _) {
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: provider.domains.length,
            itemBuilder: (context, index) {
              final domain = provider.domains[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.block_rounded, color: Color(0xFF536B74), size: 14),
                  title: Text(domain['domain'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 14),
                    onPressed: () => provider.removeDomain(domain['domain']),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: const Color(0xFF47ACAF),
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add, color: Colors.white, size: 18),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Domain', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 14),
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
