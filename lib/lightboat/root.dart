import 'dart:async';

import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/pages/home.dart';
import 'package:fl_clash/lightboat/pages/login.dart';
import 'package:fl_clash/lightboat/pages/logo.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Runs once the provider container exists and before the first boot dialogs,
/// which Lightboat answers on the user's behalf: FlClash's disclaimer and
/// Crashlytics notice do not apply to a build without Firebase.
Future<void> lightboatPrepare(ProviderContainer container) async {
  container
      .read(appSettingProvider.notifier)
      .update(
        (state) => state.copyWith(
          disclaimerAccepted: true,
          crashlyticsTip: true,
          crashlytics: false,
          autoCheckUpdate: false,
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
      .update((state) => state.copyWith(globalUa: userAgent));
  final session = container.read(lbSessionProvider.notifier);
  await session.restore();
  unawaited(session.refresh());
}

class LbRoot extends ConsumerStatefulWidget {
  const LbRoot({super.key});

  @override
  ConsumerState<LbRoot> createState() => _LbRootState();
}

class _LbRootState extends ConsumerState<LbRoot> with WidgetsBindingObserver {
  static const _refreshAfter = Duration(hours: 1);
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (now.difference(_lastRefresh) < _refreshAfter) return;
    _lastRefresh = now;
    unawaited(ref.read(lbSessionProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(lbSessionProvider.select((state) => state.phase));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(ref.read(systemActionProvider.notifier).handleClose());
      },
      child: switch (phase) {
        LbPhase.loading => const _Splash(),
        LbPhase.signedOut => const LbLoginPage(),
        LbPhase.signedIn => const LbHomePage(),
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
