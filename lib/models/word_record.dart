class WordRecord {
  final String id;
  final String folderId;
  final String english;
  final String turkish;
  
  // Isolated mode counters (v4)
  final int flashcardScore;
  final int testScore;
  final int spellingScore;
  
  final String? nextReviewDate;
  final int consecutiveCorrect;

  // Gamification fields (v4)
  final int masteryLevel;      // 0 to 4
  final int difficultCount;    // Increases on errors, legacy field
  
  // Tracking fields (v5)
  final int testSuccessCount;
  final int testAttemptCount;
  final int spellingSuccessCount;
  final int spellingAttemptCount;

  WordRecord({
    required this.id,
    required this.folderId,
    required this.english,
    required this.turkish,
    required this.flashcardScore,
    required this.testScore,
    required this.spellingScore,
    this.nextReviewDate,
    this.consecutiveCorrect = 0,
    this.masteryLevel = 0,
    this.difficultCount = 0,
    this.testSuccessCount = 0,
    this.testAttemptCount = 0,
    this.spellingSuccessCount = 0,
    this.spellingAttemptCount = 0,
  });

  int get calculatedMasteryLevel {
    // Mastery based on attempts + spelling
    // Note: difficultCount is legacy, but we use it as a proxy for failures in some places.
    // However, to follow the user's specific accuracy request:
    
    final attempts = testAttemptCount + spellingAttemptCount;
    if (attempts == 0) return 0; // New
    
    final success = testSuccessCount + spellingSuccessCount;
    final rate = (success / attempts) * 100;
    
    if (rate == 0) return 0;
    if (rate <= 33) return 1; // Seen
    if (rate <= 66) return 2; // Familiar
    if (rate <= 90) return 3; // Earned
    return 4; // Mastered (91-100)
  }

  bool get isDifficult {
    final attempts = testAttemptCount + spellingAttemptCount;
    if (attempts < 5) return false; 
    
    final success = testSuccessCount + spellingSuccessCount;
    final successRate = success / attempts;
    return successRate < 0.66;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folderId': folderId,
      'english': english,
      'turkish': turkish,
      'flashcardScore': flashcardScore,
      'testScore': testScore,
      'spellingScore': spellingScore,
      'nextReviewDate': nextReviewDate,
      'consecutiveCorrect': consecutiveCorrect,
      'masteryLevel': masteryLevel,
      'difficultCount': difficultCount,
      'testSuccessCount': testSuccessCount,
      'testAttemptCount': testAttemptCount,
      'spellingSuccessCount': spellingSuccessCount,
      'spellingAttemptCount': spellingAttemptCount,
      'isBasket': 0, // Legacy support for DB column
      'status': masteryLevel >= 3 ? 'learned' : 'active',
    };
  }

  factory WordRecord.fromMap(Map<String, dynamic> map) {
    return WordRecord(
      id: map['id'] as String,
      folderId: map['folderId'] as String,
      english: map['english'] as String,
      turkish: map['turkish'] as String,
      flashcardScore: map['flashcardScore'] as int,
      testScore: (map['testScore'] as int?) ?? 0,
      spellingScore: (map['spellingScore'] as int?) ?? 0,
      nextReviewDate: map['nextReviewDate'] as String?,
      consecutiveCorrect: (map['consecutiveCorrect'] as int?) ?? 0,
      masteryLevel: (map['masteryLevel'] as int?) ?? 0,
      difficultCount: (map['difficultCount'] as int?) ?? 0,
      testSuccessCount: (map['testSuccessCount'] as int?) ?? 0,
      testAttemptCount: (map['testAttemptCount'] as int?) ?? 0,
      spellingSuccessCount: (map['spellingSuccessCount'] as int?) ?? 0,
      spellingAttemptCount: (map['spellingAttemptCount'] as int?) ?? 0,
    );
  }

  WordRecord copyWith({
    String? id,
    String? folderId,
    String? english,
    String? turkish,
    int? flashcardScore,
    int? testScore,
    int? spellingScore,
    String? nextReviewDate,
    int? consecutiveCorrect,
    int? masteryLevel,
    int? difficultCount,
    int? testSuccessCount,
    int? testAttemptCount,
    int? spellingSuccessCount,
    int? spellingAttemptCount,
  }) {
    return WordRecord(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      english: english ?? this.english,
      turkish: turkish ?? this.turkish,
      flashcardScore: flashcardScore ?? this.flashcardScore,
      testScore: testScore ?? this.testScore,
      spellingScore: spellingScore ?? this.spellingScore,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      difficultCount: difficultCount ?? this.difficultCount,
      testSuccessCount: testSuccessCount ?? this.testSuccessCount,
      testAttemptCount: testAttemptCount ?? this.testAttemptCount,
      spellingSuccessCount: spellingSuccessCount ?? this.spellingSuccessCount,
      spellingAttemptCount: spellingAttemptCount ?? this.spellingAttemptCount,
    );
  }
}
