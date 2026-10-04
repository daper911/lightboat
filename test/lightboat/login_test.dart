import 'dart:convert';

import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/auth/credential_store.dart';
import 'package:fl_clash/lightboat/pages/login.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _FakePanelApi extends PanelApi {
  _FakePanelApi() : super(userAgent: 'test');

  final List<String?> loginTickets = [];
  final List<int> verifiedX = [];
  int captchasServed = 0;
  bool requireCaptcha = false;
  bool rejectFirstCaptcha = false;
  int? loginError;

  @override
  Future<String> login({
    required String email,
    required String password,
    String? captchaTicket,
  }) async {
    loginTickets.add(captchaTicket);
    final error = loginError;
    if (error != null) throw PanelException(error, '');
    if (requireCaptcha && captchaTicket == null) {
      throw const PanelException(LbErrorCode.captchaRequired, '');
    }
    return 'jwt';
  }

  @override
  Future<List<LbSubscription>> subscriptions(String jwt) async => const [];

  @override
  Future<LbSlideCaptcha> slideCaptcha() async {
    captchasServed++;
    return LbSlideCaptcha(
      id: 'captcha-$captchasServed',
      image: _pixel,
      thumb: _pixel,
      thumbX: 5,
      thumbY: 72,
      thumbWidth: 65,
      thumbHeight: 65,
    );
  }

  @override
  Future<String> verifySlideCaptcha({
    required String id,
    required int x,
    required int y,
  }) async {
    verifiedX.add(x);
    if (rejectFirstCaptcha && verifiedX.length == 1) {
      throw const PanelException(LbErrorCode.captchaFailed, '');
    }
    return 'ticket';
  }
}

class _MemoryStore extends LbCredentialStore {
  LbStoredSession saved = const LbStoredSession();

  @override
  Future<LbStoredSession> load() async => saved;

  @override
  Future<void> save(LbStoredSession session) async => saved = session;

  @override
  Future<void> clearJwt() async {}

  @override
  Future<void> clear() async => saved = const LbStoredSession();
}

void main() {
  late _FakePanelApi api;
  late _MemoryStore store;
  late ProviderContainer container;

  setUp(() {
    api = _FakePanelApi();
    store = _MemoryStore();
    container = ProviderContainer(
      overrides: [
        lbPanelApiProvider.overrideWithValue(api),
        lbCredentialStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: LbLoginPage()),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text(LbStrings.login));
    await tester.pump();
  }

  Future<void> slideKnob(WidgetTester tester) async {
    final knob = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(GlyphIcon),
    );
    await tester.drag(knob, const Offset(120, 0));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  testWidgets('shows the brand copy for a wrong password', (tester) async {
    api.loginError = LbErrorCode.wrongPassword;
    await pumpLogin(tester);
    await tester.pump();

    expect(find.text('密码错误'), findsOneWidget);
    expect(container.read(lbSessionProvider).phase, LbPhase.loading);
  });

  testWidgets('runs the slide captcha and retries with its ticket', (
    tester,
  ) async {
    api.requireCaptcha = true;
    await pumpLogin(tester);
    await tester.pump();

    expect(find.text(LbStrings.captchaTitle), findsOneWidget);
    await slideKnob(tester);

    expect(api.verifiedX.single, greaterThan(5));
    expect(api.loginTickets, [null, 'ticket']);
    expect(find.text(LbStrings.captchaTitle), findsNothing);
    expect(container.read(lbSessionProvider).phase, LbPhase.signedIn);
    expect(store.saved.jwt, 'jwt');
    expect(store.saved.email, 'a@example.com');
  });

  testWidgets('serves a new image after a missed slide', (tester) async {
    api.requireCaptcha = true;
    api.rejectFirstCaptcha = true;
    await pumpLogin(tester);
    await tester.pump();

    await slideKnob(tester);
    expect(find.text(LbStrings.captchaFailed), findsOneWidget);
    expect(api.captchasServed, 2);

    await slideKnob(tester);
    expect(api.loginTickets, [null, 'ticket']);
    expect(container.read(lbSessionProvider).phase, LbPhase.signedIn);
  });

  testWidgets('closing the captcha sends no second login', (tester) async {
    api.requireCaptcha = true;
    await pumpLogin(tester);
    await tester.pump();

    await tester.tap(find.text(LbStrings.cancel));
    await tester.pumpAndSettle();

    expect(api.loginTickets, [null]);
    expect(api.verifiedX, isEmpty);
  });
}
