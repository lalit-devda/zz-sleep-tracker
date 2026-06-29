import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../theme/app_theme.dart';
import '../widgets/plant_widget.dart';
import '../utils/app_state.dart';

import '../utils/location_helper.dart';
import '../models/sleep_model.dart';
import '../utils/dartstream_manager.dart';
import '../utils/toast_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static String? _cachedLocation;
  static String? _cachedTimezone;
  static String? _cachedTemperature;
  static String? _cachedWeather;
  static String? _cachedMinTemp;
  static String? _cachedMaxTemp;
  static String? _cachedTempMorning;
  static String? _cachedTempAfternoon;
  static String? _cachedTempEvening;
  static String? _cachedTempNight;
  static DateTime? _lastFetchTime;

  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  bool _isSleeping = false;
  bool _isFetchingWeather = false;

  // Track weather: sun, moon, cloud, rain
  String _selectedWeather = 'sun';
  String _location = 'New Delhi, India';
  String _timezone = 'Asia/Kolkata (GMT+5:30)';
  String _temperature = '25°C';

  String _minTemp = '20°C';
  String _maxTemp = '30°C';
  String _tempMorning = '20°';
  String _tempAfternoon = '24°';
  String _tempEvening = '28°';
  String _tempNight = '22°';

  DateTime? _sleepStartTime;
  DateTime? _simulatedTime;
  bool _hasTriggeredMissedSleepPenalty = false;
  bool _hasTriggeredMissedWakeupPenalty = false;

  DateTime get _effectiveTime => _simulatedTime ?? _now;

  late UserProfile _user;
  final ScrollController _scrollController = ScrollController();

  bool _sleepTrackingEnabled = true;
  bool _xpRewardsEnabled = true;
  bool _plantGrowthEnabled = true;


  String _greetingMessage() {
    final hour = _effectiveTime.hour;
    final name = _user.name.split(' ').first;
    if (hour >= 5 && hour < 12) {
      return 'Hi $name, Good morning! ☀️';
    } else if (hour >= 12 && hour < 17) {
      return 'Hi $name, Good afternoon! 🌤️';
    } else if (hour >= 17 && hour < 21) {
      return 'Hi $name, Good evening! 🌆';
    } else {
      return 'Hi $name, Good night! 🌙';
    }
  }

  @override
  void initState() {
    super.initState();
    // onUnauthorized is registered globally in main.dart using _router.go('/login')
    // so it works from any screen (home, history, profile, sleep-session)

    _user = DartStreamManager.cachedUserProfile ?? UserProfile(
      name: 'Lalit Devda',
      email: 'lalit@example.com',
      age: 25,
      totalXp: 0,
      level: 1,
      sessions: [],
    );
    _loadOnboardingData();
    _fetchFeatureFlags();
    final hr = DateTime.now().hour;
    _selectedWeather = (hr < 6 || hr >= 18) ? 'moon' : 'sun';
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
      _checkPunctualityTriggers();
    });
    _fetchLocationAndWeather();
  }

  Future<void> _loadOnboardingData() async {
    // Guard: if there's no active DartStream connection, go back to login
    if (!DartStreamManager.isLoggedIn) {
      if (mounted) context.go('/login');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // Check if user is currently sleeping (forces redirect)
    final isSleeping = prefs.getBool('is_sleeping') ?? false;
    if (isSleeping && mounted) {
      context.go('/sleep-session');
      return;
    }

    // Use cache immediately — never block UI
    if (DartStreamManager.cachedUserProfile != null) {
      setState(() {
        _user = DartStreamManager.cachedUserProfile!;
      });
    }

    // Fetch dynamic profile from DartStream in the background
    UserProfile? dsProfile;
    try {
      dsProfile = await DartStreamManager.loadUserData();
    } catch (_) {
      if (!DartStreamManager.isLoggedIn) return;
    }

    if (dsProfile != null) {
      if (mounted) {
        setState(() {
          _user = dsProfile!;
        });
      }
      // Sync local caches
      await prefs.setString('user_name', _user.name);
      await prefs.setInt('user_age', _user.age);
    } else {
      if (mounted) {
        setState(() {
        });
      }
      // Check if they completed onboarding locally but failed to save on server
      final hasCompleted = prefs.getBool('has_completed_onboarding') ?? false;
      if (!hasCompleted && mounted) {
        context.go('/onboarding');
        return;
      }
      final cachedName = prefs.getString('user_name');
      final cachedAge = prefs.getInt('user_age');
      if (cachedName != null && cachedAge != null) {
        setState(() {
          _user = UserProfile(
            name: cachedName,
            email: DartStreamManager.connection?.session.email ?? _user.email,
            age: cachedAge,
            totalXp: _user.totalXp,
            level: _user.level,
            sessions: _user.sessions,
          );
        });
      }
    }

    // Check if a sleep session was completed and needs scoring
    final completed = prefs.getBool('session_just_completed') ?? false;
    if (completed) {
      final lastHours = prefs.getDouble('last_session_hours') ?? 0.0;
      final lastStartStr = prefs.getString('last_session_start_time');

      // Clear flag and cached values first
      await prefs.setBool('session_just_completed', false);
      await prefs.remove('last_session_hours');
      await prefs.remove('last_session_start_time');

      if (lastStartStr != null) {
        _sleepStartTime = DateTime.parse(lastStartStr);
        // Call log session to calculate scorecard and trigger scorecard dialog
        _logSleepSession(lastHours);
      }
    }

    setState(() {
    });
  }

  Future<void> _fetchFeatureFlags() async {
    final connection = DartStreamManager.connection;
    if (connection == null) return;
    try {
      final flags = await connection.platform.featureFlags.list();
      setState(() {
        _sleepTrackingEnabled = flags
            .firstWhere(
              (f) => f.key == 'sleep_tracking_enabled',
              orElse: () =>
                  FeatureFlag(key: 'sleep_tracking_enabled', enabled: true),
            )
            .enabled;
        _xpRewardsEnabled = flags
            .firstWhere(
              (f) => f.key == 'xp_rewards_enabled',
              orElse: () =>
                  FeatureFlag(key: 'xp_rewards_enabled', enabled: true),
            )
            .enabled;
        _plantGrowthEnabled = flags
            .firstWhere(
              (f) => f.key == 'plant_growth_enabled',
              orElse: () =>
                  FeatureFlag(key: 'plant_growth_enabled', enabled: true),
            )
            .enabled;
      });
    } catch (_) {
      // Fallbacks remain true
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String get _timeString {
    final h = _effectiveTime.hour.toString().padLeft(2, '0');
    final m = _effectiveTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get _amPm => '';

  // Live Location and Weather Fetch
  // final nowTime = DateTime.now();
  Future<void> _fetchLocationAndWeather() async {
    if (_isFetchingWeather) return;

    final nowTime = DateTime.now();
    if (_lastFetchTime != null &&
        nowTime.difference(_lastFetchTime!).inMinutes < 15 &&
        _cachedLocation != null) {
      if (mounted) {
        setState(() {
          _location = _cachedLocation!;
          _timezone = _cachedTimezone ?? _timezone;
          _temperature = _cachedTemperature ?? _temperature;
          _selectedWeather = _cachedWeather ?? _selectedWeather;
          _minTemp = _cachedMinTemp ?? _minTemp;
          _maxTemp = _cachedMaxTemp ?? _maxTemp;
          _tempMorning = _cachedTempMorning ?? _tempMorning;
          _tempAfternoon = _cachedTempAfternoon ?? _tempAfternoon;
          _tempEvening = _cachedTempEvening ?? _tempEvening;
          _tempNight = _cachedTempNight ?? _tempNight;
          _isFetchingWeather = false;
        });
        AppState.location.value = _location;
        AppState.timezone.value = _timezone;
      }
      return;
    }

    setState(() => _isFetchingWeather = true);

    try {
      double lat = 28.61;
      double lon = 77.20;
      String city = 'New Delhi';
      String country = 'India';
      String timezoneDisplay = 'Asia/Kolkata (GMT+5:30)';
      bool resolved = false;

      // 1. Try to get browser location coordinates
      final Map<String, double>? coords = await getBrowserLocation().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );

      if (coords != null) {
        // 2. If coordinates are found, reverse geocode using BigDataCloud free client geocoder
        final revGeocodeUrl =
            'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${coords['latitude']}&longitude=${coords['longitude']}&localityLanguage=en';
        final revResponse = await http
            .get(Uri.parse(revGeocodeUrl))
            .timeout(const Duration(seconds: 5));

        if (revResponse.statusCode == 200) {
          final revData = jsonDecode(revResponse.body);
          city = revData['city'] ?? revData['locality'] ?? 'Unknown City';
          country = revData['countryName'] ?? '';
          lat = coords['latitude']!;
          lon = coords['longitude']!;
          resolved = true;
        }
      }

      if (!resolved) {
        // Fallback to IP detection (ipapi.co/json/)
        final ipResponse = await http
            .get(Uri.parse('https://ipapi.co/json/'))
            .timeout(const Duration(seconds: 6));
        if (ipResponse.statusCode == 200) {
          final ipData = jsonDecode(ipResponse.body);
          city = ipData['city'] ?? 'New Delhi';
          country = ipData['country_name'] ?? 'India';
          lat = (ipData['latitude'] as num?)?.toDouble() ?? 28.61;
          lon = (ipData['longitude'] as num?)?.toDouble() ?? 77.20;
          final String tz = ipData['timezone'] ?? 'Asia/Kolkata';
          timezoneDisplay = '$tz (GMT${_formatOffset(ipData['utc_offset'])})';
        }
      }

      final weatherResponse = await http
          .get(
            Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&hourly=temperature_2m&daily=temperature_2m_max,temperature_2m_min&timezone=auto',
            ),
          )
          .timeout(const Duration(seconds: 6));

      if (weatherResponse.statusCode == 200) {
        final weatherData = jsonDecode(weatherResponse.body);
        final current = weatherData['current_weather'];
        final double temp =
            (current['temperature'] as num?)?.toDouble() ?? 25.0;
        final int code = (current['weathercode'] as num?)?.toInt() ?? 0;

        if (resolved) {
          final tzName = weatherData['timezone'] ?? 'Asia/Kolkata';
          final tzAbbrev = weatherData['timezone_abbreviation'] ?? 'GMT';
          timezoneDisplay = '$tzName ($tzAbbrev)';
        }

        // Cache timezone for other pages
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_timezone', timezoneDisplay);

        // Parse daily min/max
        String minT = '20°C';
        String maxT = '30°C';
        if (weatherData['daily'] != null) {
          final daily = weatherData['daily'];
          final minVal = daily['temperature_2m_min']?[0];
          final maxVal = daily['temperature_2m_max']?[0];
          if (minVal != null) minT = '${(minVal as num).toStringAsFixed(0)}°C';
          if (maxVal != null) maxT = '${(maxVal as num).toStringAsFixed(0)}°C';
        }

        // Parse hourly temperatures
        String tempM = '20°';
        String tempA = '24°';
        String tempE = '28°';
        String tempN = '22°';
        if (weatherData['hourly'] != null) {
          final hourly = weatherData['hourly'];
          final temps = hourly['temperature_2m'] as List<dynamic>?;
          if (temps != null && temps.length >= 24) {
            tempM = '${(temps[8] as num).toStringAsFixed(0)}°';
            tempA = '${(temps[14] as num).toStringAsFixed(0)}°';
            tempE = '${(temps[18] as num).toStringAsFixed(0)}°';
            tempN = '${(temps[22] as num).toStringAsFixed(0)}°';
          }
        }

        String mappedWeather = 'sun';
        if (code >= 51) {
          mappedWeather = 'rain';
        } else if (code >= 1 && code <= 48) {
          mappedWeather = 'cloud';
        } else {
          final hr = DateTime.now().hour;
          mappedWeather = (hr < 6 || hr >= 18) ? 'moon' : 'sun';
        }

        if (mounted) {
          setState(() {
            _location = country.isEmpty ? city : '$city, $country';
            _timezone = timezoneDisplay;
            _temperature = '${temp.toStringAsFixed(0)}°C';
            _selectedWeather = mappedWeather;
            _minTemp = minT;
            _maxTemp = maxT;
            _tempMorning = tempM;
            _tempAfternoon = tempA;
            _tempEvening = tempE;
            _tempNight = tempN;
            _isFetchingWeather = false;

            // Save to static cache variables
            _cachedLocation = _location;
            _cachedTimezone = _timezone;
            _cachedTemperature = _temperature;
            _selectedWeather = _selectedWeather;
            _cachedMinTemp = _minTemp;
            _cachedMaxTemp = _maxTemp;
            _cachedTempMorning = _tempMorning;
            _cachedTempAfternoon = _tempAfternoon;
            _cachedTempEvening = _tempEvening;
            _cachedTempNight = _tempNight;
            _lastFetchTime = DateTime.now();
          });
          AppState.location.value = _location;
          AppState.timezone.value = _timezone;
        }
        return;
      }
    } catch (e) {
      debugPrint('Error loading location/weather: $e');
    }
    if (mounted) {
      setState(() => _isFetchingWeather = false);
    }
  }

  String _formatOffset(dynamic offset) {
    if (offset == null) return '+5:30';
    final offsetStr = offset.toString();
    if (!offsetStr.startsWith('+') && !offsetStr.startsWith('-')) {
      return '+$offsetStr';
    }
    return offsetStr;
  }

  void _toggleSleep() {
    if (!_sleepTrackingEnabled) {
      ToastHelper.showWarning(
        context,
        'Sleep tracking is temporarily disabled.',
      );
      return;
    }

    final now = DateTime.now();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('is_sleeping', true);
      prefs.setString('sleep_start_time', now.toIso8601String());

      // Track sleep started event (snake_case payload keys required)
      DartStreamManager.trackEvent('sleep_session_started', {
        'bed_time': now.toIso8601String(),
        'user_id': DartStreamManager.connection?.session.userId ?? '',
      });

      if (mounted) {
        context.go('/sleep-session');
      }
    });
  }

  void _logSleepSession(double hours) {
    // Track sleep ended event (snake_case payload keys required)
    DartStreamManager.trackEvent('sleep_session_ended', {
      'wake_time': DateTime.now().toIso8601String(),
      'hours_slept': hours,
      'user_id': DartStreamManager.connection?.session.userId ?? '',
    });

    if (hours < 0.5) {
      setState(() {
        _isSleeping = false;
        _selectedWeather = 'sun';
        _sleepStartTime = null;
      });
      ToastHelper.showWarning(
        context,
        'Sleep too short to score — minimum 30 minutes',
      );
      return;
    }

    final minH = _user.minOptimalHours;
    final maxH = _user.maxOptimalHours;

    final String hoursStr = hours.toStringAsFixed(2);

    // 1. Sleep Duration Score
    int durationXp = 0;
    String durationLabel = '';
    Color durationColor = Colors.green;
    if (hours < 1.0) {
      durationXp = -30;
      durationLabel = 'Extremely under-slept ($hoursStr hours)';
      durationColor = Colors.red;
    } else if (hours >= minH && hours <= maxH) {
      durationXp = 40;
      durationLabel = 'Optimal Rest ($hoursStr hours)';
      durationColor = Colors.green;
    } else if (hours < minH) {
      durationXp = 10;
      durationLabel = 'Under-slept ($hoursStr hours)';
      durationColor = Colors.orange;
    } else {
      durationXp = -15;
      durationLabel = 'Overslept ($hoursStr hours)';
      durationColor = Colors.red;
    }

    String formatOffset(int totalMins) {
      final int absMins = totalMins.abs();
      final int h = absMins ~/ 60;
      final int m = absMins % 60;
      if (h > 0) {
        return '${h}h ${m}m';
      }
      return '${m}m';
    }

    // 2. Bedtime Goal Punctuality Score (Target: _bedTimeGoalHour)
    final sleepStart = _sleepStartTime ?? _effectiveTime;
    final int actualBedtimeMinutes = sleepStart.hour * 60 + sleepStart.minute;
    final int targetBedtimeMinutes = (_bedTimeGoalHour * 60).round();
    final int diffBedtime = _getMinutesDiff(
      actualBedtimeMinutes,
      targetBedtimeMinutes,
    );

    int bedtimeXp = 0;
    String bedtimeLabel = '';
    Color bedtimeColor = Colors.green;

    if (diffBedtime >= -3 && diffBedtime <= 5) {
      bedtimeXp = 10;
      bedtimeColor = Colors.green;
      if (diffBedtime == 0) {
        bedtimeLabel = 'Bedtime: Perfect on time';
      } else {
        bedtimeLabel =
            'Bedtime: On time (${formatOffset(diffBedtime)} ${diffBedtime > 0 ? "late" : "early"})';
      }
    } else {
      if (diffBedtime < -3) {
        bedtimeXp = -15;
        bedtimeColor = Colors.red;
        bedtimeLabel =
            'Bedtime: Too early (${formatOffset(diffBedtime)} remaining)';
      } else {
        final int minsPastWindow = diffBedtime - 5;
        final int additionalPenalty = (minsPastWindow / 10).floor() * 5;
        bedtimeXp = -15 - additionalPenalty;
        if (bedtimeXp < -40) bedtimeXp = -40;
        bedtimeColor = Colors.red;
        bedtimeLabel = 'Bedtime: Too late (${formatOffset(diffBedtime)} late)';
      }
    }

    // 3. Wake Up Punctuality Score (Target: 06:30 = 390 minutes)
    final wakeNow = (_sleepStartTime ?? DateTime.now()).add(
      Duration(seconds: (hours * 3600).round()),
    );
    final int actualWakeupMinutes = wakeNow.hour * 60 + wakeNow.minute;
    final int targetWakeupMinutes = 390; // 06:30
    final int diffWakeup = _getMinutesDiff(
      actualWakeupMinutes,
      targetWakeupMinutes,
    );

    int wakeupXp = 0;
    String wakeupLabel = '';
    Color wakeupColor = Colors.green;

    if (diffWakeup >= 0 && diffWakeup <= 5) {
      wakeupXp = 10;
      wakeupColor = Colors.green;
      if (diffWakeup == 0) {
        wakeupLabel = 'Wakeup: Perfect on time';
      } else {
        wakeupLabel = 'Wakeup: On schedule (+${formatOffset(diffWakeup)} late)';
      }
    } else {
      if (diffWakeup < 0) {
        wakeupXp = -15;
        wakeupColor = Colors.red;
        wakeupLabel = 'Wakeup: Too early (${formatOffset(diffWakeup)} early)';
      } else {
        final int minsPastWindow = diffWakeup - 5;
        final int additionalPenalty = (minsPastWindow / 10).floor() * 5;
        wakeupXp = -15 - additionalPenalty;
        if (wakeupXp < -40) wakeupXp = -40;
        wakeupColor = Colors.red;
        wakeupLabel = 'Wakeup: Late (${formatOffset(diffWakeup)} past 06:35)';
      }
    }

    int netXp = durationXp + bedtimeXp + wakeupXp;
    if (!_xpRewardsEnabled) {
      netXp = 0;
      durationXp = 0;
      bedtimeXp = 0;
      wakeupXp = 0;
    }

    final bool isOverallPositive = netXp >= 0;

    // Track dynamic events (checklist requires amount + total keys)
    if (netXp != 0) {
      DartStreamManager.trackEvent('xp_earned', {
        'amount': netXp,
        'total': _user.totalXp + netXp,
        'user_id': DartStreamManager.connection?.session.userId ?? '',
      });
    }

    final newSession = SleepSession(
      bedTime: sleepStart,
      wakeTime: wakeNow,
      hoursSlept: hours,
      xpEarned: netXp,
      quality: netXp >= 40
          ? 5
          : (netXp >= 20 ? 4 : (netXp >= 0 ? 3 : (netXp >= -20 ? 2 : 1))),
    );

    setState(() {
      _isSleeping = false;
      _selectedWeather = 'sun';
      _sleepStartTime = null;

      // Update XP & level bounds
      _user.sessions.add(newSession);
      _user.totalXp += netXp;
      if (_user.totalXp < 0) _user.totalXp = 0;

      final int oldLevel = _user.level;
      _user.level = (_user.totalXp ~/ 300) + 1;
      _user.level = _user.level.clamp(1, 99);
      if (_user.level > oldLevel) {
        DartStreamManager.trackEvent('level_up', {'new_level': _user.level});
      }
    });

    // Save updated UserProfile to cloud save
    DartStreamManager.saveUserData(_user);

    // Show beautiful Scorecard Dialog!
    _showScorecardDialog(
      durationLabel: durationLabel,
      durationXp: durationXp,
      durationColor: durationColor,
      bedtimeLabel: bedtimeLabel,
      bedtimeXp: bedtimeXp,
      bedtimeColor: bedtimeColor,
      wakeupLabel: wakeupLabel,
      wakeupXp: wakeupXp,
      wakeupColor: wakeupColor,
      netXp: netXp,
      isOverallPositive: isOverallPositive,
    );
  }

  void _showScorecardDialog({
    required String durationLabel,
    required int durationXp,
    required Color durationColor,
    required String bedtimeLabel,
    required int bedtimeXp,
    required Color bedtimeColor,
    required String wakeupLabel,
    required int wakeupXp,
    required Color wakeupColor,
    required int netXp,
    required bool isOverallPositive,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final overallColor = isOverallPositive ? Colors.green : Colors.red;
        final overallIcon = isOverallPositive
            ? Icons.emoji_events_outlined
            : Icons.report_problem_outlined;

        return Dialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(overallIcon, color: overallColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Sleep Scorecard',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Scorecard Rows
                _scorecardRow(durationLabel, durationXp, durationColor),
                const SizedBox(height: 12),
                _scorecardRow(bedtimeLabel, bedtimeXp, bedtimeColor),
                const SizedBox(height: 12),
                _scorecardRow(wakeupLabel, wakeupXp, wakeupColor),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Net Result
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net XP Change:',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      netXp >= 0 ? '+$netXp XP' : '$netXp XP',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: overallColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    isOverallPositive
                        ? 'Excellent rest!'
                        : 'Let\'s improve tomorrow',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scorecardRow(String label, int xp, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Text(
          xp >= 0 ? '+$xp XP' : '$xp XP',
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String get _weatherDesc {
    final bool isNight = _effectiveTime.hour >= 18 || _effectiveTime.hour < 6;
    if (isNight) {
      return _selectedWeather == 'cloud'
          ? 'Cloudy Night'
          : (_selectedWeather == 'rain' ? 'Rainy Night' : 'Clear Night');
    }
    switch (_selectedWeather) {
      case 'sun':
        return 'Mostly Sunny';
      case 'cloud':
        return 'Partly Cloudy';
      case 'rain':
        return 'Light Showers';
      case 'moon':
      default:
        return 'Clear Day';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final int currentHour = _effectiveTime.hour;
    final bool isNightSky = currentHour >= 18 || currentHour < 6;

    String weatherAsset;
    final weatherDesc = _weatherDesc;
    if (_selectedWeather == 'rain') {
      weatherAsset = 'assets/lottie/rainy.json';
    } else if (_selectedWeather == 'cloud') {
      weatherAsset = 'assets/lottie/cloud.json';
    } else {
      if (isNightSky) {
        weatherAsset = 'assets/lottie/moon.json';
      } else {
        weatherAsset = 'assets/lottie/clear_day.json';
      }
    }



    // Standardized heights: Top row larger (290), bottom row set to clean fixed 210
    const double topCardHeight = 290.0;
    const double bottomCardHeight = 210.0;

    // Desktop Layout (Top: 2 equal cards, Bottom: 3 equal cards)
    Widget mainContent = isDesktop
        ? Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. TOP ROW: 2 Cards (Weather & Plant Growth)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildPrimaryWeatherCard(
                        weatherAsset,
                        weatherDesc,
                        topCardHeight,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildPlantGrowthCard(isNightSky, topCardHeight),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. BOTTOM ROW: 3 Columns
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1 (Left): Sleep Zones Weather
                    Expanded(child: _buildCitiesWeatherCard(bottomCardHeight)),
                    const SizedBox(width: 20),

                    // Column 2 (Center): Timeline Temp Card
                    Expanded(
                      child: _buildTemperatureProgressionCard(bottomCardHeight),
                    ),
                    const SizedBox(width: 20),

                    // Column 3 (Right): Sleep Controls Card
                    Expanded(child: _buildSleepControlsCard(bottomCardHeight)),
                  ],
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greetingMessage(),
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          color: isNightSky ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        "Let's track your sleep sanctuary today.",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: isNightSky ? Colors.white60 : AppTheme.textSecondary,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSleepControlsCard(bottomCardHeight),
                const SizedBox(height: 16),
                _buildPrimaryWeatherCard(
                  weatherAsset,
                  weatherDesc,
                  topCardHeight,
                ),
                const SizedBox(height: 16),
                _buildPlantGrowthCard(isNightSky, topCardHeight),
                const SizedBox(height: 16),
                _buildTemperatureProgressionCard(bottomCardHeight),
                const SizedBox(height: 16),
                _buildCitiesWeatherCard(bottomCardHeight),
              ],
            ),
          );

    // ignore: unused_local_variable
    final simulatorBar = Container(
      decoration: BoxDecoration(
        color: isNightSky ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isNightSky
                ? const Color(0xFF1E293B)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'DEBUG TIME SIMULATOR:',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isNightSky ? Colors.white70 : AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 12),
            _simulatorBtn('Real Time', null),
            _simulatorBtn('10:28 PM', DateTime(2026, 6, 28, 22, 28)),
            _simulatorBtn('10:45 PM', DateTime(2026, 6, 28, 22, 45)),
            _simulatorBtn('11:15 PM', DateTime(2026, 6, 28, 23, 15)),
            _simulatorBtn('06:32 AM', DateTime(2026, 6, 29, 6, 32)),
            _simulatorBtn('06:45 AM', DateTime(2026, 6, 29, 6, 45)),
            _simulatorBtn('12:05 PM (Noon)', DateTime(2026, 6, 29, 12, 5)),
          ],
        ),
      ),
    );


    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // simulatorBar, // Commented out debug time simulator bar from rendering
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thickness: 3.5,
            radius: const Radius.circular(8),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: mainContent,
            ),
          ),
        ),
      ],
    );
  }

  // --- DYNAMIC CARD BUILDERS (NO FIXED HEIGHT  // 1. Primary Weather Card (Mockup Inspired)
  Widget _buildPrimaryWeatherCard(
    String weatherAsset,
    String weatherDesc,
    double height,
  ) {
    final bool isNight = _effectiveTime.hour >= 18 || _effectiveTime.hour < 6;

    final cardBorder = isNight
        ? const Color(0xFF1E2F52)
        : const Color(0xFFE2E8F0);
    final textPrimaryColor = isNight ? Colors.white : AppTheme.textPrimary;
    final textSecondaryColor = isNight
        ? Colors.white60
        : AppTheme.textSecondary;

    final List<Color> gradientColors = isNight
        ? [const Color(0xFF0D1527), const Color(0xFF162544)]
        : (_selectedWeather == 'sun'
              ? [const Color(0xFFEFF6FF), const Color(0xFFFEF3C7)]
              : _selectedWeather == 'cloud'
              ? [
                  const Color(0xFFE0F2FE),
                  const Color(0xFF7DD3FC),
                ] // Premium Sky Blue for contrast
              : [
                  const Color(0xFFE0F2FE),
                  const Color(0xFF99F6E4),
                ]); // Mint for rain/other

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            width: 110,
            height: 110,
            child: Lottie.asset(weatherAsset, fit: BoxFit.contain),
          ),

          // Weather Details
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: isNight ? Colors.white70 : AppTheme.accentDark,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _location,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        weatherDesc,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: textSecondaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isFetchingWeather)
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppTheme.accent,
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _fetchLocationAndWeather,
                          child: Icon(
                            Icons.sync_rounded,
                            size: 13,
                            color: isNight ? Colors.white54 : AppTheme.accent,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _temperature,
                    style: GoogleFonts.outfit(
                      fontSize: 52,
                      fontWeight: FontWeight.w300,
                      color: textPrimaryColor,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _weatherDetailChip('XP Boost', '1.5x', isNight),
                      const SizedBox(width: 8),
                      _weatherDetailChip('Humidity', '82%', isNight),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherDetailChip(String label, String val, bool isNight) {
    final cardBg = isNight ? Colors.white.withValues(alpha: 0.1) : Colors.white;
    final cardBorder = isNight ? Colors.white10 : const Color(0xFFE2E8F0);
    final textColor = isNight
        ? Colors.white.withValues(alpha: 0.8)
        : AppTheme.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Text(
        '$label: $val',
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
      ),
    );
  }

  // 2. Cuter Plant Growth Card (Gradients locked inside corners)
  Widget _buildPlantGrowthCard(bool isNightSky, double height) {
    final List<Color> cuteSkyGradient = isNightSky
        ? [const Color(0xFFE0E7FF), const Color(0xFF312E81)]
        : [const Color(0xFFEEF2FF), const Color(0xFFECFDF5)];

    final cardBg = isNightSky ? const Color(0xFF0D1527) : Colors.white;
    final cardBorder = isNightSky
        ? const Color(0xFF1E2F52)
        : const Color(0xFFE2E8F0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: cuteSkyGradient,
                  ),
                ),
              ),
            ),

            // Curved soft mint green hill at bottom
            Positioned(
              bottom: 0,
              left: -50,
              right: -50,
              height: 110,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isNightSky
                        ? [const Color(0xFF14532D), const Color(0xFF064E3B)]
                        : [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(200),
                  ),
                ),
              ),
            ),

            // Plant seedling Lottie
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 32.0),
                child: PlantWidget(
                  stage: _plantGrowthEnabled ? _user.plantStage : 'seedling',
                  size: 165,
                ),
              ),
            ),

            // Time Display Overlay
            Positioned(
              top: 14,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _timeString,
                        style: GoogleFonts.outfit(
                          fontSize: 30,
                          fontWeight: FontWeight.w400,
                          color: isNightSky
                              ? Colors.white
                              : AppTheme.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _amPm,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: isNightSky
                              ? Colors.white70
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Active Stage Tag Overlay
            Positioned(
              top: 14,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isNightSky
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isNightSky
                        ? Colors.white10
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Lv.${_user.level} Seedling',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isNightSky
                        ? Colors.white.withOpacity(0.8)
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
            ),

            // Level Progress
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Growth XP',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                          color: isNightSky
                              ? Colors.white.withOpacity(0.8)
                              : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${_user.totalXp}/${_user.xpForNextLevel} XP',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isNightSky
                              ? Colors.white
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_user.totalXp / _user.xpForNextLevel).clamp(
                        0.0,
                        1.0,
                      ),
                      minHeight: 4,
                      backgroundColor: isNightSky
                          ? Colors.white24
                          : Colors.grey.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isNightSky ? Colors.white : AppTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _bedTimeGoalHour {
    final double avgHours =
        (_user.minOptimalHours + _user.maxOptimalHours) / 2.0;
    double wakeHour = 6.5; // 06:30
    double bedHour = wakeHour - avgHours;
    if (bedHour < 0) {
      bedHour += 24.0;
    }
    return bedHour;
  }

  String get _bedTimeGoalString {
    final double bedHour = _bedTimeGoalHour;
    int hour = bedHour.toInt();
    int minute = ((bedHour - hour) * 60).round();
    final minStr = minute.toString().padLeft(2, '0');
    final hrStr = hour.toString().padLeft(2, '0');
    return '$hrStr:$minStr';
  }

  String get _bedTimeGoalTimeOnly {
    return _bedTimeGoalString;
  }

  String get _bedTimeGoalAmPmOnly {
    return '';
  }

  int _getMinutesDiff(int actual, int target) {
    int diff = actual - target;
    if (diff > 720) diff -= 1440;
    if (diff < -720) diff += 1440;
    return diff;
  }

  // 3. Sleep Controls Card
  Widget _buildSleepControlsCard(double height) {
    Color btnColor = const Color(0xFF0F172A); // Default black slate
    String warningMsg = '';

    String formatOffset(int totalMins) {
      final int absMins = totalMins.abs();
      final int h = absMins ~/ 60;
      final int m = absMins % 60;
      if (h > 0) {
        return '${h}h ${m}m';
      }
      return '${m}m';
    }

    if (!_isSleeping) {
      final int targetMin = (_bedTimeGoalHour * 60).round();
      final int currentMin = _effectiveTime.hour * 60 + _effectiveTime.minute;
      final int diff = _getMinutesDiff(currentMin, targetMin);

      if (diff > 5) {
        final int minsPastWindow = diff - 5;
        final int additionalPenalty = (minsPastWindow / 10).floor() * 5;
        final int bedtimePenalty = -15 - additionalPenalty;
        final int maxClampedPenalty = bedtimePenalty.clamp(-40, -15);

        warningMsg =
            'Late by ${formatOffset(diff)}: $maxClampedPenalty XP if you sleep now!';

        if (diff <= 15) {
          btnColor = const Color(0xFFEA580C);
        } else if (diff <= 30) {
          btnColor = const Color(0xFFDC2626);
        } else {
          btnColor = const Color(0xFF991B1B);
        }
      } else if (diff < -3) {
        warningMsg =
            'Sleeping early (${formatOffset(diff)} remaining): -15 XP!';
        btnColor = const Color(0xFF64748B);
      } else {
        warningMsg = 'On schedule! +10 XP bedtime bonus.';
        btnColor = const Color(0xFF10B981);
      }
    } else {
      final int targetWakeupMinutes = 390; // 06:30 AM
      final int actualWakeupMinutes =
          _effectiveTime.hour * 60 + _effectiveTime.minute;
      final int diffWakeup = _getMinutesDiff(
        actualWakeupMinutes,
        targetWakeupMinutes,
      );

      if (diffWakeup > 5) {
        final int minsPastWindow = diffWakeup - 5;
        final int additionalPenalty = (minsPastWindow / 10).floor() * 5;
        final int wakeupPenalty = -15 - additionalPenalty;
        final int maxClampedPenalty = wakeupPenalty.clamp(-40, -15);

        warningMsg =
            'Late wakeup! (+${formatOffset(diffWakeup)}): $maxClampedPenalty XP!';
        btnColor = const Color(0xFF991B1B);
      } else if (diffWakeup < 0) {
        warningMsg =
            'Waking up early (${formatOffset(diffWakeup)} early): -15 XP!';
        btnColor = const Color(0xFF64748B);
      } else {
        warningMsg = 'On schedule! +10 XP wakeup bonus.';
        btnColor = const Color(0xFF10B981);
      }
    }

    final bool isNight = _effectiveTime.hour >= 18 || _effectiveTime.hour < 6;
    final cardBg = isNight ? const Color(0xFF0D1527) : Colors.white;
    final cardBorder = isNight
        ? const Color(0xFF1E2F52)
        : const Color(0xFFE2E8F0);
    final textPrimary = isNight ? Colors.white : AppTheme.textPrimary;
    final textSecondary = isNight ? Colors.white60 : AppTheme.textSecondary;
    final badgeBg = isNight ? const Color(0xFF1A263F) : const Color(0xFFF1F5F9);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bed Time Goal',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _bedTimeGoalTimeOnly,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _bedTimeGoalAmPmOnly,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'For ${_user.age}y (Target: 06:30)',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: textSecondary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: AppTheme.accent,
                  size: 18,
                ),
              ),
            ],
          ),

          if (warningMsg.isNotEmpty)
            Text(
              warningMsg,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: btnColor == const Color(0xFF0F172A)
                    ? textSecondary
                    : btnColor,
              ),
            ),

          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _toggleSleep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSleeping
                    ? (btnColor == const Color(0xFF10B981)
                          ? Colors.white
                          : btnColor.withOpacity(0.1))
                    : btnColor,
                foregroundColor: _isSleeping
                    ? (btnColor == const Color(0xFF10B981)
                          ? AppTheme.textPrimary
                          : btnColor)
                    : Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                side: _isSleeping
                    ? BorderSide(
                        color: btnColor == const Color(0xFF10B981)
                            ? const Color(0xFFE2E8F0)
                            : btnColor,
                        width: 1,
                      )
                    : BorderSide.none,
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSleeping ? Icons.wb_sunny : Icons.nights_stay_outlined,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    !_sleepTrackingEnabled
                        ? 'Sleep Tracking Disabled'
                        : (_isSleeping ? 'Wake Up & Log' : 'Go to Sleep Now'),
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Cities Weather Card
  Widget _buildCitiesWeatherCard(double height) {
    final bool isNight = _effectiveTime.hour >= 18 || _effectiveTime.hour < 6;
    final cardBg = isNight ? const Color(0xFF0D1527) : Colors.white;
    final cardBorder = isNight
        ? const Color(0xFF1E2F52)
        : const Color(0xFFE2E8F0);
    final textPrimary = isNight ? Colors.white : AppTheme.textPrimary;
    final dividerColor = isNight
        ? const Color(0xFF1E2F52)
        : const Color(0xFFE2E8F0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Sleep Zones Weather',
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
          _cityRow(
            '${_location.split(',')[0]} (Home)',
            _weatherDesc,
            '$_maxTemp / $_minTemp',
            _selectedWeather == 'sun'
                ? '☀️'
                : _selectedWeather == 'moon'
                ? '🌙'
                : _selectedWeather == 'rain'
                ? '🌧️'
                : '☁️',
            isNight,
          ),
          Divider(height: 1, color: dividerColor),
          _cityRow('Optimal Zone', 'Sleep Temp', '18°C / 16°C', '💤', isNight),
        ],
      ),
    );
  }

  Widget _cityRow(
    String city,
    String desc,
    String temp,
    String icon,
    bool isNight,
  ) {
    final textPrimary = isNight ? Colors.white : AppTheme.textPrimary;
    final textSecondary = isNight ? Colors.white60 : AppTheme.textSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: textSecondary,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
        Text(
          temp,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  // 5. "How is the temperature today?" Card
  Widget _buildTemperatureProgressionCard(double height) {
    final bool isNight = _effectiveTime.hour >= 18 || _effectiveTime.hour < 6;
    final cardBg = isNight ? const Color(0xFF0D1527) : Colors.white;
    final cardBorder = isNight
        ? const Color(0xFF1E2F52)
        : const Color(0xFFE2E8F0);
    final textPrimary = isNight ? Colors.white : AppTheme.textPrimary;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'How is the temperature today?',
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _progressionItem(
                _tempMorning,
                'Morning',
                Icons.wb_twilight_outlined,
                const Color(0xFFF59E0B),
                isNight,
              ),
              _progressionItem(
                _tempAfternoon,
                'Afternoon',
                Icons.wb_sunny_outlined,
                const Color(0xFFEF4444),
                isNight,
              ),
              _progressionItem(
                _tempEvening,
                'Evening',
                Icons.cloud_queue_outlined,
                const Color(0xFF64748B),
                isNight,
              ),
              _progressionItem(
                _tempNight,
                'Night',
                Icons.nights_stay_outlined,
                const Color(0xFF3B82F6),
                isNight,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressionItem(
    String temp,
    String label,
    IconData icon,
    Color color,
    bool isNight,
  ) {
    final textPrimary = isNight ? Colors.white : AppTheme.textPrimary;
    final textSecondary = isNight ? Colors.white60 : AppTheme.textSecondary;
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(
          temp,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w300,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _simulatorBtn(String label, DateTime? targetTime) {
    final isSelected =
        (_simulatedTime == targetTime) ||
        (targetTime == null && _simulatedTime == null);
    final bool isNight = _effectiveTime.hour >= 18 || _effectiveTime.hour < 6;

    final Color selectedBg = isNight ? Colors.white : const Color(0xFF0F172A);
    final Color selectedText = isNight ? const Color(0xFF0F172A) : Colors.white;
    final Color inactiveBg = isNight ? const Color(0xFF1E293B) : Colors.white;
    final Color inactiveBorder = isNight
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final Color inactiveText = isNight ? Colors.white70 : AppTheme.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _simulatedTime = targetTime;
            if (targetTime != null) {
              if (targetTime.hour >= 18 || targetTime.hour < 6) {
                _selectedWeather = 'moon';
              } else {
                _selectedWeather = 'sun';
              }
            } else {
              _fetchLocationAndWeather();
            }
          });
          _checkPunctualityTriggers();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : inactiveBg,
            border: Border.all(
              color: isSelected ? Colors.transparent : inactiveBorder,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? selectedText : inactiveText,
            ),
          ),
        ),
      ),
    );
  }

  void _checkPunctualityTriggers() {
    final hour = _effectiveTime.hour;
    final minute = _effectiveTime.minute;

    // Reset flags at 8:00 PM (night cycle begin)
    if (hour >= 20) {
      _hasTriggeredMissedSleepPenalty = false;
      _hasTriggeredMissedWakeupPenalty = false;
    }

    // 1. Missed Sleep Cycle (Past 6:30 AM and user didn't sleep)
    final int currentMinutes = hour * 60 + minute;
    final int targetWakeupMinutes = 390; // 06:30 AM

    if (!_isSleeping && currentMinutes >= targetWakeupMinutes && hour < 12) {
      if (!_hasTriggeredMissedSleepPenalty) {
        _hasTriggeredMissedSleepPenalty = true;
        setState(() {
          _user.totalXp -= 100;
          if (_user.totalXp < 0) _user.totalXp = 0;
        });
        _showPenaltyDialog(
          title: 'Missed Sleep Cycle! ⚠️',
          message:
              'It is past 06:30 and you did not log any sleep for tonight. Plant loses 100 XP.',
        );
      }
    }

    // 2. Missed Wake Up (Sleeping past 12:00 PM noon)
    if (_isSleeping && hour >= 12 && hour < 20) {
      if (!_hasTriggeredMissedWakeupPenalty) {
        _hasTriggeredMissedWakeupPenalty = true;
        setState(() {
          _isSleeping = false;
          _selectedWeather = 'sun';
          _user.totalXp -= 100;
          if (_user.totalXp < 0) _user.totalXp = 0;
        });
        _showPenaltyDialog(
          title: 'Missed Wake Up! ⚠️',
          message:
              'It is past 12:00 and you did not wake up to log your sleep. Plant loses 100 XP.',
        );
      }
    }
  }

  void _showPenaltyDialog({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.report_problem_outlined,
                      color: Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF991B1B,
                    ), // dark warning crimson
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Acknowledge Penalty',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
