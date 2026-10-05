import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LbPlan', () {
    test('offers the single unit plus every discounted duration', () {
      final plan = LbPlan.fromPanel({
        'id': 3,
        'name': '基础版',
        'unit_price': 1500,
        'unit_time': 'Month',
        'traffic': 107374182400,
        'discount': [
          {'quantity': 12, 'discount': 80},
          {'quantity': 3, 'discount': 95},
        ],
      });
      expect(plan.durations.map((d) => d.quantity), [1, 3, 12]);
      expect(plan.durations.last.discount, 80);
      expect(plan.durationLabel(3), '3 个月');
    });

    test('hides the single unit when the plan hides its original price', () {
      final plan = LbPlan.fromPanel({
        'id': 3,
        'show_original_price': false,
        'unit_time': 'Year',
        'discount': [
          {'quantity': 2, 'discount': 90},
        ],
      });
      expect(plan.durations.map((d) => d.quantity), [2]);
      expect(plan.durationLabel(2), '2 年');
    });

    test('lists only plans on sale and shown', () {
      final plans = lbSellablePlans({
        'list': [
          {'id': 1, 'name': 'a', 'sell': true, 'show': true},
          {'id': 2, 'name': 'b', 'sell': false, 'show': true},
          {'id': 3, 'name': 'c', 'sell': true, 'show': false},
        ],
      });
      expect(plans.map((p) => p.id), [1]);
    });
  });

  test('groups payment methods like the website', () {
    LbPaymentMethod method(int id, String platform) =>
        LbPaymentMethod(id: id, name: platform, platform: platform);
    expect(method(-1, 'balance').kind, LbPaymentKind.balance);
    expect(method(2, 'GMPay').kind, LbPaymentKind.crypto);
    expect(method(3, 'EPay').kind, LbPaymentKind.online);
  });

  test('reads order status codes', () {
    LbOrder order(int status) => LbOrder.fromPanel({
      'order_no': 'x',
      'status': status,
      'payment': {'platform': 'GMPay'},
    });
    expect(order(1).status, LbOrderStatus.pending);
    expect(order(2).isPaid, isTrue);
    expect(order(5).isPaid, isTrue);
    expect(order(3).isOver, isTrue);
    expect(order(4).isOver, isTrue);
    expect(order(1).paymentName, 'GMPay');
  });

  test('parses a crypto checkout', () {
    final checkout = LbCheckout.fromPanel({
      'type': 'crypto',
      'checkout_url': '',
      'crypto': {
        'address': 'TXYZ',
        'amount': '2.0731',
        'token': 'USDT',
        'network': 'tron',
        'fiat': '15.00',
        'currency': 'CNY',
        'expires_at': 1791200000,
      },
    });
    expect(checkout.crypto?.amount, '2.0731');
    expect(checkout.crypto?.networkLabel, 'TRC20 · TRON');
  });

  test('formats fen as yuan', () {
    expect(lbFormatCents(1500), '¥15.00');
    expect(lbFormatCents(5), '¥0.05');
  });

  test('names exit regions in Chinese', () {
    expect(lbRegionName('hk'), '香港');
    expect(lbRegionName('ZZ'), 'ZZ');
  });

  test('keeps the plan id a renewal is priced by', () {
    final subscription = LbSubscription.fromPanel({
      'id': 9,
      'subscribe_id': 3,
      'subscribe': {'id': 3, 'name': '基础版'},
    });
    expect(subscription.planId, 3);
    expect(LbSubscription.fromJson(subscription.toJson().cast()).planId, 3);
  });
}
