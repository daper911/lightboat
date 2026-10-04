import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Reply = (int, Object?);

/// Answers by path and records every request it saw.
class _Adapter implements HttpClientAdapter {
  final Map<String, _Reply> replies;
  final Set<String> unreachableHosts;
  final List<RequestOptions> requests = [];

  _Adapter(this.replies, {this.unreachableHosts = const {}});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (unreachableHosts.contains(options.uri.host)) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'unreachable',
      );
    }
    final (status, body) = replies[options.uri.path] ?? (404, null);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  RequestOptions last(String path) =>
      requests.lastWhere((request) => request.uri.path == path);
}

Map<String, Object?> _ok(Object? data) => {
  'code': 200,
  'msg': 'success',
  'data': data,
};

const _heartbeat = '/v1/common/heartbeat';

void main() {
  late _Adapter adapter;
  late PanelApi api;

  PanelApi build(
    Map<String, _Reply> replies, {
    List<String> panels = const ['https://a.example'],
    Set<String> unreachable = const {},
  }) {
    adapter = _Adapter({
      _heartbeat: (200, _ok({'status': true})),
      ...replies,
    }, unreachableHosts: unreachable);
    return api = PanelApi(
      userAgent: 'Lightboat-Android/9 (Clash.Meta)',
      panelUrls: panels,
      adapter: adapter,
    );
  }

  test('logs in with the brand UA and no ticket unless one is given', () async {
    build({
      '/v1/auth/login': (200, _ok({'token': 'jwt'})),
    });
    expect(await api.login(email: 'a@b.c', password: 'p'), 'jwt');
    final request = adapter.last('/v1/auth/login');
    expect(request.method, 'POST');
    expect(request.headers['User-Agent'], 'Lightboat-Android/9 (Clash.Meta)');
    expect(request.data, {'email': 'a@b.c', 'password': 'p'});

    await api.login(email: 'a@b.c', password: 'p', captchaTicket: 't');
    expect((adapter.last('/v1/auth/login').data as Map)['captcha_ticket'], 't');
  });

  test('sends the JWT bare, without a Bearer prefix', () async {
    build({
      '/v1/public/user/subscribe': (
        200,
        _ok({
          'list': [
            {
              'id': 1,
              'subscribe_id': 3,
              'token': 'tok',
              'status': 1,
              'subscribe': {'name': '基础版'},
            },
          ],
        }),
      ),
    });
    final list = await api.subscriptions('jwt-1');
    expect(list.single.token, 'tok');
    expect(list.single.planId, 3);
    expect(
      adapter.last('/v1/public/user/subscribe').headers['Authorization'],
      'jwt-1',
    );
  });

  test('falls back to the next panel when the first is unreachable', () async {
    build(
      {
        '/v1/common/site/config': (
          200,
          _ok({
            'subscribe': {
              'subscribe_domain': 'sub.example',
              'subscribe_path': '/api/subscribe',
            },
          }),
        ),
      },
      panels: const ['https://down.example', 'https://up.example'],
      unreachable: const {'down.example'},
    );
    final site = await api.siteConfig();
    expect(api.panelUrl, 'https://up.example');
    expect(adapter.last('/v1/common/site/config').uri.host, 'up.example');
    expect(site.subscribeUrl('t'), 'https://sub.example/api/subscribe?token=t');
  });

  test('turns transport failures into a network error', () async {
    build(const {}, unreachable: const {'a.example'});
    await expectLater(
      api.slideCaptcha(),
      throwsA(
        isA<PanelException>().having(
          (e) => e.code,
          'code',
          LbErrorCode.network,
        ),
      ),
    );
  });

  test('tells the network failures apart', () {
    final options = RequestOptions(path: '/');
    LbNetworkIssue issueOf(DioExceptionType type, [Object? cause]) =>
        lbNetworkIssue(
          DioException(requestOptions: options, type: type, error: cause),
        );
    expect(issueOf(DioExceptionType.connectionTimeout), LbNetworkIssue.timeout);
    expect(
      issueOf(
        DioExceptionType.unknown,
        const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
      ),
      LbNetworkIssue.certificate,
    );
    expect(
      issueOf(
        DioExceptionType.connectionError,
        const SocketException('Failed host lookup: ssr.cnbetx.com'),
      ),
      LbNetworkIssue.hostLookup,
    );
    expect(
      issueOf(
        DioExceptionType.connectionError,
        const SocketException('Connection refused'),
      ),
      LbNetworkIssue.connection,
    );
    expect(
      LbStrings.loginError(
        const PanelException(
          LbErrorCode.network,
          'x',
          issue: LbNetworkIssue.certificate,
        ),
      ),
      contains('证书'),
    );
  });

  test('maps HTTP 429 to the rate limit', () async {
    build({
      '/v1/auth/login': (429, {'code': 401, 'msg': 'Too Many Requests'}),
    });
    await expectLater(
      api.login(email: 'a', password: 'b'),
      throwsA(
        isA<PanelException>().having(
          (e) => e.code,
          'code',
          LbErrorCode.rateLimited,
        ),
      ),
    );
  });

  test('reads the login email from the auth methods', () async {
    build({
      '/v1/public/user/info': (
        200,
        _ok({
          'auth_methods': [
            {'auth_type': 'mobile', 'auth_identifier': '123'},
            {'auth_type': 'email', 'auth_identifier': 'a@b.c'},
          ],
        }),
      ),
    });
    expect(await api.email('jwt'), 'a@b.c');
  });

  test('runs the captcha and registration calls', () async {
    build({
      '/v1/common/captcha/slide': (
        200,
        _ok({
          'id': 'c1',
          'image': base64Encode([1]),
          'thumb': base64Encode([2]),
          'thumb_x': 5,
          'thumb_y': 72,
          'thumb_width': 65,
          'thumb_height': 65,
        }),
      ),
      '/v1/common/captcha/slide/verify': (200, _ok({'ticket': 'tk'})),
      '/v1/common/send_code': (200, _ok(null)),
      '/v1/auth/register': (200, _ok({'token': 'new-jwt'})),
    });
    expect((await api.slideCaptcha()).id, 'c1');
    expect(await api.verifySlideCaptcha(id: 'c1', x: 100, y: 72), 'tk');
    expect(adapter.last('/v1/common/captcha/slide/verify').data, {
      'id': 'c1',
      'x': 100,
      'y': 72,
    });

    await api.sendEmailCode(email: 'n@b.c', captchaTicket: 'tk');
    expect(adapter.last('/v1/common/send_code').data, {
      'email': 'n@b.c',
      'type': 1,
      'captcha_ticket': 'tk',
    });

    final jwt = await api.register(
      email: 'n@b.c',
      password: 'p',
      code: '123456',
      invite: 'INV',
    );
    expect(jwt, 'new-jwt');
    expect(adapter.last('/v1/auth/register').data, {
      'email': 'n@b.c',
      'password': 'p',
      'code': '123456',
      'invite': 'INV',
    });
  });

  test('runs the order calls the website uses', () async {
    build({
      '/v1/public/subscribe/list': (
        200,
        _ok({
          'list': [
            {'id': 3, 'name': '基础版', 'sell': true, 'show': true},
          ],
        }),
      ),
      '/v1/public/portal/payment-method': (
        200,
        _ok({
          'list': [
            {'id': -1, 'name': 'Balance', 'platform': 'balance'},
            {'id': 2, 'name': 'USDT', 'platform': 'GMPay'},
          ],
        }),
      ),
      '/v1/public/order/pre': (200, _ok({'amount': 1500, 'price': 1500})),
      '/v1/public/order/purchase': (200, _ok({'order_no': 'P1'})),
      '/v1/public/order/renewal': (200, _ok({'order_no': 42})),
      '/v1/public/order/detail': (
        200,
        _ok({'order_no': 'P1', 'status': 2, 'amount': 1500}),
      ),
      '/v1/public/portal/order/checkout': (
        200,
        _ok({'type': 'url', 'checkout_url': 'https://pay.example/x'}),
      ),
    });
    expect((await api.plans('jwt')).single.id, 3);
    expect((await api.paymentMethods('jwt')).first.kind, LbPaymentKind.balance);

    final quote = await api.quote(
      'jwt',
      planId: 3,
      quantity: 3,
      payment: 2,
      userSubscribeId: 9,
    );
    expect(quote.amount, 1500);
    expect(adapter.last('/v1/public/order/pre').data, {
      'subscribe_id': 3,
      'quantity': 3,
      'payment': 2,
      'user_subscribe_id': 9,
    });

    expect(await api.purchase('jwt', planId: 3, quantity: 1, payment: 2), 'P1');
    expect(
      await api.renew('jwt', userSubscribeId: 9, quantity: 1, payment: 2),
      '42',
    );

    final order = await api.order('jwt', 'P1');
    expect(order.isPaid, isTrue);
    expect(adapter.last('/v1/public/order/detail').uri.queryParameters, {
      'order_no': 'P1',
    });

    final checkout = await api.checkout(
      'jwt',
      orderNo: 'P1',
      returnUrl: 'https://a.example/#/order',
    );
    expect(checkout.checkoutUrl, 'https://pay.example/x');
    expect(adapter.last('/v1/public/portal/order/checkout').data, {
      'orderNo': 'P1',
      'returnUrl': 'https://a.example/#/order',
    });
  });

  test('keeps subscription order as the panel lists it', () async {
    build({
      '/v1/public/user/subscribe': (200, _ok({'list': <Object>[]})),
    });
    expect(await api.subscriptions('jwt'), isEmpty);
    expect(pickSubscription(const []), isNull);
  });
}
