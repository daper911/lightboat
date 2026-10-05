import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/auth/credential_store.dart';
import 'package:fl_clash/lightboat/desktop/auth.dart';
import 'package:fl_clash/lightboat/desktop/lines.dart';
import 'package:fl_clash/lightboat/desktop/me.dart';
import 'package:fl_clash/lightboat/desktop/purchase.dart';
import 'package:fl_clash/lightboat/desktop/shell.dart';
import 'package:fl_clash/lightboat/desktop/tray.dart';
import 'package:fl_clash/lightboat/logic/connection.dart';
import 'package:fl_clash/lightboat/root.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/widgets/crypto_payment.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray/tray.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'fakes.dart';
import 'ui_fakes.dart';

const _gb = 1024 * 1024 * 1024;

LbSubscription _subscription() => LbSubscription(
  id: 9,
  planId: 3,
  token: 't',
  name: '基础版',
  status: LbPlanStatus.active,
  expireTime: DateTime.now()
      .add(const Duration(days: 20))
      .millisecondsSinceEpoch,
  traffic: 100 * _gb,
  upload: 0,
  download: 32 * _gb,
  renewable: true,
);

const _plan = LbPlan(
  id: 3,
  name: '基础版',
  description: '',
  unitPrice: 1000,
  unitTime: 'Month',
  traffic: 0,
  durations: [
    LbPlanDuration(quantity: 1),
    LbPlanDuration(quantity: 3, discount: 90),
  ],
);

const _groups = [
  Group(
    type: GroupType.Selector,
    name: '🚀 Proxy',
    now: '🌏 Auto',
    all: [
      Proxy(name: '🌏 Auto', type: 'URLTest'),
      Proxy(name: '香港 HK1 · AnyTLS', type: 'AnyTLS'),
      Proxy(name: '日本 JP1 · Reality', type: 'Vless'),
    ],
  ),
  Group(
    type: GroupType.Selector,
    name: 'GLOBAL',
    now: 'DIRECT',
    all: [
      Proxy(name: 'DIRECT', type: 'Direct'),
      Proxy(name: '🚀 Proxy', type: 'Selector'),
    ],
  ),
  Group(
    type: GroupType.URLTest,
    name: '🌏 Auto',
    now: '香港 HK1 · AnyTLS',
    all: [
      Proxy(name: '香港 HK1 · AnyTLS', type: 'AnyTLS'),
      Proxy(name: '日本 JP1 · Reality', type: 'Vless'),
    ],
  ),
];

void main() {
  late FakePanelApi api;
  late MemoryStore store;
  late ProviderContainer container;

  ProviderContainer makeContainer({LbPortProbe? probe}) {
    final profile = Profile.normal(label: '轻舟', url: 'https://sub.example');
    final made = ProviderContainer(
      overrides: [
        lbPanelApiProvider.overrideWithValue(api),
        lbCredentialStoreProvider.overrideWithValue(store),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        proxiesActionProvider.overrideWith(RecordingProxies.new),
        commonActionProvider.overrideWith(FakeCommonAction.new),
        outboundIpProbeProvider.overrideWith(FakeProbe.new),
        systemActionProvider.overrideWith(FakeSystemAction.new),
        lbPortProbeProvider.overrideWithValue(probe),
      ],
    );
    addTearDown(made.dispose);
    made
      ..listen(currentProfileIdProvider, (_, _) {})
      ..listen(appSettingProvider, (_, _) {})
      ..listen(lbDesktopNavProvider, (_, _) {});
    made.read(currentProfileIdProvider.notifier).value = profile.id;
    made.read(groupsProvider.notifier).value = _groups;
    return made;
  }

  setUp(() {
    setTestPackageInfo();
    SharedPreferences.setMockInitialValues({});
    RecordingProxies.calls.clear();
    FakeCommonAction.toggles = 0;
    api = FakePanelApi()
      ..planList = const [_plan]
      ..methods = const [
        LbPaymentMethod(id: 2, name: 'USDT', platform: 'GMPay'),
        LbPaymentMethod(id: 4, name: '支付宝', platform: 'EPay'),
      ];
    store = MemoryStore();
    container = makeContainer();
  });

  Future<void> signIn() async {
    final subscription = _subscription();
    store.saved = LbStoredSession(
      jwt: 'jwt',
      email: 'a@example.com',
      subscription: subscription,
      subscriptions: [subscription],
    );
    await container.read(lbSessionProvider.notifier).restore();
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1280, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('signs in on the card and lands in the sidebar shell', (
    tester,
  ) async {
    await pump(tester, const LbRoot(desktop: true));
    await container.read(lbSessionProvider.notifier).restore();
    await tester.pump();
    expect(find.byType(LbDesktopAuthPage), findsOneWidget);

    await tester.tap(find.text(LbStrings.registerLink));
    await tester.pump();
    expect(find.text(LbStrings.registerTitle), findsOneWidget);
    await tester.tap(find.text(LbStrings.register));
    await tester.pump();
    expect(find.text(LbStrings.registerFieldsRequired), findsOneWidget);
    await tester.tap(find.text(LbStrings.backToLogin));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'a@example.com');
    await tester.enterText(fields.at(1), 'secret');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();

    expect(api.loginTickets, [null]);
    expect(find.byType(LbDesktopShell), findsOneWidget);
    expect(find.text(LbStrings.noPlan), findsOneWidget);

    await tester.tap(find.text(LbStrings.line).first);
    await tester.pump();
    expect(find.byType(LbDesktopLines), findsOneWidget);
    await tester.tap(find.text(LbStrings.me).first);
    await tester.pump();
    expect(find.byType(LbDesktopMe), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('home connects, switches mode and opens the renewal', (
    tester,
  ) async {
    await signIn();
    await pump(tester, const LbDesktopShell());

    expect(find.text('基础版'), findsWidgets);
    expect(find.text('32.0 GB / 100 GB'), findsOneWidget);
    expect(find.text('${LbStrings.autoLine}（香港 HK1 · AnyTLS）'), findsOneWidget);

    await tester.tap(find.text(LbStrings.connect));
    await tester.pump();
    expect(FakeCommonAction.toggles, 1);
    expect(find.text(LbStrings.connecting), findsOneWidget);
    container.read(runTimeProvider.notifier).value = 2000;
    await tester.pump();
    expect(find.text('${LbStrings.connected} 00:00:02'), findsOneWidget);
    expect(RecordingProxies.calls, ['test 🚀 Proxy']);

    await tester.tap(find.text(LbStrings.modeGlobal));
    await tester.pump();
    expect(container.read(patchClashConfigProvider).mode, Mode.global);
    expect(RecordingProxies.calls.last, 'change GLOBAL -> 🚀 Proxy');

    await tester.tap(find.text(LbStrings.renewPlan));
    await tester.pump();
    await tester.pump();
    expect(find.byType(LbDesktopPurchase), findsOneWidget);
    expect(container.read(lbDesktopNavProvider).renewing?.id, 9);
  });

  testWidgets('a port held by another app stops the start with a reason', (
    tester,
  ) async {
    container = makeContainer(probe: (_) async => false);
    await signIn();
    tester.view.physicalSize = const Size(1280, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: LbDesktopShell()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(LbStrings.connect));
    await tester.pump();
    await tester.pump();
    expect(FakeCommonAction.toggles, 0);
    expect(find.text(LbStrings.portBusy(7890)), findsOneWidget);
    expect(await tester.runAsync(() => lbPortIsFree(0)), isTrue);
  });

  testWidgets('the lines table switches and tests lines', (tester) async {
    await signIn();
    await pump(tester, const LbDesktopShell());
    await tester.tap(find.text(LbStrings.changeLine));
    await tester.pump();

    expect(find.text(LbStrings.current), findsOneWidget);
    await tester.tap(find.text('日本 JP1 · Reality'));
    await tester.pump();
    expect(RecordingProxies.calls.last, 'change 🚀 Proxy -> 日本 JP1 · Reality');
    await tester.tap(find.text(LbStrings.testDelay));
    await tester.pump();
    expect(RecordingProxies.calls.last, 'test 3 proxies');
  });

  testWidgets('pays a renewal in the dialog and returns home', (tester) async {
    await signIn();
    api.checkoutResult = LbCheckout(
      type: 'crypto',
      checkoutUrl: '',
      crypto: LbCryptoPayment(
        address: 'TXYZaddress',
        amount: '2.0731',
        token: 'USDT',
        network: 'tron',
        fiat: '10.00',
        currency: 'CNY',
        expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 900,
      ),
    );
    await container
        .read(lbDesktopNavProvider.notifier)
        .openPurchase(_subscription());
    await pump(tester, const LbDesktopShell());
    await tester.pump();

    expect(find.text('¥10.00'), findsWidgets);
    await tester.tap(find.textContaining('3 个月'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text(LbStrings.payCrypto));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text(LbStrings.pay));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(api.ordered, ['renew 9 x3 via 2']);
    expect(find.byType(LbCryptoPaymentView), findsOneWidget);
    api.orderStatus = LbOrderStatus.paid;
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text(LbStrings.paySuccess), findsOneWidget);

    await tester.tap(find.text(LbStrings.backHome));
    await tester.pumpAndSettle();
    expect(container.read(lbDesktopNavProvider).tab, LbDesktopTab.home);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('my page keeps the Windows settings and logs out', (
    tester,
  ) async {
    await signIn();
    container.read(lbDesktopNavProvider.notifier).go(LbDesktopTab.me);
    await pump(tester, const LbDesktopShell());

    expect(find.text(LbStrings.sectionWindows), findsOneWidget);
    expect(find.text(LbStrings.splitTunnel), findsNothing);
    await tester.tap(find.text(LbStrings.autoLaunch));
    await tester.tap(find.text(LbStrings.autoConnect));
    await tester.tap(find.text(LbStrings.silentLaunch));
    await tester.tap(find.text(LbStrings.minimizeToTray));
    await tester.pump();
    final settings = container.read(appSettingProvider);
    expect(settings.autoLaunch, isTrue);
    expect(settings.autoRun, isTrue);
    expect(settings.silentLaunch, isTrue);
    expect(settings.minimizeOnExit, isFalse);

    await tester.tap(find.text(LbStrings.logout));
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.logoutConfirm), findsOneWidget);
    await tester.tap(find.text(LbStrings.cancel));
    await tester.pumpAndSettle();
    expect(container.read(lbSessionProvider).phase, LbPhase.signedIn);
  });

  test('the tray menu connects and switches the mode', () {
    const trayState = TrayState(
      mode: Mode.rule,
      port: 7890,
      autoLaunch: false,
      systemProxy: true,
      tunEnable: false,
      isStart: true,
      groups: [],
      selectedMap: {},
      showTrayTitle: false,
      safeMode: false,
    );
    final menu = lbTrayMenu(trayState: trayState, read: container.read);
    final labels = [
      for (final item in menu)
        if (item is TrayMenuAction) item.label,
    ];
    expect(labels, [
      LbStrings.trayStatus(running: true, node: '香港 HK1 · AnyTLS'),
      LbStrings.disconnect,
      LbStrings.openApp,
      LbStrings.quit,
    ]);
    (menu[2] as TrayMenuAction).onSelected!();
    expect(FakeCommonAction.toggles, 1);
    final modes = (menu[3] as TrayMenuSubmenu).items.cast<TrayMenuCheckbox>();
    expect(modes.first.checked, isTrue);
    modes.last.onSelected!();
    expect(container.read(patchClashConfigProvider).mode, Mode.global);
    expect(LbTray.icon(running: false), endsWith('disconnected.ico'));
  });

  testWidgets('explains the tray on the first close only', (tester) async {
    await pump(tester, const SizedBox());
    final first = lbExplainTrayOnce();
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.trayHint), findsOneWidget);
    await tester.tap(find.text(LbStrings.gotIt));
    await tester.pumpAndSettle();
    await first;

    await lbExplainTrayOnce();
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.trayHint), findsNothing);
  });

  testWidgets(
    'my page opens announcements, about, the plan switch and a re-login',
    (tester) async {
      const second = LbSubscription(
        id: 10,
        planId: 4,
        token: 't2',
        name: '进阶版',
        status: LbPlanStatus.active,
        expireTime: 0,
        traffic: 0,
        upload: 0,
        download: 0,
      );
      store.saved = LbStoredSession(
        email: 'a@example.com',
        subscription: _subscription(),
        subscriptions: [_subscription(), second],
      );
      api.subscriptionList = [_subscription(), second];
      await container.read(lbSessionProvider.notifier).restore();
      container.read(lbDesktopNavProvider.notifier).go(LbDesktopTab.me);
      await pump(tester, const LbDesktopShell());

      expect(find.text(LbStrings.loginExpired), findsOneWidget);
      expect(find.text(LbStrings.announcements), findsNothing);
      await tester.tap(find.text(LbStrings.relogin));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'a@example.com');
      await tester.enterText(fields.at(1), 'secret');
      await tester.tap(find.text(LbStrings.login));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(lbSessionProvider).hasJwt, isTrue);

      await tester.tap(find.text(LbStrings.switchPlan));
      await tester.pumpAndSettle();
      await tester.tap(find.text('进阶版'));
      await tester.pumpAndSettle();
      expect(container.read(lbSessionProvider).subscription?.id, 10);

      api.announcementList = const [
        LbAnnouncement(
          id: 1,
          title: '国庆维护',
          content: '**今晚** 维护',
          createdAt: 1,
        ),
      ];
      await tester.tap(find.text(LbStrings.announcements));
      await tester.pumpAndSettle();
      await tester.tap(find.text('国庆维护'));
      await tester.pumpAndSettle();
      expect(find.text('今晚 维护'), findsWidgets);
      await tester.tap(find.text(LbStrings.gotIt));
      await tester.pumpAndSettle();
      await tester.tap(find.text(LbStrings.close));
      await tester.pumpAndSettle();

      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text(LbStrings.about));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
      expect(find.text(LbStrings.advanced), findsOneWidget);

      await tester.tap(find.text(LbStrings.refreshPlan));
      await tester.pump();
      await tester.pump();
      expect(find.text(LbStrings.syncing), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 40));
    },
  );

  testWidgets('registers with a code sent after the captcha', (tester) async {
    await pump(tester, const LbDesktopAuthPage());
    await tester.tap(find.text(LbStrings.registerLink));
    await tester.pump();
    final fields = find.byType(TextField);
    await tester.tap(find.text(LbStrings.sendCode));
    await tester.pump();
    expect(find.text(LbStrings.emailFirst), findsOneWidget);

    await tester.enterText(fields.at(0), 'new@example.com');
    await tester.tap(find.text(LbStrings.sendCode));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final knob = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(GlyphIcon),
    );
    await tester.drag(knob, const Offset(120, 0));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(api.codesSent, ['new@example.com/ticket']);
    expect(find.text(LbStrings.codeSent), findsOneWidget);

    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), 'secret');
    await tester.enterText(fields.at(3), 'INVITE');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(container.read(lbSessionProvider).phase, LbPhase.signedIn);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('a wrong password shows the panel reason', (tester) async {
    api.loginError = 20001;
    await pump(tester, const LbDesktopAuthPage());
    await tester.tap(find.text(LbStrings.login));
    await tester.pump();
    expect(find.text(LbStrings.emailRequired), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'a@example.com');
    await tester.enterText(fields.at(1), 'wrong');
    await tester.tap(find.text(LbStrings.login));
    await tester.pump();
    await tester.pump();
    expect(find.text(LbStrings.emailRequired), findsNothing);
    expect(container.read(lbSessionProvider).phase, isNot(LbPhase.signedIn));
  });

  testWidgets(
    'the cashier path waits in the dialog and a closed order says so',
    (tester) async {
      await signIn();
      api.methods = const [
        LbPaymentMethod(id: 4, name: '支付宝', platform: 'EPay'),
      ];
      api.checkoutResult = const LbCheckout(
        type: 'qr',
        checkoutUrl: 'https://pay',
      );
      container.read(lbDesktopNavProvider.notifier).go(LbDesktopTab.purchase);
      await pump(tester, const LbDesktopShell());
      await tester.pump();
      await tester.tap(find.text(LbStrings.pay));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(api.ordered.single, startsWith('purchase 3'));
      expect(find.text(LbStrings.waitingPayment), findsOneWidget);
      expect(find.text(LbStrings.openCashier), findsOneWidget);

      api.orderStatus = LbOrderStatus.closed;
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text(LbStrings.orderClosed), findsOneWidget);
      await tester.tap(find.text(LbStrings.close));
      await tester.pumpAndSettle();
      expect(container.read(lbDesktopNavProvider).tab, LbDesktopTab.purchase);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the purchase page asks for a new login once the JWT is gone', (
    tester,
  ) async {
    store.saved = LbStoredSession(subscription: _subscription());
    await container.read(lbSessionProvider.notifier).restore();
    container.read(lbDesktopNavProvider.notifier).go(LbDesktopTab.purchase);
    await pump(tester, const LbDesktopShell());
    await tester.pump();
    expect(find.text(LbStrings.plansNeedLogin), findsOneWidget);
    await tester.tap(find.text(LbStrings.relogin));
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.login), findsOneWidget);
  });
}
