import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/auth/ai_auth_session.dart';
import '../../../core/settings/app_settings.dart';
import '../../modules/presentation/modules_page.dart';
import 'ai_auth_page.dart';
import 'body_profile_page.dart';
import 'settings_page.dart';
import '../../updates/app_update_page.dart';
import '../../updates/app_update_notice.dart';
import 'contact_developer_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    this.aiAuthSession,
    this.updateNotice,
  });

  final AppController controller;
  final AiAuthSession? aiAuthSession;
  final AppUpdateNotice? updateNotice;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListTileTheme(
      data: const ListTileThemeData(minTileHeight: 52, minVerticalPadding: 8),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: const ValueKey('theme-mode-toggle'),
              tooltip: isDarkMode ? '切换至日间模式' : '切换至夜间模式',
              onPressed: () {
                controller.setThemePreference(
                  isDarkMode
                      ? AppThemePreference.light
                      : AppThemePreference.dark,
                );
              },
              icon: Icon(
                isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
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
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('profile-modules-entry'),
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('板块管理'),
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
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('profile-theme-entry'),
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsPage(controller: controller),
                    ),
                  ),
                ),
                const Divider(height: 1),
                if (aiAuthSession case final session?)
                  AnimatedBuilder(
                    animation: session,
                    builder: (context, _) => ListTile(
                      key: const ValueKey('profile-ai-auth-entry'),
                      leading: const Icon(Icons.security_outlined),
                      title: const Text('AI 服务账号'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => AiAuthPage(session: session),
                          ),
                        );
                      },
                    ),
                  )
                else
                  const ListTile(
                    key: ValueKey('profile-ai-auth-entry'),
                    enabled: false,
                    leading: Icon(Icons.security_outlined),
                    title: Text('AI 服务账号'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('更多', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.account_balance_wallet_outlined),
                  title: Text('我的钱包'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('profile-body-entry'),
                  leading: Icon(Icons.straighten_outlined),
                  title: const Text('我的身材'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            BodyProfilePage(controller: controller),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('联系开发者'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ContactDeveloperPage(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListenableBuilder(
                  listenable: updateNotice ?? controller,
                  builder: (context, _) => ListTile(
                    key: const ValueKey('profile-about-entry'),
                    leading: const Icon(Icons.system_update_outlined),
                    title: Row(
                      children: [
                        const Flexible(child: Text('关于与更新')),
                        if (updateNotice?.hasMinorUpdate == true) ...[
                          const SizedBox(width: 8),
                          Semantics(
                            label: '有新版本可更新',
                            child: Container(
                              key: const ValueKey('profile-update-dot'),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AppUpdatePage(notice: updateNotice),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
