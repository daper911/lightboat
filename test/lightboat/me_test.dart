import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/auth/credential_store.dart';
import 'package:fl_clash/lightboat/pages/apps.dart';
import 'package:fl_clash/lightboat/pages/login.dart';
import 'package:fl_clash/lightboat/pages/me.dart';
import 'package:fl_clash/lightboat/pages/purchase.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'fakes.dart';
import 'ui_fakes.dart';

LbSubscription _plan(int id, String name) => LbSubscription(
  id: id,
  planId: 3,
  token: 't$id',
  name: name,
  status: LbPlanStatus.active,
  expireTime: DateTime(2026, 11, 4).millisecondsSinceEpoch,
  traffic: 0,
  upload: 0,
  download: 0,
);

void main() {
  late MemoryStore store;
  late ProviderContainer container;

  setUp(setTestPackageInfo);

  Future<void> pumpMe(
    WidgetTester tester, {
    bool withJwt = true,
    List<LbSubscription>? plans,
  }) async {
    final subscriptions = plans ?? [_plan(9, '基础版')];
    store = MemoryStore()
      ..saved = LbStoredSession(
        jwt: withJwt ? 'jwt' : null,
        email: 'a@example.com',
        subscription: subscriptions.first,
        subscriptions: subscriptions,
      );
    final systemAction = FakeSystemAction();
    container = ProviderContainer(
      overrides: [
        lbPanelApiProvider.overrideWithValue(FakePanelApi()),
        lbCredentialStoreProvider.overrideWithValue(store),
        profilesProvider.overrideWith(TestProfiles.new),
        systemActionProvider.overrideWith(() => systemAction),
      ],
    );
    addTearDown(container.dispose);
    await container.read(lbSessionProvider.notifier).restore();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: LbMePage()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the account and its plan', (tester) async {
    await pumpMe(tester);

    expect(find.text('a@example.com'), findsOneWidget);
    expect(find.text('基础版 · 到期 2026-11-04'), findsOneWidget);
    expect(find.text(LbStrings.renew), findsOneWidget);
    expect(find.text(LbStrings.splitTunnel), findsOneWidget);
    expect(find.text(LbStrings.loginExpired), findsNothing);
    expect(find.text(LbStrings.switchPlan), findsNothing);
    expect(find.text(LbStrings.advanced), findsNothing);
  });

  testWidgets('renewal opens in the app', (tester) async {
    await pumpMe(tester);

    await tester.tap(find.text(LbStrings.renew));
    await tester.pumpAndSettle();
    expect(find.byType(LbPurchasePage), findsOneWidget);
  });

  testWidgets('an expired login offers to sign in again', (tester) async {
    await pumpMe(tester, withJwt: false);

    expect(find.text(LbStrings.loginExpired), findsOneWidget);
    await tester.tap(find.text(LbStrings.relogin));
    await tester.pumpAndSettle();
    expect(find.byType(LbLoginPage), findsOneWidget);
  });

  testWidgets('lists the plans to switch between', (tester) async {
    await pumpMe(tester, plans: [_plan(9, '基础版'), _plan(10, '高级版')]);

    await tester.tap(find.text(LbStrings.switchPlan));
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(find.text('高级版 · 2026-11-04'), findsOneWidget);
  });

  testWidgets('seven taps on 关于 reveal the FlClash screens', (tester) async {
    await pumpMe(tester);

    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text(LbStrings.about));
      await tester.pumpAndSettle();
      expect(find.text('${LbStrings.version} 0.3.0'), findsOneWidget);
      expect(find.text(LbStrings.sourceCode), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
    expect(find.text(LbStrings.advanced), findsOneWidget);
  });

  testWidgets('opens the split tunneling page', (tester) async {
    await pumpMe(tester);

    await tester.tap(find.text(LbStrings.splitTunnel));
    await tester.pumpAndSettle();
    expect(find.byType(LbAppsPage), findsOneWidget);
  });

  testWidgets('refreshing says how it went', (tester) async {
    await pumpMe(tester);

    await tester.tap(find.text(LbStrings.refreshPlan));
    await tester.pumpAndSettle();
    final ended =
        find.text(LbStrings.refreshDone).evaluate().isNotEmpty ||
        find.text(LbStrings.syncFailed).evaluate().isNotEmpty;
    expect(ended, isTrue);
  });

  testWidgets('logging out asks first, then clears the session', (
    tester,
  ) async {
    await pumpMe(tester);

    await tester.tap(find.text(LbStrings.logout));
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.logoutConfirm), findsOneWidget);
    await tester.tap(find.text(LbStrings.cancel));
    await tester.pumpAndSettle();
    expect(container.read(lbSessionProvider).phase, LbPhase.signedIn);

    await tester.tap(find.text(LbStrings.logout));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(LbStrings.logout),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(lbSessionProvider).phase, LbPhase.signedOut);
    expect(store.saved.jwt, isNull);
  });
}
