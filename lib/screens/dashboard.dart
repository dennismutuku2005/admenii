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
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFFED5550),
        unselectedItemColor: const Color(0xFF717175),
        backgroundColor: Colors.white,
        elevation: 16,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Status'),
          BottomNavigationBarItem(icon: Icon(Icons.source_outlined), activeIcon: Icon(Icons.source), label: 'Sources'),
          BottomNavigationBarItem(icon: Icon(Icons.block_outlined), activeIcon: Icon(Icons.block), label: 'Blocked'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), activeIcon: Icon(Icons.check_circle), label: 'Allowed'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
        ],
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
      backgroundColor: const Color(0xFFFAFAF9),
      body: CustomScrollView(
        slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF504A56),
              flexibleSpace: FlexibleSpaceBar(
                title: Row(
                  children: [
                    Image.asset('assets/images/logo.png', height: 24),
                    const SizedBox(width: 8),
                    const Text('AdMenii Pro', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                centerTitle: false,
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Consumer<AdBlockerProvider>(
                  builder: (context, provider, _) => _buildHeroCard(context, provider),
                ),
                const SizedBox(height: 24),
                Text('Real-time Protection', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Consumer<AdBlockerProvider>(
                  builder: (context, provider, _) => _buildStatsGrid(provider),
                ),
                const SizedBox(height: 24),
                Text('Activity Overview', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildActivityChart(context),
                const SizedBox(height: 80), // Space for bottom nav
              ]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeroCard(BuildContext context, AdBlockerProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: provider.isRunning 
              ? [const Color(0xFF47ACAF), const Color(0xFF50BEBA)]
              : [const Color(0xFFED5550), const Color(0xFFED5852)],
        ),
        boxShadow: [
          BoxShadow(
            color: (provider.isRunning ? const Color(0xFF47ACAF) : const Color(0xFFED5550)).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                provider.isRunning ? Icons.shield : Icons.shield_outlined,
                color: Colors.white,
                size: 40,
              ),
              Switch(
                value: provider.isRunning,
                onChanged: (val) => val ? provider.startServer() : provider.stopServer(),
                activeColor: Colors.white,
                activeTrackColor: Colors.white24,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            provider.isRunning ? 'System Secure' : 'Protection Disabled',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            provider.isRunning 
                ? 'Your network is currently being filtered' 
                : 'Click the switch to enable ad blocking',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsGrid(AdBlockerProvider provider) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard('Blocked Domains', provider.totalDomains.toString(), Icons.block, const Color(0xFFED5550)),
        _buildStatCard('Total Queries', provider.totalQueries.toString(), Icons.dns, const Color(0xFF536B74)),
        _buildStatCard('Blocked Requests', provider.blockedQueries.toString(), Icons.security, const Color(0xFF47ACAF)),
        _buildStatCard('Efficiency', '${provider.blockRate.toStringAsFixed(1)}%', Icons.auto_graph, const Color(0xFFED5852)),
      ],
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF717175))),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityChart(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Blocked Hits (Today)', style: TextStyle(fontWeight: FontWeight.bold)),
                Icon(Icons.more_horiz, size: 16),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final height = [40, 80, 60, 100, 70, 90, 50][index].toDouble();
                  return Container(
                    width: 20,
                    height: height,
                    decoration: BoxDecoration(
                      color: index == 3 ? const Color(0xFFED5550) : const Color(0xFF47ACAF).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => Text(d, style: TextStyle(fontSize: 10, color: Color(0xFF717175)))).toList(),
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
      appBar: AppBar(title: const Text('System Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsGroup('Network', [
            ListTile(
              leading: const Icon(Icons.router_outlined),
              title: const Text('Upstream DNS'),
              subtitle: Consumer<AdBlockerProvider>(
                builder: (context, provider, _) => Text(provider.upstreamDNS),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDNSDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Clear Query Logs'),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 24),
          _buildSettingsGroup('Security', [
            SwitchListTile(
              secondary: const Icon(Icons.update),
              title: const Text('Auto-update Blocklists'),
              subtitle: const Text('Every 48 hours'),
              value: true,
              activeColor: const Color(0xFF47ACAF),
              onChanged: (val) {},
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup Database'),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 24),
          _buildSettingsGroup('About', [
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('AdMenii Pro v2.5'),
              subtitle: Text('Enterprise DNS Ad Blocker'),
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
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF717175))),
        ),
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
        title: const Text('Upstream DNS'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'IP Address'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              provider.setUpstream(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
