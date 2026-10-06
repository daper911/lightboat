import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One platform's entry of `latest.json` (05 §4). Builds are the `+N` of the
/// shared pubspec version; each platform carries its own, since its installer
/// can trail the other's.
class LbRelease {
  final String version;
  final int build;
  final int minBuild;
  final String notes;
  final String url;

  const LbRelease({
    required this.version,
    required this.build,
    required this.minBuild,
    required this.notes,
    required this.url,
  });

  static LbRelease? fromJson(Map<String, Object?> json, String platform) {
    final (section, file) = switch (platform) {
      'android' => ('android', 'arm64-v8a'),
      'windows' => ('windows', 'amd64-setup'),
      _ => (platform, ''),
    };
    final platformEntry = json[section] as Map?;
    final entry = platformEntry?[file] as Map?;
    final url = entry?['url'] as String?;
    if (url == null || url.isEmpty) return null;
    return LbRelease(
      version:
          platformEntry?['version'] as String? ??
          json['version'] as String? ??
          '',
      build:
          (platformEntry?['build'] as num?)?.toInt() ??
          (json['build'] as num?)?.toInt() ??
          0,
      minBuild: (json['min_build'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String? ?? '',
      url: url,
    );
  }

  bool isNewerThan(int current) => build > current;

  bool isRequiredFor(int current) => current < minBuild;
}

Future<LbRelease?> lbFetchRelease({
  HttpClientAdapter? adapter,
  String platform = '',
}) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  final response = await dio.get<Object?>(
    LbConfig.releaseUrl,
    queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
  );
  final data = response.data;
  if (data is! Map) return null;
  return LbRelease.fromJson(
    data.cast<String, Object?>(),
    platform.isNotEmpty ? platform : Platform.operatingSystem,
  );
}

/// Android's split-per-ABI build adds 1000 × the ABI code to the versionCode
/// (arm64-v8a turns build 7 into 2007), while `latest.json` carries the
/// plain build of the shared pubspec version.
int lbInstalledBuild(String buildNumber) =>
    (int.tryParse(buildNumber) ?? 0) % 1000;

const _checkedAtKey = 'lb_update_checked_at';
const _autoCheckEvery = Duration(hours: 12);

/// Automatic checks run at most every 12 hours and stay silent unless there is
/// something to install; [manual] also reports "up to date" and failures.
Future<void> lbCheckForUpdate(
  BuildContext context, {
  bool manual = false,
  Future<LbRelease?> Function() fetch = lbFetchRelease,
}) async {
  if (!manual) {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_checkedAtKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _autoCheckEvery.inMilliseconds) return;
    await prefs.setInt(_checkedAtKey, now);
  }
  final current = lbInstalledBuild(globalState.packageInfo.buildNumber);
  final LbRelease? release;
  try {
    release = await fetch();
  } catch (error) {
    commonPrint.log('lightboat update check: $error');
    if (manual && context.mounted) {
      lbToast(context, LbStrings.updateCheckFailed, error: true);
    }
    return;
  }
  if (release == null || !release.isNewerThan(current)) {
    if (manual && context.mounted) lbToast(context, LbStrings.upToDate);
    return;
  }
  if (!context.mounted) return;
  await _showRelease(
    context,
    release,
    required: release.isRequiredFor(current),
  );
}

Future<void> _showRelease(
  BuildContext context,
  LbRelease release, {
  required bool required,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !required,
    builder: (context) => PopScope(
      canPop: !required,
      child: AlertDialog(
        title: Text(LbStrings.newVersion(release.version)),
        content: SingleChildScrollView(
          child: Text(
            [
              if (required) LbStrings.updateRequired,
              if (release.notes.isNotEmpty) release.notes,
            ].join('\n\n'),
          ),
        ),
        actions: [
          if (!required)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(LbStrings.later),
            ),
          TextButton(
            onPressed: () => unawaited(lbOpenUrl(release.url)),
            child: const Text(LbStrings.download),
          ),
        ],
      ),
    ),
  );
}
