import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LbPlanSummary {
  final String name;
  final bool expired;
  final bool exhausted;
  final String status;
  final String expireText;
  final double progress;
  final String usage;

  const LbPlanSummary({
    required this.name,
    required this.expired,
    required this.exhausted,
    required this.status,
    required this.expireText,
    required this.progress,
    required this.usage,
  });

  bool get warn => expired || exhausted;

  factory LbPlanSummary.of(LbSubscription subscription, DateTime now) {
    final expired = subscription.isExpired(now);
    final exhausted = subscription.isTrafficExhausted;
    final traffic = subscription.traffic;
    return LbPlanSummary(
      name: subscription.name.isEmpty ? LbStrings.appName : subscription.name,
      expired: expired,
      exhausted: exhausted,
      status: expired
          ? LbStrings.planExpired
          : exhausted
          ? LbStrings.planExhausted
          : LbStrings.planActive,
      expireText: subscription.expireTime == 0
          ? LbStrings.neverExpires
          : LbStrings.expiresOn(
              lbFormatDate(subscription.expireTime),
              expired ? null : subscription.daysLeft(now),
            ),
      progress: traffic > 0
          ? (subscription.used / traffic).clamp(0.0, 1.0)
          : 0.0,
      usage:
          '${lbFormatBytes(subscription.used)} / '
          '${traffic > 0 ? lbFormatBytes(traffic) : LbStrings.unlimited}',
    );
  }
}

/// From a week before the end, unlike the three-day startup reminder.
String? lbPlanTip(LbSubscription subscription, DateTime now) {
  if (subscription.isExpired(now)) return LbStrings.expiredTip;
  if (subscription.isTrafficExhausted) return LbStrings.exhaustedTip;
  final days = subscription.daysLeft(now);
  if (days != null && days <= 7) return LbStrings.expiresSoon(days);
  return null;
}

/// Expired, out of traffic, or within three days of its end (01 §5).
String? lbPlanReminder(LbSubscription subscription, DateTime now) {
  if (subscription.isExpired(now)) return LbStrings.expiredTip;
  if (subscription.isTrafficExhausted) return LbStrings.exhaustedTip;
  final days = subscription.daysLeft(now);
  if (days != null && days <= 3) return LbStrings.expiresSoon(days);
  return null;
}

/// The panel stops serving a plan once it expires or runs out of traffic, so
/// a dead line on such a plan is the plan's doing, not the node's.
String? lbPlanBlockReason(LbSubscription? subscription, DateTime now) {
  if (subscription == null) return null;
  if (subscription.isExpired(now)) return LbStrings.lineDownExpired;
  if (subscription.isTrafficExhausted) return LbStrings.lineDownExhausted;
  return null;
}

const _remindedKey = 'lb_plan_reminded_on';

Future<bool> lbClaimDailyReminder(DateTime today) async {
  final prefs = await SharedPreferences.getInstance();
  final stamp = '${today.year}-${today.month}-${today.day}';
  if (prefs.getString(_remindedKey) == stamp) return false;
  await prefs.setString(_remindedKey, stamp);
  return true;
}
