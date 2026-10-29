import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/settings/app_settings.dart';

class BodyProfilePage extends StatelessWidget {
  const BodyProfilePage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('我的身材')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('性别', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('用于调整穿搭页面中的默认衣服品类。'),
            const SizedBox(height: 12),
            Card(
              child: RadioGroup<ProfileGender>(
                groupValue: controller.profileGender,
                onChanged: (value) {
                  if (value != null) {
                    controller.setProfileGender(value);
                  }
                },
                child: Column(
                  children: [
                    for (final gender in ProfileGender.values)
                      RadioListTile<ProfileGender>(
                        key: ValueKey('profile-gender-${gender.name}'),
                        title: Text(gender.label),
                        value: gender,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              controller.profileGender == ProfileGender.female
                  ? '穿搭中将显示内衣、裙装和连衣裙。'
                  : '内衣、裙装和连衣裙仅在选择女性时显示。',
            ),
          ],
        ),
      ),
    );
  }
}
