import 'dart:io';

abstract final class LbConfig {
  /// Tried in order; the first one answering the heartbeat wins.
  static const panelUrls = ['https://ssr.cnbetx.com'];

  static const fallbackSubscribeDomain = 'sub.cnbetx.com';
  static const fallbackSubscribePath = '/api/subscribe';

  static const profileLabel = '轻舟';

  /// The panel picks the subscription format by User-Agent and only answers
  /// with mihomo YAML when it contains `clash`.
  static String userAgent(String version, {bool? windows}) =>
      'Lightboat-${(windows ?? Platform.isWindows) ? 'Windows' : 'Android'}'
      '/$version (Clash.Meta)';

  static const proxyGroup = '🚀 Proxy';
  static const autoProxy = '🌏 Auto';

  /// mihomo's own group for global mode; it starts on DIRECT.
  static const globalGroup = 'GLOBAL';

  static const sourceUrl = 'https://github.com/daper911/lightboat';

  /// Where `latest.json` and the installers live (R2 behind cdn.cnbetx.com).
  static const releaseUrl = 'https://cdn.cnbetx.com/lightboat/latest.json';

  static const supportEmail = 'support@mail.cnbetx.com';

  static String siteLink(String route) => '${panelUrls.first}/#/$route';

  static final registerUrl = siteLink('auth');
  static final tutorialUrl = siteLink('document');
  static final ticketUrl = siteLink('ticket');
  static final tosUrl = siteLink('tos');
  static final privacyUrl = siteLink('privacy-policy');
}
