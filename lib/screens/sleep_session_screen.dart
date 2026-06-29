import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/toast_helper.dart';
import '../utils/dartstream_manager.dart';
import '../models/sleep_model.dart';
import '../utils/audio_helper.dart';

class SleepSessionScreen extends StatefulWidget {
  const SleepSessionScreen({super.key});

  @override
  State<SleepSessionScreen> createState() => _SleepSessionScreenState();
}

class _SleepSessionScreenState extends State<SleepSessionScreen> with TickerProviderStateMixin {
  DateTime? _sleepStartTime;
  Duration _elapsed = Duration.zero;
  Timer? _tickerTimer;
  bool _isLoading = true;
  UserProfile? _userProfile;

  // Breathing guide animation variables
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  String _breathingPhase = "Breathe In";
  bool _showBreathingGuide = false;
  Timer? _breathingPhaseTimer;

  // Wave painter animation controller
  late AnimationController _waveController;

  // Sound generator variables
  String _selectedSound = 'none';
  double _volume = 0.5;

  // Alarm variables
  bool _isAlarmRinging = false;

  // Sleep Analysis display variables
  bool _showAnalysis = false;
  String _sleptDurationLabel = '0h 0m';
  int _analysisQualityScore = 80;
  String _sleepStartTimeLabel = '23:00';
  String _sleepEndTimeLabel = '07:00';
  String _analysisDeepSleepLabel = '2h 10m';
  String _analysisFellAsleepLabel = '15m';

  @override
  void initState() {
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    super.initState();
    _initAudioJs();
    _loadSleepStartTime();
    _startBreathingGuide();
  }

  void _initAudioJs() {
    initAudioJs();
  }

  void _loadSleepStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTimeStr = prefs.getString('sleep_start_time');
    UserProfile? profile;
    try {
      profile = await DartStreamManager.loadUserData();
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    }
    
    if (mounted) {
      setState(() {
        _userProfile = profile;
      });
    }

    if (savedTimeStr != null) {
      final parsedTime = DateTime.parse(savedTimeStr);
      if (mounted) {
        setState(() {
          _sleepStartTime = parsedTime;
          _elapsed = DateTime.now().difference(parsedTime);
          _isLoading = false;
        });
      }
    } else {
      final now = DateTime.now();
      await prefs.setString('sleep_start_time', now.toIso8601String());
      await prefs.setBool('is_sleeping', true);
      if (mounted) {
        setState(() {
          _sleepStartTime = now;
          _elapsed = Duration.zero;
          _isLoading = false;
        });
      }
    }

    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepStartTime != null && mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_sleepStartTime!);
        });
        _checkAlarmTime();
      }
    });
  }

  void _checkAlarmTime() {
    final now = DateTime.now();
    if (now.hour == 6 && now.minute == 30 && now.second == 0 && !_isAlarmRinging && !_showAnalysis) {
      _triggerAlarm();
    }
  }

  void _triggerAlarm() {
    if (_isAlarmRinging) return;
    if (kIsWeb) startAlarm();
    setState(() {
      _isAlarmRinging = true;
    });
    ToastHelper.showSuccess(context, '⏰ Alarm is ringing! Good morning.');
  }

  void _dismissAlarm() {
    if (kIsWeb) stopAlarm();
    setState(() {
      _isAlarmRinging = false;
    });
    _wakeUp();
  }

  void _snoozeAlarm() {
    if (kIsWeb) stopAlarm();
    setState(() {
      _isAlarmRinging = false;
    });
    ToastHelper.showInfo(context, 'Alarm snoozed for 5 minutes.');
  }

  void _startBreathingGuide() {
    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    int secondsCounter = 0;
    _breathingPhaseTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      secondsCounter += 4;
      setState(() {
        if (secondsCounter % 12 == 4) {
          _breathingPhase = "Hold";
        } else if (secondsCounter % 12 == 8) {
          _breathingPhase = "Exhale";
        } else {
          _breathingPhase = "Inhale";
        }
      });
    });
  }

  void _changeSound(String type) {
    if (_selectedSound == type) {
      if (kIsWeb) stopAudio();
      setState(() {
        _selectedSound = 'none';
      });
    } else {
      if (kIsWeb) {
        startAudio(type);
        setAudioVolume(_volume);
      }
      setState(() {
        _selectedSound = type;
      });
    }
  }

  void _setVolume(double val) {
    if (kIsWeb) setAudioVolume(val);
    setState(() {
      _volume = val;
    });
  }



  void _showSoundsPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CHOOSE SLEEP SOUNDSCAPE',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _modalSoundCircle(Icons.volume_off_rounded, 'Silence', 'none'),
                      _modalSoundCircle(Icons.grain_rounded, 'Rain', 'rain'),
                      _modalSoundCircle(Icons.water_rounded, 'Ocean', 'waves'),
                      _modalSoundCircle(Icons.spa_rounded, 'Zen Drone', 'bell'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.volume_down_rounded, color: Colors.white60, size: 18),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          activeColor: AppTheme.accent,
                          inactiveColor: Colors.white12,
                          onChanged: (val) {
                            setModalState(() {
                              _setVolume(val);
                            });
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up_rounded, color: Colors.white60, size: 18),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _modalSoundCircle(IconData icon, String label, String type) {
    final bool isSelected = _selectedSound == type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            _changeSound(type);
            Navigator.pop(context);
            setState(() {});
          },
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: isSelected ? AppTheme.accent : Colors.white12,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? AppTheme.accent : Colors.white70,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppTheme.accent : Colors.white54,
          ),
        ),
      ],
    );
  }

  Future<void> _wakeUp() async {
    if (_sleepStartTime == null) return;
    
    // Stop any active sound/alarm
    if (kIsWeb) {
      stopAudio();
      stopAlarm();
    }
    
    final elapsedSession = DateTime.now().difference(_sleepStartTime!);
    final double hoursSlept = elapsedSession.inSeconds / 3600.0;

    final prefs = await SharedPreferences.getInstance();

    final String bedTimeStr = DateFormat('HH:mm').format(_sleepStartTime!);
    final String wakeTimeStr = DateFormat('HH:mm').format(DateTime.now());
    
    final int hours = elapsedSession.inHours;
    final int minutes = elapsedSession.inMinutes.remainder(60);
    
    final int totalMins = elapsedSession.inMinutes;
    final int fellAsleepMin = totalMins <= 0
        ? 0
        : (totalMins > 20
            ? (10 + (elapsedSession.inSeconds % 6))
            : (totalMins * 0.15).round().clamp(1, totalMins));
    final double deepSleepFraction = 0.25 + (elapsedSession.inSeconds % 12) / 100.0;
    final int deepSleepMinTotal = (elapsedSession.inMinutes * deepSleepFraction).round();
    final int deepHours = deepSleepMinTotal ~/ 60;
    final int deepMins = deepSleepMinTotal % 60;

    int score = 82;
    int xpEarned = 0;
    if (hoursSlept < 0.08) { // Less than 5 mins (e.g. testing)
      score = (hoursSlept * 800).round().clamp(10, 45);
      xpEarned = -20;
    } else if (hoursSlept < 1.0) { // Less than 1 hour
      score = 30;
      xpEarned = -15;
    } else if (hoursSlept >= 7.0 && hoursSlept <= 9.0) {
      score += 12;
      xpEarned = score * 2;
    } else if (hoursSlept < 6.0) {
      score -= 15;
      xpEarned = -10;
    } else {
      xpEarned = (score * 1.5).round();
    }
    score += (elapsedSession.inSeconds % 5);
    score = score.clamp(10, 98);

    try {
      // Load existing cloud profile or build a fresh one from local onboarding data
      UserProfile? user;
      try {
        user = await DartStreamManager.loadUserData();
      } catch (_) {}

      if (user == null) {
        // First save ever — build profile from SharedPreferences onboarding data
        final name = prefs.getString('user_name') ?? 'Sleeper';
        final email = prefs.getString('ds_email') ?? '';
        final age = prefs.getInt('user_age') ?? 25;
        user = UserProfile(name: name, email: email, age: age);
      }

      final newSession = SleepSession(
        bedTime: _sleepStartTime!,
        wakeTime: DateTime.now(),
        hoursSlept: hoursSlept,
        xpEarned: xpEarned,
        quality: score,
      );
      user.sessions.add(newSession);
      user.totalXp += newSession.xpEarned;
      user.totalXp = user.totalXp.clamp(0, 999999);
      user.level = (user.totalXp ~/ 300) + 1;
      user.level = user.level.clamp(1, 99);
      await DartStreamManager.saveUserData(user);
      debugPrint('✅ Cloud save success: level=${user.level} xp=${user.totalXp}');
    } catch (e) {
      debugPrint('❌ Cloud save error: $e');
    }

    await prefs.setBool('session_just_completed', true);
    await prefs.setDouble('last_session_hours', hoursSlept);
    await prefs.setString('last_session_start_time', _sleepStartTime!.toIso8601String());

    await prefs.setBool('is_sleeping', false);
    await prefs.remove('sleep_start_time');

    if (mounted) {
      setState(() {
        _sleptDurationLabel = '${hours}h ${minutes}m';
        _analysisQualityScore = score;
        _sleepStartTimeLabel = bedTimeStr;
        _sleepEndTimeLabel = wakeTimeStr;
        _analysisDeepSleepLabel = '${deepHours}h ${deepMins}m';
        _analysisFellAsleepLabel = '${fellAsleepMin}m';
        _showAnalysis = true;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _breathingPhaseTimer?.cancel();
    _breathingController.dispose();
    _waveController.dispose();
    if (kIsWeb) {
      stopAudio();
      stopAlarm();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _initAudioJs();
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF030712),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: _showAnalysis ? _buildAnalysisView() : _buildTrackingView(),
    );
  }

  Widget _buildTrackingView() {
    final durationStr = _formatDuration(_elapsed);
    final greetingName = _userProfile?.name ?? 'Lalit Devda';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF030712)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(), // Absolutely blocks viewport scrolling
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top controls dashboard (horizontally padded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800), // wider constraints for even spacing
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Centered Greeting Header
                          Center(
                            child: Text(
                              'Good night, $greetingName 🌙',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // 3 Action capsules row, evenly distributed
                          Row(
                            children: [
                              Expanded(
                                child: _actionTab(
                                  icon: Icons.alarm_rounded,
                                  label: 'Alarm 06:30',
                                  onTap: _triggerAlarm,
                                  color: AppTheme.accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _actionTab(
                                  icon: Icons.music_note_rounded,
                                  label: _selectedSound == 'none' ? 'Sounds' : _selectedSound.toUpperCase(),
                                  onTap: _showSoundsPicker,
                                  color: const Color(0xFF38BDF8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _actionTab(
                                  icon: Icons.spa_rounded,
                                  label: _showBreathingGuide ? 'Stop Breathe' : 'Breathe Helper',
                                  onTap: () {
                                    setState(() {
                                      _showBreathingGuide = !_showBreathingGuide;
                                    });
                                  },
                                  color: const Color(0xFF34D399),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Middle Section: Time & Glowing Moon (Spans 100% full screen width edge-to-edge)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      durationStr,
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          BoxShadow(
                            color: const Color(0xFF93C5FD).withValues(alpha: 0.15),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fixed height (220px) to prevent layout shifting
                    SizedBox(
                      height: 220,
                      child: _showBreathingGuide
                          ? Center(
                              child: AnimatedBuilder(
                                animation: _breathingAnimation,
                                builder: (context, child) {
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 130 * _breathingAnimation.value,
                                        height: 130 * _breathingAnimation.value,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              const Color(0xFF10B981).withValues(alpha: 0.12 * (1.6 - _breathingAnimation.value)),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 110 * _breathingAnimation.value,
                                        height: 110 * _breathingAnimation.value,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF0F172A), Color(0xFF022C22)],
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                _breathingPhase,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Follow Ring',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 8.5,
                                                  color: Colors.white38,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                // Waves exactly running through the vertical center of the moon
                                SizedBox(
                                  width: double.infinity,
                                  height: 180,
                                  child: AnimatedBuilder(
                                    animation: _waveController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        painter: WavePainter(_waveController.value, isPlaying: _selectedSound != 'none'),
                                      );
                                    },
                                  ),
                                ),
                                
                                // Lottie Moon overlay (Increased size to 190x190)
                                Container(
                                  width: 190,
                                  height: 190,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF93C5FD).withValues(alpha: 0.22),
                                        blurRadius: 48,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Lottie.asset(
                                    'assets/lottie/moon.json',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Amplifiers Sound wave visualizer bars placed directly below the Moon
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return _buildAmplifierVisualizer();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // Bottom Area: Centered Wake Up Button (horizontally padded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: _wakeUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                              side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Wake Up',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionTab({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmplifierVisualizer() {
    final bool isPlaying = _selectedSound != 'none';
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(10, (index) {
          // Compute bouncing dynamic heights
          final double speedMultiplier = isPlaying ? 2.5 : 0.0;
          final double waveVal = _waveController.value * 2 * math.pi * speedMultiplier;
          final double factor = isPlaying 
              ? 0.2 + 0.8 * math.sin(waveVal + index * 0.7).abs() 
              : 0.15; // flat line if silenced
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 40),
            width: 3.5,
            height: isPlaying ? (20 * factor).clamp(4.0, 20.0) : 4.0,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isPlaying ? AppTheme.accent : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAlarmOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.alarm_on_rounded, size: 48, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(height: 24),
              Text(
                '06:30 AM',
                style: GoogleFonts.outfit(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Good Morning! Time to wake up.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _dismissAlarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Dismiss & Check Stats',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _snoozeAlarm,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Snooze 5m',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildAnalysisView() {
    final todayStr = DateFormat('MMMM d, y').format(DateTime.now());

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF061021),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  children: [
                    // Title Header
                    Text(
                      'Sleep Analysis',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      todayStr,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // Neon Green circular quality ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                blurRadius: 24,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: CircularProgressIndicator(
                            value: _analysisQualityScore / 100.0,
                            strokeWidth: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Quality',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                color: Colors.white38,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$_analysisQualityScore',
                                  style: GoogleFonts.outfit(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '%',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Sleep Duration display
                    Text(
                      _sleptDurationLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Sleep Duration',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.trending_up_rounded, color: Color(0xFF34D399), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Slightly better than yesterday',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: const Color(0xFF34D399),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Dark rounded sleep details panel at bottom
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sleep Information',
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                context.go('/dashboard');
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    Text(
                                      'See Graph',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF38BDF8),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.show_chart_rounded, size: 14, color: Color(0xFF38BDF8)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Grid details
                        Row(
                          children: [
                            Expanded(
                              child: _infoRow(Icons.nightlight_round, 'Went to sleep', _sleepStartTimeLabel, const Color(0xFF818CF8)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _infoRow(Icons.wb_sunny_rounded, 'Woke up', _sleepEndTimeLabel, const Color(0xFFFBBF24)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _infoRow(Icons.access_time_rounded, 'Fell asleep', _analysisFellAsleepLabel, const Color(0xFFC084FC)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _infoRow(Icons.cloud_outlined, 'Deep sleep', _analysisDeepSleepLabel, const Color(0xFF34D399)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Back to Home Button
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () {
                              context.go('/dashboard');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(23),
                              ),
                            ),
                            child: Text(
                              'Back to Home',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String val, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                val,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animValue;
  final bool isPlaying;
  WavePainter(this.animValue, {required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path1 = Path();
    final path2 = Path();

    final yCenter = size.height / 2;
    final double amp = isPlaying ? 24.0 : 12.0;
    
    path1.moveTo(0, yCenter);
    path2.moveTo(0, yCenter);

    for (double x = 0; x <= size.width; x++) {
      final relX = x / size.width;
      final y1 = yCenter + amp * math.sin(relX * 2 * math.pi * 1.5 + animValue * 2 * math.pi);
      final y2 = yCenter + (amp * 0.7) * math.sin(relX * 2 * math.pi * 1.2 - animValue * 2 * math.pi + math.pi / 2);
      
      path1.lineTo(x, y1);
      path2.lineTo(x, y2);
    }

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animValue != animValue || oldDelegate.isPlaying != isPlaying;
  }
}
