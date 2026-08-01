import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/settings/app_settings.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
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
        Text('板块开关', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            key: const ValueKey('profile-outfit-switch'),
            secondary: const Icon(Icons.checkroom_outlined),
            title: const Text('穿搭'),
            subtitle: const Text('在底部导航中显示穿搭入口'),
            value: controller.outfitModuleEnabled,
            onChanged: controller.setOutfitModuleEnabled,
          ),
        ),
        const SizedBox(height: 20),
        Text('外观', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('主题模式'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AppThemePreference>(
                    key: const ValueKey('theme-mode-selector'),
                    segments: const [
                      ButtonSegment(
                        value: AppThemePreference.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('日间'),
                      ),
                      ButtonSegment(
                        value: AppThemePreference.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('夜间'),
                      ),
                      ButtonSegment(
                        value: AppThemePreference.system,
                        icon: Icon(Icons.settings_brightness_outlined),
                        label: Text('跟随系统'),
                      ),
                    ],
                    selected: {controller.themePreference},
                    onSelectionChanged: (selection) {
                      controller.setThemePreference(selection.first);
                    },
                    showSelectedIcon: false,
                  ),
                ),
              ],
            ),
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
