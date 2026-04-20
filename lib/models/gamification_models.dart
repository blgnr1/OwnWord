class PlayerProfile {
  final String id;
  final int totalXP;
  final int level;
  final int currentStreak;
  final String? lastStudyDate;
  final int bossQuizProgress; // Number of words studied towards unlocking the next boss quiz

  PlayerProfile({
    required this.id,
    this.totalXP = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.lastStudyDate,
    this.bossQuizProgress = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'totalXP': totalXP,
      'level': level,
      'currentStreak': currentStreak,
      'lastStudyDate': lastStudyDate,
      'bossQuizProgress': bossQuizProgress,
    };
  }

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    return PlayerProfile(
      id: map['id'] as String,
      totalXP: map['totalXP'] as int,
      level: map['level'] as int,
      currentStreak: map['currentStreak'] as int,
      lastStudyDate: map['lastStudyDate'] as String?,
      bossQuizProgress: map['bossQuizProgress'] as int,
    );
  }

  PlayerProfile copyWith({
    String? id,
    int? totalXP,
    int? level,
    int? currentStreak,
    String? lastStudyDate,
    int? bossQuizProgress,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      totalXP: totalXP ?? this.totalXP,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      bossQuizProgress: bossQuizProgress ?? this.bossQuizProgress,
    );
  }
}

class DailyMission {
  final String id;
  final String title;
  final int target;
  final int current;
  final int xpReward;
  final bool isCompleted;
  final String date;

  DailyMission({
    required this.id,
    required this.title,
    required this.target,
    this.current = 0,
    required this.xpReward,
    this.isCompleted = false,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target': target,
      'current': current,
      'xpReward': xpReward,
      'isCompleted': isCompleted ? 1 : 0,
      'date': date,
    };
  }

  factory DailyMission.fromMap(Map<String, dynamic> map) {
    return DailyMission(
      id: map['id'] as String,
      title: map['title'] as String,
      target: map['target'] as int,
      current: map['current'] as int,
      xpReward: map['xpReward'] as int,
      isCompleted: map['isCompleted'] == 1,
      date: map['date'] as String,
    );
  }

  DailyMission copyWith({
    String? id,
    String? title,
    int? target,
    int? current,
    int? xpReward,
    bool? isCompleted,
    String? date,
  }) {
    return DailyMission(
      id: id ?? this.id,
      title: title ?? this.title,
      target: target ?? this.target,
      current: current ?? this.current,
      xpReward: xpReward ?? this.xpReward,
      isCompleted: isCompleted ?? this.isCompleted,
      date: date ?? this.date,
    );
  }
}
