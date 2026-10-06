import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/events.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _redactions = <(RegExp, String Function(Match))>[
  (RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+'), (_) => '<jwt>'),
  (RegExp(r'(token=)[^&\s"]+', caseSensitive: false), (m) => '${m[1]}<token>'),
  (
    RegExp(r'("?(?:password|token|uuid|captcha_ticket)"?\s*:\s*)"?[^",}\s]+"?'),
    (m) => '${m[1]}<hidden>',
  ),
  (
    RegExp(
      r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
      caseSensitive: false,
    ),
    (_) => '<uuid>',
  ),
  (RegExp(r'\b[0-9a-f]{32}\b', caseSensitive: false), (_) => '<token>'),
  (
    RegExp(r'\b([\w.+-])[\w.+-]*@([\w-]+\.[\w.-]+)\b'),
    (m) => '${m[1]}***@${m[2]}',
  ),
];

/// Masks what CLAUDE.md §3.6 keeps out of exported logs; e-mail keeps its
/// first letter and domain so support can still tell users apart.
String lbRedact(String text) => _redactions.fold(
  text,
  (result, rule) => result.replaceAllMapped(rule.$1, rule.$2),
);

String lbDiagnosticSummary({
  required String version,
  required String system,
  required LbSessionState session,
  required bool running,
  required int? runTime,
  required Mode mode,
  required List<Group> groups,
  required DateTime now,
}) {
  final subscription = session.subscription;
  final expired = session.hasJwt ? '' : '（登录已过期）';
  final modeName = switch (mode) {
    Mode.global => '全局',
    Mode.rule => '智能分流',
    _ => mode.name,
  };
  final lines = [
    '轻舟诊断日志',
    '导出时间：${now.toIso8601String()}',
    '版本：$version',
    '系统：$system',
    '账号：${session.email ?? '未登录'}$expired',
    '套餐：${subscription == null ? '无' : _plan(subscription, now)}',
    '连接：${running ? '已连接 ${(runTime ?? 0) ~/ 1000} 秒' : '未连接'}',
    '模式：$modeName',
    '分组：',
    for (final group in groups)
      '  ${group.name} → ${group.now ?? ''}${group.hidden == true ? '（隐藏）' : ''}',
  ];
  return lines.join('\n');
}

String _plan(LbSubscription subscription, DateTime now) {
  final expire = subscription.expireTime == 0
      ? '不限期'
      : '${lbFormatDate(subscription.expireTime)} 到期'
            '${subscription.isExpired(now) ? '（已过期）' : ''}';
  final traffic = subscription.traffic > 0
      ? '${lbFormatBytes(subscription.used)} / ${lbFormatBytes(subscription.traffic)}'
      : '${lbFormatBytes(subscription.used)} / 不限';
  return '${subscription.name} · $expire · $traffic';
}

Future<String> _system() async {
  try {
    return switch (await DeviceInfoPlugin().deviceInfo) {
      AndroidDeviceInfo(:final manufacturer, :final model, :final version) =>
        'Android ${version.release}（SDK ${version.sdkInt}）· '
            '$manufacturer $model',
      WindowsDeviceInfo(
        :final productName,
        :final displayVersion,
        :final buildNumber,
      ) =>
        '$productName $displayVersion（build $buildNumber）',
      _ => '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    };
  } catch (_) {
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }
}

Future<String> _summary(WidgetRef ref) async {
  final info = globalState.packageInfo;
  return lbDiagnosticSummary(
    version: '${info.version}（${info.buildNumber}）',
    system: await _system(),
    session: ref.read(lbSessionProvider),
    running: ref.read(isStartProvider),
    runTime: ref.read(runTimeProvider),
    mode: ref.read(patchClashConfigProvider).mode,
    groups: ref.read(groupsProvider),
    now: DateTime.now(),
  );
}

String lbEventLines(List<LbEvent> events) => [
  LbStrings.eventsHeading,
  if (events.isEmpty) LbStrings.noEvents,
  for (final event in events) event.format(),
].join('\n');

/// Short enough to paste into a chat: the summary and the app's own recent
/// requests, without the Core's log.
Future<String> lbDiagnosticBrief(WidgetRef ref) async => lbRedact(
  '${await _summary(ref)}\n\n${lbEventLines(lbEvents.recent(20))}\n',
);

/// The redacted text both the export and the upload hand over.
Future<String> lbDiagnosticText(WidgetRef ref) async {
  final logs = await encodeLogsTask(ref.read(logsProvider).list);
  return lbRedact(
    '${await _summary(ref)}\n\n${lbEventLines(lbEvents.recent())}\n\n'
    '${LbStrings.logsHeading}\n$logs\n',
  );
}

/// False when the user cancelled the save dialog.
Future<bool> lbExportLogs(WidgetRef ref) async {
  final text = await lbDiagnosticText(ref);
  final path = await appPath.tempFilePath;
  await File(path).safeWriteAsString(text);
  final stamp = DateTime.now()
      .toIso8601String()
      .replaceAll(RegExp(r'[:.]'), '-')
      .substring(0, 19);
  return await picker.saveFileWithPath('lightboat-log-$stamp.txt', path) !=
      null;
}

/// The upload's id, for the user to quote to support.
Future<String> lbUploadLogs(WidgetRef ref) async =>
    ref.read(lbPanelApiProvider).uploadDiagnostics(await lbDiagnosticText(ref));
