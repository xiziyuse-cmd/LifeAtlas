import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WeatherAttribution extends StatelessWidget {
  const WeatherAttribution({super.key, this.showLabel = false});
  final bool showLabel;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      try {
        if (await launchUrl(
          Uri.parse('https://www.qweather.com'),
          mode: LaunchMode.externalApplication,
        )) {
          return;
        }
      } catch (_) {
        /* Report unsupported external browser below. */
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开官网：https://www.qweather.com')),
        );
      }
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        showLabel ? '来源：和风天气' : '和风天气',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    ),
  );
}
