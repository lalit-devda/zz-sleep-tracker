import 'package:dartstream_client/dartstream_client.dart';

class AppConfig {
  static const firebaseApiKey =
      String.fromEnvironment('FIREBASE_API_KEY');
  static bool get hasFirebaseApiKey => firebaseApiKey.isNotEmpty;
  static DartStreamConfig get dartStream =>
      DartStreamConfig.dev(firebaseApiKey: firebaseApiKey);
}
