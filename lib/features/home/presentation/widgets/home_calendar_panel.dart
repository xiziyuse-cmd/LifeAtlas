import 'package:flutter/material.dart';

import '../../domain/home_day_data.dart';

class HomeCalendarPanel extends StatelessWidget {
  const HomeCalendarPanel({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.days,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final Map<DateTime, HomeDayData> days;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onDateSelected;

  static const _background = Color(0xFF171C19);
  static const _surface = Color(0xFF222824);
  static const _primaryText = Color(0xFFF1F5F2);
  static const _secondaryText = Color(0xFF98A49D);
  static const _todayAccent = Color(0xFFB7E4C7);
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final selectedData =
        days[_dateOnly(selectedDate)] ?? HomeDayData.empty(selectedDate);

    return Container(
      key: const ValueKey('home-calendar-panel'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthHeader(
            month: month,
            onPreviousMonth: onPreviousMonth,
            onNextMonth: onNextMonth,
            onToday: onToday,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final weekday in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisSpacing = 2.0;
                const mainAxisSpacing = 1.0;
                final cellWidth =
                    (constraints.maxWidth - (crossAxisSpacing * 6)) / 7;
                final cellHeight =
                    (constraints.maxHeight - (mainAxisSpacing * 5)) / 6;

                return GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 42,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: cellWidth / cellHeight,
                    mainAxisSpacing: mainAxisSpacing,
                    crossAxisSpacing: crossAxisSpacing,
                  ),
                  itemBuilder: (context, index) {
                    final date = _dateForCell(index);
                    if (date == null) {
                      return const SizedBox.shrink();
                    }

                    final data =
                        days[_dateOnly(date)] ?? HomeDayData.empty(date);
                    return _CalendarDay(
                      date: date,
                      data: data,
                      isToday: _isSameDay(date, DateTime.now()),
                      isSelected: _isSameDay(date, selectedDate),
                      onTap: () => onDateSelected(date),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          const Row(
            children: [
              _MarkerLegend(color: Color(0xFF5FC3F2), label: '天气'),
              SizedBox(width: 12),
              _MarkerLegend(color: Color(0xFFFFB86B), label: '穿搭'),
              SizedBox(width: 12),
              _MarkerLegend(color: Color(0xFFC6A3FF), label: 'AI'),
            ],
          ),
          const SizedBox(height: 6),
          _SelectedDaySummary(data: selectedData),
        ],
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

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
  });

  final DateTime month;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${month.year}年 ${month.month}月',
            style: const TextStyle(
              color: HomeCalendarPanel._primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        _HeaderButton(
          tooltip: '上个月',
          icon: Icons.chevron_left,
          onPressed: onPreviousMonth,
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: onToday,
          style: TextButton.styleFrom(
            foregroundColor: HomeCalendarPanel._todayAccent,
            minimumSize: const Size(38, 32),
            padding: const EdgeInsets.symmetric(horizontal: 7),
          ),
          child: const Text('今天'),
        ),
        const SizedBox(width: 4),
        _HeaderButton(
          tooltip: '下个月',
          icon: Icons.chevron_right,
          onPressed: onNextMonth,
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: HomeCalendarPanel._primaryText,
        backgroundColor: HomeCalendarPanel._surface,
        minimumSize: const Size(32, 32),
      ),
      icon: Icon(icon, size: 19),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.data,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final HomeDayData data;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final markerColors = <Color>[
      if (data.hasWeatherRecord) const Color(0xFF5FC3F2),
      if (data.hasOutfitRecord) const Color(0xFFFFB86B),
      if (data.textEntries.isNotEmpty || data.imagePaths.isNotEmpty)
        const Color(0xFFC6A3FF),
    ];

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${date.year}年${date.month}月${date.day}日',
      child: InkWell(
        key: ValueKey('home-calendar-date-${date.toIso8601String()}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: FittedBox(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? HomeCalendarPanel._todayAccent
                      : Colors.transparent,
                  border: isToday && !isSelected
                      ? Border.all(
                          color: HomeCalendarPanel._todayAccent,
                          width: 1.4,
                        )
                      : null,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isSelected
                        ? HomeCalendarPanel._background
                        : HomeCalendarPanel._primaryText,
                    fontSize: 12,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                height: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in markerColors)
                      Container(
                        width: 5,
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: color,
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
    );
  }
}

class _MarkerLegend extends StatelessWidget {
  const _MarkerLegend({required this.color, required this.label});

  final Color color;
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
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: HomeCalendarPanel._secondaryText,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _SelectedDaySummary extends StatelessWidget {
  const _SelectedDaySummary({required this.data});

  final HomeDayData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: HomeCalendarPanel._surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${data.date.month}月${data.date.day}日',
                style: const TextStyle(
                  color: HomeCalendarPanel._primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '模拟当天信息',
                style: TextStyle(
                  color: HomeCalendarPanel._secondaryText,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '多云 26℃ · 轻薄上衣 / 长裤 · '
            'AI ${data.textEntries.isEmpty ? '暂无' : data.textEntries.last}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HomeCalendarPanel._secondaryText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
