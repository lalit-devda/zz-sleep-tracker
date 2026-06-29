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
    this.totalXp = 0,
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
    return UserProfile(
      name: json['name'] as String? ?? 'Lalit Devda',
      email: json['email'] as String? ?? '',
      age: json['age'] as int? ?? 25,
      totalXp: json['totalXp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      sessions: rawSessions
          .map((s) => SleepSession.fromJson(s as Map<String, dynamic>))
          .toList(),
      avatar: json['avatar'] as String?,
    );
  }
}
