import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../home/presentation/home_page.dart';
import '../../modules/presentation/modules_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../wardrobe/presentation/outfit_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _selectedDestination = 'home';

  @override
  Widget build(BuildContext context) {
    final destinations = <_AppDestination>[
      const _AppDestination(
        id: 'home',
        label: '首页',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        page: HomePage(key: PageStorageKey('home')),
      ),
      _AppDestination(
        id: 'modules',
        label: '板块',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        page: ModulesPage(
          key: const PageStorageKey('modules'),
          controller: widget.controller,
        ),
      ),
      if (widget.controller.outfitModuleEnabled)
        const _AppDestination(
          id: 'outfit',
          label: '穿搭',
          icon: Icons.checkroom_outlined,
          selectedIcon: Icons.checkroom,
          page: OutfitPage(key: PageStorageKey('outfit')),
        ),
      _AppDestination(
        id: 'profile',
        label: '我的',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        page: ProfilePage(
          key: const PageStorageKey('profile'),
          controller: widget.controller,
        ),
      ),
    ];

    var selectedIndex = destinations.indexWhere(
      (destination) => destination.id == _selectedDestination,
    );
    if (selectedIndex < 0) {
      selectedIndex = 0;
      _selectedDestination = destinations.first.id;
    }

    return Scaffold(
      appBar: AppBar(title: Text(destinations[selectedIndex].label)),
      body: IndexedStack(
        index: selectedIndex,
        children: [for (final destination in destinations) destination.page],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedDestination = destinations[index].id;
          });
        },
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}
