import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/logic/account.dart';
import 'package:fl_clash/lightboat/logic/plan.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the purchase in whichever shell is showing, renewing when given.
typedef LbOpenPurchase = Future<void> Function(LbSubscription? renewing);

/// True when a reminder was shown, so the caller can hold back other startup
/// prompts.
Future<bool> lbRemindPlan(
  BuildContext context,
  LbSubscription? subscription, {
  required LbOpenPurchase openPurchase,
  DateTime? now,
}) async {
  final today = now ?? DateTime.now();
  final message = subscription == null
      ? null
      : lbPlanReminder(subscription, today);
  if (subscription == null || message == null) return false;
  if (!await lbClaimDailyReminder(today)) return false;
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
    await openPurchase(subscription.renewable ? subscription : null);
  }
  return true;
}

Future<void> lbShowAnnouncement(BuildContext context, LbAnnouncement item) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(item.title),
      content: SingleChildScrollView(
        child: SelectableText(lbMarkdownToText(item.content)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(LbStrings.gotIt),
        ),
      ],
    ),
  );
}

Future<void> lbShowPopupAnnouncement(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!ref.read(lbSessionProvider).hasJwt) return;
  try {
    final next = await lbTakeNewPopup(
      await ref.read(lbAnnouncementsProvider.future),
    );
    if (next != null && context.mounted) {
      await lbShowAnnouncement(context, next);
    }
  } catch (error) {
    commonPrint.log('lightboat announcements: $error');
  }
}
