import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/pages/lines.dart';
import 'package:fl_clash/lightboat/pages/login.dart';
import 'package:fl_clash/lightboat/pages/me.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LbHomePage extends ConsumerWidget {
  const LbHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final session = ref.watch(lbSessionProvider);
    final subscription = session.subscription;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        surfaceTintColor: Colors.transparent,
        title: Text(
          LbStrings.appName,
          style: context.textTheme.titleLarge?.copyWith(
            color: colors.ink,
            fontFamily: lbSerif,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: LbStrings.me,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const LbMePage())),
            icon: GlyphIcon(AppGlyphs.account, color: colors.ink),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: colors.accent,
        onRefresh: () => ref.read(lbSessionProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (subscription == null)
              const _NoPlanCard()
            else
              _PlanCard(subscription: subscription),
            const SizedBox(height: 40),
            const Center(child: _ConnectButton()),
            const SizedBox(height: 40),
            const _LineCard(),
            if (subscription != null) _PlanTip(subscription: subscription),
            if (session.syncing || session.syncError != null) ...[
              const SizedBox(height: 16),
              Text(
                session.syncing ? LbStrings.syncing : LbStrings.syncFailed,
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LbCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const LbCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return Material(
      color: Colors.transparent,
      shape: AppShape.xl.copyWith(side: BorderSide(color: colors.rule)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: AppShape.xl,
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      ),
    );
  }
}

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

class _PlanCard extends StatelessWidget {
  final LbSubscription subscription;

  const _PlanCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final now = DateTime.now();
    final expired = subscription.isExpired(now);
    final exhausted = subscription.isTrafficExhausted;
    final warn = expired || exhausted;
    final status = expired
        ? LbStrings.planExpired
        : exhausted
        ? LbStrings.planExhausted
        : LbStrings.planActive;
    final expireText = subscription.expireTime == 0
        ? LbStrings.neverExpires
        : LbStrings.expiresOn(
            lbFormatDate(subscription.expireTime),
            expired ? null : subscription.daysLeft(now),
          );
    final traffic = subscription.traffic;
    final progress = traffic > 0
        ? (subscription.used / traffic).clamp(0.0, 1.0)
        : 0.0;
    const tabular = [FontFeature.tabularFigures()];
    return LbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subscription.name.isEmpty
                      ? LbStrings.appName
                      : subscription.name,
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '● $status',
                style: textTheme.labelLarge?.copyWith(
                  color: warn ? colors.seal : colors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            expireText,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.muted,
              fontFeatures: tabular,
            ),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: traffic > 0 ? progress : 0,
            minHeight: 6,
            color: exhausted ? colors.seal : colors.accent,
            backgroundColor: colors.accentSoft,
          ),
          const SizedBox(height: 8),
          Text(
            '${lbFormatBytes(subscription.used)} / '
            '${traffic > 0 ? lbFormatBytes(traffic) : LbStrings.unlimited}',
            style: textTheme.bodySmall?.copyWith(
              color: colors.muted,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard();

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return LbCard(
      onTap: () => unawaited(lbOpenUrl(LbConfig.purchaseUrl)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              LbStrings.noPlan,
              style: context.textTheme.titleMedium?.copyWith(color: colors.ink),
            ),
          ),
          Text(
            LbStrings.buyPlan,
            style: context.textTheme.labelLarge?.copyWith(color: colors.accent),
          ),
          GlyphIcon(AppGlyphs.chevronForward, color: colors.accent),
        ],
      ),
    );
  }
}

class _PlanTip extends StatelessWidget {
  final LbSubscription subscription;

  const _PlanTip({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = subscription.daysLeft(now);
    final String? message;
    if (subscription.isExpired(now)) {
      message = LbStrings.expiredTip;
    } else if (subscription.isTrafficExhausted) {
      message = LbStrings.exhaustedTip;
    } else if (days != null && days <= 7) {
      message = LbStrings.expiresSoon(days);
    } else {
      message = null;
    }
    if (message == null) return const SizedBox.shrink();
    final colors = LbColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: colors.seal.withValues(alpha: 0.1),
        shape: AppShape.xl,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: AppShape.xl,
          onTap: subscription.renewable
              ? () => unawaited(lbOpenUrl(LbConfig.purchaseUrl))
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                GlyphIcon(AppGlyphs.warning, color: colors.seal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: colors.seal,
                    ),
                  ),
                ),
                if (subscription.renewable)
                  Text(
                    LbStrings.renew,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: colors.seal,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectButton extends ConsumerWidget {
  const _ConnectButton();

  static const _size = 168.0;
  static const _vpnExplainedKey = 'lb_vpn_explained';

  /// Explains the system VPN prompt the first time, before Android shows it.
  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    if (!ref.read(isStartProvider)) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_vpnExplainedKey) != true) {
        if (!context.mounted) return;
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(LbStrings.vpnTitle),
            content: const Text(LbStrings.vpnExplain),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(LbStrings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(LbStrings.continueText),
              ),
            ],
          ),
        );
        if (accepted != true) return;
        await prefs.setBool(_vpnExplainedKey, true);
      }
    }
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final runTime = ref.watch(runTimeProvider);
    final hasProfile = ref.watch(currentProfileProvider) != null;
    final isStart = runTime != null;
    final connecting = isStart && runTime < 1500;
    final connected = isStart && !connecting;
    final label = connecting
        ? LbStrings.connecting
        : connected
        ? '${LbStrings.connected} ${getTimeText(runTime)}'
        : LbStrings.disconnected;
    return Column(
      children: [
        SizedBox.square(
          dimension: _size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (connecting)
                SizedBox.square(
                  dimension: _size,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: colors.accent,
                  ),
                ),
              Material(
                color: connected ? colors.accent : colors.paper,
                shape: AppShape.circle.copyWith(
                  side: BorderSide(
                    color: isStart ? colors.accent : colors.ink,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: AppShape.circle,
                  onTap: hasProfile
                      ? () => unawaited(_toggle(context, ref))
                      : null,
                  child: SizedBox.square(
                    dimension: _size - 16,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GlyphIcon(
                            AppGlyphs.vpn,
                            size: 44,
                            fill: connected ? 1 : 0,
                            color: connected ? colors.accentInk : colors.ink,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isStart ? LbStrings.disconnect : LbStrings.connect,
                            style: context.textTheme.titleMedium?.copyWith(
                              color: connected ? colors.accentInk : colors.ink,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: context.textTheme.titleMedium?.copyWith(
            color: isStart ? colors.accent : colors.muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// The group the home page calls 线路: `🚀 Proxy`, else the first selector.
Group? lbLineGroup(List<Group> groups) =>
    groups.firstWhereOrNull((group) => group.name == LbConfig.proxyGroup) ??
    groups.firstWhereOrNull((group) => group.type == GroupType.Selector);

String lbLineName(String? name) =>
    name == null || name == LbConfig.autoProxy ? LbStrings.autoLine : name;

class _LineCard extends ConsumerWidget {
  const _LineCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final group = lbLineGroup(ref.watch(groupsProvider));
    final now = group?.now;
    final delay = now == null
        ? null
        : ref.watch(delayProvider(proxyName: now, testUrl: group?.testUrl));
    final autoNode = now == LbConfig.autoProxy
        ? ref
              .watch(groupsProvider)
              .firstWhereOrNull((item) => item.name == now)
              ?.now
        : null;
    final lineText = autoNode == null
        ? lbLineName(now)
        : '${LbStrings.autoLine}（$autoNode）';
    final labelStyle = context.textTheme.bodyMedium?.copyWith(
      color: colors.muted,
    );
    final valueStyle = context.textTheme.bodyLarge?.copyWith(
      color: colors.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return LbCard(
      onTap: () => unawaited(showLbLines(context)),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(LbStrings.line, style: labelStyle),
              ),
              Expanded(
                child: Text(
                  group == null ? '—' : lineText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
              GlyphIcon(AppGlyphs.chevronForward, color: colors.muted),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(LbStrings.delay, style: labelStyle),
              ),
              Expanded(
                child: Text(
                  delay == null
                      ? '—'
                      : delay > 0
                      ? '$delay ms'
                      : 'Timeout',
                  style: valueStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
