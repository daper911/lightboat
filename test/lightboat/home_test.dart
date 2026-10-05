import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/auth/credential_store.dart';
import 'package:fl_clash/lightboat/mobile/home.dart';
import 'package:fl_clash/lightboat/mobile/purchase.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'fakes.dart';
import 'ui_fakes.dart';

const _gb = 1024 * 1024 * 1024;

LbSubscription _plan({int expireInDays = 20, int used = 32 * _gb}) =>
    LbSubscription(
      id: 9,
      planId: 3,
      token: 't',
      name: '基础版',
      status: LbPlanStatus.active,
      expireTime: DateTime.now()
          .add(Duration(days: expireInDays))
          .millisecondsSinceEpoch,
      traffic: 100 * _gb,
      upload: 0,
      download: used,
    );

const _groups = [
  Group(
    type: GroupType.Selector,
    name: '🚀 Proxy',
    now: '🌏 Auto',
    all: [
      Proxy(name: '🌏 Auto', type: 'URLTest'),
      Proxy(name: '🎯 Direct', type: 'Selector'),
      Proxy(name: '香港 HK1 · Reality', type: 'Vless'),
      Proxy(name: '香港 HK1 · Hysteria2', type: 'Hysteria2'),
    ],
  ),
  Group(
    type: GroupType.Selector,
    name: '🎯 Direct',
    now: 'DIRECT',
    hidden: true,
    all: [Proxy(name: 'DIRECT', type: 'Direct')],
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
    now: '香港 HK1 · Reality',
    all: [
      Proxy(name: '香港 HK1 · Reality', type: 'Vless'),
      Proxy(name: '香港 HK1 · Hysteria2', type: 'Hysteria2'),
    ],
  ),
];

void main() {
  late FakePanelApi api;
  late MemoryStore store;
  late ProviderContainer container;

  setUp(() {
    setTestPackageInfo();
    SharedPreferences.setMockInitialValues({'lb_vpn_explained': true});
    RecordingProxies.calls.clear();
    FakeCommonAction.toggles = 0;
    FakeProbe.calls.clear();
    FakeProbe.initial = const RoutedProbeState({});
    api = FakePanelApi();
    store = MemoryStore();
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    LbSubscription? plan,
    bool withJwt = true,
    int? runTime,
  }) async {
    final profile = Profile.normal(label: '轻舟', url: 'https://sub.example');
    container = ProviderContainer(
      overrides: [
        lbPanelApiProvider.overrideWithValue(api),
        lbCredentialStoreProvider.overrideWithValue(store),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        proxiesActionProvider.overrideWith(RecordingProxies.new),
        commonActionProvider.overrideWith(FakeCommonAction.new),
        outboundIpProbeProvider.overrideWith(FakeProbe.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value = profile.id;
    container.read(groupsProvider.notifier).value = _groups;
    container.read(runTimeProvider.notifier).value = runTime;
    store.saved = LbStoredSession(
      jwt: withJwt ? 'jwt' : null,
      email: 'a@example.com',
      subscription: plan,
      subscriptions: [?plan],
    );
    await container.read(lbSessionProvider.notifier).restore();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: LbHomePage()),
      ),
    );
    await tester.pump();
  }

  void setRunTime(int? value) =>
      container.read(runTimeProvider.notifier).value = value;

  testWidgets('shows the plan and switches between the two modes', (
    tester,
  ) async {
    await pumpHome(tester, plan: _plan());

    expect(find.text('基础版'), findsOneWidget);
    expect(find.text('● ${LbStrings.planActive}'), findsOneWidget);
    expect(find.text('32.0 GB / 100 GB'), findsOneWidget);
    expect(find.text(LbStrings.modeSmartHint), findsOneWidget);
    expect(find.text(LbStrings.disconnected), findsOneWidget);

    await tester.tap(find.text(LbStrings.modeGlobal));
    await tester.pump();
    expect(container.read(patchClashConfigProvider).mode, Mode.global);
    expect(find.text(LbStrings.modeGlobalHint), findsOneWidget);
    expect(RecordingProxies.calls, ['change GLOBAL -> 🚀 Proxy']);

    await tester.tap(find.text(LbStrings.modeSmart));
    await tester.pump();
    expect(container.read(patchClashConfigProvider).mode, Mode.rule);
  });

  testWidgets('warns about an expired plan and opens the renewal', (
    tester,
  ) async {
    await pumpHome(tester, plan: _plan(expireInDays: -1));

    expect(find.text('● ${LbStrings.planExpired}'), findsOneWidget);
    await tester.tap(find.text(LbStrings.expiredTip));
    await tester.pumpAndSettle();
    expect(find.byType(LbPurchasePage), findsOneWidget);
  });

  testWidgets('warns a week before expiry and when traffic runs out', (
    tester,
  ) async {
    await pumpHome(tester, plan: _plan(expireInDays: 3, used: 100 * _gb));
    expect(find.text('● ${LbStrings.planExhausted}'), findsOneWidget);
    expect(find.text(LbStrings.exhaustedTip), findsOneWidget);
  });

  testWidgets('without a plan the card leads to the purchase', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text(LbStrings.noPlan));
    await tester.pumpAndSettle();
    expect(find.byType(LbPurchasePage), findsOneWidget);
  });

  testWidgets('explains the VPN prompt once, then connects', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FakeProbe.initial = const RoutedProbeState({
      routedOutbound: ProbeEntry(
        phase: ProbePhase.fresh,
        value: IpInfo(ip: '1.2.3.4', countryCode: 'HK'),
      ),
    });
    await pumpHome(tester, plan: _plan());

    await tester.tap(find.text(LbStrings.connect));
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.vpnTitle), findsOneWidget);
    await tester.tap(find.text(LbStrings.continueText));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(FakeCommonAction.toggles, 1);
    expect(find.text(LbStrings.connecting), findsOneWidget);
    expect(FakeProbe.calls, contains('watch'));

    setRunTime(2000);
    await tester.pump();
    expect(find.text('${LbStrings.connected} 00:00:02'), findsOneWidget);
    expect(find.textContaining(LbStrings.sessionUsage('')), findsOneWidget);
    expect(find.textContaining('香港'), findsWidgets);
    expect(RecordingProxies.calls, ['test 🚀 Proxy']);

    setRunTime(3000);
    await tester.pump();
    expect(RecordingProxies.calls, hasLength(1));

    await tester.tap(find.text(LbStrings.disconnect));
    await tester.pump();
    expect(FakeCommonAction.toggles, 2);
    expect(find.text(LbStrings.disconnected), findsOneWidget);
    expect(find.text(LbStrings.connectFailed), findsNothing);

    await tester.tap(find.text(LbStrings.connect));
    await tester.pump();
    expect(find.text(LbStrings.vpnTitle), findsNothing);
  });

  testWidgets('a start that drops at once shows the failure and retries', (
    tester,
  ) async {
    await pumpHome(tester, plan: _plan());

    await tester.tap(find.text(LbStrings.connect));
    await tester.pump();
    await tester.pump();
    setRunTime(null);
    await tester.pump();

    expect(find.text(LbStrings.connectFailed), findsOneWidget);
    expect(find.text(LbStrings.connectFailedHint), findsOneWidget);
    await tester.tap(find.text(LbStrings.retry));
    await tester.pump();
    await tester.pump();
    expect(FakeCommonAction.toggles, 2);
    expect(find.text(LbStrings.connectFailed), findsNothing);
  });

  testWidgets('the line card names the auto pick and opens the lines', (
    tester,
  ) async {
    await pumpHome(tester, plan: _plan());

    expect(
      find.text('${LbStrings.autoLine}（香港 HK1 · Reality）'),
      findsOneWidget,
    );
    await tester.tap(find.text(LbStrings.testDelay));
    await tester.pump();
    expect(RecordingProxies.calls, ['test 🚀 Proxy']);

    await tester.tap(find.text(LbStrings.line));
    await tester.pumpAndSettle();
    expect(find.text('香港 HK1 · Hysteria2'), findsOneWidget);
    expect(find.text('🎯 Direct'), findsNothing);

    await tester.tap(find.text('香港 HK1 · Hysteria2'));
    await tester.pump();
    expect(
      RecordingProxies.calls.last,
      'change 🚀 Proxy -> 香港 HK1 · Hysteria2',
    );

    await tester.tap(find.text(LbStrings.testDelay));
    await tester.pump();
    expect(RecordingProxies.calls.last, 'test 3 proxies');
  });

  testWidgets('a failed exit probe offers a retry', (tester) async {
    FakeProbe.initial = const RoutedProbeState({
      routedOutbound: ProbeEntry(phase: ProbePhase.failed),
    });
    await pumpHome(tester, plan: _plan(), runTime: 5000);

    expect(find.text(LbStrings.lineDown), findsOneWidget);
    await tester.tap(find.text(LbStrings.retry));
    await tester.pump();
    expect(FakeProbe.calls, contains('retry'));
  });
}
