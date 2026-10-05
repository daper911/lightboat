import 'package:url_launcher/url_launcher.dart';

Future<void> lbOpenUrl(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

String lbFormatDate(int milliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

String lbFormatBytes(int bytes) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) {
    final value = bytes / gb;
    return '${value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} GB';
  }
  return '${(bytes / mb).toStringAsFixed(0)} MB';
}

/// Null until the line has been tested; a non-positive delay is a timeout.
String? lbDelayText(int? delay) => delay == null
    ? null
    : delay > 0
    ? '$delay ms'
    : 'Timeout';

/// Region names for the exit country codes the nodes are likely to use.
String lbRegionName(String code) {
  const names = {
    'HK': '香港',
    'TW': '台湾',
    'MO': '澳门',
    'CN': '中国大陆',
    'JP': '日本',
    'KR': '韩国',
    'SG': '新加坡',
    'US': '美国',
    'GB': '英国',
    'DE': '德国',
    'FR': '法国',
    'NL': '荷兰',
    'CA': '加拿大',
    'AU': '澳大利亚',
    'MY': '马来西亚',
    'TH': '泰国',
    'VN': '越南',
    'PH': '菲律宾',
    'IN': '印度',
    'RU': '俄罗斯',
    'TR': '土耳其',
    'AE': '阿联酋',
  };
  final upper = code.toUpperCase();
  return names[upper] ?? upper;
}
