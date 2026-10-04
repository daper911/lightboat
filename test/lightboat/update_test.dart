import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/update.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
