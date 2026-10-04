import 'package:material_ui/material_ui.dart';

/// Bundled subset of Noto Serif SC holding only 轻舟已过万重山; any other
/// character falls back to the system font.
const lbSerif = 'LightboatSerif';

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

extension LbThemeData on ThemeData {
  /// Paper backgrounds and brand-coloured dialogs and snack bars for every
  /// route, so pages and FlClash's own dialogs need no per-widget colours.
  ThemeData get withLightboatBrand {
    final colors = brightness == Brightness.dark
        ? LbColors.dark
        : LbColors.light;
    return copyWith(
      scaffoldBackgroundColor: colors.paper,
      appBarTheme: appBarTheme.copyWith(
        backgroundColor: colors.paper,
        foregroundColor: colors.ink,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: dialogTheme.copyWith(
        backgroundColor: colors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.paper),
        actionTextColor: colors.mist,
      ),
      progressIndicatorTheme: progressIndicatorTheme.copyWith(
        color: colors.accent,
      ),
    );
  }
}

/// One look for every short message; errors use the seal red (08 §3).
void lbToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? LbColors.of(context).seal : null,
      ),
    );
}
