import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartstream_client/dartstream_client.dart';
import '../config.dart';
import '../models/sleep_model.dart';

extension DartStreamConnectionExtensions on DartStreamConnection {
  ConnectionPlatform get platform => ConnectionPlatform(this);
}

class ConnectionPlatform {
  final DartStreamConnection _connection;
  ConnectionPlatform(this._connection);

  FeatureFlagsWrapper get featureFlags => FeatureFlagsWrapper(_connection);
  DartStreamPersistenceClient get persistence => _connection.client.persistence;
}

class FeatureFlagsWrapper {
  final DartStreamConnection _connection;
  FeatureFlagsWrapper(this._connection);

  Future<List<FeatureFlag>> list() async {
    final list = await _connection.client.platform.listFeatureFlags(_connection.session);
    return list.map<FeatureFlag>((dynamic item) {
      if (item is Map) {
        return FeatureFlag(
          key: item['key'] as String? ?? item['flagKey'] as String? ?? '',
          enabled: item['enabled'] as bool? ?? false,
        );
      }
      return FeatureFlag(key: '', enabled: false);
    }).toList();
  }

  Future<void> create(String key, bool enabled) async {
    await _connection.client.platform.createFeatureFlag(
      _connection.session,
      flag: {
        'key': key,
        'enabled': enabled,
      },
    );
  }

  Future<void> update(String key, bool enabled) async {
    await _connection.client.platform.updateFeatureFlag(
      _connection.session,
      key,
      updates: {
        'enabled': enabled,
      },
    );
  }

  Future<void> delete(String key) async {
    await _connection.client.platform.deleteFeatureFlag(
      _connection.session,
      key,
    );
  }
}

class FeatureFlag {
  final String key;
  final bool enabled;
  FeatureFlag({required this.key, required this.enabled});
}

class DartStreamManager {
  static DartStreamConnection? _connection;
  static VoidCallback? onUnauthorized;
  static DartStreamConnection? get connection => _connection;
  static UserProfile? cachedUserProfile;

  static set connection(DartStreamConnection? conn) {
    _connection = conn;
    if (conn != null) {
      _saveSession(conn.session);
    }
  }

  static bool get isLoggedIn => _connection != null;

  static Future<T> wrap<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DartStreamApiException catch (e) {
      // 401 = token expired, 403 = stale/invalid token — both require re-login
      if (e.statusCode == 401 || e.statusCode == 403) {
        await clearAuthOnly(); // only clear tokens, not onboarding state
        if (onUnauthorized != null) {
          onUnauthorized!();
        }
      }
      rethrow;
    }
  }

  // Restore session from SharedPreferences
  static Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final idToken = prefs.getString('ds_id_token');
    final userId = prefs.getString('ds_user_id');
    final tenantId = prefs.getString('ds_tenant_id');
    final email = prefs.getString('ds_email');
    final loginTimeMs = prefs.getInt('login_time');

    if (idToken != null && userId != null && tenantId != null) {
      // Check 7-day session validity
      if (loginTimeMs != null) {
        final loginTime = DateTime.fromMillisecondsSinceEpoch(loginTimeMs);
        final difference = DateTime.now().difference(loginTime).inDays;
        if (difference >= 7) {
          // Token is older than 7 days, force login again
          await clearAuthOnly();
          return false;
        }
      }
      
      final session = DartStreamSession(
        idToken: idToken,
        userId: userId,
        tenantId: tenantId,
        email: email,
        raw: const {},
      );
      final client = DartStreamClient(
        config: AppConfig.dartStream,
        idToken: idToken,
        session: session,
      );
      _connection = DartStreamConnection(client: client, session: session);
      return true;
    }
    return false;
  }

  // Persist session to SharedPreferences
  static Future<void> _saveSession(DartStreamSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ds_id_token', session.idToken);
    await prefs.setString('ds_user_id', session.userId);
    await prefs.setString('ds_tenant_id', session.tenantId);
    if (session.email != null) {
      await prefs.setString('ds_email', session.email!);
    }
    await prefs.setInt('login_time', DateTime.now().millisecondsSinceEpoch);
  }

  // clearAuthOnly: clears tokens only — used by 403/401 auto-handler
  // Keeps has_completed_onboarding so user lands on dashboard after re-login
  static Future<void> clearAuthOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ds_id_token');
    await prefs.remove('ds_user_id');
    await prefs.remove('ds_tenant_id');
    await prefs.remove('ds_email');
    await prefs.remove('login_time');
    _connection = null;
  }

  // signOut: full wipe — used by the manual Sign Out button
  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    // DartStream auth tokens
    await prefs.remove('ds_id_token');
    await prefs.remove('ds_user_id');
    await prefs.remove('ds_tenant_id');
    await prefs.remove('ds_email');
    await prefs.remove('login_time');
    // Onboarding & app state
    await prefs.remove('has_completed_onboarding');
    await prefs.remove('user_name');
    await prefs.remove('user_age');
    await prefs.remove('is_sleeping');
    await prefs.remove('sleep_start_time');
    await prefs.remove('session_just_completed');
    await prefs.remove('last_session_hours');
    await prefs.remove('last_session_start_time');
    _connection = null;
    cachedUserProfile = null; // Clear cache
  }

  // clearSession kept as alias for signOut for backward compatibility
  static Future<void> clearSession() => signOut();

  static Future<void> signIn(String email, String password) async {
    _connection = await DartStreamClient.signIn(
      config: AppConfig.dartStream,
      email: email,
      password: password,
    );
    await _saveSession(_connection!.session);
  }

  static Future<void> signUp(String email, String password) async {
    _connection = await DartStreamClient.signUp(
      config: AppConfig.dartStream,
      email: email,
      password: password,
    );
    await _saveSession(_connection!.session);
  }

  static Future<void> saveUserData(UserProfile profile) async {
    if (_connection == null) throw StateError('No active DartStream connection');
    cachedUserProfile = profile; // Update cache
    await wrap(() async {
      await _connection!.client.experience.saveCloudSave(
        _connection!.session,
        payload: profile.toJson(),
      );
    });
  }

  static Future<UserProfile?> loadUserData() async {
    if (_connection == null) return null;
    return await wrap(() async {
      final raw = await _connection!.client.experience.loadCloudSave(_connection!.session);
      if (raw == null) return null;

      // Try all possible unwrap shapes
      Map<String, dynamic>? payload;

      // Shape 1: {'payload': {'payload': {...}}} — double wrapped
      final top = raw['payload'];
      if (top is Map<String, dynamic> && top.containsKey('payload')) {
        payload = top['payload'] as Map<String, dynamic>?;
      }
      // Shape 2: {'payload': {...}} — single wrapped  
      else if (top is Map<String, dynamic>) {
        payload = top;
      }
      // Shape 3: direct data
      else if (raw.containsKey('name')) {
        payload = raw;
      }

      const bool isSeedDemo = bool.fromEnvironment('MARKETING_DEMO_SEED') ||
          String.fromEnvironment('MARKETING_DEMO_SEED') == 'true';

      payload ??= {
        'name': _connection!.session.email?.split('@').first ?? 'You',
        'email': _connection!.session.email ?? '',
        'age': 25,
        'totalXp': isSeedDemo ? 180 : 0,
        'sleepSessions': [],
      };
      
      final profile = UserProfile.fromJson(payload);
      cachedUserProfile = profile; // Update local cache
      
      // Auto-save patch: if the raw payload had no sessions and demo seeding is enabled,
      // the fromJson factory generated 7 days of mock data. We save this immediately.
      if (isSeedDemo && ((payload['sleepSessions'] as List?)?.isEmpty ?? true)) {
        // saveUserData cannot be awaited here because we are already inside a wrap() mutex.
        // We can dispatch it asynchronously.
        _connection!.client.experience.saveCloudSave(
          _connection!.session,
          payload: profile.toJson(),
        );
      }
      
      return profile;
    });
  }

  static Future<void> trackEvent(String eventType, Map<String, dynamic> payload) async {
    if (_connection == null) return;
    await wrap(() async {
      await _connection!.client.reactive.trackEvent(
        _connection!.session,
        eventType: eventType,
        payload: payload,
      );
    });
  }
}
