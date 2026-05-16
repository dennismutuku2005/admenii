import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_blocker_provider.dart';

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('DNS Sources', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), toolbarHeight: 60),
      body: Consumer<AdBlockerProvider>(
        builder: (context, provider, _) {
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: provider.sources.length,
            itemBuilder: (context, index) {
              final source = provider.sources[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.link_rounded, color: Color(0xFF47ACAF), size: 16),
                  title: Text(source['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(source['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                  trailing: TextButton(
                    onPressed: () => provider.fetchBlocklist(source['url']),
                    child: const Text('Sync', style: TextStyle(fontSize: 12)),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: const Color(0xFF47ACAF),
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white, size: 18),
      ),
    );
  }
}
