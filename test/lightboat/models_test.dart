import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

LbSubscription _subscription({
  int id = 1,
  LbPlanStatus status = LbPlanStatus.active,
  int expireTime = 0,
  int traffic = 0,
  int upload = 0,
  int download = 0,
}) => LbSubscription(
  id: id,
  token: 'token-$id',
  name: 'plan-$id',
  status: status,
  expireTime: expireTime,
  traffic: traffic,
  upload: upload,
  download: download,
);

void main() {
  group('LbSubscription', () {
    test('parses the panel shape', () {
      final subscription = LbSubscription.fromPanel({
        'id': 7,
        'token': 'abc',
        'status': 3,
        'expire_time': 1793621522000,
        'traffic': 107374182400,
        'upload': 266054,
        'download': 266768625,
        'subscribe': {'name': '基础版', 'sell': false},
      });
      expect(subscription.id, 7);
      expect(subscription.status, LbPlanStatus.expired);
      expect(subscription.name, '基础版');
      expect(subscription.used, 266054 + 266768625);
      expect(subscription.renewable, isFalse);
    });

    test('survives a round trip through storage', () {
      final original = _subscription(expireTime: 42, traffic: 9, upload: 1);
      final restored = LbSubscription.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      );
      expect(restored.toJson(), original.toJson());
    });

    test('treats a zero expiry as never expiring', () {
      final now = DateTime(2026, 10, 4);
      final subscription = _subscription();
      expect(subscription.isExpired(now), isFalse);
      expect(subscription.daysLeft(now), isNull);
    });

    test('counts days left and expiry', () {
      final now = DateTime(2026, 10, 4, 12);
      final soon = _subscription(
        expireTime: now
            .add(const Duration(days: 2, hours: 3))
            .millisecondsSinceEpoch,
      );
      expect(soon.daysLeft(now), 3);
      expect(soon.isExpired(now), isFalse);
      final past = _subscription(
        expireTime: now
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      );
      expect(past.isExpired(now), isTrue);
      expect(past.daysLeft(now), 0);
    });

    test('flags exhausted traffic only for limited plans', () {
      expect(
        _subscription(traffic: 10, upload: 4, download: 6).isTrafficExhausted,
        isTrue,
      );
      expect(_subscription(upload: 4, download: 6).isTrafficExhausted, isFalse);
    });

    test('folds in subscription-userinfo, whose expire is seconds', () {
      final updated = _subscription().withUserinfo(
        const SubscriptionInfo(
          upload: 1,
          download: 2,
          total: 3,
          expire: 1793621522,
        ),
      );
      expect(updated.expireTime, 1793621522000);
      expect(updated.traffic, 3);
      expect(updated.used, 3);
    });
  });

  group('pickSubscription', () {
    test('prefers the remembered plan, then the first active one', () {
      final list = [
        _subscription(id: 1, status: LbPlanStatus.expired),
        _subscription(id: 2),
        _subscription(id: 3),
      ];
      expect(pickSubscription(list)?.id, 2);
      expect(pickSubscription(list, preferredId: 3)?.id, 3);
      expect(pickSubscription(list, preferredId: 99)?.id, 2);
    });

    test('never picks a deducted plan', () {
      final list = [
        _subscription(id: 1, status: LbPlanStatus.deducted),
        _subscription(id: 2, status: LbPlanStatus.expired),
      ];
      expect(pickSubscription(list)?.id, 2);
      expect(pickSubscription([list.first]), isNull);
    });
  });

  group('LbSlideCaptcha', () {
    final captcha = LbSlideCaptcha(
      id: 'id',
      image: Uint8List(0),
      thumb: Uint8List(0),
      thumbX: 5,
      thumbY: 72,
      thumbWidth: 65,
      thumbHeight: 65,
    );

    test('maps the slider ends onto the image range', () {
      expect(captcha.pieceX(0, 300, 56), 5);
      expect(captcha.pieceX(244, 300, 56), 300 - 65);
      expect(captcha.pieceX(1000, 300, 56), 300 - 65);
    });

    test('decodes data URIs', () {
      final decoded = LbSlideCaptcha.fromPanel({
        'id': 'x',
        'image': 'data:image/jpeg;base64,${base64Encode([1, 2, 3])}',
        'thumb': base64Encode([4]),
        'thumb_x': 5,
        'thumb_y': 72,
        'thumb_width': 65,
        'thumb_height': 65,
      });
      expect(decoded.image, [1, 2, 3]);
      expect(decoded.thumb, [4]);
    });
  });

  group('PanelApi.parseEnvelope', () {
    test('returns data on success', () {
      expect(
        PanelApi.parseEnvelope(200, {
          'code': 200,
          'data': {'token': 't'},
        }),
        {'token': 't'},
      );
    });

    test('raises business errors that arrive as HTTP 200', () {
      expect(
        () => PanelApi.parseEnvelope(200, {'code': 110001, 'msg': 'captcha'}),
        throwsA(
          isA<PanelException>().having(
            (e) => e.code,
            'code',
            LbErrorCode.captchaRequired,
          ),
        ),
      );
    });

    test('maps HTTP 429 to the rate limit code', () {
      expect(
        () => PanelApi.parseEnvelope(429, {'code': 401}),
        throwsA(
          isA<PanelException>().having(
            (e) => e.code,
            'code',
            LbErrorCode.rateLimited,
          ),
        ),
      );
    });

    test('recognises every expired-login code', () {
      for (final code in [40002, 40003, 40004, 40005]) {
        expect(PanelException(code, '').isAuthExpired, isTrue);
      }
      expect(const PanelException(40001, '').isAuthExpired, isFalse);
    });
  });

  group('LbSiteConfig', () {
    test('uses the first subscribe domain', () {
      final site = LbSiteConfig.fromPanel({
        'subscribe': {
          'subscribe_domain': 'sub.cnbetx.com\nsub2.cnbetx.com',
          'subscribe_path': '/api/subscribe',
        },
      }, 'https://ssr.cnbetx.com');
      expect(
        site.subscribeUrl('a b'),
        'https://sub.cnbetx.com/api/subscribe?token=a+b',
      );
    });

    test('falls back to the panel host', () {
      final site = LbSiteConfig.fromPanel({
        'subscribe': {'subscribe_domain': ''},
      }, 'https://ssr.cnbetx.com');
      expect(
        site.subscribeUrl('t'),
        'https://ssr.cnbetx.com/api/subscribe?token=t',
      );
    });
  });

  test('login errors read as the brand copy', () {
    expect(
      LbStrings.loginError(const PanelException(LbErrorCode.wrongPassword, '')),
      '密码错误',
    );
    expect(
      LbStrings.loginError(const PanelException(LbErrorCode.rateLimited, '')),
      '操作太频繁，请稍后再试',
    );
  });
}
