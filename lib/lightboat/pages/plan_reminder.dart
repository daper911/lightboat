import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/pages/purchase.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What to tell the user about [subscription] today, or null when it is fine:
/// expired, out of traffic, or within three days of its end (01 §5).
String? lbPlanReminder(LbSubscription subscription, DateTime now) {
  if (subscription.isExpired(now)) return LbStrings.expiredTip;
  if (subscription.isTrafficExhausted) return LbStrings.exhaustedTip;
  final days = subscription.daysLeft(now);
  if (days != null && days <= 3) return LbStrings.expiresSoon(days);
  return null;
}

const _remindedKey = 'lb_plan_reminded_on';

/// At most once a day. True when a reminder was shown, so the caller can hold
/// back other startup prompts.
Future<bool> lbRemindPlan(
  BuildContext context,
  LbSubscription? subscription, {
  DateTime? now,
}) async {
  final today = now ?? DateTime.now();
  final message = subscription == null
      ? null
      : lbPlanReminder(subscription, today);
  if (subscription == null || message == null) return false;
  final prefs = await SharedPreferences.getInstance();
  final stamp = '${today.year}-${today.month}-${today.day}';
  if (prefs.getString(_remindedKey) == stamp) return false;
  await prefs.setString(_remindedKey, stamp);
  if (!context.mounted) return false;
  final renew = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(LbStrings.planReminderTitle),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(LbStrings.later),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            subscription.renewable ? LbStrings.renewPlan : LbStrings.buy,
          ),
        ),
      ],
    ),
  );
  if (renew == true && context.mounted) {
    await showLbPurchase(
      context,
      renewing: subscription.renewable ? subscription : null,
    );
  }
  return true;
}
