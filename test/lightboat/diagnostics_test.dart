import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/diagnostics.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redacts credentials, subscription addresses and e-mail', () {
    const raw =
        'GET https://ssr.cnbetx.com/api/subscribe?token=0d2bbd3a2f4eb6a063dc98beecacffb6&x=1\n'
        'Authorization: eyJhbGciOiJIUzI1NiJ9.eyJpZCI6MTN9.c2lnbmF0dXJl\n'
        '{"email":"someone@gmail.com","password":"hunter2"}\n'
        'uuid: 3f1c2b9a-1d2e-4f3a-9b8c-7d6e5f4a3b2c\n'
        'profile 0d2bbd3a2f4eb6a063dc98beecacffb6 loaded';
    final text = lbRedact(raw);
    expect(text, isNot(contains('0d2bbd3a')));
    expect(text, isNot(contains('eyJhbGci')));
    expect(text, isNot(contains('hunter2')));
    expect(text, isNot(contains('3f1c2b9a')));
    expect(text, isNot(contains('someone')));
    expect(text, contains('token=<token>&x=1'));
    expect(text, contains('s***@gmail.com'));
    expect(text, contains('ssr.cnbetx.com/api/subscribe'));
  });

  test('the summary names the mode and where every group points', () {
    final summary = lbDiagnosticSummary(
      version: '0.3.1（4）',
      system: 'Android 14',
      session: LbSessionState(
        phase: LbPhase.signedIn,
        email: 'someone@gmail.com',
        subscription: LbSubscription.fromJson(const {
          'id': 1,
          'token': 't',
          'name': 'Standard',
        }),
      ),
      running: true,
      runTime: 65000,
      mode: Mode.global,
      groups: const [
        Group(type: GroupType.Selector, name: 'GLOBAL', now: '🚀 Proxy'),
      ],
      now: DateTime(2026, 10, 5),
    );
    expect(summary, contains('模式：全局'));
    expect(summary, contains('GLOBAL → 🚀 Proxy'));
    expect(summary, contains('已连接 65 秒'));
    expect(summary, contains('（登录已过期）'));
    expect(summary, contains('Standard · 不限期'));
  });
}
