// ignore_for_file: avoid_print
import 'dart:io';
import 'package:dartstream_client/dartstream_client.dart';

void main() async {
  print('===================================================');
  print(' DartStream IntelliToggle Feature Flags CLI Deep Dive ');
  print('===================================================');

  final firebaseApiKey = Platform.environment['FIREBASE_API_KEY']?.trim() ?? 
      'AIzaSyAtJLCMoEtw3lFUNa4agcuaKA9kSkXOuaA';
  final token = Platform.environment['DARTSTREAM_SESSION_TOKEN']?.trim();

  if (token == null || token.isEmpty) {
    print('❌ Error: Missing session token in environment variables.');
    print('');
    print('Please set the DARTSTREAM_SESSION_TOKEN environment variable.');
    print('Example (PowerShell):');
    print('  \$env:DARTSTREAM_SESSION_TOKEN = "your-bearer-token"');
    print('  dart run bin/intellitoggle_deepdive.dart');
    print('');
    exit(1);
  }

  print('Completions endpoint/IntelliToggle verification script...');
  print('📡 Target Project: dartcodeai-prod');
  print('🔄 Connecting to DartStream services...');

  final config = DartStreamConfig.dev(firebaseApiKey: firebaseApiKey);
  
  // Create session object wrapping the user details
  const session = DartStreamSession(
    idToken: 'token', // Dummy token for session initialization metadata
    userId: 'user-demo-id',
    tenantId: 'tenant-demo-id',
    email: 'user@example.com',
    raw: {},
  );

  final client = DartStreamClient(
    config: config,
    idToken: token,
    session: session,
  );

  try {
    print('📥 Fetching feature flags from platform...');
    final flags = await client.platform.listFeatureFlags(session);
    
    print('✅ Feature flags retrieved successfully:');
    print('---------------------------------------------------');
    if (flags.isEmpty) {
      print('  No feature flags configured in the database.');
    } else {
      for (var f in flags) {
        if (f is Map) {
          final key = f['key'] ?? f['flagKey'] ?? 'unknown';
          final enabled = f['enabled'] ?? false;
          print('  🚩 Key: $key | Enabled: $enabled');
        }
      }
    }
    print('---------------------------------------------------');
  } catch (e) {
    print('❌ Failed to evaluate feature flags: $e');
    exit(1);
  }
}
