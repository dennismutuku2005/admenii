import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_blocker_provider.dart';

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Blocklist Sources')),
      body: Consumer<AdBlockerProvider>(
        builder: (context, provider, _) {
          if (provider.sources.isEmpty) {
            return const Center(child: Text('No sources found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.sources.length,
            itemBuilder: (context, index) {
              final source = provider.sources[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF536B74),
                    child: Icon(Icons.link, color: Colors.white, size: 18),
                  ),
                  title: Text(source['name'] ?? 'Unknown Source', style: theme.textTheme.titleMedium),
                  subtitle: Text(source['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: source['is_active'] == 1 ? const Color(0xFF47ACAF).withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      source['is_active'] == 1 ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: source['is_active'] == 1 ? const Color(0xFF47ACAF) : Colors.red,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFED5550),
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
