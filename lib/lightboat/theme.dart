import 'package:material_ui/material_ui.dart';

/// Brand palette from docs/lightboat/08-brand-and-ui.md §3.
class LbColors {
  final Color paper;
  final Color ink;
  final Color muted;
  final Color rule;
  final Color accent;
  final Color accentInk;
  final Color seal;
  final Color mist;

  const LbColors._({
    required this.paper,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.accent,
    required this.accentInk,
    required this.seal,
    required this.mist,
  });

  static const primary = 0xFF006C6C;

  static const light = LbColors._(
    paper: Color(0xFFFAF6EE),
    ink: Color(0xFF14212A),
    muted: Color(0xFF5B6770),
    rule: Color(0xFFDCD7CC),
    accent: Color(0xFF006C6C),
    accentInk: Color(0xFFFBF8F1),
    seal: Color(0xFFC5372F),
    mist: Color(0xFFBFD6D7),
  );

  static const dark = LbColors._(
    paper: Color(0xFF08131A),
    ink: Color(0xFFECE7DE),
    muted: Color(0xFF98A3AA),
    rule: Color(0xFF26323A),
    accent: Color(0xFF65BCB7),
    accentInk: Color(0xFF061118),
    seal: Color(0xFFDD574B),
    mist: Color(0xFF253C42),
  );

  static LbColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  Color get accentSoft => accent.withValues(alpha: 0.12);
}
