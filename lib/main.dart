import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'utils/dartstream_manager.dart';
import 'utils/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/levels_screen.dart';
import 'screens/flags_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sleep_session_screen.dart';
import 'screens/signup_screen.dart';
import 'widgets/app_shell.dart';

void main() {
  usePathUrlStrategy();
  DartStreamManager.onUnauthorized = () {
    _router.go('/login');
  };
  runApp(const SleepTrackerApp());
}

/// Wraps a widget in a smooth fade transition page.
CustomTransitionPage<void> _fadePage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/', redirect: (_, __) => '/login'),
    GoRoute(
      path: '/login',
      pageBuilder: (_, __) => _fadePage(const LoginScreen()),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (_, __) => _fadePage(const SignupScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (_, __) => _fadePage(const OnboardingScreen()),
    ),
    GoRoute(
      path: '/sleep-session',
      pageBuilder: (_, __) => _fadePage(const SleepSessionScreen()),
    ),

    // ─── Persistent Shell: sidebar/navbar renders ONCE ───────────────────────
    ShellRoute(
      builder: (context, state, child) {
        // Update active path so shell nav highlights correct item
        AppState.currentPath.value = state.uri.path;
        return AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (_, __) => _fadePage(const HomeScreen()),
        ),
        GoRoute(
          path: '/history',
          pageBuilder: (_, __) => _fadePage(const HistoryScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (_, __) => _fadePage(const ProfileScreen()),
        ),
        GoRoute(
          path: '/levels',
          pageBuilder: (_, __) => _fadePage(const LevelsScreen()),
        ),
        GoRoute(
          path: '/flags',
          pageBuilder: (_, __) => _fadePage(const FlagsScreen()),
        ),
      ],
    ),
  ],
  redirect: (context, state) async {
    final location = state.uri.path;
    final isAuthRoute = location == '/login' || location == '/signup' || location == '/';
    final isShellRoute = location == '/dashboard' || location == '/history' || location == '/profile' || location == '/levels' || location == '/flags';

    // Fast path: logged-in user navigating between shell routes
    if (DartStreamManager.isLoggedIn && isShellRoute) return null;

    // Auto-restore session if not logged in
    if (!DartStreamManager.isLoggedIn) {
      await DartStreamManager.tryRestoreSession();
    }

    final loggedIn = DartStreamManager.isLoggedIn;

    if (!loggedIn) {
      if (!isAuthRoute) return '/login';
    } else {
      if (isAuthRoute) {
        final prefs = await SharedPreferences.getInstance();
        final hasCompleted = prefs.getBool('has_completed_onboarding') ?? false;
        return hasCompleted ? '/dashboard' : '/onboarding';
      }
    }
    return null;
  },
);

class SleepTrackerApp extends StatelessWidget {
  const SleepTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zᶻ Sleep Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
