import 'package:flutter/material.dart';

enum WardrobeTagKind {
  season('季节'),
  category('种类'),
  brand('品牌');

  const WardrobeTagKind(this.label);
  final String label;
}

class WardrobeTagColors {
  const WardrobeTagColors(this.background, this.foreground);
  final Color background, foreground;

  static WardrobeTagColors of(BuildContext context, WardrobeTagKind kind) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch ((kind, dark)) {
      (WardrobeTagKind.season, false) => const WardrobeTagColors(
        Color(0xFFE4F2E7),
        Color(0xFF245D36),
      ),
      (WardrobeTagKind.category, false) => const WardrobeTagColors(
        Color(0xFFE3EDFC),
        Color(0xFF234F89),
      ),
      (WardrobeTagKind.brand, false) => const WardrobeTagColors(
        Color(0xFFF0E7F8),
        Color(0xFF664084),
      ),
      (WardrobeTagKind.season, true) => const WardrobeTagColors(
        Color(0xFF203B2B),
        Color(0xFFB4E6BF),
      ),
      (WardrobeTagKind.category, true) => const WardrobeTagColors(
        Color(0xFF20344F),
        Color(0xFFB9D5FF),
      ),
      (WardrobeTagKind.brand, true) => const WardrobeTagColors(
        Color(0xFF3A294A),
        Color(0xFFE4C5FC),
      ),
    };
  }
}

class WardrobeTag extends StatelessWidget {
  const WardrobeTag({
    super.key,
    required this.label,
    required this.kind,
    this.icon,
  });
  final String label;
  final WardrobeTagKind kind;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final colors = WardrobeTagColors.of(context, kind);
    return Semantics(
      label: '${kind.label}：$label',
      child: ExcludeSemantics(
        child: Chip(
          label: Text(label),
          avatar: icon == null
              ? null
              : Icon(icon, size: 18, color: colors.foreground),
          backgroundColor: colors.background,
          labelStyle: TextStyle(color: colors.foreground),
          side: BorderSide(color: colors.foreground.withValues(alpha: .3)),
        ),
      ),
    );
  }
}
