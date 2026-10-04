import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/pages/lines.dart';
import 'package:fl_clash/lightboat/pages/me.dart';
import 'package:fl_clash/lightboat/pages/purchase.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
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

  /// A start that has not produced a running VPN by then counts as failed.
  static const _startTimeout = Duration(seconds: 20);

  bool _wantRunning = false;
  DateTime? _startRequestedAt;
  bool _failed = false;
  bool _testedThisRun = false;
  Timer? _startWatchdog;

  @override
  void initState() {
    super.initState();
    _wantRunning = ref.read(isStartProvider);
    ref.listenManual(isStartProvider, (prev, next) {
      if (next) {
        _startWatchdog?.cancel();
        if (_failed) setState(() => _failed = false);
        return;
      }
      _testedThisRun = false;
      final requested = _startRequestedAt;
      final justStarted =
          requested != null &&
          DateTime.now().difference(requested) < const Duration(seconds: 30);
      if (prev == true && _wantRunning && justStarted) _markFailed();
    });
    ref.listenManual(runTimeProvider, (_, runTime) {
      if (runTime != null && runTime >= 1500 && !_testedThisRun) {
        _testedThisRun = true;
        _testLineOnce();
      }
    });
  }

  @override
  void dispose() {
    _startWatchdog?.cancel();
    super.dispose();
  }

  void _markFailed() {
    _wantRunning = false;
    if (mounted) setState(() => _failed = true);
  }

  /// Delay is measured once per connection; the card's 测速 runs it again.
  void _testLineOnce() {
    final group = lbLineGroup(ref.read(groupsProvider));
    if (group == null) return;
    unawaited(
      ref.read(proxiesActionProvider.notifier).delayTestGroups([group]),
    );
  }

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
    setState(() {
      _failed = false;
      _wantRunning = starting;
    });
    _startWatchdog?.cancel();
    _startRequestedAt = starting ? DateTime.now() : null;
    if (starting) {
      _startWatchdog = Timer(_startTimeout, () {
        if (_wantRunning && !ref.read(isStartProvider)) _markFailed();
      });
    }
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final runTime = ref.watch(runTimeProvider);
    final hasProfile = ref.watch(currentProfileProvider) != null;
    final isStart = runTime != null;
    final connecting = isStart && runTime < 1500;
    final connected = isStart && !connecting;
    final failed = _failed && !isStart;
    final label = failed
        ? LbStrings.connectFailed
        : connecting
        ? LbStrings.connecting
        : connected
        ? '${LbStrings.connected} ${getTimeText(runTime)}'
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

  /// The profile pins GLOBAL to the line group on its next refresh; a profile
  /// loaded before that pin existed is corrected here, when it starts to matter.
  void _changeMode(WidgetRef ref, Mode mode) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: mode));
    if (mode != Mode.global) return;
    final global = ref
        .read(groupsProvider)
        .firstWhereOrNull((group) => group.name == LbConfig.globalGroup);
    if (global != null && global.now != LbConfig.proxyGroup) {
      unawaited(
        ref
            .read(proxiesActionProvider.notifier)
            .changeProxy(
              groupName: LbConfig.globalGroup,
              proxyName: LbConfig.proxyGroup,
            ),
      );
    }
  }

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
            onSelectionChanged: (value) => _changeMode(ref, value.first),
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

/// The group the home page calls 线路: `🚀 Proxy`, else the first selector.
Group? lbLineGroup(List<Group> groups) =>
    groups.firstWhereOrNull((group) => group.name == LbConfig.proxyGroup) ??
    groups.firstWhereOrNull((group) => group.type == GroupType.Selector);

/// The lines worth offering: everything in [line] except choices that end in
/// a direct connection, since 线路 never means "no proxy" (01: no 直连 mode).
List<Proxy> lbLineChoices(Group line, List<Group> groups) {
  bool direct(Proxy proxy, Set<String> seen) {
    if (_directTypes.contains(proxy.type)) return true;
    final group = groups.firstWhereOrNull((item) => item.name == proxy.name);
    if (group == null || !seen.add(group.name)) return false;
    return group.all.isNotEmpty &&
        group.all.every((member) => direct(member, seen));
  }

  return [
    for (final proxy in line.all)
      if (!direct(proxy, {})) proxy,
  ];
}

const _directTypes = {'Direct', 'Reject', 'RejectDrop', 'Pass', 'Compatible'};

String lbLineName(String? name) =>
    name == null || name == LbConfig.autoProxy ? LbStrings.autoLine : name;

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

class _LineCard extends ConsumerStatefulWidget {
  const _LineCard();

  @override
  ConsumerState<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends ConsumerState<_LineCard> {
  late final OutboundIpProbe _probe;
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    _probe = ref.read(outboundIpProbeProvider.notifier);
    ref.listenManual(isStartProvider, (_, running) {
      if (running && !_watching) {
        _probe.watch(routedOutbound);
        _watching = true;
      } else if (!running && _watching) {
        _probe.unwatch(routedOutbound);
        _watching = false;
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    if (_watching) _probe.unwatch(routedOutbound);
    super.dispose();
  }

  void _testDelay(Group group) => unawaited(
    ref.read(proxiesActionProvider.notifier).delayTestGroups([group]),
  );

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final groups = ref.watch(groupsProvider);
    final group = lbLineGroup(groups);
    final now = group?.now;
    final delay = now == null
        ? null
        : ref.watch(delayProvider(proxyName: now, testUrl: group?.testUrl));
    final autoNode = now == LbConfig.autoProxy
        ? groups.firstWhereOrNull((item) => item.name == now)?.now
        : null;
    final lineText = autoNode == null
        ? lbLineName(now)
        : '${LbStrings.autoLine}（$autoNode）';
    final isStart = ref.watch(isStartProvider);
    final location = ref.watch(
      outboundIpProbeProvider.select((state) => state.entryOf(routedOutbound)),
    );
    final countryCode = location.value?.countryCode;
    final locationFailed = location.phase == ProbePhase.failed;
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
              group == null ? '—' : lineText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: valueStyle,
            ),
            trailing: GlyphIcon(AppGlyphs.chevronForward, color: colors.muted),
          ),
          row(
            LbStrings.delay,
            Text(
              delay == null
                  ? '—'
                  : delay > 0
                  ? '$delay ms'
                  : 'Timeout',
              style: valueStyle?.copyWith(
                color: delay != null && delay <= 0 ? colors.seal : null,
              ),
            ),
            trailing: group == null
                ? null
                : TextButton(
                    onPressed: () => _testDelay(group),
                    child: const Text(LbStrings.testDelay),
                  ),
          ),
          if (isStart)
            row(
              LbStrings.location,
              locationFailed
                  ? Text(
                      LbStrings.lineDown,
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
              trailing: locationFailed
                  ? TextButton(
                      style: TextButton.styleFrom(foregroundColor: colors.seal),
                      onPressed: () => _probe.retry(routedOutbound),
                      child: const Text(LbStrings.retry),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
