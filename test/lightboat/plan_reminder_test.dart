import 'dart:async';

import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/pages/plan_reminder.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

final _now = DateTime(2026, 10, 5, 12);

LbSubscription _plan({
  DateTime? expires,
  int traffic = 0,
  int used = 0,
  bool renewable = true,
}) => LbSubscription(
  id: 1,
  token: 't',
  name: '基础版',
  status: LbPlanStatus.active,
  expireTime: expires?.millisecondsSinceEpoch ?? 0,
  traffic: traffic,
  upload: 0,
  download: used,
  renewable: renewable,
);

void main() {
  test('reminds in the last three days, when expired or out of traffic', () {
    expect(lbPlanReminder(_plan(expires: DateTime(2026, 11, 5)), _now), isNull);
    expect(lbPlanReminder(_plan(), _now), isNull);
    expect(
      lbPlanReminder(_plan(expires: DateTime(2026, 10, 7, 12)), _now),
      LbStrings.expiresSoon(2),
    );
    expect(
      lbPlanReminder(_plan(expires: DateTime(2026, 10, 1)), _now),
      LbStrings.expiredTip,
    );
    expect(
      lbPlanReminder(_plan(traffic: 10, used: 10), _now),
      LbStrings.exhaustedTip,
    );
  });

  Future<BuildContext> pump(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      TestApp(
        child: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );
    return context;
  }

  testWidgets('shows the reminder once a day', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final context = await pump(tester);
    final plan = _plan(expires: DateTime(2026, 10, 1), renewable: false);

    final first = lbRemindPlan(context, plan, now: _now);
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.expiredTip), findsOneWidget);
    expect(find.text(LbStrings.buyPlan), findsOneWidget);
    await tester.tap(find.text(LbStrings.later));
    await tester.pumpAndSettle();
    expect(await first, isTrue);

    expect(await lbRemindPlan(context, plan, now: _now), isFalse);
    final tomorrow = lbRemindPlan(
      context,
      plan,
      now: _now.add(const Duration(days: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.expiredTip), findsOneWidget);
    await tester.tap(find.text(LbStrings.later));
    await tester.pumpAndSettle();
    unawaited(tomorrow);
  });
}
