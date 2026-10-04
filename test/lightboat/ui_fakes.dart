import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/state.dart';
import 'package:package_info_plus/package_info_plus.dart';

bool _packageInfoSet = false;

/// `GlobalState.packageInfo` is a `late final`, so one assignment per isolate.
void setTestPackageInfo() {
  if (_packageInfoSet) return;
  _packageInfoSet = true;
  globalState.packageInfo = PackageInfo(
    appName: '轻舟',
    packageName: 'com.lightboat.app.dev',
    version: '0.3.0',
    buildNumber: '3',
  );
}

class RecordingProxies extends ProxiesAction {
  static final List<String> calls = [];

  @override
  Future<void> delayTestGroups(List<Group> groups) async =>
      calls.add('test ${groups.map((group) => group.name).join(',')}');

  @override
  Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async =>
      calls.add('test ${proxies.length} proxies');

  @override
  Future<void> changeProxy({
    required String groupName,
    required String proxyName,
  }) async => calls.add('change $groupName -> $proxyName');
}

/// Flips the run state the way an optimistic Android start does.
class FakeCommonAction extends CommonAction {
  static int toggles = 0;

  @override
  void toggleRunning() {
    toggles++;
    final runTime = ref.read(runTimeProvider.notifier);
    runTime.value = runTime.value == null ? 0 : null;
  }
}

/// Holds whatever entry a test sets, without reaching the Core.
class FakeProbe extends OutboundIpProbe {
  static RoutedProbeState<String, IpInfo> initial = const RoutedProbeState({});
  static final List<String> calls = [];

  @override
  RoutedProbeState<String, IpInfo> build() => initial;

  @override
  void watch(String target) => calls.add('watch');

  @override
  void unwatch(String target) => calls.add('unwatch');

  @override
  void retry(String target) => calls.add('retry');
}

class FakeSystemAction extends SystemAction {
  List<Package> packages = const [];
  bool permissionGranted = true;

  @override
  Future<List<Package>> getPackages() async {
    if (permissionGranted) {
      ref.read(packagesProvider.notifier).value = packages;
    }
    return ref.read(packagesProvider);
  }

  @override
  Future<bool> isInstalledAppsPermissionGranted() async => permissionGranted;

  @override
  Future<bool> requestInstalledAppsPermission() async {
    permissionGranted = true;
    return true;
  }
}
