import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_blocker_provider.dart';

class WhitelistScreen extends StatelessWidget {
  const WhitelistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Allowed Domains')),
      body: Consumer<AdBlockerProvider>(
        builder: (context, provider, _) {
          if (provider.whitelist.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: theme.colorScheme.secondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('No domains whitelisted yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Add domains you want to allow', style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.whitelist.length,
            itemBuilder: (context, index) {
              final domain = provider.whitelist[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF47ACAF), // Tropical Teal
                    child: Icon(Icons.check, color: Colors.white),
                  ),
                  title: Text(domain, style: theme.textTheme.titleMedium),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFED5550)),
                    onPressed: () => provider.removeWhitelist(domain),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.primaryColor,
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow Domain'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g., google.com',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Provider.of<AdBlockerProvider>(context, listen: false).addWhitelist(controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }
}
