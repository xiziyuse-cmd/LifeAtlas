import 'package:flutter/material.dart';

import '../../domain/home_day_data.dart';

class HomeCalendarCard extends StatelessWidget {
  const HomeCalendarCard({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.days,
    required this.isLoading,
    required this.loadError,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final Map<DateTime, HomeDayData> days;
  final bool isLoading;
  final String? loadError;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onDateSelected;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final selectedData =
        days[_dateOnly(selectedDate)] ?? HomeDayData.empty(selectedDate);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${month.year}年${month.month}月',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '上个月',
                  onPressed: onPreviousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton(onPressed: onToday, child: const Text('今天')),
                IconButton(
                  tooltip: '下个月',
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (isLoading) const LinearProgressIndicator(minHeight: 2),
            if (loadError != null) ...[
              const SizedBox(height: 8),
              _InlineNotice(message: loadError!),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                for (final weekday in _weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        weekday,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 42,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.88,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (context, index) {
                final date = _dateForCell(index);
                if (date == null) {
                  return const SizedBox.shrink();
                }
                return _CalendarDayCell(
                  date: date,
                  data: days[_dateOnly(date)] ?? HomeDayData.empty(date),
                  isSelected: _isSameDay(date, selectedDate),
                  isToday: _isSameDay(date, DateTime.now()),
                  onTap: () => onDateSelected(date),
                );
              },
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _MarkerLegend(marker: HomeDayMarker.weather, label: '天气'),
                _MarkerLegend(marker: HomeDayMarker.outfit, label: '穿搭'),
                _MarkerLegend(marker: HomeDayMarker.text, label: '文字'),
                _MarkerLegend(marker: HomeDayMarker.image, label: '图片'),
              ],
            ),
            const SizedBox(height: 16),
            _SelectedDayDetails(data: selectedData),
          ],
        ),
      ),
    );
  }

  DateTime? _dateForCell(int index) {
    final firstDay = DateTime(month.year, month.month);
    final leadingEmptyCells = firstDay.weekday - DateTime.monday;
    final day = index - leadingEmptyCells + 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    if (day < 1 || day > daysInMonth) {
      return null;
    }
    return DateTime(month.year, month.month, day);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.data,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final HomeDayData data;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${date.year}年${date.month}月${date.day}日',
      child: Material(
        color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isToday
              ? BorderSide(color: colorScheme.primary)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('home-calendar-day-${date.toIso8601String()}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : null,
                        fontWeight: isToday || isSelected
                            ? FontWeight.w700
                            : null,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final marker in data.markers)
                        Container(
                          width: 5,
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: _markerColor(marker, colorScheme),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerLegend extends StatelessWidget {
  const _MarkerLegend({required this.marker, required this.label});

  final HomeDayMarker marker;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 4,
          decoration: BoxDecoration(
            color: _markerColor(marker, Theme.of(context).colorScheme),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _SelectedDayDetails extends StatelessWidget {
  const _SelectedDayDetails({required this.data});

  final HomeDayData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final weather = data.hasWeatherRecord
        ? _weatherDescription(data)
        : '暂无天气记录';
    final outfit = data.hasOutfitRecord ? '已记录当日穿搭' : '暂无穿搭记录';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${data.date.month}月${data.date.day}日',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _DetailRow(icon: Icons.cloud_outlined, label: '天气', value: weather),
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.checkroom_outlined,
              label: '穿搭',
              value: outfit,
            ),
            if (data.textEntries.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.notes_outlined,
                label: '文字',
                value: data.textEntries.last,
              ),
            ],
            if (data.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.image_outlined,
                label: '图片',
                value: '${data.imagePaths.length} 张',
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _weatherDescription(HomeDayData data) {
    final parts = <String>[
      if (data.weatherType != null && data.weatherType!.isNotEmpty)
        data.weatherType!,
      if (data.currentTemperature != null)
        '${_formatTemperature(data.currentTemperature!)}°',
      if (data.minTemperature != null && data.maxTemperature != null)
        '${_formatTemperature(data.minTemperature!)}°～'
            '${_formatTemperature(data.maxTemperature!)}°',
    ];
    return parts.isEmpty ? '已记录天气' : parts.join(' · ');
  }

  static String _formatTemperature(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: colorScheme.primary),
        const SizedBox(width: 9),
        SizedBox(
          width: 38,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _markerColor(HomeDayMarker marker, ColorScheme colorScheme) {
  return switch (marker) {
    HomeDayMarker.weather => Colors.blue.shade500,
    HomeDayMarker.outfit => colorScheme.tertiary,
    HomeDayMarker.text => colorScheme.primary,
    HomeDayMarker.image => Colors.pink.shade400,
  };
}
