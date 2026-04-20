import '../models/folder.dart';
import '../models/word_record.dart';

/// Direction of translation for the session
enum StudyDirection { trToEn, enToTr }

/// Per-day learning statistics
class DayStats {
  final String date; // ISO date "2026-03-13"
  final int studied;
  final int learned;
  final int riveted;
  final int basket;
  final int? totalActivity; // v4 total counter

  const DayStats({
    required this.date,
    this.studied = 0,
    this.learned = 0,
    this.riveted = 0,
    this.basket = 0,
    this.totalActivity = 0,
  });

  Map<String, dynamic> toMap() => {
    'date': date,
    'studied': studied,
    'learned': learned,
    'riveted': riveted,
    'basket': basket,
    'totalActivity': totalActivity,
  };

  factory DayStats.fromMap(Map<String, dynamic> m) => DayStats(
    date: m['date'] as String,
    studied: (m['studied'] as int?) ?? 0,
    learned: (m['learned'] as int?) ?? 0,
    riveted: (m['riveted'] as int?) ?? 0,
    basket: (m['basket'] as int?) ?? 0,
    totalActivity: (m['totalActivity'] as int?) ?? 0,
  );
}

class LinguistQuestState {
  final Folder? currentFolder;
  final List<WordRecord> activeDeck;
  final List<WordRecord> learnedDeck;
  final String currentTheme;
  final WordRecord? currentWord;
  final Map<String, int> sessionStats;
  final bool isLoading;

  // v2 fields
  final StudyDirection direction;
  final bool isCelebrating;          // Emerald glow + "Pekiştirildi!" text
  final String? celebratedWordName;  // Name of the word that triggered celebration
  final bool smithErrorVisible;      // 2-sec error display in Yazım
  final String? smithCorrectWord;    // The correct word shown on error
  final int comboCount;              // Consecutive correct answers
  final int? lastXPGain;             // XP amount gained from last answer

  const LinguistQuestState({
    this.currentFolder,
    this.activeDeck = const [],
    this.learnedDeck = const [],
    this.currentTheme = 'flashcards',
    this.currentWord,
    this.sessionStats = const {'success': 0},
    this.isLoading = true,
    this.direction = StudyDirection.enToTr,
    this.isCelebrating = false,
    this.celebratedWordName,
    this.smithErrorVisible = false,
    this.smithCorrectWord,
    this.comboCount = 0,
    this.lastXPGain,
  });

  LinguistQuestState copyWith({
    Folder? currentFolder,
    List<WordRecord>? activeDeck,
    List<WordRecord>? learnedDeck,
    String? currentTheme,
    WordRecord? currentWord,
    Map<String, int>? sessionStats,
    bool? isLoading,
    StudyDirection? direction,
    bool? isCelebrating,
    String? celebratedWordName,
    bool? smithErrorVisible,
    String? smithCorrectWord,
    int? comboCount,
    int? lastXPGain,
  }) {
    return LinguistQuestState(
      currentFolder: currentFolder ?? this.currentFolder,
      activeDeck: activeDeck ?? this.activeDeck,
      learnedDeck: learnedDeck ?? this.learnedDeck,
      currentTheme: currentTheme ?? this.currentTheme,
      currentWord: currentWord ?? this.currentWord,
      sessionStats: sessionStats ?? this.sessionStats,
      isLoading: isLoading ?? this.isLoading,
      direction: direction ?? this.direction,
      isCelebrating: isCelebrating ?? this.isCelebrating,
      celebratedWordName: celebratedWordName ?? this.celebratedWordName,
      smithErrorVisible: smithErrorVisible ?? this.smithErrorVisible,
      smithCorrectWord: smithCorrectWord ?? this.smithCorrectWord,
      comboCount: comboCount ?? this.comboCount,
      lastXPGain: lastXPGain ?? this.lastXPGain,
    );
  }
}
