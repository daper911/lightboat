import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/mobile/apps.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import 'ui_fakes.dart';

Package _package(String name, String label, {bool system = false}) => Package(
  packageName: name,
  label: label,
  system: system,
  internet: true,
  lastUpdateTime: 0,
);

final _packages = [
  _package('com.eg.android.AlipayGphone', '支付宝'),
  _package('com.tencent.mm', '微信'),
  _package('com.google.android.youtube', 'YouTube'),
  _package('com.android.settings', '设置', system: true),
];

void main() {
  late FakeSystemAction systemAction;
  late ProviderContainer container;

  setUp(() {
    systemAction = FakeSystemAction()..packages = _packages;
    container = ProviderContainer(
      overrides: [systemActionProvider.overrideWith(() => systemAction)],
    );
    addTearDown(container.dispose);
    container.listen(vpnSettingProvider, (_, _) {});
  });

  Future<void> pumpApps(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LbAppsPage()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  AccessControlProps saved() =>
      container.read(vpnSettingProvider).accessControlProps;

  testWidgets('is off until enabled, then lists apps to exclude', (
    tester,
  ) async {
    await pumpApps(tester);
    expect(find.text('支付宝'), findsNothing);

    await tester.tap(find.text(LbStrings.splitEnable));
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.splitExclude), findsOneWidget);
    expect(find.text('支付宝'), findsOneWidget);
    expect(find.text('设置'), findsNothing);

    await tester.tap(find.text('支付宝'));
    await tester.pump();
    expect(find.text(LbStrings.splitSelected(1)), findsOneWidget);

    await leave(tester);
    expect(saved().enable, isTrue);
    expect(saved().mode, AccessControlMode.rejectSelected);
    expect(saved().rejectList, ['com.eg.android.AlipayGphone']);
  });

  testWidgets('can let only the chosen apps through', (tester) async {
    await pumpApps(tester);
    await tester.tap(find.text(LbStrings.splitEnable));
    await tester.pumpAndSettle();

    await tester.tap(find.text(LbStrings.splitInclude));
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.splitPickChina), findsNothing);
    await tester.tap(find.text('YouTube'));
    await tester.pump();

    await leave(tester);
    expect(saved().mode, AccessControlMode.acceptSelected);
    expect(saved().acceptList, ['com.google.android.youtube']);
  });

  testWidgets('searches and reveals system apps', (tester) async {
    await pumpApps(tester);
    await tester.tap(find.text(LbStrings.splitEnable));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'tube');
    await tester.pump();
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('微信'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('leaving without changes saves nothing', (tester) async {
    await pumpApps(tester);
    final before = saved();
    await leave(tester);
    expect(identical(saved(), before), isTrue);
  });

  testWidgets('asks for the app list permission when it is missing', (
    tester,
  ) async {
    systemAction.permissionGranted = false;
    await pumpApps(tester);
    await tester.tap(find.text(LbStrings.splitEnable));
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.splitNeedPermission), findsOneWidget);

    await tester.tap(find.text(LbStrings.splitGrant));
    await tester.pumpAndSettle();
    expect(find.text('支付宝'), findsOneWidget);
  });
}
