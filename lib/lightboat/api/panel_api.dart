import 'package:dio/dio.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/config.dart';

abstract final class LbErrorCode {
  static const rateLimited = 401;
  static const userNotFound = 20002;
  static const wrongPassword = 20003;
  static const userDisabled = 20004;
  static const captchaRequired = 110001;
  static const captchaFailed = 110002;
  static const network = -1;

  static bool isAuthExpired(int code) => code >= 40002 && code <= 40005;
}

class PanelException implements Exception {
  final int code;
  final String message;

  const PanelException(this.code, this.message);

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
    Dio? dio,
  }) : _panelUrls = panelUrls,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
               headers: {'User-Agent': userAgent},
               responseType: ResponseType.json,
               validateStatus: (_) => true,
             ),
           );

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
    String? token,
  }) async {
    final base = await _resolvePanel();
    final Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        '$base$path',
        data: body,
        options: Options(method: method, headers: {'Authorization': ?token}),
      );
    } on DioException catch (error) {
      _panelUrl = null;
      throw PanelException(LbErrorCode.network, error.message ?? '$error');
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
