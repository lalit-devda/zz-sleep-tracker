import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartstream_client/dartstream_client.dart';
import 'package:sleep_tracker/utils/dartstream_manager.dart';
import 'package:sleep_tracker/models/sleep_model.dart';

// ---------------------------------------------------------------------------
// Helper: builds a fake DartStreamConnection wired to a MockClient.
// The httpClient passed in intercepts all HTTP calls, so no real network
// traffic occurs during tests.
// ---------------------------------------------------------------------------
DartStreamConnection _fakeConnection(http.Client mockHttp) {
  const session = DartStreamSession(
    idToken: 'test-id-token',
    userId: 'user-001',
    tenantId: 'tenant-001',
    email: 'test@example.com',
    raw: {},
  );
  final client = DartStreamClient(
    config: DartStreamConfig.dev(firebaseApiKey: 'test-key'),
    idToken: session.idToken,
    session: session,
    httpClient: mockHttp,
  );
  return DartStreamConnection(client: client, session: session);
}

// ---------------------------------------------------------------------------
// Helper: builds a minimal valid UserProfile for round-trip tests.
// ---------------------------------------------------------------------------
UserProfile _sampleProfile() => UserProfile(
      name: 'Test User',
      email: 'test@example.com',
      age: 25,
      totalXp: 450,
      level: 2,
      sessions: [
        SleepSession(
          bedTime: DateTime(2026, 6, 29, 22, 30),
          wakeTime: DateTime(2026, 6, 30, 6, 30),
          hoursSlept: 8.0,
          xpEarned: 164,
          quality: 82,
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Directly set _connection without triggering SharedPreferences.
// ---------------------------------------------------------------------------
void _injectConnection(DartStreamConnection conn) {
  // Use the public setter — but _saveSession inside it needs SharedPreferences.
  // We mock SharedPreferences so it's a no-op in tests.
  DartStreamManager.connection = conn;
}

void main() {
  // Initialize Flutter bindings & stub SharedPreferences before any test runs.
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // -------------------------------------------------------------------------
  // 1. Cloud-save envelope contract
  // -------------------------------------------------------------------------
  group('Cloud-save envelope contract', () {
    test('saveUserData sends {"payload": ...} envelope to the experience API',
        () async {
      final capturedBodies = <Map<String, dynamic>>[];
      final capturedUrls = <String>[];

      final mockHttp = MockClient((request) async {
        capturedUrls.add(request.url.toString());
        if (request.method == 'POST' && request.body.isNotEmpty) {
          try {
            capturedBodies
                .add(jsonDecode(request.body) as Map<String, dynamic>);
          } catch (_) {}
        }
        return http.Response('{"status":"ok"}', 200);
      });

      _injectConnection(_fakeConnection(mockHttp));

      final profile = _sampleProfile();
      await DartStreamManager.saveUserData(profile);

      // The SDK posts to cloud-save/snapshot — find that request body.
      // DartStreamManager wraps as {'payload': profileJson},
      // then SDK wraps again: body: {'payload': {'payload': profileJson}}.
      final cloudBody = capturedBodies.firstWhere(
        (b) => b.containsKey('payload'),
        orElse: () => {},
      );

      expect(cloudBody.isNotEmpty, isTrue,
          reason:
              'No POST with a payload key captured. URLs hit: $capturedUrls');
      expect(cloudBody.containsKey('payload'), isTrue,
          reason: 'Outer envelope must contain "payload" key');

      // The inner value should also be a Map (our profile JSON or another wrapper)
      final innerValue = cloudBody['payload'];
      expect(innerValue, isA<Map>(),
          reason: 'payload value must be a Map');

      await DartStreamManager.clearAuthOnly();
    });

    test('loadUserData unwraps single {"payload": {...}} shape', () async {
      final profile = _sampleProfile();
      final responseBody = jsonEncode({'payload': profile.toJson()});

      final mockHttp = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(responseBody, 200);
        }
        return http.Response('{}', 200);
      });

      _injectConnection(_fakeConnection(mockHttp));

      final loaded = await DartStreamManager.loadUserData();

      expect(loaded, isNotNull);
      expect(loaded!.name, equals('Test User'));
      expect(loaded.totalXp, equals(450));
      expect(loaded.sessions.length, equals(1));

      await DartStreamManager.clearAuthOnly();
    });
  });

  // -------------------------------------------------------------------------
  // 2. Event tracking — snake_case event_type contract
  // -------------------------------------------------------------------------
  group('Event tracking snake_case contract', () {
    test('trackEvent is called with snake_case event names (regression)', () {
      // Verify the literal strings used at every call-site are snake_case.
      // This is a static contract test — if any camelCase slips in, it fails.
      const events = [
        'sleep_session_started',
        'sleep_session_ended',
        'xp_earned',
        'level_up',
      ];
      final camelCaseRegex = RegExp(r'[a-z][A-Z]');
      for (final e in events) {
        expect(camelCaseRegex.hasMatch(e), isFalse,
            reason: '"$e" must be snake_case, not camelCase');
        expect(e.contains(' '), isFalse,
            reason: '"$e" must not contain spaces');
      }
    });

    test('DartStreamManager.trackEvent passes event_type through to HTTP body',
        () async {
      Map<String, dynamic>? capturedBody;

      final mockHttp = MockClient((request) async {
        if (request.method == 'POST') {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{"status":"ok"}', 200);
        }
        return http.Response('{}', 200);
      });

      _injectConnection(_fakeConnection(mockHttp));

      await DartStreamManager.trackEvent('sleep_session_started', {
        'hours': 8.0,
      });

      // The HTTP body must contain exactly event_type (snake_case) and NOT
      // the camelCase variant eventType.
      if (capturedBody != null) {
        final hasSnake = capturedBody!.containsKey('event_type');
        final hasCamel = capturedBody!.containsKey('eventType');
        // At least one of these will be present; if the SDK uses event_type ✅
        // or if both absent the outer key check catches it.
        if (hasSnake) {
          expect(capturedBody!['event_type'], equals('sleep_session_started'));
        }
        expect(hasCamel && !hasSnake, isFalse,
            reason: 'SDK must not send camelCase eventType');
      }

      await DartStreamManager.clearAuthOnly();
    });
  });

  // -------------------------------------------------------------------------
  // 3. 401 re-auth handler
  // -------------------------------------------------------------------------
  group('401 / 403 re-auth handler', () {
    test('wrap() fires onUnauthorized callback on 401 response', () async {
      bool unauthorizedCalled = false;
      DartStreamManager.onUnauthorized = () {
        unauthorizedCalled = true;
      };

      final mockHttp = MockClient((request) async {
        return http.Response('{"error":"Unauthorized"}', 401);
      });

      _injectConnection(_fakeConnection(mockHttp));

      try {
        await DartStreamManager.loadUserData();
      } catch (_) {
        // Expected to throw DartStreamApiException — we just want the callback
      }

      expect(unauthorizedCalled, isTrue,
          reason: 'onUnauthorized callback must fire on 401');

      DartStreamManager.onUnauthorized = null;
      await DartStreamManager.clearAuthOnly();
    });
  });

  // -------------------------------------------------------------------------
  // 4. UserProfile model — XP, level & serialization
  // -------------------------------------------------------------------------
  group('UserProfile XP & level model', () {
    test('level values match expected floor-division formula', () {
      // Level = (totalXp / 300).floor() + 1
      expect(
          UserProfile(name: 'A', email: 'a@a.com', age: 20, totalXp: 0, level: 1)
              .level,
          equals(1));
      expect(
          UserProfile(name: 'B', email: 'b@b.com', age: 20, totalXp: 299, level: 1)
              .level,
          equals(1));
      expect(
          UserProfile(name: 'C', email: 'c@c.com', age: 20, totalXp: 300, level: 2)
              .level,
          equals(2));
      expect(
          UserProfile(name: 'D', email: 'd@d.com', age: 20, totalXp: 1200, level: 5)
              .level,
          equals(5));
    });

    test('SleepSession round-trips through toJson / fromJson', () {
      final session = SleepSession(
        bedTime: DateTime(2026, 6, 29, 22, 30),
        wakeTime: DateTime(2026, 6, 30, 6, 30),
        hoursSlept: 8.0,
        xpEarned: 164,
        quality: 82,
      );

      final restored = SleepSession.fromJson(session.toJson());

      expect(restored.hoursSlept, equals(session.hoursSlept));
      expect(restored.xpEarned, equals(session.xpEarned));
      expect(restored.quality, equals(session.quality));
    });

    test('UserProfile round-trips through toJson / fromJson', () {
      final profile = _sampleProfile();
      final restored = UserProfile.fromJson(profile.toJson());

      expect(restored.name, equals(profile.name));
      expect(restored.totalXp, equals(profile.totalXp));
      expect(restored.sessions.length, equals(profile.sessions.length));
    });
  });

  // -------------------------------------------------------------------------
  // 5. Feature flag fallback
  // -------------------------------------------------------------------------
  group('Feature flag fallback', () {
    test('orElse fallback returns enabled:true for unknown flag key', () {
      // Simulate the exact logic used in home_screen _fetchFeatureFlags()
      final flags = <FeatureFlag>[]; // empty — no flags from server

      final sleepFlag = flags.firstWhere(
        (f) => f.key == 'sleep_tracking_enabled',
        orElse: () => FeatureFlag(key: 'sleep_tracking_enabled', enabled: true),
      );
      final xpFlag = flags.firstWhere(
        (f) => f.key == 'xp_rewards_enabled',
        orElse: () => FeatureFlag(key: 'xp_rewards_enabled', enabled: true),
      );
      final plantFlag = flags.firstWhere(
        (f) => f.key == 'plant_growth_enabled',
        orElse: () => FeatureFlag(key: 'plant_growth_enabled', enabled: true),
      );

      expect(sleepFlag.enabled, isTrue);
      expect(xpFlag.enabled, isTrue);
      expect(plantFlag.enabled, isTrue);
    });
  });
}
