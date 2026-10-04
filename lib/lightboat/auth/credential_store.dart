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
    try {
      return _decode(await _storage.readAll());
    } catch (_) {
      // A backup restored onto a new device carries values whose Keystore key
      // stayed behind, and a value can be cut short; neither is recoverable.
      await clear();
      return const LbStoredSession();
    }
  }

  LbStoredSession _decode(Map<String, String> values) {
    final rawSubscription = values[_subscriptionKey];
    final rawList = values[_subscriptionsKey];
    return LbStoredSession(
      jwt: values[_jwtKey],
      email: values[_emailKey],
      subscription: rawSubscription == null
          ? null
          : LbSubscription.fromJson(
              (jsonDecode(rawSubscription) as Map).cast<String, Object?>(),
            ),
      subscriptions: rawList == null
          ? const []
          : [
              for (final item in jsonDecode(rawList) as List)
                LbSubscription.fromJson((item as Map).cast<String, Object?>()),
            ],
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
