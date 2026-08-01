import 'package:flutter/material.dart';

import '../../domain/weather_model.dart';

class HomeWeatherCard extends StatelessWidget {
  const HomeWeatherCard({
    super.key,
    required this.weather,
    required this.isLoading,
  });

  final WeatherModel weather;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label:
          '模拟天气：${weather.status}，'
          '当前${_temperature(weather.currentTemperature)}度，'
          '${_temperature(weather.minTemperature)}到'
          '${_temperature(weather.maxTemperature)}度',
      child: Container(
        key: const ValueKey('home-weather-bar'),
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: isLoading
                  ? SizedBox.square(
                      key: const ValueKey('weather-loading'),
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.primary,
                      ),
                    )
                  : Text(
                      weather.icon,
                      key: ValueKey(weather.icon),
                      style: const TextStyle(fontSize: 29),
                    ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        weather.status,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (weather.isSimulated) ...[
                        const SizedBox(width: 7),
                        Text(
                          '模拟',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_temperature(weather.minTemperature)}℃ - '
                    '${_temperature(weather.maxTemperature)}℃',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_temperature(weather.currentTemperature)}℃',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _temperature(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}
