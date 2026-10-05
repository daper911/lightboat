import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/logic/account.dart';
import 'package:fl_clash/lightboat/logic/connection.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/logic/plan.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StuckStart extends CommonAction {
  static int toggles = 0;

  @override
  void toggleRunning() => toggles++;
}

void main() {
  test(
    'retries once with the captcha ticket, or stops when it is closed',
    () async {
      final tickets = <String?>[];
      Future<void> attempt(String? ticket) async {
        tickets.add(ticket);
        if (ticket == null) {
          throw const PanelException(LbErrorCode.captchaRequired, 'captcha');
        }
      }

      expect(await lbWithCaptcha(attempt, () async => 'ticket'), isTrue);
      expect(tickets, [null, 'ticket']);
      expect(await lbWithCaptcha(attempt, () async => null), isFalse);
      expect(
        lbWithCaptcha(
          (_) async => throw const PanelException(20001, 'wrong password'),
          () async => 'ticket',
        ),
        throwsA(isA<PanelException>()),
      );
    },
  );

  testWidgets('the resend countdown runs down to zero', (tester) async {
    final countdown = LbResendCountdown()..start();
    expect(countdown.value, LbResendCountdown.seconds);
    await tester.pump(const Duration(seconds: 1));
    expect(countdown.value, LbResendCountdown.seconds - 1);
    await tester.pump(const Duration(seconds: LbResendCountdown.seconds));
    expect(countdown.value, 0);
    countdown.dispose();
  });

  testWidgets('a start that never comes up fails after the timeout', (
    tester,
  ) async {
    _StuckStart.toggles = 0;
    final container = ProviderContainer(
      overrides: [commonActionProvider.overrideWith(_StuckStart.new)],
    );
    addTearDown(container.dispose);
    container.listen(lbConnectPhaseProvider, (_, _) {});

    container.read(lbConnectionProvider.notifier).toggle();
    expect(_StuckStart.toggles, 1);
    expect(container.read(lbConnectPhaseProvider), LbConnectPhase.disconnected);

    await tester.pump(const Duration(seconds: 21));
    expect(container.read(lbConnectPhaseProvider), LbConnectPhase.failed);
  });

  test('counts the first moments of a run as connecting', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(lbConnectPhaseProvider, (_, _) {});

    container.read(runTimeProvider.notifier).value = 0;
    expect(container.read(lbConnectPhaseProvider), LbConnectPhase.connecting);
    container.read(runTimeProvider.notifier).value = 1500;
    expect(container.read(lbConnectPhaseProvider), LbConnectPhase.connected);
  });

  test('formats delays and summarizes an unlimited plan', () {
    expect(lbDelayText(null), isNull);
    expect(lbDelayText(42), '42 ms');
    expect(lbDelayText(0), 'Timeout');

    const plan = LbSubscription(
      id: 1,
      token: 't',
      name: '',
      status: LbPlanStatus.active,
      expireTime: 0,
      traffic: 0,
      upload: 0,
      download: 512 * 1024 * 1024,
    );
    final summary = LbPlanSummary.of(plan, DateTime(2026, 10, 5));
    expect(summary.name, LbStrings.appName);
    expect(summary.warn, isFalse);
    expect(summary.expireText, LbStrings.neverExpires);
    expect(summary.progress, 0);
    expect(summary.usage, '512 MB / ${LbStrings.unlimited}');
    expect(lbPlanTip(plan, DateTime(2026, 10, 5)), isNull);
  });

  test('names the platform in the subscription User-Agent', () {
    expect(
      LbConfig.userAgent('0.5.0', windows: true),
      'Lightboat-Windows/0.5.0 (Clash.Meta)',
    );
    expect(
      LbConfig.userAgent('0.5.0', windows: false),
      'Lightboat-Android/0.5.0 (Clash.Meta)',
    );
  });
}
