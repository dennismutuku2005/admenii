import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_blocker_provider.dart';
import 'sources_screen.dart';
import 'domains_screen.dart';
import 'whitelist_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const HomeScreen(),
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
      width: 200, // Narrower sidebar
      color: const Color(0xFF504A56),
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Image.asset('assets/images/logo.png', height: 40),
          const SizedBox(height: 40),
          _buildNavItem(0, Icons.grid_view_rounded, 'Overview'),
          _buildNavItem(1, Icons.language_rounded, 'Filter Lists'),
          _buildNavItem(2, Icons.shield_outlined, 'Blacklist'),
          _buildNavItem(3, Icons.verified_user_outlined, 'Whitelist'),
          const Spacer(),
          _buildNavItem(4, Icons.tune_rounded, 'Settings'),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
              Icon(icon, color: isSelected ? const Color(0xFF47ACAF) : Colors.white54, size: 16),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
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
        title: const Text('Status Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            const SizedBox(height: 20),
            Consumer<AdBlockerProvider>(
              builder: (context, provider, _) => _buildStatsRow(provider),
            ),
            const SizedBox(height: 20),
            _buildChartSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AdBlockerProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: provider.isRunning ? const Color(0xFF47ACAF).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: provider.isRunning ? const Color(0xFF47ACAF) : Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            provider.isRunning ? 'ACTIVE' : 'OFF',
            style: TextStyle(color: provider.isRunning ? const Color(0xFF47ACAF) : Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHero(AdBlockerProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.isRunning ? 'Network Protection Active' : 'System Paused',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF504A56)),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.isRunning ? 'Filtering ads and tracking domains.' : 'Click the button to start filtering.',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: () => provider.isRunning ? provider.stopServer() : provider.startServer(),
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.isRunning ? const Color(0xFF47ACAF) : const Color(0xFFF5F7F8),
                foregroundColor: provider.isRunning ? Colors.white : const Color(0xFF504A56),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(provider.isRunning ? 'Stop Service' : 'Start Service'),
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
              Icon(icon, color: const Color(0xFF536B74), size: 14),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF504A56))),
        ],
      ),
    );
  }

  Widget _buildChartSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Blocking Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 24),
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (index) {
                final heights = [20.0, 40.0, 30.0, 60.0, 80.0, 70.0, 60.0, 90.0, 70.0, 80.0, 100.0, 90.0];
                return Container(
                  width: 24,
                  height: heights[index],
                  decoration: BoxDecoration(
                    color: index == 10 ? const Color(0xFF47ACAF) : const Color(0xFFF5F7F8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
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
            _buildSmallToggle('Auto-update', 'Refresh domains.', true, (v) {}),
          ]),
          const SizedBox(height: 20),
          _buildCompactGroup('Service', [
            ListTile(
              dense: true,
              title: const Text('Background Service', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              trailing: SizedBox(
                height: 30,
                child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)), child: const Text('Setup', style: TextStyle(fontSize: 12))),
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
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(children: children)),
      ],
    );
  }

  Widget _buildSmallToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      dense: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      value: value,
      activeColor: const Color(0xFF47ACAF),
      onChanged: onChanged,
    );
  }
}
