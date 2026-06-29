import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../widgets/plant_widget.dart';
import '../models/sleep_model.dart';
import '../utils/dartstream_manager.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  UserProfile? _user = DartStreamManager.cachedUserProfile;
  DateTime _now = DateTime.now();
  late Timer _clockTimer;

  static const List<Map<String, dynamic>> _mockHistory = [
    {'day': '10', 'hours': 7.2},
    {'day': '11', 'hours': 6.0},
    {'day': '12', 'hours': 8.5},
    {'day': '13', 'hours': 5.5},
    {'day': '14', 'hours': 7.8},
    {'day': '15', 'hours': 9.2},
    {'day': '16', 'hours': 6.5},
    {'day': '17', 'hours': 8.3},
  ];

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
    _loadHistoryData();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  Future<void> _loadHistoryData() async {
    // Use cache immediately — never block UI with a full-screen loader
    if (DartStreamManager.cachedUserProfile != null) {
      if (mounted) {
        setState(() {
          _user = DartStreamManager.cachedUserProfile!;
        });
      }
    }

    // Always fetch fresh data silently in background
    try {
      final user = await DartStreamManager.loadUserData();
      if (user != null && mounted) {
        setState(() {
          _user = user;
        });
      }
    } catch (e) {
      // Sliently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? UserProfile(name: 'You', email: '', level: 1, totalXp: 180);
    final size = MediaQuery.of(context).size;

    // 1. Calculate Experience Progress
    final String levelText = 'Level ${user.level}';
    final String xpText = '${user.xpProgress} / ${user.xpNeeded} XP';
    final double progressValue = user.levelProgress;

    // 2. Calculate Last Awake at
    String lastAwakeStr = '--:--';
    if (user.sessions.isNotEmpty) {
      final lastSession = user.sessions.last;
      final hour = lastSession.wakeTime.hour.toString().padLeft(2, '0');
      final minute = lastSession.wakeTime.minute.toString().padLeft(2, '0');
      lastAwakeStr = '$hour:$minute';
    }

    // 3. Calculate Average/Total Sleep Hours
    String avgSleepStr = '0h';
    if (user.sessions.isNotEmpty) {
      double total = 0;
      for (var s in user.sessions) {
        total += s.hoursSlept;
      }
      final avg = total / user.sessions.length;
      final hoursPart = avg.toInt();
      final minsPart = ((avg - hoursPart) * 60).round();
      avgSleepStr = '${hoursPart}h ${minsPart}m';
    }

    // 4. Generate dynamic chart data from last 7 sessions
    final List<Map<String, dynamic>> chartHistory = [];
    if (user.sessions.isEmpty) {
      chartHistory.addAll(_mockHistory);
    } else {
      final lastSessions = user.sessions.length > 8
          ? user.sessions.sublist(user.sessions.length - 8)
          : user.sessions;
      for (int i = 0; i < lastSessions.length; i++) {
        final s = lastSessions[i];
        final dayStr = '${s.wakeTime.day}';
        chartHistory.add({'day': dayStr, 'hours': s.hoursSlept});
      }
    }

    final String timeStr = DateFormat('hh:mm').format(_now);
    final String amPmStr = DateFormat('a').format(_now);

    final isWide = size.width > 900;
    final isNightSky = _now.hour >= 18 || _now.hour < 6;

    final cardBg = isNightSky ? const Color(0xFF0D1527) : Colors.white;
    final cardBorder = isNightSky ? const Color(0xFF1E2F52) : const Color(0xFFE2E8F0);
    final textPrimaryColor = isNightSky ? Colors.white : AppTheme.textPrimary;
    final textSecondaryColor = isNightSky ? Colors.white70 : AppTheme.textSecondary;

    final cardBgGradient = isNightSky
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF131C31), Color(0xFF0A101D)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FAFC)],
          );

    // Left Column: Unified Sleep/Experience Card
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: cardBgGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: isNightSky ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Weather and Digital clock
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Lottie.asset(
                        isNightSky ? 'assets/lottie/moon.json' : 'assets/lottie/clear_day.json',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: GoogleFonts.outfit(
                            fontSize: 64,
                            fontWeight: FontWeight.w200,
                            color: textPrimaryColor,
                            letterSpacing: -2,
                            height: 1.0,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, left: 6.0),
                          child: Text(
                            amPmStr,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // 2. Plant Widget with Spotlight effect
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Spotlight glow
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    PlantWidget(
                      stage: user.plantStage,
                      size: 160,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Divider(height: 1, thickness: 1, color: isNightSky ? Colors.white10 : Colors.black12),
              const SizedBox(height: 24),
              // 3. Level details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Experience',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        levelText,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.xpColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+ 30XP',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.xpColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        xpText,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress Bar
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progressValue.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: isNightSky ? const Color(0xFF1A263F) : const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Tip Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isNightSky ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'TIP: The healthier your sleep, the larger your plants will grow.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: textSecondaryColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // Right Column: Stats, Bar Chart & Sessions List
    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stats row (Last Awake at, Avg Sleep)
        Row(
          children: [
            Expanded(
              child: _buildStatTile('Last Awake at', lastAwakeStr, '', isNightSky),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile('Avg Sleep', avgSleepStr, '', isNightSky),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // If sessions are empty, show a clean empty state card
        if (user.sessions.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder, width: 1),
            ),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              children: [
                const Icon(Icons.hotel_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No sleep sessions recorded yet',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your weekly sleep graphs and logs will appear here once you start logging your sleep from the home screen.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Chart Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep Statistic',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 120,
                  child: BarChart(
                    BarChartData(
                      maxY: 12,
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: Colors.grey.withValues(alpha: 0.1),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 3,
                            getTitlesWidget: (v, _) => Text(
                              '${v.toInt()}h',
                              style: GoogleFonts.outfit(fontSize: 8, color: textSecondaryColor),
                            ),
                            reservedSize: 22,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= chartHistory.length) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  chartHistory[idx]['day'],
                                  style: GoogleFonts.outfit(fontSize: 9, color: textSecondaryColor, fontWeight: FontWeight.w500),
                                ),
                              );
                            },
                            reservedSize: 18,
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(chartHistory.length, (i) {
                        final hours = chartHistory[i]['hours'] as double;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: hours,
                              color: AppTheme.accent,
                              width: 12,
                              borderRadius: BorderRadius.circular(4),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: 12,
                                color: Colors.grey.withValues(alpha: 0.05),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Logged Sessions List Card!
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Sleep Logs',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: user.sessions.length > 5 ? 5 : user.sessions.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
                  itemBuilder: (context, index) {
                    final sessionIndex = user.sessions.length - 1 - index;
                    final session = user.sessions[sessionIndex];
                    final dateStr = DateFormat('MMM d, y').format(session.bedTime);
                    final hoursStr = session.hoursSlept.toStringAsFixed(1);
                    final durationStr = "${DateFormat('HH:mm').format(session.bedTime)} - ${DateFormat('HH:mm').format(session.wakeTime)}";

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateStr,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimaryColor,
                                ),
                              ),
                              Text(
                                durationStr,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$hoursStr hrs',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.sleepBlue,
                                    ),
                                  ),
                                  Text(
                                    '+${session.xpEarned} XP',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.xpColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: List.generate(
                                  5,
                                  (starIdx) => Icon(
                                    Icons.star_rounded,
                                    size: 11,
                                    color: starIdx < session.quality ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: isWide ? 1050 : 500),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: leftColumn),
                          const SizedBox(width: 24),
                          Expanded(flex: 6, child: rightColumn),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          leftColumn,
                          const SizedBox(height: 20),
                          rightColumn,
                        ],
                      ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, String unit, bool isNight) {
    final bg = isNight ? const Color(0xFF0D1527) : Colors.white;
    final border = isNight ? const Color(0xFF1E2F52) : const Color(0xFFE2E8F0);
    final valColor = isNight ? Colors.white : AppTheme.textPrimary;
    final labelColor = isNight ? Colors.white70 : AppTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: valColor,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Text(
                    unit,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
