import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/logic/connection.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/logic/plan.dart';
import 'package:fl_clash/lightboat/mobile/lines.dart';
import 'package:fl_clash/lightboat/mobile/me.dart';
import 'package:fl_clash/lightboat/mobile/purchase.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/lightboat/widgets/card.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
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
            const SizedBox(height: 32),
            const Center(child: _ConnectButton()),
            const SizedBox(height: 28),
            const _ModeCard(),
            const SizedBox(height: 12),
            const _LineCard(),
            if (subscription != null) _PlanTip(subscription: subscription),
            if (session.syncing || session.syncError != null) ...[
              const SizedBox(height: 16),
              Text(
                session.syncing
                    ? LbStrings.syncing
                    : LbStrings.syncFailedFor(hasJwt: session.hasJwt),
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

class _PlanCard extends StatelessWidget {
  final LbSubscription subscription;

  const _PlanCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final summary = LbPlanSummary.of(subscription, DateTime.now());
    const tabular = [FontFeature.tabularFigures()];
    return LbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.name,
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '● ${summary.status}',
                style: textTheme.labelLarge?.copyWith(
                  color: summary.warn ? colors.seal : colors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary.expireText,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.muted,
              fontFeatures: tabular,
            ),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: summary.progress,
            minHeight: 6,
            color: summary.exhausted ? colors.seal : colors.accent,
            backgroundColor: colors.accentSoft,
          ),
          const SizedBox(height: 8),
          Text(
            summary.usage,
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
      onTap: () => unawaited(showLbPurchase(context)),
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
    final message = lbPlanTip(subscription, DateTime.now());
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
              ? () => unawaited(showLbPurchase(context, renewing: subscription))
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

class _ConnectButton extends ConsumerStatefulWidget {
  const _ConnectButton();

  @override
  ConsumerState<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends ConsumerState<_ConnectButton> {
  static const _size = 168.0;
  static const _vpnExplainedKey = 'lb_vpn_explained';

  /// Explains the system VPN prompt the first time, before Android shows it.
  Future<bool> _explainVpnOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_vpnExplainedKey) == true) return true;
    if (!mounted) return false;
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
    if (accepted != true) return false;
    await prefs.setBool(_vpnExplainedKey, true);
    return true;
  }

  Future<void> _toggle() async {
    final starting = !ref.read(isStartProvider);
    if (starting && !await _explainVpnOnce()) return;
    ref.read(lbConnectionProvider.notifier).toggle();
  }

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final runTime = ref.watch(runTimeProvider);
    final phase = ref.watch(lbConnectPhaseProvider);
    final hasProfile = ref.watch(currentProfileProvider) != null;
    final isStart = runTime != null;
    final connecting = phase == LbConnectPhase.connecting;
    final connected = phase == LbConnectPhase.connected;
    final failed = phase == LbConnectPhase.failed;
    final label = failed
        ? LbStrings.connectFailed
        : connecting
        ? LbStrings.connecting
        : connected
        ? '${LbStrings.connected} ${getTimeText(runTime!)}'
        : LbStrings.disconnected;
    final ringColor = failed
        ? colors.seal
        : isStart
        ? colors.accent
        : colors.ink;
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
                  side: BorderSide(color: ringColor, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: AppShape.circle,
                  onTap: hasProfile ? () => unawaited(_toggle()) : null,
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
                            color: connected ? colors.accentInk : ringColor,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isStart ? LbStrings.disconnect : LbStrings.connect,
                            style: textTheme.titleMedium?.copyWith(
                              color: connected ? colors.accentInk : ringColor,
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
          style: textTheme.titleMedium?.copyWith(
            color: failed
                ? colors.seal
                : isStart
                ? colors.accent
                : colors.muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (connected) const _TrafficLine(),
        if (failed) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              LbStrings.connectFailedHint,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: colors.muted),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.seal),
            onPressed: hasProfile ? () => unawaited(_toggle()) : null,
            child: const Text(LbStrings.retry),
          ),
        ],
      ],
    );
  }
}

class _TrafficLine extends ConsumerWidget {
  const _TrafficLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final speed =
        ref.watch(trafficsProvider).list.lastOrNull ?? const Traffic();
    final total = ref.watch(totalTrafficProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '↑ ${speed.up.traffic.show}/s   ↓ ${speed.down.traffic.show}/s   '
        '${LbStrings.sessionUsage((total.up + total.down).traffic.show)}',
        style: context.textTheme.bodySmall?.copyWith(
          color: colors.muted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ModeCard extends ConsumerWidget {
  const _ModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final global = mode == Mode.global;
    return LbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<Mode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: Mode.rule, label: Text(LbStrings.modeSmart)),
              ButtonSegment(
                value: Mode.global,
                label: Text(LbStrings.modeGlobal),
              ),
            ],
            selected: {global ? Mode.global : Mode.rule},
            onSelectionChanged: (value) =>
                ref.read(lbConnectionProvider.notifier).changeMode(value.first),
          ),
          const SizedBox(height: 10),
          Text(
            global ? LbStrings.modeGlobalHint : LbStrings.modeSmartHint,
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends ConsumerStatefulWidget {
  const _LineCard();

  @override
  ConsumerState<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends ConsumerState<_LineCard> with LbExitProbeWatcher {
  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final line = ref.watch(lbLineInfoProvider);
    final now = line?.current;
    final delay = now == null
        ? null
        : ref.watch(
            delayProvider(proxyName: now, testUrl: line?.group.testUrl),
          );
    final isStart = ref.watch(isStartProvider);
    final location = ref.watch(lbExitProbeProvider);
    final countryCode = location.value?.countryCode;
    final locationFailed = location.phase == ProbePhase.failed;
    final subscription = ref.watch(
      lbSessionProvider.select((state) => state.subscription),
    );
    final blocked = locationFailed
        ? lbPlanBlockReason(subscription, DateTime.now())
        : null;
    final labelStyle = context.textTheme.bodyMedium?.copyWith(
      color: colors.muted,
    );
    final valueStyle = context.textTheme.bodyLarge?.copyWith(
      color: colors.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget row(String label, Widget value, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(label, style: labelStyle)),
          Expanded(child: value),
          ?trailing,
        ],
      ),
    );
    return LbCard(
      onTap: () => unawaited(showLbLines(context)),
      child: Column(
        children: [
          row(
            LbStrings.line,
            Text(
              line?.label ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: valueStyle,
            ),
            trailing: GlyphIcon(AppGlyphs.chevronForward, color: colors.muted),
          ),
          row(
            LbStrings.delay,
            Text(
              lbDelayText(delay) ?? '—',
              style: valueStyle?.copyWith(
                color: delay != null && delay <= 0 ? colors.seal : null,
              ),
            ),
            trailing: line == null
                ? null
                : TextButton(
                    onPressed: () =>
                        ref.read(lbConnectionProvider.notifier).testLine(),
                    child: const Text(LbStrings.testDelay),
                  ),
          ),
          if (isStart)
            row(
              LbStrings.location,
              locationFailed
                  ? Text(
                      blocked ?? LbStrings.lineDown,
                      style: valueStyle?.copyWith(color: colors.seal),
                    )
                  : countryCode == null
                  ? Text(LbStrings.locating, style: labelStyle)
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${countryCode.countryFlagEmoji} ',
                            style: TextStyle(
                              fontFamily: FontFamily.twEmoji.value,
                            ),
                          ),
                          TextSpan(text: lbRegionName(countryCode)),
                        ],
                      ),
                      style: valueStyle,
                    ),
              trailing: !locationFailed
                  ? null
                  : blocked != null && subscription != null
                  ? TextButton(
                      style: TextButton.styleFrom(foregroundColor: colors.seal),
                      onPressed: () => unawaited(
                        showLbPurchase(
                          context,
                          renewing: subscription.renewable
                              ? subscription
                              : null,
                        ),
                      ),
                      child: Text(
                        subscription.renewable
                            ? LbStrings.renewPlan
                            : LbStrings.buy,
                      ),
                    )
                  : TextButton(
                      style: TextButton.styleFrom(foregroundColor: colors.seal),
                      onPressed: retryExitProbe,
                      child: const Text(LbStrings.retry),
                    ),
            ),
        ],
      ),
    );
  }
}
