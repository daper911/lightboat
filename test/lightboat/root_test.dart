import 'package:fl_clash/lightboat/auth/credential_store.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/pages/home.dart';
import 'package:fl_clash/lightboat/pages/login.dart';
import 'package:fl_clash/lightboat/pages/logo.dart';
import 'package:fl_clash/lightboat/root.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'fakes.dart';
import 'ui_fakes.dart';

void main() {
  late MemoryStore store;
  late ProviderContainer container;

  setUp(() {
    setTestPackageInfo();
    store = MemoryStore();
    container = ProviderContainer(
      overrides: [
        lbPanelApiProvider.overrideWithValue(FakePanelApi()),
        lbCredentialStoreProvider.overrideWithValue(store),
        profilesProvider.overrideWith(TestProfiles.new),
        proxiesActionProvider.overrideWith(RecordingProxies.new),
        outboundIpProbeProvider.overrideWith(FakeProbe.new),
      ],
    );
    addTearDown(container.dispose);
    container
      ..listen(appSettingProvider, (_, _) {})
      ..listen(themeSettingProvider, (_, _) {})
      ..listen(patchClashConfigProvider, (_, _) {});
  });

  Future<void> pumpRoot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: LbRoot()),
      ),
    );
    await tester.pump();
  }

  test('prepare answers the FlClash prompts and sets the brand', () async {
    await lightboatPrepare(container);

    final app = container.read(appSettingProvider);
    expect(app.disclaimerAccepted, isTrue);
    expect(app.crashlyticsTip, isTrue);
    expect(app.crashlytics, isFalse);
    expect(app.autoCheckUpdate, isFalse);
    final theme = container.read(themeSettingProvider);
    expect(theme.primaryColor, LbColors.primary);
    expect(theme.themeMode, ThemeMode.system);
    expect(
      container.read(patchClashConfigProvider).globalUa,
      LbConfig.userAgent('0.3.0'),
    );
    expect(container.read(lbSessionProvider).phase, LbPhase.signedOut);
  });

  testWidgets('shows the seal until the session is restored', (tester) async {
    await pumpRoot(tester);
    expect(find.byType(LbLogo), findsOneWidget);
    expect(find.byType(LbLoginPage), findsNothing);

    await container.read(lbSessionProvider.notifier).restore();
    await tester.pump();
    expect(find.byType(LbLoginPage), findsOneWidget);
  });

  testWidgets('a stored session goes straight to the home page', (
    tester,
  ) async {
    store.saved = const LbStoredSession(jwt: 'jwt', email: 'a@example.com');
    await container.read(lbSessionProvider.notifier).restore();
    await pumpRoot(tester);
    expect(find.byType(LbHomePage), findsOneWidget);
  });
}
