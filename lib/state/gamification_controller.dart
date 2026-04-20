import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../models/gamification_models.dart';
import '../services/database_service.dart';
import 'gamification_state.dart';

final gamificationProvider = NotifierProvider<GamificationController, LinguistGamificationState>(() {
  return GamificationController();
});

class GamificationController extends Notifier<LinguistGamificationState> {
  final _db = DatabaseService.instance;

  @override
  LinguistGamificationState build() {
    final dummy = PlayerProfile(id: 'default');
    return LinguistGamificationState(profile: dummy, isLoading: true);
  }

  Future<void> init() async {
    final profile = await _db.getPlayerProfile();
    final today = _today();
    
    // Check streak
    PlayerProfile updatedProfile = await _verifyStreak(profile);
    
    // Load missions
    List<DailyMission> missions = await _db.getMissionsForDate(today);
    if (missions.isEmpty) {
      missions = _generateDailyMissions(today);
      await _db.insertMissions(missions);
    }

    state = state.copyWith(
      profile: updatedProfile,
      todayMissions: missions,
      isLoading: false,
    );
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<PlayerProfile> _verifyStreak(PlayerProfile profile) async {
    if (profile.lastStudyDate == null) return profile;
    
    final lastDate = DateTime.parse(profile.lastStudyDate!);
    final now = DateTime.now();
    final diff = now.difference(lastDate).inDays;

    if (diff > 1) {
      final updated = profile.copyWith(currentStreak: 0);
      await _db.updatePlayerProfile(updated);
      return updated;
    }
    return profile;
  }

  List<DailyMission> _generateDailyMissions(String date) {
    return [
      DailyMission(
        id: const Uuid().v4(),
        title: '10 Kelime Öğren (+50 XP)',
        target: 10,
        xpReward: 50,
        date: date,
      ),
      DailyMission(
        id: const Uuid().v4(),
        title: '20 Soru Yanıtla (+50 XP)',
        target: 20,
        xpReward: 50,
        date: date,
      ),
      DailyMission(
        id: const Uuid().v4(),
        title: '5 Yazım Egzersizi Yap (+50 XP)',
        target: 5,
        xpReward: 50,
        date: date,
      ),
    ];
  }

  Future<void> addXP(int xp) async {
    int oldTotalXP = state.profile.totalXP;
    int totalXP = oldTotalXP + xp;
    
    // Exponential Level Logic: TotalXP = 100 * Level^2
    // Level = sqrt(TotalXP / 100)
    int oldLevel = math.sqrt(oldTotalXP / 100).floor() + 1;
    int newLevel = math.sqrt(totalXP / 100).floor() + 1;
    
    bool levelUp = newLevel > oldLevel;
    
    final updatedProfile = state.profile.copyWith(
      totalXP: totalXP,
      level: newLevel,
      lastStudyDate: _today(),
    );
    
    await _db.updatePlayerProfile(updatedProfile);
    state = state.copyWith(
      profile: updatedProfile,
      showLevelUp: levelUp,
    );
  }

  void dismissLevelUp() {
    state = state.copyWith(showLevelUp: false);
  }

  Future<void> updateProgress(String missionTitle, int increment, {String? wordId}) async {
    final missions = [...state.todayMissions];
    final index = missions.indexWhere((m) => m.title == missionTitle);
    
    if (index != -1) {
      var mission = missions[index];
      if (mission.isCompleted) return;

      // Special check for distinct words
      if (mission.title == '10 Kelime Öğren (+50 XP)' && wordId != null) {
        if (state.processedWordIds.contains(wordId)) return;
        final newProcessed = Set<String>.from(state.processedWordIds)..add(wordId);
        state = state.copyWith(processedWordIds: newProcessed);
      }

      int newCurrent = mission.current + increment;
      bool newlyCompleted = newCurrent >= mission.target;
      
      mission = mission.copyWith(
        current: newCurrent,
        isCompleted: newlyCompleted,
      );
      
      missions[index] = mission;
      await _db.updateMission(mission);
      
      if (newlyCompleted) {
        await addXP(mission.xpReward);
      }
      
      state = state.copyWith(todayMissions: missions);
    }
  }

  Future<void> incrementBossProgress() async {
    final updated = state.profile.copyWith(
      bossQuizProgress: state.profile.bossQuizProgress + 1,
    );
    await _db.updatePlayerProfile(updated);
    state = state.copyWith(profile: updated);
  }

  Future<void> resetBossProgress() async {
    final updated = state.profile.copyWith(bossQuizProgress: 0);
    await _db.updatePlayerProfile(updated);
    state = state.copyWith(profile: updated);
  }

  Future<void> incrementStreak() async {
    final today = _today();
    if (state.profile.lastStudyDate == today) return;

    final updated = state.profile.copyWith(
      currentStreak: state.profile.currentStreak + 1,
      lastStudyDate: today,
    );
    await _db.updatePlayerProfile(updated);
    state = state.copyWith(profile: updated);
  }
}
