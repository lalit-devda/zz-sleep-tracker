// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('==================================================');
  print(' DartStream OAuth2 M2M Client Credentials Harness  ');
  print('==================================================');

  // Read configuration from environment variables
  final clientId = Platform.environment['DARTSTREAM_CLIENT_ID']?.trim();
  final clientSecret = Platform.environment['DARTSTREAM_CLIENT_SECRET']?.trim();
  final tokenUrlStr = Platform.environment['DARTSTREAM_TOKEN_URL']?.trim() ?? 
      'https://dev-apiauth.dartstream.io/oauth2/token';

  if (clientId == null || clientId.isEmpty || clientSecret == null || clientSecret.isEmpty) {
    print('❌ Error: Missing credentials in environment variables.');
    print('');
    print('Please set the following environment variables:');
    print('  - DARTSTREAM_CLIENT_ID');
    print('  - DARTSTREAM_CLIENT_SECRET');
    print('  - DARTSTREAM_TOKEN_URL (optional, defaults to $tokenUrlStr)');
    print('');
    print('Example (PowerShell):');
    print('  \$env:DARTSTREAM_CLIENT_ID = "your-client-id"');
    print('  \$env:DARTSTREAM_CLIENT_SECRET = "your-client-secret"');
    print('  dart run bin/oauth2_deepdive.dart');
    print('');
    exit(1);
  }

  print('📡 Target Token URL: $tokenUrlStr');
  print('🔑 Client ID: $clientId');
  print('🔒 Client Secret: [REDACTED (${clientSecret.length} chars)]');
  print('🔄 Requesting OAuth2 client_credentials token...');

  final Uri tokenUri;
  try {
    tokenUri = Uri.parse(tokenUrlStr);
  } catch (e) {
    print('❌ Error: Invalid DARTSTREAM_TOKEN_URL value: $tokenUrlStr');
    exit(1);
  }

  final client = http.Client();
  try {
    // Standard OAuth2 Client Credentials request
    final response = await client.post(
      tokenUri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );

    print('⏬ Response Status: ${response.statusCode}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('✅ Token request successful!');
      final Map<String, dynamic> data = jsonDecode(response.body);
      final accessToken = data['access_token'];
      final tokenType = data['token_type'] ?? 'Bearer';
      final expiresIn = data['expires_in'];
      final scope = data['scope'];

      print('');
      print('📦 Token Metadata:');
      print('  - Token Type: $tokenType');
      print('  - Expires In: ${expiresIn ?? "N/A"} seconds');
      print('  - Scope: ${scope ?? "N/A"}');
      print('');
      print('🔑 ACCESS TOKEN:');
      print('  $accessToken');
      print('');
    } else {
      print('❌ Token request failed.');
      print('Response body:');
      print(response.body);
      exit(1);
    }
  } catch (e) {
    print('❌ Connection error: $e');
    exit(1);
  } finally {
    client.close();
  }
}
