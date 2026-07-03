import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../models/folder.dart';
import '../models/word_record.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'quest_state.dart';
import 'gamification_controller.dart';

final questProvider = NotifierProvider<QuestController, LinguistQuestState>(() {
  return QuestController();
});

class QuestController extends Notifier<LinguistQuestState> {
  final _db = DatabaseService.instance;
  final Set<String> _sessionSeenWords = {};

  @override
  LinguistQuestState build() => const LinguistQuestState();

  Future<void> loadFolder(Folder folder) async {
    _sessionSeenWords.clear();
    state = state.copyWith(isLoading: true, currentFolder: folder, sessionStats: {'success': 0}, comboCount: 0);
    final words = await _db.getWordsForFolder(folder.id);
    
    // User requested: No restrictions in training modes anymore.
    final active = words.toList();
    active.shuffle();

    state = state.copyWith(
      activeDeck: active,
      learnedDeck: [], // Not used for filtering anymore
      isLoading: false,
    );
  }

  Future<void> loadBossQuiz(List<WordRecord> words) async {
    _sessionSeenWords.clear();
    state = state.copyWith(
      isLoading: true, 
      currentFolder: const Folder(id: 'boss', name: 'BOSS QUIZ'), 
      sessionStats: {'success': 0}, 
      comboCount: 0
    );
    
    final deck = words.toList()..shuffle();
    state = state.copyWith(activeDeck: deck, learnedDeck: [], isLoading: false);
  }

  Future<void> loadSpecialCategory(String title, List<WordRecord> words) async {
    _sessionSeenWords.clear();
    state = state.copyWith(
      isLoading: true, 
      currentFolder: Folder(id: 'special', name: title), 
      sessionStats: {'success': 0}, 
      comboCount: 0
    );
    
    final deck = words.toList()..shuffle();
    state = state.copyWith(activeDeck: deck, learnedDeck: [], isLoading: false);
  }

  void setTheme(String theme) => state = state.copyWith(currentTheme: theme);

  void setDirection(StudyDirection direction) => state = state.copyWith(direction: direction);

  // ==== INTERNAL XP & COMBO CALC ====
  
  int _calculateXP(int baseXP) {
    double multiplier = 1.0;
    if (state.comboCount >= 10) {
      multiplier = 2.0;
    } else if (state.comboCount >= 3) {
      multiplier = 1.5;
    }
    return (baseXP * multiplier).toInt();
  }

  Future<void> _onStudySuccess(WordRecord word, int baseXP) async {
    final gCtrl = ref.read(gamificationProvider.notifier);
    final xp = _calculateXP(baseXP);
    
    await gCtrl.addXP(xp);
    await gCtrl.incrementBossProgress();
    await gCtrl.incrementStreak();
    await gCtrl.updateProgress('answer_questions', 1);

    if (state.comboCount + 1 >= 5) {
      await gCtrl.updateProgress('combo_streak', 1);
    }
    if (word.isDifficult) {
      await gCtrl.updateProgress('difficult_practice', 1);
    }
    
    state = state.copyWith(comboCount: state.comboCount + 1);
    // lastXPGain (popup feedback) is removed per request
  }

  Future<void> _onStudyFailure() async {
    state = state.copyWith(comboCount: 0);
  }

  // ==== FLASHCARD MECHANICS ====

  Future<void> markAsKnown(WordRecord word) async {
    
    final updatedWord = word.copyWith(
      masteryLevel: word.calculatedMasteryLevel,
      consecutiveCorrect: word.consecutiveCorrect + 1,
      flashcardScore: word.flashcardScore + 1,
    );

    await _onStudySuccess(word, 5);
    await ref.read(gamificationProvider.notifier).updateProgress('learn_words', 1, wordId: word.id);
    await _updateWordState(updatedWord, true);
    await _db.incrementDailyStat('studied');
    
    if (updatedWord.masteryLevel >= 3 && word.masteryLevel < 3) {
       await _db.incrementDailyStat('learned');
    }
    
  }

  Future<void> markForReview(WordRecord word) async {
    final updatedWord = word.copyWith(
      masteryLevel: word.calculatedMasteryLevel,
      difficultCount: word.difficultCount + 1,
      consecutiveCorrect: 0,
    );
    await _onStudyFailure();
    await _updateWordState(updatedWord, false);
    await _db.incrementDailyStat('studied');
  }

  // ==== TEST MECHANICS ====

  Future<void> testCorrect(WordRecord word) async {
    final updatedWord = word.copyWith(
      testScore: word.testScore + 1,
      testSuccessCount: word.testSuccessCount + 1,
      testAttemptCount: word.testAttemptCount + 1,
    );
    
    final finalizedWord = updatedWord.copyWith(masteryLevel: updatedWord.calculatedMasteryLevel);

    await _onStudySuccess(word, 10);
    await ref.read(gamificationProvider.notifier).updateProgress('learn_words', 1, wordId: word.id);
    await _updateWordState(finalizedWord, true);
    await _db.incrementDailyStat('studied');
  }

  Future<void> answerIncorrect(WordRecord word, {bool isTest = true}) async {
    final updatedWord = word.copyWith(
      difficultCount: word.difficultCount + 1,
      consecutiveCorrect: 0,
      testAttemptCount: isTest ? word.testAttemptCount + 1 : word.testAttemptCount,
      spellingAttemptCount: !isTest ? word.spellingAttemptCount + 1 : word.spellingAttemptCount,
    );
    final finalizedWord = updatedWord.copyWith(masteryLevel: updatedWord.calculatedMasteryLevel);
    
    await _onStudyFailure();
    await _updateWordState(finalizedWord, false);
    await _db.incrementDailyStat('studied');
  }

  void resetSessionStats() {
    _sessionSeenWords.clear();
    state = state.copyWith(sessionStats: {'success': 0}, comboCount: 0);
  }

  // ==== SPELLING (YAZIM) MECHANICS ====

  Future<String> submitSpelling(WordRecord word, String input, {bool isAudioDictation = false}) async {
    final target = (isAudioDictation || state.direction == StudyDirection.trToEn) 
        ? word.english.trim().toLowerCase() 
        : word.turkish.trim().toLowerCase();
    final given = input.trim().toLowerCase();

    if (target == given) {
      final updatedWord = word.copyWith(
        spellingScore: word.spellingScore + 1,
        consecutiveCorrect: word.consecutiveCorrect + 1,
        spellingSuccessCount: word.spellingSuccessCount + 1,
        spellingAttemptCount: word.spellingAttemptCount + 1,
      );
      final finalizedWord = updatedWord.copyWith(masteryLevel: updatedWord.calculatedMasteryLevel);

      await _onStudySuccess(word, 20);
      await ref.read(gamificationProvider.notifier).updateProgress('learn_words', 1, wordId: word.id);
      await ref.read(gamificationProvider.notifier).updateProgress('do_spelling', 1);
      await _updateWordState(finalizedWord, true);
      await _db.incrementDailyStat('studied');
      
      return 'correct';
    }

    final distance = _levenshtein(target, given);
    if (distance <= 1 && target.length > 3) {
      return 'typo';
    }

    state = state.copyWith(
      smithErrorVisible: true,
      smithCorrectWord: (isAudioDictation || state.direction == StudyDirection.trToEn) ? word.english : word.turkish,
    );
    await answerIncorrect(word, isTest: false);

    Future.delayed(const Duration(milliseconds: 2000), () {
      state = state.copyWith(smithErrorVisible: false, smithCorrectWord: null);
    });

    return 'wrong';
  }

  Future<void> _updateWordState(WordRecord word, bool isSuccess) async {
    String? nextReview;
    if (isSuccess) {
      final now = DateTime.now();
      switch (word.masteryLevel) {
        case 1:
          nextReview = now.add(const Duration(days: 1)).toIso8601String().substring(0, 10);
          break;
        case 2:
          nextReview = now.add(const Duration(days: 3)).toIso8601String().substring(0, 10);
          break;
        case 3:
          nextReview = now.add(const Duration(days: 7)).toIso8601String().substring(0, 10);
          break;
        case 4:
          nextReview = now.add(const Duration(days: 14)).toIso8601String().substring(0, 10);
          break;
      }
    }
    
    final updatedWord = word.copyWith(nextReviewDate: nextReview);
    await _db.updateWord(updatedWord);

    final s = state;
    final allWords = [...s.activeDeck, ...s.learnedDeck]
        .where((w) => w.id != word.id)
        .toList()..add(updatedWord);

    final newActive = allWords.toList();

    final stats = Map<String, int>.from(state.sessionStats);
    if (!_sessionSeenWords.contains(word.id)) {
      _sessionSeenWords.add(word.id);
      if (isSuccess) {
        stats['success'] = (stats['success'] ?? 0) + 1;
      }
    }

    state = state.copyWith(activeDeck: newActive, learnedDeck: [], sessionStats: stats);
    NotificationService.instance.scheduleStreakReminder();
  }

  int _levenshtein(String s, String t) {
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    List<int> v0 = List.generate(t.length + 1, (i) => i);
    List<int> v1 = List.filled(t.length + 1, 0);
    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}
