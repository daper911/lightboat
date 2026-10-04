import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/diagnostics.dart';
import 'package:fl_clash/lightboat/pages/apps.dart';
import 'package:fl_clash/lightboat/pages/home.dart';
import 'package:fl_clash/lightboat/pages/login.dart';
import 'package:fl_clash/lightboat/pages/logo.dart';
import 'package:fl_clash/lightboat/pages/purchase.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/lightboat/update.dart';
import 'package:fl_clash/pages/pages.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class LbMePage extends ConsumerStatefulWidget {
  const LbMePage({super.key});

  @override
  ConsumerState<LbMePage> createState() => _LbMePageState();
}

class _LbMePageState extends ConsumerState<LbMePage> {
  int _versionTaps = 0;

  bool get _advancedUnlocked => _versionTaps >= 7;

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(LbStrings.logout),
        content: const Text(LbStrings.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(LbStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(LbStrings.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(lbSessionProvider.notifier).logout();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _switchPlan() async {
    final session = ref.read(lbSessionProvider);
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text(LbStrings.switchPlan),
        children: [
          for (final item in session.subscriptions)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(item.id),
              child: Text(
                item.expireTime == 0
                    ? item.name
                    : '${item.name} · ${lbFormatDate(item.expireTime)}',
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    final subscription = session.subscriptions.firstWhere(
      (item) => item.id == chosen,
    );
    await ref.read(lbSessionProvider.notifier).selectSubscription(subscription);
  }

  Future<void> _exportLogs() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await lbExportLogs(ref)) return;
      messenger.showSnackBar(
        const SnackBar(content: Text(LbStrings.exportLogsDone)),
      );
    } catch (error) {
      commonPrint.log('lightboat export logs: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text(LbStrings.exportLogsFailed)),
      );
    }
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final colors = LbColors.of(context);
        return AlertDialog(
          icon: const LbLogo(size: 56),
          title: const Text(LbStrings.appName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${LbStrings.version} ${globalState.packageInfo.version}',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: 12),
              const Text(LbStrings.aboutBasedOn),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => unawaited(lbOpenUrl(LbConfig.sourceUrl)),
              child: const Text(LbStrings.sourceCode),
            ),
            TextButton(
              onPressed: () => unawaited(lbOpenUrl(LbConfig.tosUrl)),
              child: const Text(LbStrings.tos),
            ),
            TextButton(
              onPressed: () => unawaited(lbOpenUrl(LbConfig.privacyUrl)),
              child: const Text(LbStrings.privacy),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final session = ref.watch(lbSessionProvider);
    final subscription = session.subscription;
    final textTheme = context.textTheme;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        surfaceTintColor: Colors.transparent,
        title: const Text(LbStrings.me),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            session.email ?? '',
            style: textTheme.titleLarge?.copyWith(color: colors.ink),
          ),
          const SizedBox(height: 4),
          if (subscription != null)
            Text(
              subscription.expireTime == 0
                  ? '${subscription.name} · ${LbStrings.neverExpires}'
                  : '${subscription.name} · '
                        '${LbStrings.expiresOn(lbFormatDate(subscription.expireTime), null)}',
              style: textTheme.bodyMedium?.copyWith(color: colors.muted),
            ),
          if (!session.hasJwt) ...[
            const SizedBox(height: 12),
            Text(
              LbStrings.loginExpired,
              style: textTheme.bodyMedium?.copyWith(color: colors.seal),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LbLoginPage()),
                ),
                child: const Text(LbStrings.relogin),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.accentInk,
              ),
              onPressed: () => unawaited(
                showLbPurchase(
                  context,
                  renewing: subscription != null && subscription.renewable
                      ? subscription
                      : null,
                ),
              ),
              child: Text(
                subscription == null ? LbStrings.buyPlan : LbStrings.renew,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: colors.rule),
          if (session.subscriptions.length > 1)
            _MeRow(
              label: LbStrings.switchPlan,
              onTap: () => unawaited(_switchPlan()),
            ),
          _MeRow(
            label: LbStrings.splitTunnel,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const LbAppsPage())),
          ),
          _MeRow(
            label: LbStrings.refreshPlan,
            onTap: () =>
                unawaited(ref.read(lbSessionProvider.notifier).refresh()),
          ),
          _MeRow(
            label: LbStrings.orders,
            onTap: () => unawaited(lbOpenUrl(LbConfig.siteLink('order'))),
          ),
          _MeRow(
            label: LbStrings.tutorial,
            onTap: () => unawaited(lbOpenUrl(LbConfig.tutorialUrl)),
          ),
          _MeRow(
            label: LbStrings.support,
            trailing: LbConfig.supportEmail,
            onTap: () => unawaited(lbOpenUrl(LbConfig.ticketUrl)),
          ),
          _MeRow(
            label: LbStrings.checkUpdate,
            onTap: () => unawaited(lbCheckForUpdate(context, manual: true)),
          ),
          _MeRow(
            label: LbStrings.exportLogs,
            onTap: () => unawaited(_exportLogs()),
          ),
          _MeRow(
            label: LbStrings.about,
            trailing: globalState.packageInfo.version,
            onTap: () {
              setState(() => _versionTaps++);
              _showAbout();
            },
          ),
          if (_advancedUnlocked)
            _MeRow(
              label: LbStrings.advanced,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const HomePage())),
            ),
          Divider(color: colors.rule),
          _MeRow(
            label: LbStrings.logout,
            color: colors.seal,
            onTap: () => unawaited(_confirmLogout()),
          ),
        ],
      ),
    );
  }
}

class _MeRow extends StatelessWidget {
  final String label;
  final String? trailing;
  final Color? color;
  final VoidCallback onTap;

  const _MeRow({
    required this.label,
    required this.onTap,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return InkWell(
      customBorder: AppShape.md,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: color ?? colors.ink,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.muted,
                ),
              ),
            if (color == null)
              GlyphIcon(AppGlyphs.chevronForward, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
