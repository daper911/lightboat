import 'dart:convert';

import 'package:fl_clash/lightboat/api/models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LbStoredSession {
  final String? jwt;
  final String? email;
  final LbSubscription? subscription;
  final List<LbSubscription> subscriptions;

  const LbStoredSession({
    this.jwt,
    this.email,
    this.subscription,
    this.subscriptions = const [],
  });

  /// The subscription token alone keeps the connection working; the JWT only
  /// unlocks account data and expires after seven days.
  bool get isSignedIn => subscription != null;
}

/// Backed by the Android Keystore, so neither token sits in plain preferences.
class LbCredentialStore {
  final FlutterSecureStorage _storage;

  LbCredentialStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _jwtKey = 'lb_jwt';
  static const _emailKey = 'lb_email';
  static const _subscriptionKey = 'lb_subscription';
  static const _subscriptionsKey = 'lb_subscriptions';

  Future<LbStoredSession> load() async {
    final Map<String, String> values;
    try {
      values = await _storage.readAll();
    } catch (_) {
      // A backup restored onto a new device carries values whose Keystore key
      // stayed behind; they can never be decrypted again.
      await clear();
      return const LbStoredSession();
    }
    LbSubscription? subscription;
    final rawSubscription = values[_subscriptionKey];
    if (rawSubscription != null) {
      subscription = LbSubscription.fromJson(
        (jsonDecode(rawSubscription) as Map).cast<String, Object?>(),
      );
    }
    final rawList = values[_subscriptionsKey];
    final subscriptions = rawList == null
        ? const <LbSubscription>[]
        : [
            for (final item in jsonDecode(rawList) as List)
              LbSubscription.fromJson((item as Map).cast<String, Object?>()),
          ];
    return LbStoredSession(
      jwt: values[_jwtKey],
      email: values[_emailKey],
      subscription: subscription,
      subscriptions: subscriptions,
    );
  }

  Future<void> save(LbStoredSession session) async {
    await _put(_jwtKey, session.jwt);
    await _put(_emailKey, session.email);
    await _put(
      _subscriptionKey,
      session.subscription == null
          ? null
          : jsonEncode(session.subscription!.toJson()),
    );
    await _put(
      _subscriptionsKey,
      jsonEncode([for (final item in session.subscriptions) item.toJson()]),
    );
  }

  Future<void> clearJwt() => _storage.delete(key: _jwtKey);

  Future<void> clear() => _storage.deleteAll();

  Future<void> _put(String key, String? value) {
    if (value == null) return _storage.delete(key: key);
    return _storage.write(key: key, value: value);
  }
}
