import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import 'theme_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('外观', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            key: const ValueKey('settings-theme-entry'),
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主题'),
            subtitle: Text(controller.themePalette.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ThemeSettingsPage(controller: controller),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
