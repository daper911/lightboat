import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/desktop/auth.dart';
import 'package:fl_clash/lightboat/desktop/shell.dart';
import 'package:fl_clash/lightboat/diagnostics.dart';
import 'package:fl_clash/lightboat/logic/account.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/lightboat/update.dart';
import 'package:fl_clash/lightboat/widgets/card.dart';
import 'package:fl_clash/lightboat/widgets/logo.dart';
import 'package:fl_clash/lightboat/widgets/prompts.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/pages.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class LbDesktopMe extends ConsumerStatefulWidget {
  const LbDesktopMe({super.key});

  @override
  ConsumerState<LbDesktopMe> createState() => _LbDesktopMeState();
}

class _LbDesktopMeState extends ConsumerState<LbDesktopMe> {
  int _versionTaps = 0;

  bool get _advancedUnlocked => _versionTaps >= 7;

  LbSession get _session => ref.read(lbSessionProvider.notifier);

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(LbStrings.logoutTitle),
        content: const Text(LbStrings.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(LbStrings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: LbColors.of(context).seal,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(LbStrings.logout),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _session.logout();
    ref.read(lbDesktopNavProvider.notifier).go(LbDesktopTab.home);
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
    await _session.selectSubscription(
      session.subscriptions.firstWhere((item) => item.id == chosen),
    );
  }

  Future<void> _refresh() async {
    lbToast(context, LbStrings.syncing);
    await _session.refresh();
    if (!mounted) return;
    final state = ref.read(lbSessionProvider);
    final failed = state.syncError != null;
    lbToast(
      context,
      failed
          ? LbStrings.syncFailedFor(hasJwt: state.hasJwt)
          : LbStrings.refreshDone,
      error: failed,
    );
  }

  Future<void> _exportLogs() async {
    try {
      if (!await lbExportLogs(ref)) return;
      if (mounted) lbToast(context, LbStrings.exportLogsDone);
    } catch (error) {
      commonPrint.log('lightboat export logs: $error');
      if (mounted) lbToast(context, LbStrings.exportLogsFailed, error: true);
    }
  }

  void _showAnnouncements() {
    showDialog<void>(
      context: context,
      builder: (context) => const _AnnouncementsDialog(),
    );
  }

  void _showAbout() {
    setState(() => _versionTaps++);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const LbLogo(size: 56),
        title: const Text(LbStrings.appName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${LbStrings.version} ${globalState.packageInfo.version}',
              style: context.textTheme.bodyMedium?.copyWith(
                color: LbColors.of(context).muted,
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
      ),
    );
  }

  void _updateSetting(AppSettingProps Function(AppSettingProps) update) =>
      ref.read(appSettingProvider.notifier).update(update);

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final session = ref.watch(lbSessionProvider);
    final subscription = session.subscription;
    final settings = ref.watch(appSettingProvider);
    final navigator = ref.read(lbDesktopNavProvider.notifier);
    final account = LbCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.email ?? '',
                  style: textTheme.titleLarge?.copyWith(color: colors.ink),
                ),
                if (subscription != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subscription.expireTime == 0
                        ? '${subscription.name} · ${LbStrings.neverExpires}'
                        : '${subscription.name} · '
                              '${LbStrings.expiresOn(lbFormatDate(subscription.expireTime), null)}',
                    style: textTheme.bodyMedium?.copyWith(color: colors.muted),
                  ),
                ],
                if (!session.hasJwt) ...[
                  const SizedBox(height: 8),
                  Text(
                    LbStrings.loginExpired,
                    style: textTheme.bodyMedium?.copyWith(color: colors.seal),
                  ),
                ],
              ],
            ),
          ),
          if (!session.hasJwt) ...[
            OutlinedButton(
              onPressed: () => unawaited(showLbDesktopLogin(context)),
              child: const Text(LbStrings.relogin),
            ),
            const SizedBox(width: 12),
          ],
          FilledButton(
            onPressed: () => navigator.openPurchase(
              subscription != null && subscription.renewable
                  ? subscription
                  : null,
            ),
            child: Text(
              subscription == null ? LbStrings.buyPlan : LbStrings.renew,
            ),
          ),
        ],
      ),
    );
    final left = Column(
      children: [
        _Group(
          title: LbStrings.sectionPlan,
          children: [
            if (session.subscriptions.length > 1)
              _Row(
                label: LbStrings.switchPlan,
                onTap: () => unawaited(_switchPlan()),
              ),
            _Row(
              label: LbStrings.refreshPlan,
              onTap: () => unawaited(_refresh()),
            ),
            _Row(
              label: LbStrings.orders,
              external: true,
              onTap: () => unawaited(lbOpenUrl(LbConfig.siteLink('order'))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Group(
          title: LbStrings.sectionHelp,
          children: [
            if (session.hasJwt)
              _Row(label: LbStrings.announcements, onTap: _showAnnouncements),
            _Row(
              label: LbStrings.tutorial,
              external: true,
              onTap: () => unawaited(lbOpenUrl(LbConfig.tutorialUrl)),
            ),
            _Row(
              label: LbStrings.support,
              trailing: LbConfig.supportEmail,
              external: true,
              onTap: () => unawaited(lbOpenUrl(LbConfig.ticketUrl)),
            ),
            _Row(
              label: LbStrings.exportLogs,
              onTap: () => unawaited(_exportLogs()),
            ),
            _Row(
              label: LbStrings.uploadLogs,
              onTap: () => unawaited(lbUploadLogsWithFeedback(context, ref)),
            ),
          ],
        ),
      ],
    );
    final right = Column(
      children: [
        _Group(
          title: LbStrings.sectionWindows,
          children: [
            _Toggle(
              label: LbStrings.autoLaunch,
              value: settings.autoLaunch,
              onChanged: (value) =>
                  _updateSetting((state) => state.copyWith(autoLaunch: value)),
            ),
            _Toggle(
              label: LbStrings.silentLaunch,
              hint: LbStrings.silentLaunchHint,
              value: settings.silentLaunch,
              onChanged: (value) => _updateSetting(
                (state) => state.copyWith(silentLaunch: value),
              ),
            ),
            _Toggle(
              label: LbStrings.autoConnect,
              value: settings.autoRun,
              onChanged: (value) =>
                  _updateSetting((state) => state.copyWith(autoRun: value)),
            ),
            _Toggle(
              label: LbStrings.minimizeToTray,
              hint: LbStrings.minimizeToTrayHint,
              value: settings.minimizeOnExit,
              onChanged: (value) => _updateSetting(
                (state) => state.copyWith(minimizeOnExit: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Group(
          title: LbStrings.sectionAbout,
          children: [
            _Row(
              label: LbStrings.checkUpdate,
              onTap: () => unawaited(lbCheckForUpdate(context, manual: true)),
            ),
            _Row(
              label: LbStrings.about,
              trailing: globalState.packageInfo.version,
              onTap: _showAbout,
            ),
            if (_advancedUnlocked)
              _Row(
                label: LbStrings.advanced,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HomePage()),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.seal),
            onPressed: () => unawaited(_confirmLogout()),
            child: const Text(LbStrings.logout),
          ),
        ),
      ],
    );
    return LbDesktopPage(
      title: LbStrings.me,
      children: [
        account,
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: context.textTheme.labelMedium?.copyWith(color: colors.muted),
          ),
        ),
        LbCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? trailing;
  final bool external;
  final VoidCallback onTap;

  const _Row({
    required this.label,
    required this.onTap,
    this.trailing,
    this.external = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: colors.ink,
                  ),
                ),
              ),
              if (trailing != null)
                Flexible(
                  child: Text(
                    trailing!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              GlyphIcon(
                external ? AppGlyphs.openExternal : AppGlyphs.chevronForward,
                size: 18,
                color: colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: colors.ink,
                    ),
                  ),
                  if (hint != null)
                    Text(
                      hint!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                      ),
                    ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementsDialog extends ConsumerWidget {
  const _AnnouncementsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final announcements = ref.watch(lbAnnouncementsProvider);
    Widget note(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: context.textTheme.bodyMedium?.copyWith(color: colors.muted),
        ),
      ),
    );
    return AlertDialog(
      title: const Text(LbStrings.announcements),
      content: SizedBox(
        width: 520,
        child: announcements.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              note(LbStrings.panelError(error, action: LbStrings.loadAction)),
          data: (items) => items.isEmpty
              ? note(LbStrings.noAnnouncements)
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(color: colors.rule),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item.pinned ? LbStrings.pinnedMark : ''}'
                        '${item.title}',
                      ),
                      subtitle: Text(
                        lbMarkdownToText(item.content),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => unawaited(lbShowAnnouncement(context, item)),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(LbStrings.close),
        ),
      ],
    );
  }
}
