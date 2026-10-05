import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/line_groups.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LbConnectPhase { disconnected, connecting, connected, failed }

const _connectingFor = 1500;

final lbConnectionProvider = NotifierProvider<LbConnection, bool>(
  LbConnection.new,
);

final lbConnectPhaseProvider = Provider<LbConnectPhase>((ref) {
  final runTime = ref.watch(runTimeProvider);
  if (runTime == null) {
    return ref.watch(lbConnectionProvider)
        ? LbConnectPhase.failed
        : LbConnectPhase.disconnected;
  }
  return runTime < _connectingFor
      ? LbConnectPhase.connecting
      : LbConnectPhase.connected;
});

/// One-tap connect on top of FlClash's run state, which stays the source of
/// truth. The state is whether the last start failed: on Android a refused
/// VPN prompt or a dead profile shows up only as a start that never comes up.
class LbConnection extends Notifier<bool> {
  static const _startTimeout = Duration(seconds: 20);

  bool _wantRunning = false;
  DateTime? _startRequestedAt;
  bool _testedThisRun = false;
  Timer? _startWatchdog;

  @override
  bool build() {
    _wantRunning = ref.read(isStartProvider);
    ref.listen(isStartProvider, (prev, next) {
      if (next) {
        _startWatchdog?.cancel();
        state = false;
        return;
      }
      _testedThisRun = false;
      final requested = _startRequestedAt;
      final justStarted =
          requested != null &&
          DateTime.now().difference(requested) < const Duration(seconds: 30);
      if (prev == true && _wantRunning && justStarted) _markFailed();
    });
    ref.listen(runTimeProvider, (_, runTime) {
      if (runTime != null && runTime >= _connectingFor && !_testedThisRun) {
        _testedThisRun = true;
        testLine();
      }
    });
    ref.onDispose(() => _startWatchdog?.cancel());
    return false;
  }

  void _markFailed() {
    _wantRunning = false;
    state = true;
  }

  void toggle() {
    final starting = !ref.read(isStartProvider);
    state = false;
    _wantRunning = starting;
    _startWatchdog?.cancel();
    _startRequestedAt = starting ? DateTime.now() : null;
    if (starting) {
      _startWatchdog = Timer(_startTimeout, () {
        if (ref.mounted && _wantRunning && !ref.read(isStartProvider)) {
          _markFailed();
        }
      });
    }
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  /// The profile pins GLOBAL to the line group on its next refresh; a profile
  /// loaded before that pin existed is corrected here, when it starts to matter.
  void changeMode(Mode mode) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: mode));
    if (mode != Mode.global) return;
    final global = ref
        .read(groupsProvider)
        .firstWhereOrNull((group) => group.name == LbConfig.globalGroup);
    if (global != null && global.now != LbConfig.proxyGroup) {
      selectLine(LbConfig.globalGroup, LbConfig.proxyGroup);
    }
  }

  void testLine() {
    final group = lbLineGroup(ref.read(groupsProvider));
    if (group == null) return;
    unawaited(
      ref.read(proxiesActionProvider.notifier).delayTestGroups([group]),
    );
  }

  void testLines(LbLineInfo line) => unawaited(
    ref
        .read(proxiesActionProvider.notifier)
        .delayTest(line.choices, line.group.testUrl),
  );

  void selectLine(String groupName, String proxyName) => unawaited(
    ref
        .read(proxiesActionProvider.notifier)
        .changeProxy(groupName: groupName, proxyName: proxyName),
  );
}

class LbLineInfo {
  final Group group;
  final List<Proxy> choices;
  final String? autoNode;

  const LbLineInfo({required this.group, required this.choices, this.autoNode});

  String? get current => group.now;

  String get label => autoNode == null
      ? lbLineName(current)
      : '${LbStrings.autoLine}（$autoNode）';
}

final lbLineInfoProvider = Provider<LbLineInfo?>((ref) {
  final groups = ref.watch(groupsProvider);
  final group = lbLineGroup(groups);
  if (group == null) return null;
  final now = group.now;
  return LbLineInfo(
    group: group,
    choices: lbLineChoices(group, groups),
    autoNode: now == LbConfig.autoProxy
        ? groups.firstWhereOrNull((item) => item.name == now)?.now
        : null,
  );
});

final lbExitProbeProvider = Provider<ProbeEntry<IpInfo>>(
  (ref) => ref.watch(
    outboundIpProbeProvider.select((state) => state.entryOf(routedOutbound)),
  ),
);

/// The exit-location probe is watcher-counted, so it runs only while a widget
/// showing the location is on screen and the connection is up.
mixin LbExitProbeWatcher<T extends ConsumerStatefulWidget> on ConsumerState<T> {
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

  void retryExitProbe() => _probe.retry(routedOutbound);
}
