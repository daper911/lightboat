import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/auth/credential_store.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/rules.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LbPhase { loading, signedOut, signedIn }

/// The group selections Lightboat keeps in its profile. 全局 sends everything
/// through mihomo's GLOBAL group, which starts on DIRECT, so it is pinned to the
/// line group and follows whatever line the user picked.
Map<String, String> lbSelectedMap(Map<String, String> current) => {
  LbConfig.proxyGroup: LbConfig.autoProxy,
  ...current,
  LbConfig.globalGroup: LbConfig.proxyGroup,
};

class LbSessionState {
  final LbPhase phase;
  final String? email;
  final bool hasJwt;
  final LbSubscription? subscription;
  final List<LbSubscription> subscriptions;
  final bool syncing;
  final Object? syncError;

  const LbSessionState({
    this.phase = LbPhase.loading,
    this.email,
    this.hasJwt = false,
    this.subscription,
    this.subscriptions = const [],
    this.syncing = false,
    this.syncError,
  });

  LbSessionState copyWith({
    LbPhase? phase,
    String? email,
    bool? hasJwt,
    LbSubscription? subscription,
    List<LbSubscription>? subscriptions,
    bool? syncing,
    Object? syncError,
    bool clearSyncError = false,
    bool clearSubscription = false,
  }) => LbSessionState(
    phase: phase ?? this.phase,
    email: email ?? this.email,
    hasJwt: hasJwt ?? this.hasJwt,
    subscription: clearSubscription ? null : subscription ?? this.subscription,
    subscriptions: subscriptions ?? this.subscriptions,
    syncing: syncing ?? this.syncing,
    syncError: clearSyncError ? null : syncError ?? this.syncError,
  );
}

final lbCredentialStoreProvider = Provider<LbCredentialStore>(
  (_) => LbCredentialStore(),
);

final lbPanelApiProvider = Provider<PanelApi>(
  (_) =>
      PanelApi(userAgent: LbConfig.userAgent(globalState.packageInfo.version)),
);

final lbSessionProvider = NotifierProvider<LbSession, LbSessionState>(
  LbSession.new,
);

class LbSession extends Notifier<LbSessionState> {
  String? _jwt;
  LbSiteConfig? _site;
  Future<void>? _refreshing;

  PanelApi get _api => ref.read(lbPanelApiProvider);

  LbCredentialStore get _store => ref.read(lbCredentialStoreProvider);

  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  LbSessionState build() => const LbSessionState();

  Future<void> restore() async {
    final stored = await _store.load();
    _jwt = stored.jwt;
    state = LbSessionState(
      phase: stored.jwt != null || stored.isSignedIn
          ? LbPhase.signedIn
          : LbPhase.signedOut,
      email: stored.email,
      hasJwt: stored.jwt != null,
      subscription: stored.subscription,
      subscriptions: stored.subscriptions,
    );
  }

  /// Throws [PanelException]; [LbErrorCode.captchaRequired] asks the caller to
  /// run the slide captcha and retry with its ticket.
  Future<void> login({
    required String email,
    required String password,
    String? captchaTicket,
  }) async {
    final jwt = await _api.login(
      email: email,
      password: password,
      captchaTicket: captchaTicket,
    );
    await _signIn(email, jwt);
  }

  /// Same captcha contract as [login]; a new account starts without a plan.
  Future<void> register({
    required String email,
    required String password,
    required String code,
    String? invite,
    String? captchaTicket,
  }) async {
    final jwt = await _api.register(
      email: email,
      password: password,
      code: code,
      invite: invite,
      captchaTicket: captchaTicket,
    );
    await _signIn(email, jwt);
  }

  /// Runs an account call with the JWT; an expired one is dropped so the UI
  /// can ask for a new login while the connection keeps running.
  Future<T> authed<T>(Future<T> Function(PanelApi api, String jwt) call) async {
    final jwt = _jwt;
    if (jwt == null) {
      throw const PanelException(40002, 'not signed in');
    }
    try {
      return await call(_api, jwt);
    } on PanelException catch (error) {
      if (error.isAuthExpired) await _expireJwt();
      rethrow;
    }
  }

  Future<void> _signIn(String email, String jwt) async {
    _jwt = jwt;
    final subscriptions = await _api.subscriptions(jwt);
    final subscription = pickSubscription(subscriptions);
    state = LbSessionState(
      phase: LbPhase.signedIn,
      email: email,
      hasJwt: true,
      subscription: subscription,
      subscriptions: subscriptions,
    );
    await _persist();
    unawaited(refresh(fetchAccount: false));
  }

  Future<void> refresh({bool fetchAccount = true}) {
    return _refreshing ??= _refresh(
      fetchAccount: fetchAccount,
    ).whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh({required bool fetchAccount}) async {
    if (state.phase != LbPhase.signedIn) return;
    state = state.copyWith(syncing: true, clearSyncError: true);
    try {
      final jwt = _jwt;
      if (fetchAccount && jwt != null) {
        try {
          final subscriptions = await _api.subscriptions(jwt);
          final picked = pickSubscription(
            subscriptions,
            preferredId: state.subscription?.id,
          );
          state = state.copyWith(
            subscriptions: subscriptions,
            subscription: picked,
            clearSubscription: picked == null,
          );
          await _persist();
        } on PanelException catch (error) {
          if (!error.isAuthExpired) rethrow;
          await _expireJwt();
        }
      }
      final subscription = state.subscription;
      if (subscription != null) {
        await _syncProfile(subscription);
      }
    } catch (error) {
      commonPrint.log('lightboat refresh: $error', logLevel: LogLevel.warning);
      state = state.copyWith(syncError: error);
    } finally {
      state = state.copyWith(syncing: false);
    }
  }

  Future<void> selectSubscription(LbSubscription subscription) async {
    state = state.copyWith(subscription: subscription);
    await _persist();
    await refresh(fetchAccount: false);
  }

  Future<void> logout() async {
    if (ref.read(isStartProvider)) {
      await ref.read(setupActionProvider.notifier).setRunning(false);
    }
    final profile = _ownProfile();
    if (profile != null) {
      await ref.read(profilesActionProvider.notifier).deleteProfile(profile.id);
    }
    _jwt = null;
    await _store.clear();
    state = const LbSessionState(phase: LbPhase.signedOut);
  }

  Future<void> _expireJwt() async {
    _jwt = null;
    await _store.clearJwt();
    state = state.copyWith(hasJwt: false);
  }

  Future<void> _persist() => _store.save(
    LbStoredSession(
      jwt: _jwt,
      email: state.email,
      subscription: state.subscription,
      subscriptions: state.subscriptions,
    ),
  );

  Profile? _ownProfile() => ref
      .read(profilesProvider)
      .firstWhereOrNull((profile) => profile.label == LbConfig.profileLabel);

  Future<LbSiteConfig> _siteConfig() async {
    final known = _site;
    if (known != null) return known;
    try {
      return _site = await _api.siteConfig();
    } on PanelException {
      return const LbSiteConfig();
    }
  }

  Future<void> _waitForCore() async {
    for (var i = 0; i < 300 && !ref.read(initProvider); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _seedRuleSets(int profileId) async => lbSeedRuleSets(
    await appPath.getProviderDirPath(profileId, rulesProviderDirectoryName),
  );

  Future<void> _syncProfile(LbSubscription subscription) async {
    final url = (await _siteConfig()).subscribeUrl(subscription.token);
    await _waitForCore();
    final existing = _ownProfile();
    final profilesAction = ref.read(profilesActionProvider.notifier);
    final Profile profile;
    if (existing == null) {
      profile = await Profile.normal(label: LbConfig.profileLabel, url: url)
          .copyWith(
            autoUpdateDuration: const Duration(hours: 6),
            selectedMap: lbSelectedMap(const {}),
          )
          .update(validate: (path) => _core.validateConfig(path));
      await _seedRuleSets(profile.id);
      profilesAction.putProfile(profile);
    } else {
      await _seedRuleSets(existing.id);
      await profilesAction.updateProfile(
        existing.copyWith(
          url: url,
          selectedMap: lbSelectedMap(existing.selectedMap),
        ),
      );
      profile = _ownProfile() ?? existing;
    }
    if (ref.read(currentProfileIdProvider) != profile.id) {
      ref.read(currentProfileIdProvider.notifier).value = profile.id;
    }
    final info = profile.subscriptionInfo;
    if (!state.hasJwt && info != null && info.total + info.expire > 0) {
      state = state.copyWith(subscription: subscription.withUserinfo(info));
      await _persist();
    }
  }
}
