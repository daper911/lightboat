import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import 'ui_fakes.dart';

const _latest = {
  'version': '0.4.0',
  'build': 5,
  'min_build': 3,
  'notes': '· 修复全局模式',
  'android': {
    'arm64-v8a': {'url': 'https://cdn.example/a.apk', 'sha256': 'x'},
  },
  'windows': {
    'amd64-setup': {'url': 'https://cdn.example/w.exe', 'sha256': 'y'},
  },
};

class _Adapter implements HttpClientAdapter {
  RequestOptions? seen;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options;
    return ResponseBody.fromString(
      jsonEncode(_latest),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('picks the installer for each platform', () {
    expect(LbRelease.fromJson(_latest, 'android')?.url, contains('a.apk'));
    expect(LbRelease.fromJson(_latest, 'windows')?.url, contains('w.exe'));
    expect(LbRelease.fromJson(_latest, 'linux'), isNull);
  });

  test('a platform entry carries its own version when it trails', () {
    final release = LbRelease.fromJson({
      ..._latest,
      'windows': {
        'version': '0.3.9',
        'build': 4,
        'amd64-setup': {'url': 'https://cdn.example/w.exe'},
      },
    }, 'windows')!;
    expect(release.version, '0.3.9');
    expect(release.isNewerThan(4), isFalse);
    expect(LbRelease.fromJson(_latest, 'android')!.build, 5);
  });

  test('compares builds and knows when an update is required', () {
    final release = LbRelease.fromJson(_latest, 'android')!;
    expect(release.isNewerThan(4), isTrue);
    expect(release.isNewerThan(5), isFalse);
    expect(release.isRequiredFor(2), isTrue);
    expect(release.isRequiredFor(3), isFalse);
  });

  test('fetches latest.json past any cache', () async {
    final adapter = _Adapter();
    final release = await lbFetchRelease(adapter: adapter, platform: 'windows');
    expect(release?.version, '0.4.0');
    expect(adapter.seen?.uri.toString(), startsWith(LbConfig.releaseUrl));
    expect(adapter.seen?.uri.queryParameters, contains('t'));
  });

  Future<BuildContext> pump(WidgetTester tester) async {
    setTestPackageInfo();
    late BuildContext context;
    await tester.pumpWidget(
      TestApp(
        child: Scaffold(
          body: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return context;
  }

  LbRelease release({required int build, int minBuild = 0}) => LbRelease(
    version: '9.9.9',
    build: build,
    minBuild: minBuild,
    notes: '· 新功能',
    url: 'https://cdn.example/a.apk',
  );

  testWidgets('offers a newer build and lets the user put it off', (
    tester,
  ) async {
    final context = await pump(tester);
    final check = lbCheckForUpdate(
      context,
      manual: true,
      fetch: () async => release(build: 9999),
    );
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.newVersion('9.9.9')), findsOneWidget);
    expect(find.text('· 新功能'), findsOneWidget);
    await tester.tap(find.text(LbStrings.later));
    await tester.pumpAndSettle();
    await check;
    expect(find.text(LbStrings.newVersion('9.9.9')), findsNothing);
  });

  testWidgets('a required update cannot be put off', (tester) async {
    final context = await pump(tester);
    unawaited(
      lbCheckForUpdate(
        context,
        manual: true,
        fetch: () async => release(build: 9999, minBuild: 9998),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.later), findsNothing);
    expect(find.text(LbStrings.download), findsOneWidget);
  });

  testWidgets('a manual check reports when nothing is newer', (tester) async {
    final context = await pump(tester);
    await lbCheckForUpdate(
      context,
      manual: true,
      fetch: () async => release(build: 0),
    );
    await tester.pump();
    expect(find.text(LbStrings.upToDate), findsOneWidget);
  });

  test('reads the plain build out of an Android per-ABI versionCode', () {
    expect(lbInstalledBuild('2007'), 7);
    expect(lbInstalledBuild('7'), 7);
    expect(lbInstalledBuild(''), 0);
  });
}
