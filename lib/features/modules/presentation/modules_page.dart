import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';

class ModulesPage extends StatelessWidget {
  const ModulesPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('功能板块', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            key: const ValueKey('modules-outfit-switch'),
            secondary: const CircleAvatar(child: Icon(Icons.checkroom)),
            title: const Text('穿搭'),
            subtitle: const Text('衣柜、套装、穿搭记录与预购管理'),
            value: controller.outfitModuleEnabled,
            onChanged: controller.setOutfitModuleEnabled,
          ),
        ),
      ],
    );
  }
}
