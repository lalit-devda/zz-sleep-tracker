class SleepSession {
  final DateTime bedTime;
  final DateTime wakeTime;
  final double hoursSlept;
  final int xpEarned;
  final int quality; // 1-5

  SleepSession({
    required this.bedTime,
    required this.wakeTime,
    required this.hoursSlept,
    required this.xpEarned,
    required this.quality,
  });

  Map<String, dynamic> toJson() => {
    'bedTime': bedTime.toIso8601String(),
    'wakeTime': wakeTime.toIso8601String(),
    'hoursSlept': hoursSlept,
    'xpEarned': xpEarned,
    'quality': quality,
  };

  factory SleepSession.fromJson(Map<String, dynamic> json) => SleepSession(
    bedTime: DateTime.parse(json['bedTime']),
    wakeTime: DateTime.parse(json['wakeTime']),
    hoursSlept: (json['hoursSlept'] as num).toDouble(),
    xpEarned: json['xpEarned'] as int,
    quality: json['quality'] as int,
  );
}

class UserProfile {
  String name;
  final String email;
  int age; // User's age to customize sleep goals
  int totalXp;
  int level;
  List<SleepSession> sessions;
  String? avatar; // Stored profile photo (base64 or URL)

  UserProfile({
    required this.name,
    required this.email,
    this.age = 25, // Defaults to 25
    this.totalXp = 180,
    this.level = 1,
    List<SleepSession>? sessions,
    this.avatar,
  }) : sessions = sessions ?? [];

  // Optimal sleep ranges based on age (National Sleep Foundation)
  int get minOptimalHours {
    if (age <= 2) return 11;
    if (age <= 5) return 10;
    if (age <= 13) return 9;
    if (age <= 17) return 8;
    if (age <= 64) return 7;
    return 7; // 65+
  }

  int get maxOptimalHours {
    if (age <= 2) return 14;
    if (age <= 5) return 13;
    if (age <= 13) return 11;
    if (age <= 17) return 10;
    if (age <= 64) return 9;
    return 8; // 65+
  }

  int get xpForCurrentLevel => (level - 1) * 300;
  int get xpForNextLevel => level * 300;
  int get xpProgress => totalXp - xpForCurrentLevel;
  int get xpNeeded => xpForNextLevel - xpForCurrentLevel;
  double get levelProgress => xpProgress / xpNeeded;

  String get plantStage {
    if (level == 1) return 'mascot';
    if (level == 2) return 'seedling';
    if (level == 3) return 'walking';
    if (level == 4) return 'plants';
    return 'waving';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'age': age,
    'totalXp': totalXp,
    'level': level,
    'sleepSessions': sessions.map((s) => s.toJson()).toList(),
    'avatar': avatar,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['sleepSessions'] as List<dynamic>? ?? [];
    
    // Auto-repair missing XP and generate mock data if demo seeding is explicitly enabled
    int xp = json['totalXp'] as int? ?? 0;
    List<SleepSession> parsedSessions = rawSessions
        .map((s) => SleepSession.fromJson(s as Map<String, dynamic>))
        .toList();
        
    const bool isSeedDemo = bool.fromEnvironment('MARKETING_DEMO_SEED') ||
        String.fromEnvironment('MARKETING_DEMO_SEED') == 'true';
        
    if (parsedSessions.isEmpty && isSeedDemo) {
      if (xp == 0) xp = 180;
      
      // Generate a week of realistic sleep data
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final bedTime = now.subtract(Duration(days: i + 1)).copyWith(
          hour: 22 + (DateTime.now().microsecond % 2), 
          minute: 30
        );
        final hoursSlept = 6.5 + (DateTime.now().microsecond % 20) / 10.0; // 6.5 to 8.5
        final wakeTime = bedTime.add(Duration(minutes: (hoursSlept * 60).round()));
        
        parsedSessions.add(SleepSession(
          bedTime: bedTime,
          wakeTime: wakeTime,
          hoursSlept: hoursSlept,
          xpEarned: 80,
          quality: hoursSlept > 7.5 ? 5 : (hoursSlept > 6.5 ? 4 : 3),
        ));
        
        xp += 80; // Add earned XP for these mock sessions
      }
    }
    
    return UserProfile(
      name: json['name'] as String? ?? 'Lalit Devda',
      email: json['email'] as String? ?? '',
      age: json['age'] as int? ?? 25,
      totalXp: xp,
      level: (xp ~/ 300) + 1,
      sessions: parsedSessions,
      avatar: json['avatar'] as String?,
    );
  }
}
