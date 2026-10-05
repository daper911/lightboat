import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/desktop/shell.dart';
import 'package:fl_clash/lightboat/logic/connection.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/logic/plan.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/lightboat/widgets/card.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _tabular = [FontFeature.tabularFigures()];

class LbDesktopHome extends ConsumerWidget {
  const LbDesktopHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final session = ref.watch(lbSessionProvider);
    return LbDesktopPage(
      title: LbStrings.home,
      children: [
        const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _ConnectPanel()),
              SizedBox(width: 16),
              Expanded(flex: 2, child: _PlanPanel()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _LineStrip(),
        if (session.syncing || session.syncError != null) ...[
          const SizedBox(height: 12),
          Text(
            session.syncing ? LbStrings.syncing : LbStrings.syncFailed,
            style: context.textTheme.bodySmall?.copyWith(color: colors.muted),
          ),
        ],
      ],
    );
  }
}

class _ConnectPanel extends ConsumerWidget {
  static const _size = 160.0;

  const _ConnectPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final phase = ref.watch(lbConnectPhaseProvider);
    final runTime = ref.watch(runTimeProvider);
    final hasProfile = ref.watch(currentProfileProvider) != null;
    final connection = ref.read(lbConnectionProvider.notifier);
    final running = runTime != null;
    final connected = phase == LbConnectPhase.connected;
    final failed = phase == LbConnectPhase.failed;
    final ring = failed
        ? colors.seal
        : running
        ? colors.accent
        : colors.ink;
    final label = switch (phase) {
      LbConnectPhase.failed => LbStrings.connectFailed,
      LbConnectPhase.connecting => LbStrings.connecting,
      LbConnectPhase.connected =>
        '${LbStrings.connected} ${getTimeText(runTime!)}',
      LbConnectPhase.disconnected => LbStrings.disconnected,
    };
    return LbCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox.square(
            dimension: _size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (phase == LbConnectPhase.connecting)
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
                    side: BorderSide(color: ring, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: AppShape.circle,
                    onTap: hasProfile ? connection.toggle : null,
                    child: SizedBox.square(
                      dimension: _size - 16,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GlyphIcon(
                            AppGlyphs.vpn,
                            size: 40,
                            fill: connected ? 1 : 0,
                            color: connected ? colors.accentInk : ring,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            running ? LbStrings.disconnect : LbStrings.connect,
                            style: textTheme.titleMedium?.copyWith(
                              color: connected ? colors.accentInk : ring,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: textTheme.titleMedium?.copyWith(
              color: failed
                  ? colors.seal
                  : running
                  ? colors.accent
                  : colors.muted,
              fontFeatures: _tabular,
            ),
          ),
          if (connected) const _TrafficLine(),
          if (failed) ...[
            const SizedBox(height: 4),
            Text(
              ref.watch(lbConnectionProvider) == LbConnectFailure.portBusy
                  ? LbStrings.portBusy(
                      ref.watch(
                        patchClashConfigProvider.select((s) => s.mixedPort),
                      ),
                    )
                  : LbStrings.connectFailedHintDesktop,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: colors.muted),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colors.seal),
              onPressed: hasProfile ? connection.toggle : null,
              child: const Text(LbStrings.retry),
            ),
          ],
          const SizedBox(height: 18),
          const _ModeSwitch(),
        ],
      ),
    );
  }
}

class _TrafficLine extends ConsumerWidget {
  const _TrafficLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed =
        ref.watch(trafficsProvider).list.lastOrNull ?? const Traffic();
    final total = ref.watch(totalTrafficProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '↑ ${speed.up.traffic.show}/s   ↓ ${speed.down.traffic.show}/s   '
        '${LbStrings.sessionUsage((total.up + total.down).traffic.show)}',
        style: context.textTheme.bodySmall?.copyWith(
          color: LbColors.of(context).muted,
          fontFeatures: _tabular,
        ),
      ),
    );
  }
}

class _ModeSwitch extends ConsumerWidget {
  const _ModeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final global = mode == Mode.global;
    return Column(
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
        const SizedBox(height: 8),
        Text(
          global ? LbStrings.modeGlobalHint : LbStrings.modeSmartHint,
          style: context.textTheme.bodySmall?.copyWith(
            color: LbColors.of(context).muted,
          ),
        ),
      ],
    );
  }
}

class _PlanPanel extends ConsumerWidget {
  const _PlanPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final subscription = ref.watch(
      lbSessionProvider.select((state) => state.subscription),
    );
    final navigator = ref.read(lbDesktopNavProvider.notifier);
    if (subscription == null) {
      return LbCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LbStrings.planCardTitle,
              style: textTheme.titleSmall?.copyWith(color: colors.muted),
            ),
            const Spacer(),
            Text(
              LbStrings.noPlan,
              style: textTheme.titleMedium?.copyWith(color: colors.ink),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => navigator.openPurchase(null),
              child: const Text(LbStrings.buyPlan),
            ),
            const Spacer(),
          ],
        ),
      );
    }
    final now = DateTime.now();
    final summary = LbPlanSummary.of(subscription, now);
    final tip = lbPlanTip(subscription, now);
    return LbCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 18),
          Text(
            summary.usage,
            style: textTheme.titleLarge?.copyWith(
              color: colors.ink,
              fontFeatures: _tabular,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: summary.progress,
            minHeight: 6,
            color: summary.exhausted ? colors.seal : colors.accent,
            backgroundColor: colors.accentSoft,
          ),
          const SizedBox(height: 10),
          Text(
            summary.expireText,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.muted,
              fontFeatures: _tabular,
            ),
          ),
          if (tip != null) ...[
            const SizedBox(height: 10),
            Text(
              tip,
              style: textTheme.bodyMedium?.copyWith(color: colors.seal),
            ),
          ],
          const Spacer(),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: subscription.renewable
                ? FilledButton(
                    onPressed: () => navigator.openPurchase(subscription),
                    child: const Text(LbStrings.renewPlan),
                  )
                : OutlinedButton(
                    onPressed: () => navigator.openPurchase(null),
                    child: const Text(LbStrings.buy),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LineStrip extends ConsumerStatefulWidget {
  const _LineStrip();

  @override
  ConsumerState<_LineStrip> createState() => _LineStripState();
}

class _LineStripState extends ConsumerState<_LineStrip>
    with LbExitProbeWatcher {
  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final line = ref.watch(lbLineInfoProvider);
    final now = line?.current;
    final delay = now == null
        ? null
        : ref.watch(
            delayProvider(proxyName: now, testUrl: line?.group.testUrl),
          );
    final delayText = lbDelayText(delay);
    final running = ref.watch(isStartProvider);
    final location = ref.watch(lbExitProbeProvider);
    final countryCode = location.value?.countryCode;
    final labelStyle = textTheme.bodyMedium?.copyWith(color: colors.muted);
    final valueStyle = textTheme.bodyLarge?.copyWith(
      color: colors.ink,
      fontFeatures: _tabular,
    );
    return LbCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Text(LbStrings.line, style: labelStyle),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              line?.label ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: valueStyle,
            ),
          ),
          if (delayText != null)
            Text(
              delayText,
              style: valueStyle?.copyWith(
                color: delay! <= 0 ? colors.seal : colors.muted,
              ),
            ),
          if (running) ...[
            const SizedBox(width: 20),
            if (location.phase == ProbePhase.failed) ...[
              Text(
                LbStrings.lineDown,
                style: valueStyle?.copyWith(color: colors.seal),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: colors.seal),
                onPressed: retryExitProbe,
                child: const Text(LbStrings.retry),
              ),
            ] else if (countryCode == null)
              Text(LbStrings.locating, style: labelStyle)
            else
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${countryCode.countryFlagEmoji} ',
                      style: TextStyle(fontFamily: FontFamily.twEmoji.value),
                    ),
                    TextSpan(text: lbRegionName(countryCode)),
                  ],
                ),
                style: valueStyle,
              ),
          ],
          const SizedBox(width: 12),
          if (line != null)
            TextButton(
              onPressed: ref.read(lbConnectionProvider.notifier).testLine,
              child: const Text(LbStrings.testDelay),
            ),
          OutlinedButton(
            onPressed: () =>
                ref.read(lbDesktopNavProvider.notifier).go(LbDesktopTab.lines),
            child: const Text(LbStrings.changeLine),
          ),
        ],
      ),
    );
  }
}
