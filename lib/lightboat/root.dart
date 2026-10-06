import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/desktop/auth.dart';
import 'package:fl_clash/lightboat/desktop/shell.dart';
import 'package:fl_clash/lightboat/desktop/tray.dart';
import 'package:fl_clash/lightboat/mobile/home.dart';
import 'package:fl_clash/lightboat/mobile/login.dart';
import 'package:fl_clash/lightboat/mobile/purchase.dart';
import 'package:fl_clash/lightboat/widgets/logo.dart';
import 'package:fl_clash/lightboat/widgets/prompts.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/lightboat/trust.dart';
import 'package:fl_clash/lightboat/update.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Runs once the provider container exists and before the first boot dialogs,
/// which Lightboat answers on the user's behalf: FlClash's disclaimer and
/// Crashlytics notice do not apply to a build without Firebase.
Future<void> lightboatPrepare(ProviderContainer container) async {
  lbTrustBundledRoots();
  if (system.isDesktop) {
    trayPort = LbTray();
    beforeHideToTray = lbExplainTrayOnce;
  }
  container
      .read(appSettingProvider.notifier)
      .update(
        (state) => state.copyWith(
          disclaimerAccepted: true,
          crashlyticsTip: true,
          crashlytics: false,
          autoCheckUpdate: false,
          openLogs: true,
        ),
      );
  container
      .read(themeSettingProvider.notifier)
      .update(
        (state) => state.copyWith(
          primaryColor: LbColors.primary,
          themeMode: ThemeMode.system,
          schemeVariant: DynamicSchemeVariant.fidelity,
        ),
      );
  final userAgent = LbConfig.userAgent(globalState.packageInfo.version);
  container
      .read(patchClashConfigProvider.notifier)
      .update(
        (state) => state.copyWith(globalUa: userAgent, logLevel: LogLevel.info),
      );
  final session = container.read(lbSessionProvider.notifier);
  await session.restore();
  unawaited(session.refresh());
}

class LbRoot extends ConsumerStatefulWidget {
  /// Picks the shell; tests pass it because the test host is a desktop.
  final bool? desktop;

  const LbRoot({super.key, this.desktop});

  bool get isDesktop => desktop ?? system.isDesktop;

  @override
  ConsumerState<LbRoot> createState() => _LbRootState();
}

class _LbRootState extends ConsumerState<LbRoot> with WidgetsBindingObserver {
  static const _refreshAfter = Duration(hours: 1);
  DateTime _lastRefresh = DateTime.now();
  bool _promptsShown = false;
  Timer? _planTimer;

  LbSession get _session => ref.read(lbSessionProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _planTimer = Timer.periodic(
      LbSession.planMaxAge,
      (_) => unawaited(_session.refreshPlanIfStale()),
    );
  }

  Future<void> _runStartupPrompts() async {
    await lbCheckForUpdate(context);
    if (!mounted) return;
    final subscription = ref.read(lbSessionProvider).subscription;
    final reminded = await lbRemindPlan(
      context,
      subscription,
      openPurchase: widget.isDesktop
          ? ref.read(lbDesktopNavProvider.notifier).openPurchase
          : (renewing) => showLbPurchase(context, renewing: renewing),
    );
    if (reminded || !mounted) return;
    await lbShowPopupAnnouncement(context, ref);
  }

  /// Startup prompts wait for the home page so they never cover the login.
  void _showStartupPrompts() {
    if (_promptsShown) return;
    _promptsShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_runStartupPrompts());
    });
  }

  @override
  void dispose() {
    _planTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (now.difference(_lastRefresh) < _refreshAfter) {
      unawaited(_session.refreshPlanIfStale());
      return;
    }
    _lastRefresh = now;
    unawaited(_session.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(lbSessionProvider.select((state) => state.phase));
    if (phase == LbPhase.signedIn) _showStartupPrompts();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(ref.read(systemActionProvider.notifier).handleClose());
      },
      child: switch ((phase, widget.isDesktop)) {
        (LbPhase.loading, _) => const _Splash(),
        (LbPhase.signedOut, true) => const LbDesktopAuthPage(),
        (LbPhase.signedOut, false) => const LbLoginPage(),
        (LbPhase.signedIn, true) => const LbDesktopShell(),
        (LbPhase.signedIn, false) => const LbHomePage(),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LbColors.of(context).paper,
      child: const Center(child: LbLogo(size: 88)),
    );
  }
}
