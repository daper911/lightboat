import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/models/models.dart';

enum LbPlanStatus { pending, active, finished, expired, deducted, stopped }

LbPlanStatus _parseStatus(Object? value) {
  final index = (value as num?)?.toInt() ?? 1;
  if (index < 0 || index >= LbPlanStatus.values.length) {
    return LbPlanStatus.active;
  }
  return LbPlanStatus.values[index];
}

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

class LbSubscription {
  final int id;

  /// The plan this subscription was bought from; renewals are priced by it.
  final int planId;
  final String token;
  final String name;
  final LbPlanStatus status;

  /// Milliseconds since epoch; 0 means it never expires.
  final int expireTime;

  /// Bytes; 0 means unlimited.
  final int traffic;
  final int upload;
  final int download;
  final bool renewable;

  const LbSubscription({
    required this.id,
    this.planId = 0,
    required this.token,
    required this.name,
    required this.status,
    required this.expireTime,
    required this.traffic,
    required this.upload,
    required this.download,
    this.renewable = true,
  });

  factory LbSubscription.fromPanel(Map<String, Object?> json) {
    final plan = json['subscribe'] as Map<String, Object?>? ?? const {};
    return LbSubscription(
      id: _int(json['id']),
      planId: _int(json['subscribe_id'] ?? plan['id']),
      token: json['token'] as String? ?? '',
      name: plan['name'] as String? ?? '',
      status: _parseStatus(json['status']),
      expireTime: _int(json['expire_time']),
      traffic: _int(json['traffic']),
      upload: _int(json['upload']),
      download: _int(json['download']),
      renewable: plan['sell'] as bool? ?? true,
    );
  }

  factory LbSubscription.fromJson(Map<String, Object?> json) => LbSubscription(
    id: _int(json['id']),
    planId: _int(json['planId']),
    token: json['token'] as String? ?? '',
    name: json['name'] as String? ?? '',
    status: _parseStatus(json['status']),
    expireTime: _int(json['expireTime']),
    traffic: _int(json['traffic']),
    upload: _int(json['upload']),
    download: _int(json['download']),
    renewable: json['renewable'] as bool? ?? true,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'planId': planId,
    'token': token,
    'name': name,
    'status': status.index,
    'expireTime': expireTime,
    'traffic': traffic,
    'upload': upload,
    'download': download,
    'renewable': renewable,
  };

  /// Folds in the `subscription-userinfo` header, whose `expire` is seconds.
  LbSubscription withUserinfo(SubscriptionInfo info) => LbSubscription(
    id: id,
    planId: planId,
    token: token,
    name: name,
    status: status,
    expireTime: info.expire * 1000,
    traffic: info.total,
    upload: info.upload,
    download: info.download,
    renewable: renewable,
  );

  int get used => upload + download;

  bool isExpired(DateTime now) =>
      status == LbPlanStatus.expired ||
      (expireTime != 0 && expireTime <= now.millisecondsSinceEpoch);

  bool get isTrafficExhausted => traffic > 0 && used >= traffic;

  /// Whole days left, or null when the plan never expires.
  int? daysLeft(DateTime now) {
    if (expireTime == 0) return null;
    final left = DateTime.fromMillisecondsSinceEpoch(
      expireTime,
    ).difference(now);
    if (left.isNegative) return 0;
    return (left.inHours / 24).ceil();
  }
}

/// Picks the plan the app connects with: the remembered one while it is still
/// listed, else the first active one, else the first one shown at all.
LbSubscription? pickSubscription(
  List<LbSubscription> list, {
  int? preferredId,
}) {
  final visible = list
      .where((item) => item.status != LbPlanStatus.deducted)
      .toList();
  if (visible.isEmpty) return null;
  if (preferredId != null) {
    for (final item in visible) {
      if (item.id == preferredId) return item;
    }
  }
  for (final item in visible) {
    if (item.status == LbPlanStatus.active) return item;
  }
  return visible.first;
}

class LbSlideCaptcha {
  final String id;
  final Uint8List image;
  final Uint8List thumb;
  final int thumbX;
  final int thumbY;
  final int thumbWidth;
  final int thumbHeight;

  static const imageWidth = 300;
  static const imageHeight = 220;

  const LbSlideCaptcha({
    required this.id,
    required this.image,
    required this.thumb,
    required this.thumbX,
    required this.thumbY,
    required this.thumbWidth,
    required this.thumbHeight,
  });

  factory LbSlideCaptcha.fromPanel(Map<String, Object?> json) => LbSlideCaptcha(
    id: json['id'] as String? ?? '',
    image: _decodeDataUri(json['image'] as String? ?? ''),
    thumb: _decodeDataUri(json['thumb'] as String? ?? ''),
    thumbX: _int(json['thumb_x']),
    thumbY: _int(json['thumb_y']),
    thumbWidth: _int(json['thumb_width']),
    thumbHeight: _int(json['thumb_height']),
  );

  /// Maps the slider offset to the piece's x in the 300-pixel source image,
  /// the same mapping the website's go-captcha-react uses.
  double pieceX(double offset, double trackWidth, double knobWidth) {
    final travel = trackWidth - knobWidth;
    if (travel <= 0) return thumbX.toDouble();
    final clamped = offset.clamp(0, travel);
    return thumbX + clamped * (imageWidth - thumbWidth - thumbX) / travel;
  }
}

Uint8List _decodeDataUri(String value) {
  final comma = value.indexOf(',');
  return base64Decode(comma >= 0 ? value.substring(comma + 1) : value);
}

class LbAnnouncement {
  final int id;
  final String title;

  /// Markdown as written in the panel.
  final String content;
  final bool pinned;
  final bool popup;

  /// Milliseconds since epoch.
  final int createdAt;

  const LbAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    this.pinned = false,
    this.popup = false,
    this.createdAt = 0,
  });

  /// Hidden ones (`show: false`) are dropped; pinned first, then newest.
  static List<LbAnnouncement> listFrom(Object? data) {
    final items = (data as Map?)?['announcements'] as List? ?? const [];
    return [
      for (final item in items.cast<Map<String, Object?>>())
        if (item['show'] != false)
          LbAnnouncement(
            id: _int(item['id']),
            title: item['title'] as String? ?? '',
            content: item['content'] as String? ?? '',
            pinned: item['pinned'] == true,
            popup: item['popup'] == true,
            createdAt: _int(item['created_at']),
          ),
    ]..sort(
      (a, b) => a.pinned != b.pinned
          ? (a.pinned ? -1 : 1)
          : b.createdAt.compareTo(a.createdAt),
    );
  }
}
