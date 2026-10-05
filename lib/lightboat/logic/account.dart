import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// False when the user closes the slide captcha instead of solving it.
Future<bool> lbWithCaptcha(
  Future<void> Function(String? ticket) attempt,
  Future<String?> Function() solve,
) async {
  try {
    await attempt(null);
  } on PanelException catch (error) {
    if (error.code != LbErrorCode.captchaRequired) rethrow;
    final ticket = await solve();
    if (ticket == null) return false;
    await attempt(ticket);
  }
  return true;
}

/// The panel's `verify_code_interval`; it rejects earlier resends anyway.
class LbResendCountdown extends ValueNotifier<int> {
  static const seconds = 60;

  Timer? _timer;

  LbResendCountdown() : super(0);

  void start() {
    _timer?.cancel();
    value = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (value <= 1) {
        timer.cancel();
        value = 0;
        return;
      }
      value--;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Announcements are short; plain text keeps them readable without a Markdown
/// renderer. Links keep their address so they can still be copied.
String lbMarkdownToText(String markdown) => markdown
    .replaceAllMapped(RegExp(r'!\[([^\]]*)\]\(([^)]*)\)'), (m) => m[1] ?? '')
    .replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => m[1] == m[2] ? m[2]! : '${m[1]}（${m[2]}）',
    )
    .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
    .replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '')
    .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '· ')
    .replaceAll(RegExp(r'(\*\*|__|~~|`)'), '')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

final lbAnnouncementsProvider =
    FutureProvider.autoDispose<List<LbAnnouncement>>(
      (ref) => ref
          .read(lbSessionProvider.notifier)
          .authed((api, jwt) => api.announcements(jwt)),
    );

const _seenKey = 'lb_seen_popup_announcements';

Future<LbAnnouncement?> lbTakeNewPopup(List<LbAnnouncement> items) async {
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getStringList(_seenKey) ?? const [];
  final next = items.firstWhereOrNull(
    (item) => item.popup && !seen.contains('${item.id}'),
  );
  if (next != null) {
    await prefs.setStringList(_seenKey, [...seen, '${next.id}']);
  }
  return next;
}
