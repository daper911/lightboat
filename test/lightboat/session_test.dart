import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/auth/credential_store.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_profiles.dart';
import 'fakes.dart';

const _plan = LbSubscription(
  id: 9,
  planId: 3,
  token: 't',
  name: '基础版',
  status: LbPlanStatus.active,
  expireTime: 0,
  traffic: 0,
  upload: 0,
  download: 0,
);

void main() {
  group('lbSelectedMap', () {
    test('a new profile starts on Auto with GLOBAL following the line', () {
      expect(lbSelectedMap(const {}), {
        LbConfig.proxyGroup: LbConfig.autoProxy,
        LbConfig.globalGroup: LbConfig.proxyGroup,
      });
    });

    test('keeps the picked line and repairs GLOBAL', () {
      expect(
        lbSelectedMap(const {
          LbConfig.proxyGroup: '香港 HK1 · Hysteria2',
          LbConfig.globalGroup: 'DIRECT',
          '🔍 Google': '🚀 Proxy',
        }),
        {
          LbConfig.proxyGroup: '香港 HK1 · Hysteria2',
          LbConfig.globalGroup: LbConfig.proxyGroup,
          '🔍 Google': '🚀 Proxy',
        },
      );
    });
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  group('LbSession', () {
    late FakePanelApi api;
    late MemoryStore store;
    late ProviderContainer container;

    LbSession session() => container.read(lbSessionProvider.notifier);
    LbSessionState state() => container.read(lbSessionProvider);

    setUp(() {
      api = FakePanelApi();
      store = MemoryStore();
      container = ProviderContainer(
        overrides: [
          lbPanelApiProvider.overrideWithValue(api),
          lbCredentialStoreProvider.overrideWithValue(store),
          profilesProvider.overrideWith(TestProfiles.new),
        ],
      );
      addTearDown(container.dispose);
    });

    test('restores as signed out with nothing stored', () async {
      await session().restore();
      expect(state().phase, LbPhase.signedOut);
    });

    test('refreshes only the plan, once it is stale', () async {
      store.saved = const LbStoredSession(
        jwt: 'jwt',
        email: 'a@example.com',
        subscription: _plan,
        subscriptions: [_plan],
      );
      await session().restore();
      const used = LbSubscription(
        id: 9,
        planId: 3,
        token: 't',
        name: '基础版',
        status: LbPlanStatus.active,
        expireTime: 0,
        traffic: 0,
        upload: 0,
        download: 5,
      );
      final start = DateTime(2026, 10, 6, 12);
      api.subscriptionList = const [used];
      await session().refreshPlanIfStale(now: start);
      expect(state().subscription?.used, 5);

      api.subscriptionList = const [_plan];
      await session().refreshPlanIfStale(
        now: start.add(const Duration(minutes: 10)),
      );
      expect(state().subscription?.used, 5);
      await session().refreshPlanIfStale(
        now: start.add(const Duration(minutes: 31)),
      );
      expect(state().subscription?.used, 0);
      expect(store.saved.subscription?.used, 0);

      api.subscriptionsError = 40002;
      await session().refreshPlanIfStale(
        now: start.add(const Duration(minutes: 62)),
      );
      expect(state().hasJwt, isFalse);
      expect(state().phase, LbPhase.signedIn);
    });

    test('a subscription alone keeps the user signed in', () async {
      store.saved = const LbStoredSession(subscription: _plan);
      await session().restore();
      expect(state().phase, LbPhase.signedIn);
      expect(state().hasJwt, isFalse);
    });

    test('account calls need a JWT', () async {
      await session().restore();
      await expectLater(
        session().authed((api, jwt) async => jwt),
        throwsA(
          isA<PanelException>().having(
            (e) => e.isAuthExpired,
            'expired',
            isTrue,
          ),
        ),
      );
    });

    test('an expired JWT is dropped without signing out', () async {
      store.saved = const LbStoredSession(jwt: 'old', subscription: _plan);
      await session().restore();
      await expectLater(
        session().authed<void>(
          (api, jwt) async => throw const PanelException(40004, ''),
        ),
        throwsA(isA<PanelException>()),
      );
      expect(state().hasJwt, isFalse);
      expect(state().phase, LbPhase.signedIn);
      expect(store.saved.jwt, isNull);
      expect(store.saved.subscription?.id, 9);
    });

    test('refresh keeps the plan when the login expired', () async {
      store.saved = const LbStoredSession(jwt: 'old');
      await session().restore();
      api.subscriptionsError = 40003;
      await session().refresh();
      expect(state().hasJwt, isFalse);
      expect(state().syncing, isFalse);
      expect(state().syncError, isNull);
    });

    test('refresh drops a plan the panel no longer lists', () async {
      store.saved = const LbStoredSession(jwt: 'jwt', subscription: _plan);
      await session().restore();
      await session().refresh();
      expect(state().subscription, isNull);
      expect(store.saved.subscription, isNull);
    });

    test('a failing refresh is reported, not thrown', () async {
      store.saved = const LbStoredSession(jwt: 'jwt');
      await session().restore();
      api.subscriptionsError = 500;
      await session().refresh();
      expect(state().syncError, isA<PanelException>());
    });

    test('logout clears everything stored', () async {
      store.saved = const LbStoredSession(
        jwt: 'jwt',
        email: 'a@b.c',
        subscription: _plan,
      );
      await session().restore();
      await session().logout();
      expect(state().phase, LbPhase.signedOut);
      expect(store.saved.jwt, isNull);
      expect(store.saved.subscription, isNull);
    });
  });

  group('LbCredentialStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('round-trips a session', () async {
      final store = LbCredentialStore();
      await store.save(
        const LbStoredSession(
          jwt: 'jwt',
          email: 'a@b.c',
          subscription: _plan,
          subscriptions: [_plan],
        ),
      );
      final loaded = await store.load();
      expect(loaded.jwt, 'jwt');
      expect(loaded.email, 'a@b.c');
      expect(loaded.subscription?.planId, 3);
      expect(loaded.subscriptions.single.id, 9);
      expect(loaded.isSignedIn, isTrue);
    });

    test('clearing the JWT keeps the subscription', () async {
      final store = LbCredentialStore();
      await store.save(const LbStoredSession(jwt: 'jwt', subscription: _plan));
      await store.clearJwt();
      final loaded = await store.load();
      expect(loaded.jwt, isNull);
      expect(loaded.subscription?.id, 9);
    });

    test('a damaged value resets to signed out instead of crashing', () async {
      FlutterSecureStorage.setMockInitialValues({
        'lb_jwt': 'jwt',
        'lb_subscription': '{not json',
      });
      final store = LbCredentialStore();
      final loaded = await store.load();
      expect(loaded.jwt, isNull);
      expect(loaded.isSignedIn, isFalse);
      expect((await store.load()).jwt, isNull);
    });
  });
}
