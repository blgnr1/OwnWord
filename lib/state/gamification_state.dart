import '../models/gamification_models.dart';

class LinguistGamificationState {
  final PlayerProfile profile;
  final List<DailyMission> todayMissions;
  final bool isLoading;
  final bool showLevelUp;
  final Set<String> processedWordIds;

  const LinguistGamificationState({
    required this.profile,
    this.todayMissions = const [],
    this.isLoading = true,
    this.showLevelUp = false,
    this.processedWordIds = const {},
  });

  LinguistGamificationState copyWith({
    PlayerProfile? profile,
    List<DailyMission>? todayMissions,
    bool? isLoading,
    bool? showLevelUp,
    Set<String>? processedWordIds,
  }) {
    return LinguistGamificationState(
      profile: profile ?? this.profile,
      todayMissions: todayMissions ?? this.todayMissions,
      isLoading: isLoading ?? this.isLoading,
      showLevelUp: showLevelUp ?? this.showLevelUp,
      processedWordIds: processedWordIds ?? this.processedWordIds,
    );
  }
}
