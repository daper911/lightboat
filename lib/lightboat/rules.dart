import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';

const _bundleDir = 'assets/lightboat/rules';

/// Puts the bundled rule sets where FlClash points each rule provider of the
/// profile (`confineProviders`: md5 of `name@url`), so the first setup reads
/// them from disk instead of fetching 5 MB before the Core answers. They are
/// backdated, which makes the Core refresh them in the background at once.
Future<void> lbSeedRuleSets(String rulesDir, {AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  try {
    final manifest =
        jsonDecode(await assets.loadString('$_bundleDir/manifest.json'))
            as List;
    for (final entry in manifest.cast<Map<String, Object?>>()) {
      final file = File(
        join(rulesDir, '${entry['name']}@${entry['url']}'.toMd5()),
      );
      if (await file.exists()) continue;
      final data = await assets.load('$_bundleDir/${entry['file']}');
      await file.create(recursive: true);
      await file.writeAsBytes(gzip.decode(data.buffer.asUint8List()));
      await file.setLastModified(DateTime(2000));
    }
  } catch (error) {
    commonPrint.log('lightboat seed rules: $error');
  }
}
