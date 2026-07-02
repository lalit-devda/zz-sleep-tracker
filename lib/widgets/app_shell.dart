import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/dartstream_manager.dart';
import '../utils/app_state.dart';
import 'dashboard_clock_capsule.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isSidebarCollapsed = false;

  bool get _isNight => (DateTime.now().hour >= 18 || DateTime.now().hour < 6);

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ??
        DartStreamManager.connection?.session.email?.split('@').first ??
        'You';
    AppState.userName.value = name;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final Color scaffoldBg = _isNight ? const Color(0xFF090E1A) : const Color(0xFFF8FAFC);
    final Color shellBg = _isNight ? const Color(0xFF0F1629) : Colors.white;
    final Color shellBorder = _isNight ? const Color(0xFF1E2A4A) : const Color(0xFFE2E8F0);

    return ValueListenableBuilder2<String, String>(
      first: AppState.userName,
      second: AppState.currentPath,
      builder: (context, userName, currentPath, _) {
        if (isDesktop) {
          return Scaffold(
            backgroundColor: scaffoldBg,
            body: Row(
              children: [
                // Collapsible Sidebar
                Container(
                  width: _isSidebarCollapsed ? 80 : 240,
                  decoration: BoxDecoration(
                    color: shellBg,
                    border: Border(
                      right: BorderSide(
                        color: shellBorder,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _isSidebarCollapsed ? 0.0 : 24.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _isNight ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isNight ? const Color(0xFF047857) : const Color(0xFFDCFCE7),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.nights_stay_rounded,
                                color: AppTheme.accent,
                                size: 20,
                              ),
                            ),
                            if (!_isSidebarCollapsed) ...[
                              const SizedBox(width: 12),
                              Text(
                                'Zᶻ Sleep Tracker',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isNight ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: shellBorder,
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _sidebarItem(
                              context,
                              icon: Icons.local_florist_outlined,
                              activeIcon: Icons.local_florist_rounded,
                              label: 'Home',
                              path: '/dashboard',
                              currentPath: currentPath,
                            ),
                            _sidebarItem(
                              context,
                              icon: Icons.history_toggle_off_outlined,
                              activeIcon: Icons.history_toggle_off_rounded,
                              label: 'History',
                              path: '/history',
                              currentPath: currentPath,
                            ),
                            _sidebarItem(
                              context,
                              icon: Icons.person_outline_rounded,
                              activeIcon: Icons.person_rounded,
                              label: 'Profile',
                              path: '/profile',
                              currentPath: currentPath,
                            ),
                            _sidebarItem(
                              context,
                              icon: Icons.star_outline_rounded,
                              activeIcon: Icons.star_rounded,
                              label: 'Levels',
                              path: '/levels',
                              currentPath: currentPath,
                            ),
                            _sidebarItem(
                              context,
                              icon: Icons.flag_outlined,
                              activeIcon: Icons.flag_rounded,
                              label: 'Flags',
                              path: '/flags',
                              currentPath: currentPath,
                            ),
                            _sidebarItem(
                              context,
                              icon: Icons.toggle_off_outlined,
                              activeIcon: Icons.toggle_on_rounded,
                              label: 'IntelliToggle',
                              path: '/intellitoggle',
                              currentPath: currentPath,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: IconButton(
                          icon: Icon(
                            _isSidebarCollapsed
                                ? Icons.chevron_right_rounded
                                : Icons.chevron_left_rounded,
                            color: _isNight ? Colors.white54 : AppTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isSidebarCollapsed = !_isSidebarCollapsed;
                            });
                          },
                          tooltip: _isSidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                        ),
                      ),
                      _isSidebarCollapsed
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: '$userName (Active)',
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                                      child: Text(
                                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.accentDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Tooltip(
                                    message: 'Sign Out',
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.logout_rounded,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                      onPressed: () async {
                                        await DartStreamManager.signOut();
                                        if (context.mounted) context.go('/');
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: shellBorder,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                                    child: Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accentDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          userName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _isNight ? Colors.white : AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Active Account',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            color: _isNight ? Colors.white54 : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.logout_rounded,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    onPressed: () async {
                                      await DartStreamManager.signOut();
                                      if (context.mounted) context.go('/');
                                    },
                                    tooltip: 'Sign Out',
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                ),
                // Main Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: shellBg,
                          border: Border(
                            bottom: BorderSide(
                              color: shellBorder,
                              width: 1.5,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                                  child: Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hello,',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: _isNight ? Colors.white70 : AppTheme.textSecondary,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                    Text(
                                      userName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _isNight ? Colors.white : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ValueListenableBuilder2<String, String>(
                              first: AppState.location,
                              second: AppState.timezone,
                              builder: (context, location, timezone, _) {
                                return DashboardClockCapsule(
                                  location: location,
                                  timezone: timezone,
                                  isNight: _isNight,
                                );
                              },
                            ),
                            Row(
                              children: [
                                _navbarIconButton(Icons.calendar_today_outlined),
                                const SizedBox(width: 8),
                                _navbarIconButton(Icons.chat_bubble_outline_rounded),
                                const SizedBox(width: 8),
                                _navbarIconButton(Icons.notifications_none_rounded),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: widget.child,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile View
          return Scaffold(
            backgroundColor: scaffoldBg,
            appBar: AppBar(
              backgroundColor: shellBg,
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.nights_stay_rounded, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Zᶻ Sleep Tracker',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isNight ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentDark,
                      ),
                    ),
                  ),
                ),
              ],
              shape: Border(
                bottom: BorderSide(
                  color: shellBorder,
                  width: 1,
                ),
              ),
            ),
            body: Material(
              color: Colors.transparent,
              child: widget.child,
            ),
            bottomNavigationBar: _buildBottomNav(context, currentPath),
          );
        }
      },
    );
  }

  Widget _navbarIconButton(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _isNight ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isNight ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: _isNight ? Colors.white70 : AppTheme.textSecondary,
        size: 18,
      ),
    );
  }

  Widget _sidebarItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String path,
    required String currentPath,
  }) {
    final isActive = currentPath == path;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final isCollapsed = _isSidebarCollapsed && isDesktop;

    final itemBg = isActive ? AppTheme.accent.withValues(alpha: 0.12) : Colors.transparent;
    final contentColor = isActive ? AppTheme.accent : (_isNight ? Colors.white70 : AppTheme.textPrimary);
    final borderSide = isActive
        ? Border.all(color: AppTheme.accent.withValues(alpha: 0.25), width: 1)
        : Border.all(color: Colors.transparent, width: 1);

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Center(
          child: Tooltip(
            message: label,
            preferBelow: false,
            verticalOffset: 20,
            child: InkWell(
              onTap: () {
                if (!isActive) context.go(path);
              },
              borderRadius: BorderRadius.circular(12),
              hoverColor: AppTheme.accent.withValues(alpha: 0.05),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: itemBg,
                  borderRadius: BorderRadius.circular(12),
                  border: borderSide,
                ),
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: contentColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: InkWell(
        onTap: () {
          if (label == 'Home') {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          if (!isActive) context.go(path);
        },
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppTheme.accent.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: itemBg,
            borderRadius: BorderRadius.circular(12),
            border: borderSide,
          ),
          child: Row(
            children: [
              Icon(isActive ? activeIcon : icon, color: contentColor, size: 20),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: contentColor,
                ),
              ),
              const Spacer(),
              if (isActive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, String currentPath) {
    return Material(
      color: _isNight ? const Color(0xFF0F1629) : Colors.white,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: _isNight ? const Color(0xFF1E2A4A) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(context, Icons.local_florist_outlined, Icons.local_florist_rounded, 'Home', '/dashboard', currentPath),
              _navItem(context, Icons.history_toggle_off_outlined, Icons.history_toggle_off_rounded, 'History', '/history', currentPath),
              _navItem(context, Icons.person_outline_rounded, Icons.person_rounded, 'Profile', '/profile', currentPath),
              _navItem(context, Icons.star_outline_rounded, Icons.star_rounded, 'Levels', '/levels', currentPath),
              _navItem(context, Icons.flag_outlined, Icons.flag_rounded, 'Flags', '/flags', currentPath),
              _navItem(context, Icons.toggle_off_outlined, Icons.toggle_on_rounded, 'IntelliToggle', '/intellitoggle', currentPath),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    IconData activeIcon,
    String label,
    String path,
    String currentPath,
  ) {
    final isActive = currentPath == path;
    const activeColor = AppTheme.accent;
    final inactiveColor = _isNight ? Colors.white60 : AppTheme.textSecondary.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () {
        if (!isActive) context.go(path);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            size: 22,
            color: isActive ? activeColor : inactiveColor,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Multi-listenable helper
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext context, A a, B b, Widget? child) builder;
  final Widget? child;

  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, _) {
            return builder(context, a, b, child);
          },
        );
      },
    );
  }
}
