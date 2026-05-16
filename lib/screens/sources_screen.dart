import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_blocker_provider.dart';

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DNS Sources')),
      body: Consumer<AdBlockerProvider>(
        builder: (context, provider, _) {
          return ListView.builder(
            padding: const EdgeInsets.all(32),
            itemCount: provider.sources.length,
            itemBuilder: (context, index) {
              final source = provider.sources[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF5F7F8),
                    child: Icon(Icons.link_rounded, color: Color(0xFF47ACAF)),
                  ),
                  title: Text(source['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(source['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: TextButton(
                    onPressed: () => provider.fetchBlocklist(source['url']),
                    child: const Text('Update Now'),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF47ACAF),
        onPressed: () {},
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Source', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
