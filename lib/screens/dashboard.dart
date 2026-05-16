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
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: const Color(0xFF504A56), // Charcoal
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Image.asset('assets/images/logo.png', height: 32),
                const SizedBox(width: 12),
                const Text(
                  'AdMenii',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
          _buildNavItem(1, Icons.dns_rounded, 'Sources'),
          _buildNavItem(2, Icons.block_rounded, 'Blocked'),
          _buildNavItem(3, Icons.verified_user_rounded, 'Allowed'),
          const Spacer(),
          _buildNavItem(4, Icons.settings_rounded, 'Settings'),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'v2.5 Pro Edition',
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF47ACAF).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF47ACAF) : Colors.white60,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Overview', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<AdBlockerProvider>(
              builder: (context, provider, _) => _buildHeroCard(context, provider),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: _buildSectionTitle('Live Analytics')),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<AdBlockerProvider>(
              builder: (context, provider, _) => _buildStatsGrid(provider),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Blocking Activity'),
            const SizedBox(height: 16),
            _buildActivityChart(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF504A56),
      ),
    );
  }
  
  Widget _buildHeroCard(BuildContext context, AdBlockerProvider provider) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: provider.isRunning ? const Color(0xFF47ACAF) : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.isRunning ? 'Active Protection' : 'Service Stopped',
                      style: TextStyle(
                        color: provider.isRunning ? const Color(0xFF47ACAF) : Colors.grey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  provider.isRunning ? 'Your network is secured.' : 'Network protection is off.',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF504A56),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ads and trackers are being filtered at the DNS level.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Transform.scale(
                scale: 1.5,
                child: Switch(
                  value: provider.isRunning,
                  onChanged: (val) => val ? provider.startServer() : provider.stopServer(),
                  activeColor: const Color(0xFF47ACAF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.isRunning ? 'ENABLED' : 'DISABLED',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsGrid(AdBlockerProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: constraints.maxWidth > 800 ? 4 : 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard('Total Queries', provider.totalQueries.toString(), Icons.dns_outlined, const Color(0xFF536B74)),
            _buildStatCard('Blocked', provider.blockedQueries.toString(), Icons.security_rounded, const Color(0xFF47ACAF)),
            _buildStatCard('Database Size', provider.totalDomains.toString(), Icons.storage_rounded, Colors.orange),
            _buildStatCard('Efficiency', '${provider.blockRate.toStringAsFixed(1)}%', Icons.auto_graph_rounded, const Color(0xFF47ACAF)),
          ],
        );
      },
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF504A56))),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityChart(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(12, (index) {
                  final heights = [30.0, 50.0, 40.0, 80.0, 120.0, 100.0, 90.0, 150.0, 110.0, 130.0, 160.0, 140.0];
                  final height = heights[index];
                  return Container(
                    width: 32,
                    height: height,
                    decoration: BoxDecoration(
                      color: index == 10 ? const Color(0xFF47ACAF) : const Color(0xFF47ACAF).withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(12, (i) => Text('${i + 1}h', style: const TextStyle(fontSize: 10, color: Colors.grey))),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Configuration')),
      body: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          _buildSettingsGroup('Network Service', [
            ListTile(
              leading: const Icon(Icons.miscellaneous_services_rounded),
              title: const Text('Install Background Service'),
              subtitle: const Text('Runs the DNS blocker even when this app is closed.'),
              trailing: ElevatedButton(
                onPressed: () {},
                child: const Text('Install'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.router_outlined),
              title: const Text('Upstream DNS Server'),
              subtitle: Consumer<AdBlockerProvider>(
                builder: (context, provider, _) => Text(provider.upstreamDNS),
              ),
              onTap: () => _showDNSDialog(context),
            ),
          ]),
          const SizedBox(height: 32),
          _buildSettingsGroup('Data Management', [
            ListTile(
              leading: const Icon(Icons.update_rounded),
              title: const Text('Auto-update Blocklists'),
              subtitle: const Text('Automatically refresh domains every 48 hours.'),
              trailing: Switch(value: true, onChanged: (v) {}),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded),
              title: const Text('Purge Query Logs'),
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }
  
  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 12),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showDNSDialog(BuildContext context) {
    final provider = Provider.of<AdBlockerProvider>(context, listen: false);
    final controller = TextEditingController(text: provider.upstreamDNS);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configure Upstream DNS'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Primary DNS IP'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              provider.setUpstream(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
