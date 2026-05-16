import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_blocker_provider.dart';
import 'package:intl/intl.dart';

class LoggerScreen extends StatelessWidget {
  const LoggerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Live Query Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        toolbarHeight: 60,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Consumer<AdBlockerProvider>(
              builder: (context, provider, _) => Text(
                '${provider.logs.length} Recent Queries',
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<AdBlockerProvider>(
        builder: (context, provider, _) {
          if (provider.logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No queries captured yet.', style: TextStyle(color: Colors.grey)),
                  Text('Try browsing some websites.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: provider.logs.length,
            itemBuilder: (context, index) {
              final log = provider.logs[index];
              final time = DateTime.fromMillisecondsSinceEpoch((log['time'] ?? 0) * 1000);
              final timeStr = DateFormat('HH:mm:ss').format(time);
              final isBlocked = log['blocked'] == true;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace')),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isBlocked ? const Color(0xFFED5550).withOpacity(0.1) : const Color(0xFF47ACAF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isBlocked ? 'BLOCKED' : 'PASS',
                        style: TextStyle(
                          color: isBlocked ? const Color(0xFFED5550) : const Color(0xFF47ACAF),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        log['domain'] ?? 'unknown',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isBlocked ? FontWeight.bold : FontWeight.normal,
                          color: const Color(0xFF504A56),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
