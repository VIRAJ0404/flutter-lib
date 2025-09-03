// File: lib/app/shell.dart
// Drawer + bottom navigation, as in the previous app.

import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(),
      const SizedBox.shrink(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('FlexIoT')),
      drawer: _AppDrawer(
        onNavigate: (route) {
          Navigator.pop(context);
          switch (route) {
            case 'edit_home':
              Navigator.pushNamed(context, '/edit');
              break;
            case 'settings':
              Navigator.pushNamed(context, '/settings');
              break;
            case 'history':
              Navigator.pushNamed(context, '/history');
              break;
            case 'alert_rules':
              Navigator.pushNamed(context, '/alerts');
              break;
            case 'devices':
              Navigator.pushNamed(context, '/devices');
              break;
            case 'temperature':
              Navigator.pushNamed(context, '/temperature');
              break;
          }
        },
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.devices_other_outlined),
              selectedIcon: Icon(Icons.devices_other),
              label: 'Devices'),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final void Function(String route) onNavigate;
  const _AppDrawer({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: cs.primaryContainer),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('Menu',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
            ),
            ListTile(
                leading: const Icon(Icons.dashboard_customize),
                title: const Text('Edit Home'),
                onTap: () => onNavigate('edit_home')),
            ListTile(
                leading: const Icon(Icons.thermostat),
                title: const Text('Temperature'),
                onTap: () => onNavigate('temperature')),
            ListTile(
                leading: const Icon(Icons.devices),
                title: const Text('Devices'),
                onTap: () => onNavigate('devices')),
            ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () => onNavigate('settings')),
            ListTile(
                leading: const Icon(Icons.history),
                title: const Text('History'),
                onTap: () => onNavigate('history')),
            ListTile(
                leading: const Icon(Icons.rule),
                title: const Text('Alert Rules'),
                onTap: () => onNavigate('alert_rules')),
          ],
        ),
      ),
    );
  }
}
