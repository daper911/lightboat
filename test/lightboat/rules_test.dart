import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/lightboat/rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('lb_rules'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('seeds every bundled rule set where FlClash will look', () async {
    final manifest =
        jsonDecode(
              await rootBundle.loadString(
                'assets/lightboat/rules/manifest.json',
              ),
            )
            as List;
    final kept = File(
      join(
        dir.path,
        '${manifest.first['name']}@${manifest.first['url']}'.toMd5(),
      ),
    )..writeAsStringSync('payload: [kept]');

    await lbSeedRuleSets(dir.path);

    expect(dir.listSync(), hasLength(manifest.length));
    expect(kept.readAsStringSync(), 'payload: [kept]');
    final seeded = File(
      join(
        dir.path,
        '${manifest.last['name']}@${manifest.last['url']}'.toMd5(),
      ),
    );
    expect(seeded.readAsStringSync(), contains('payload:'));
    expect(seeded.lastModifiedSync().year, 2000);
  });
}
