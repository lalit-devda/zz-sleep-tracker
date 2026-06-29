// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<Map<String, double>?> getBrowserLocation() async {
  try {
    final position = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 5),
    );
    final coords = position.coords;
    if (coords != null && coords.latitude != null && coords.longitude != null) {
      return {
        'latitude': coords.latitude!.toDouble(),
        'longitude': coords.longitude!.toDouble(),
      };
    }
  } catch (e) {
    // Geolocation permission denied or timed out
  }
  return null;
}
