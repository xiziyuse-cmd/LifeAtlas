import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../../core/settings/app_settings.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('主题')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text('外观模式', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SegmentedButton<AppThemePreference>(
          segments: const [
            ButtonSegment(
              value: AppThemePreference.system,
              label: Text('跟随系统'),
              icon: Icon(Icons.brightness_auto),
            ),
            ButtonSegment(
              value: AppThemePreference.light,
              label: Text('浅色'),
              icon: Icon(Icons.light_mode_outlined),
            ),
            ButtonSegment(
              value: AppThemePreference.dark,
              label: Text('深色'),
              icon: Icon(Icons.dark_mode_outlined),
            ),
          ],
          selected: {controller.themePreference},
          onSelectionChanged: (value) =>
              controller.setThemePreference(value.single),
        ),
        const SizedBox(height: 24),
        Text('主题配色', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '选择后立即应用到整个 LifeAtlas',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 600 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: AppThemePalette.values.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 174,
              ),
              itemBuilder: (context, index) => _ThemePreviewCard(
                palette: AppThemePalette.values[index],
                controller: controller,
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({required this.palette, required this.controller});
  final AppThemePalette palette;
  final AppController controller;
  static const colors = {
    AppThemePalette.defaultTheme: [
      Color(0xFF496B59),
      Color(0xFFF7F8F5),
      Colors.white,
    ],
    AppThemePalette.milkPudding: [
      Color(0xFFD3A936),
      Color(0xFFFFFAE9),
      Color(0xFFFFFEF8),
    ],
    AppThemePalette.mintSoda: [
      Color(0xFF55A98A),
      Color(0xFFF0FAF5),
      Colors.white,
    ],
    AppThemePalette.berryShake: [
      Color(0xFFC9798D),
      Color(0xFFFFF3F5),
      Color(0xFFFFFBF9),
    ],
    AppThemePalette.seaSaltSoda: [
      Color(0xFF5B91C9),
      Color(0xFFF1F8FD),
      Colors.white,
    ],
    AppThemePalette.woodLatte: [
      Color(0xFF987258),
      Color(0xFFFAF5EC),
      Colors.white,
    ],
  };
  @override
  Widget build(BuildContext context) {
    final selected = controller.themePalette == palette;
    final swatches = colors[palette]!;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        key: ValueKey('theme-${palette.name}'),
        onTap: () => controller.setThemePalette(palette),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: swatches[1],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: swatches[0],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: swatches[2],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            SizedBox(
                              width: 24,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 8,
                                    backgroundColor: swatches[0],
                                  ),
                                  const SizedBox(height: 7),
                                  Expanded(
                                    child: Container(color: swatches[2]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                palette.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      palette.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (selected)
                    const Text(
                      '✓ 当前使用',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
