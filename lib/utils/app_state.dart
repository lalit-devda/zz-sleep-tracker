import 'package:flutter/foundation.dart';

/// Holds app-wide reactive state that needs to propagate across the shell
/// and child screens without triggering full rebuilds of unrelated widgets.
class AppState {
  AppState._();

  /// The display name shown in the sidebar/navbar.
  static final userName = ValueNotifier<String>('You');

  /// Current active route path — used by shell to highlight active nav item.
  static final currentPath = ValueNotifier<String>('/dashboard');

  /// Resolved location from Home screen API calls to show in shell navbar.
  static final location = ValueNotifier<String>('Indore, India');

  /// Resolved timezone from Home screen API calls to show in shell navbar.
  static final timezone = ValueNotifier<String>('Asia/Kolkata');
}
