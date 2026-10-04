import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/config.dart';

abstract final class LbErrorCode {
  static const rateLimited = 401;
  static const userExists = 20001;
  static const userNotFound = 20002;
  static const wrongPassword = 20003;
  static const userDisabled = 20004;
  static const insufficientBalance = 20005;
  static const registerClosed = 20006;
  static const inviteCodeInvalid = 20009;
  static const planUnavailable = 60002;
  static const planOutOfStock = 60007;
  static const verifyCodeInvalid = 70001;
  static const emailExists = 90011;
  static const sendLimitReached = 90015;
  static const captchaRequired = 110001;
  static const captchaFailed = 110002;
  static const network = -1;

  static bool isAuthExpired(int code) => code >= 40002 && code <= 40005;
}

/// Why a request never got an answer; tells a clock or certificate problem
/// apart from a network that is simply down.
enum LbNetworkIssue { timeout, hostLookup, certificate, connection }

LbNetworkIssue lbNetworkIssue(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout:
      return LbNetworkIssue.timeout;
    case DioExceptionType.badCertificate:
      return LbNetworkIssue.certificate;
    default:
      return switch (error.error) {
        TlsException() => LbNetworkIssue.certificate,
        TimeoutException() => LbNetworkIssue.timeout,
        SocketException(:final message)
            when message.startsWith('Failed host lookup') =>
          LbNetworkIssue.hostLookup,
        _ => LbNetworkIssue.connection,
      };
  }
}

class PanelException implements Exception {
  final int code;
  final String message;

  /// Set when [code] is [LbErrorCode.network].
  final LbNetworkIssue? issue;

  const PanelException(this.code, this.message, {this.issue});

  bool get isAuthExpired => LbErrorCode.isAuthExpired(code);

  @override
  String toString() => 'PanelException($code, $message)';
}

class LbSiteConfig {
  final String subscribeDomain;
  final String subscribePath;

  const LbSiteConfig({
    this.subscribeDomain = LbConfig.fallbackSubscribeDomain,
    this.subscribePath = LbConfig.fallbackSubscribePath,
  });

  factory LbSiteConfig.fromPanel(Map<String, Object?> json, String panelUrl) {
    final subscribe = json['subscribe'] as Map<String, Object?>? ?? const {};
    final domains = (subscribe['subscribe_domain'] as String? ?? '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    final path = subscribe['subscribe_path'] as String? ?? '';
    return LbSiteConfig(
      subscribeDomain: domains.isNotEmpty
          ? domains.first
          : Uri.parse(panelUrl).host,
      subscribePath: path.isNotEmpty ? path : LbConfig.fallbackSubscribePath,
    );
  }

  String subscribeUrl(String token) {
    final host = subscribeDomain.contains('://')
        ? subscribeDomain
        : 'https://$subscribeDomain';
    return '$host$subscribePath?token=${Uri.encodeQueryComponent(token)}';
  }
}

class PanelApi {
  final Dio _dio;
  final List<String> _panelUrls;
  String? _panelUrl;

  PanelApi({
    required String userAgent,
    List<String> panelUrls = LbConfig.panelUrls,
    HttpClientAdapter? adapter,
  }) : _panelUrls = panelUrls,
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 15),
           headers: {'User-Agent': userAgent},
           responseType: ResponseType.json,
           validateStatus: (_) => true,
         ),
       ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  String get panelUrl => _panelUrl ?? _panelUrls.first;

  Future<String> _resolvePanel() async {
    final known = _panelUrl;
    if (known != null) return known;
    for (final url in _panelUrls) {
      try {
        final response = await _dio.get<Object?>('$url/v1/common/heartbeat');
        if (response.statusCode == 200) {
          return _panelUrl = url;
        }
      } on DioException {
        continue;
      }
    }
    return _panelUrls.first;
  }

  Future<Object?> _call(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, Object?>? query,
    String? token,
  }) async {
    final base = await _resolvePanel();
    final Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        '$base$path',
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: {'Authorization': ?token}),
      );
    } on DioException catch (error) {
      _panelUrl = null;
      final issue = lbNetworkIssue(error);
      commonPrint.log(
        'lightboat $method $path: ${issue.name} ${error.error ?? error.message}',
        logLevel: LogLevel.warning,
      );
      throw PanelException(
        LbErrorCode.network,
        error.message ?? '$error',
        issue: issue,
      );
    }
    return parseEnvelope(response.statusCode, response.data);
  }

  static Object? parseEnvelope(int? statusCode, Object? data) {
    if (statusCode == 429) {
      throw const PanelException(LbErrorCode.rateLimited, 'Too Many Requests');
    }
    if (data is! Map) {
      throw PanelException(statusCode ?? 0, 'HTTP $statusCode');
    }
    final code = (data['code'] as num?)?.toInt() ?? statusCode ?? 0;
    if (code != 200) {
      throw PanelException(code, data['msg'] as String? ?? '');
    }
    return data['data'];
  }

  Future<String> login({
    required String email,
    required String password,
    String? captchaTicket,
  }) async {
    final data =
        await _call(
              'POST',
              '/v1/auth/login',
              body: {
                'email': email,
                'password': password,
                'captcha_ticket': ?captchaTicket,
              },
            )
            as Map;
    return data['token'] as String;
  }

  /// Registration codes need a slide captcha ticket on every send.
  Future<void> sendEmailCode({
    required String email,
    required String captchaTicket,
  }) async {
    await _call(
      'POST',
      '/v1/common/send_code',
      body: {'email': email, 'type': 1, 'captcha_ticket': captchaTicket},
    );
  }

  Future<String> register({
    required String email,
    required String password,
    required String code,
    String? invite,
    String? captchaTicket,
  }) async {
    final data =
        await _call(
              'POST',
              '/v1/auth/register',
              body: {
                'email': email,
                'password': password,
                'code': code,
                'invite': ?invite,
                'captcha_ticket': ?captchaTicket,
              },
            )
            as Map;
    return data['token'] as String;
  }

  Future<List<LbPlan>> plans(String jwt) async => lbSellablePlans(
    await _call('GET', '/v1/public/subscribe/list', token: jwt),
  );

  Future<List<LbPaymentMethod>> paymentMethods(String jwt) async {
    final data =
        await _call('GET', '/v1/public/portal/payment-method', token: jwt)
            as Map?;
    return [
      for (final item in data?['list'] as List? ?? const [])
        LbPaymentMethod.fromPanel((item as Map).cast<String, Object?>()),
    ];
  }

  /// The server prices every order; the app only shows what comes back.
  Future<LbQuote> quote(
    String jwt, {
    required int planId,
    required int quantity,
    required int payment,
    int? userSubscribeId,
  }) async {
    final data =
        await _call(
              'POST',
              '/v1/public/order/pre',
              token: jwt,
              body: {
                'subscribe_id': planId,
                'quantity': quantity,
                'payment': payment,
                'user_subscribe_id': ?userSubscribeId,
              },
            )
            as Map;
    return LbQuote.fromPanel(data.cast<String, Object?>());
  }

  Future<String> purchase(
    String jwt, {
    required int planId,
    required int quantity,
    required int payment,
  }) async {
    final data =
        await _call(
              'POST',
              '/v1/public/order/purchase',
              token: jwt,
              body: {
                'subscribe_id': planId,
                'quantity': quantity,
                'payment': payment,
              },
            )
            as Map;
    return data['order_no'] as String;
  }

  Future<String> renew(
    String jwt, {
    required int userSubscribeId,
    required int quantity,
    required int payment,
  }) async {
    final data =
        await _call(
              'POST',
              '/v1/public/order/renewal',
              token: jwt,
              body: {
                'user_subscribe_id': userSubscribeId,
                'quantity': quantity,
                'payment': payment,
              },
            )
            as Map;
    return '${data['order_no']}';
  }

  Future<LbOrder> order(String jwt, String orderNo) async {
    final data =
        await _call(
              'GET',
              '/v1/public/order/detail',
              token: jwt,
              query: {'order_no': orderNo},
            )
            as Map;
    return LbOrder.fromPanel(data.cast<String, Object?>());
  }

  Future<LbCheckout> checkout(
    String jwt, {
    required String orderNo,
    required String returnUrl,
  }) async {
    final data =
        await _call(
              'POST',
              '/v1/public/portal/order/checkout',
              token: jwt,
              body: {'orderNo': orderNo, 'returnUrl': returnUrl},
            )
            as Map;
    return LbCheckout.fromPanel(data.cast<String, Object?>());
  }

  Future<List<LbAnnouncement>> announcements(String jwt) async =>
      LbAnnouncement.listFrom(
        await _call(
          'GET',
          '/v1/public/announcement/list',
          token: jwt,
          query: {'page': 1, 'size': 20},
        ),
      );

  Future<List<LbSubscription>> subscriptions(String jwt) async {
    final data =
        await _call('GET', '/v1/public/user/subscribe', token: jwt) as Map?;
    final list = data?['list'] as List? ?? const [];
    return [
      for (final item in list)
        LbSubscription.fromPanel((item as Map).cast<String, Object?>()),
    ];
  }

  Future<String?> email(String jwt) async {
    final data = await _call('GET', '/v1/public/user/info', token: jwt) as Map?;
    final methods = data?['auth_methods'] as List? ?? const [];
    for (final method in methods) {
      if (method is Map && method['auth_type'] == 'email') {
        return method['auth_identifier'] as String?;
      }
    }
    return null;
  }

  Future<LbSiteConfig> siteConfig() async {
    final data = await _call('GET', '/v1/common/site/config') as Map?;
    return LbSiteConfig.fromPanel(
      data?.cast<String, Object?>() ?? const {},
      panelUrl,
    );
  }

  Future<LbSlideCaptcha> slideCaptcha() async {
    final data = await _call('GET', '/v1/common/captcha/slide') as Map;
    return LbSlideCaptcha.fromPanel(data.cast<String, Object?>());
  }

  Future<String> verifySlideCaptcha({
    required String id,
    required int x,
    required int y,
  }) async {
    final data =
        await _call(
              'POST',
              '/v1/common/captcha/slide/verify',
              body: {'id': id, 'x': x, 'y': y},
            )
            as Map;
    return data['ticket'] as String;
  }
}
