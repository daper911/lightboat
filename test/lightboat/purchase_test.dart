import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/auth/credential_store.dart';
import 'package:fl_clash/lightboat/mobile/payment.dart';
import 'package:fl_clash/lightboat/mobile/purchase.dart';
import 'package:fl_clash/lightboat/widgets/qr.dart';
import 'package:fl_clash/lightboat/mobile/register.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import 'fakes.dart';

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

const _subscription = LbSubscription(
  id: 9,
  planId: 3,
  token: 't',
  name: '基础版',
  status: LbPlanStatus.active,
  expireTime: 0,
  traffic: 0,
  upload: 0,
  download: 0,
);

void main() {
  late FakePanelApi api;
  late MemoryStore store;
  late ProviderContainer container;

  setUp(() {
    api = FakePanelApi()
      ..planList = const [_plan]
      ..methods = const [
        LbPaymentMethod(id: 2, name: 'USDT', platform: 'GMPay'),
        LbPaymentMethod(id: 4, name: '支付宝', platform: 'EPay'),
      ];
    store = MemoryStore();
    container = ProviderContainer(
      overrides: [
        lbPanelApiProvider.overrideWithValue(api),
        lbCredentialStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: page),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> signIn() async {
    store.saved = const LbStoredSession(
      jwt: 'jwt',
      email: 'a@example.com',
      subscription: _subscription,
      subscriptions: [_subscription],
    );
    await container.read(lbSessionProvider.notifier).restore();
  }

  testWidgets('registers with an emailed code after a captcha', (tester) async {
    await pump(tester, const LbRegisterPage());
    final fields = find.byType(TextField);
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
    expect(find.text(LbStrings.resendIn(60)), findsOneWidget);

    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), 'secret');
    await tester.tap(find.text(LbStrings.register));
    await tester.pump();
    await tester.pump();

    expect(api.registerTickets, [null]);
    expect(container.read(lbSessionProvider).phase, LbPhase.signedIn);
    expect(store.saved.email, 'new@example.com');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows the panel reason when the code is wrong', (tester) async {
    api.registerError = 70001;
    await pump(tester, const LbRegisterPage());
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'new@example.com');
    await tester.enterText(fields.at(1), '000000');
    await tester.enterText(fields.at(2), 'secret');
    await tester.tap(find.text(LbStrings.register));
    await tester.pump();
    await tester.pump();

    expect(find.text('验证码不正确或已过期'), findsOneWidget);
    expect(container.read(lbSessionProvider).phase, LbPhase.loading);
  });

  testWidgets('renews the current plan and opens the payment page', (
    tester,
  ) async {
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
    await pump(tester, const LbPurchasePage(renewing: _subscription));

    expect(find.text('¥10.00'), findsOneWidget);
    await tester.tap(find.textContaining('3 个月'));
    await tester.pump();
    await tester.pump();
    expect(find.text('¥30.00'), findsOneWidget);

    await tester.tap(find.text(LbStrings.payCrypto));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text(LbStrings.pay));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(api.ordered, ['renew 9 x3 via 2']);
    expect(find.byType(LbPaymentPage), findsOneWidget);
    expect(find.text('2.0731 USDT'), findsOneWidget);
    expect(find.text('TXYZaddress'), findsOneWidget);
    expect(find.byType(LbQrCode), findsOneWidget);

    api.orderStatus = LbOrderStatus.paid;
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text(LbStrings.paySuccess), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('asks for a new login when the JWT is gone', (tester) async {
    store.saved = const LbStoredSession(subscription: _subscription);
    await container.read(lbSessionProvider.notifier).restore();
    await pump(tester, const LbPurchasePage());

    expect(find.text(LbStrings.plansNeedLogin), findsOneWidget);
    expect(find.text(LbStrings.relogin), findsOneWidget);
  });
}
