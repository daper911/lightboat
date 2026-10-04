import 'dart:io';

import 'package:fl_clash/lightboat/trust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled roots parse into an empty context', () {
    final context = SecurityContext(withTrustedRoots: false);
    expect(() => lbTrustBundledRoots(context), returnsNormally);
  });

  test('adding the roots twice to the default context is harmless', () {
    lbTrustBundledRoots();
    expect(lbTrustBundledRoots, returnsNormally);
  });
}
