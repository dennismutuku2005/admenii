import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_blocker_provider.dart';

class WhitelistScreen extends StatelessWidget {
  const WhitelistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Whitelist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), toolbarHeight: 60),
      body: Consumer<AdBlockerProvider>(
        builder: (context, provider, _) {
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: provider.whitelist.length,
            itemBuilder: (context, index) {
              final domain = provider.whitelist[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF47ACAF), size: 14),
                  title: Text(domain, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                    onPressed: () => provider.removeWhitelist(domain),
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
        title: const Text('Allow Domain', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(hintText: 'trusted-site.com', border: OutlineInputBorder()),
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
