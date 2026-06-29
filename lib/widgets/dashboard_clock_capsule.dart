import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class DashboardClockCapsule extends StatefulWidget {
  final DateTime? dateTimeOverride;
  final String? timezone;
  final String? location;
  final bool isNight;

  const DashboardClockCapsule({
    super.key,
    this.dateTimeOverride,
    this.timezone,
    this.location,
    this.isNight = false,
  });

  @override
  State<DashboardClockCapsule> createState() => _DashboardClockCapsuleState();
}

class _DashboardClockCapsuleState extends State<DashboardClockCapsule> {
  late DateTime _currentTime;
  Timer? _timer;
  String _cachedLocation = 'Indore';
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _currentTime = widget.dateTimeOverride ?? DateTime.now();
    _loadCachedData();
    _startTimer();
  }

  void _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.timezone != null) {
      await prefs.setString('cached_timezone', widget.timezone!);
    }

    if (widget.location != null) {
      if (mounted) {
        setState(() {
          _cachedLocation = widget.location!;
        });
      }
      await prefs.setString('cached_location', widget.location!);
    } else {
      final savedLoc = prefs.getString('cached_location');
      if (savedLoc != null && mounted) {
        setState(() {
          _cachedLocation = savedLoc;
        });
      }
    }
  }

  void _startTimer() {
    if (widget.dateTimeOverride == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _currentTime = DateTime.now();
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(DashboardClockCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timezone != oldWidget.timezone || widget.location != oldWidget.location) {
      _loadCachedData();
    }
    
    if (widget.dateTimeOverride != oldWidget.dateTimeOverride) {
      _timer?.cancel();
      if (widget.dateTimeOverride != null) {
        setState(() {
          _currentTime = widget.dateTimeOverride!;
        });
      } else {
        _currentTime = DateTime.now();
        _startTimer();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayStr = DateFormat('EEE').format(_currentTime); 
    final dateStr = DateFormat('MMM d').format(_currentTime); 
    final timeStr = DateFormat('hh:mm a').format(_currentTime); 

    // Extract city name for display (e.g. "Indore, India" -> "Indore")
    String displayLoc = _cachedLocation;
    if (displayLoc.contains(',')) {
      displayLoc = displayLoc.split(',').first.trim();
    }

    final bool isNight = widget.isNight;
    final textPrimary = isNight ? Colors.white : AppTheme.textPrimary;
    final textSecondary = isNight ? Colors.white60 : AppTheme.textSecondary;
    final dividerColor = isNight ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    
    final cardBg = isNight 
        ? (_isHovered ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
        : (_isHovered ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC));
    final cardBorder = isNight
        ? (_isHovered ? const Color(0xFF334155) : const Color(0xFF1E293B))
        : (_isHovered ? AppTheme.accent.withValues(alpha: 0.5) : const Color(0xFFE2E8F0));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: cardBorder,
            width: 1.2,
          ),
          boxShadow: _isHovered && !isNight
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Location Icon + Text (displays the resolved city name)
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.accent),
                const SizedBox(width: 4),
                Text(
                  displayLoc,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            
            _buildDivider(dividerColor),

            // Calendar Icon + Date
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.blueAccent),
                const SizedBox(width: 5),
                Text(
                  '$dayStr, $dateStr',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ],
            ),

            _buildDivider(dividerColor),

            // Clock Icon + Time
            Row(
              children: [
                const Icon(Icons.access_time_filled_rounded, size: 12, color: Colors.orangeAccent),
                const SizedBox(width: 5),
                Text(
                  timeStr,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Container(
        width: 1,
        height: 12,
        color: color,
      ),
    );
  }
}
