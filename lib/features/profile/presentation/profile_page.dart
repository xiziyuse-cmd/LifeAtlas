import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/settings/app_settings.dart';
import '../../modules/presentation/modules_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            key: const ValueKey('theme-mode-toggle'),
            tooltip: isDarkMode ? '切换至日间模式' : '切换至夜间模式',
            onPressed: () {
              controller.setThemePreference(
                isDarkMode ? AppThemePreference.light : AppThemePreference.dark,
              );
            },
            icon: Icon(
              isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: const Icon(Icons.person, size: 32),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LifeAtlas 用户',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('个人资料功能将在后续阶段完善'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('功能', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            key: const ValueKey('profile-modules-entry'),
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('板块管理'),
            subtitle: const Text('管理功能板块与底部导航入口'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('板块管理')),
                    body: ModulesPage(controller: controller),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text('更多', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.account_balance_wallet_outlined),
                title: Text('我的钱包'),
                subtitle: Text('后续阶段实现'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.straighten_outlined),
                title: Text('我的身材'),
                subtitle: Text('后续阶段实现'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.support_agent_outlined),
                title: Text('联系开发者'),
                subtitle: Text('后续阶段实现'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
