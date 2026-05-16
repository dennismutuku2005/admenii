import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_blocker_provider.dart';
import 'sources_screen.dart';
import 'domains_screen.dart';
import 'whitelist_screen.dart';
import 'logger_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const LoggerScreen(), // New
    const SourcesScreen(),
    const DomainsScreen(),
    const WhitelistScreen(),
    const SettingsScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Container(
              color: const Color(0xFFFAFAF9),
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 180, // Even narrower for more space
      color: const Color(0xFF504A56),
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Image.asset('assets/images/logo.png', height: 40),
          const SizedBox(height: 40),
          _buildNavItem(0, Icons.grid_view_rounded, 'Dashboard'),
          _buildNavItem(1, Icons.list_alt_rounded, 'Activity Log'),
          _buildNavItem(2, Icons.language_rounded, 'Filter Lists'),
          _buildNavItem(3, Icons.shield_outlined, 'Blacklist'),
          _buildNavItem(4, Icons.verified_user_outlined, 'Whitelist'),
          const Spacer(),
          _buildNavItem(5, Icons.tune_rounded, 'Settings'),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF47ACAF) : Colors.white54, size: 14),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        toolbarHeight: 60,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Consumer<AdBlockerProvider>(
              builder: (context, provider, _) => _buildStatusBadge(provider),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Consumer<AdBlockerProvider>(
              builder: (context, provider, _) => _buildCompactHero(provider),
            ),
            const SizedBox(height: 16),
            Consumer<AdBlockerProvider>(
              builder: (context, provider, _) => _buildStatsRow(provider),
            ),
            const SizedBox(height: 16),
            _buildChartSection(context),
            const SizedBox(height: 16),
            _buildRecentActivity(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AdBlockerProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: provider.isRunning ? const Color(0xFF47ACAF).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: provider.isRunning ? const Color(0xFF47ACAF) : Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            provider.isRunning ? 'ACTIVE' : 'OFF',
            style: TextStyle(color: provider.isRunning ? const Color(0xFF47ACAF) : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHero(AdBlockerProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.isRunning ? 'Protection Active' : 'System Paused',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF504A56)),
                ),
                const SizedBox(height: 2),
                Text(
                  provider.isRunning ? 'Currently filtering network domains.' : 'Click to start the DNS engine.',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => provider.isRunning ? provider.stopServer() : provider.startServer(),
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.isRunning ? const Color(0xFF47ACAF) : const Color(0xFFF5F7F8),
                foregroundColor: provider.isRunning ? Colors.white : const Color(0xFF504A56),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(provider.isRunning ? 'Stop' : 'Start', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(AdBlockerProvider provider) {
    return Row(
      children: [
        Expanded(child: _buildMiniStat('Queries', provider.totalQueries.toString(), Icons.dns_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _buildMiniStat('Blocked', provider.blockedQueries.toString(), Icons.block_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _buildMiniStat('Rules', provider.totalDomains.toString(), Icons.list_alt_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _buildMiniStat('Rate', '${provider.blockRate.toStringAsFixed(1)}%', Icons.bolt_rounded)),
      ],
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF536B74), size: 12),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF504A56))),
        ],
      ),
    );
  }

  Widget _buildChartSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Blocking Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 20),
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(15, (index) {
                final heights = [20.0, 40.0, 30.0, 60.0, 80.0, 70.0, 60.0, 90.0, 70.0, 80.0, 100.0, 90.0, 60.0, 40.0, 50.0];
                return Container(
                  width: 16,
                  height: heights[index],
                  decoration: BoxDecoration(
                    color: index == 10 ? const Color(0xFF47ACAF) : const Color(0xFFF5F7F8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Traffic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Icon(Icons.keyboard_arrow_right, size: 16, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Consumer<AdBlockerProvider>(
            builder: (context, provider, _) {
              final miniLogs = provider.logs.take(3).toList();
              if (miniLogs.isEmpty) return const Text('No recent activity', style: TextStyle(fontSize: 10, color: Colors.grey));
              return Column(
                children: miniLogs.map((log) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: log['blocked'] ? Colors.red : Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(log['domain'], style: const TextStyle(fontSize: 10, color: Color(0xFF504A56)), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), toolbarHeight: 60),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildCompactGroup('Security', [
            Consumer<AdBlockerProvider>(
              builder: (context, provider, _) => _buildSmallToggle('Force Local DNS', 'Blocks browser DoH.', provider.isDoHBlocked, (v) => provider.toggleDoH(v)),
            ),
          ]),
          const SizedBox(height: 16),
          _buildCompactGroup('Background', [
            Consumer<AdBlockerProvider>(
              builder: (context, provider, _) => ListTile(
                dense: true,
                title: const Text('Windows Service', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                subtitle: Text(provider.isServiceInstalled ? 'Installed' : 'Ready to setup', style: const TextStyle(fontSize: 10)),
                trailing: SizedBox(
                  height: 28,
                  child: OutlinedButton(
                    onPressed: provider.isServiceInstalled ? null : () => provider.installService(),
                    child: Text(provider.isServiceInstalled ? 'Done' : 'Install', style: const TextStyle(fontSize: 10)),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildCompactGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Column(children: children)),
      ],
    );
  }

  Widget _buildSmallToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      dense: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)),
      value: value,
      activeColor: const Color(0xFF47ACAF),
      onChanged: onChanged,
    );
  }
}
