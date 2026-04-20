import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/quest_controller.dart';
import '../../state/quest_state.dart';
import '../../theme/app_theme.dart';
import '../../models/word_record.dart';
import '../../services/audio_service.dart';

class TestScreen extends ConsumerStatefulWidget {
  const TestScreen({super.key});

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen> with TickerProviderStateMixin {
  List<WordRecord> _playList = [];
  List<WordRecord> _allWords = [];
  int _currentIndex = 0;
  List<String> _currentChoices = [];
  String? _selectedChoice;
  final Set<WordRecord> _incorrectWords = {};
  bool _isReviewPhase = false;
  int _initialTotalCount = 0;

  late AnimationController _celebController;
  late Animation<double> _celebScale;

  @override
  void initState() {
    super.initState();
    _celebController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _celebScale = CurvedAnimation(parent: _celebController, curve: Curves.elasticOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _celebController.dispose();
    super.dispose();
  }

  void _init() {
    final s = ref.read(questProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(questProvider.notifier).resetSessionStats();
    });

    _allWords = [...s.activeDeck, ...s.learnedDeck];
    final candidates = [..._allWords]..shuffle();
    setState(() {
      _playList = candidates;
      _initialTotalCount = _playList.length;
      if (_playList.isNotEmpty) _generateChoices();
    });
  }

  void _generateChoices() {
    if (_currentIndex >= _playList.length) return;
    final word = _playList[_currentIndex];
    final isTrToEn = ref.read(questProvider).direction == StudyDirection.trToEn;

    final correctAnswer = isTrToEn ? word.english : word.turkish;
    final distractors = _allWords
        .where((w) => w.id != word.id)
        .map((w) => isTrToEn ? w.english : w.turkish)
        .where((val) => val.isNotEmpty)
        .toSet()
        .toList()..shuffle();

    _currentChoices = [correctAnswer, ...distractors.take(3)]..shuffle();
    _selectedChoice = null;
  }

  Future<void> _onChoice(String choice) async {
    if (_selectedChoice != null) return;
    final word = _playList[_currentIndex];
    final isTrToEn = ref.read(questProvider).direction == StudyDirection.trToEn;
    final correctAnswer = isTrToEn ? word.english : word.turkish;
    final isCorrect = choice == correctAnswer;

    if (isCorrect) {
      ref.read(audioServiceProvider).playTestCorrect();
    } else {
      ref.read(audioServiceProvider).playTestWrong();
    }

    setState(() => _selectedChoice = choice);

    if (isCorrect) {
      if (!_isReviewPhase) {
        await ref.read(questProvider.notifier).testCorrect(word);
      }
    } else {
      if (!_isReviewPhase) {
        _incorrectWords.add(word);
        await ref.read(questProvider.notifier).answerIncorrect(word);
      }
    }

    // Celebration logic removed

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _currentIndex++;
        if (_currentIndex < _playList.length) {
          _generateChoices();
        } else if (_incorrectWords.isNotEmpty) {
          _isReviewPhase = true;
          _playList = _incorrectWords.toList()..shuffle();
          _incorrectWords.clear();
          _currentIndex = 0;
          _generateChoices();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questProvider);
    final isTrToEn = state.direction == StudyDirection.trToEn;

    if (_allWords.length < 4) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.warning_amber_rounded, size: 80, color: AppTheme.bubblegumPink),
            const SizedBox(height: 24),
            const Text('En az 4 farklı kelime gerekli.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Geri Dön')),
          ]),
        )),
      );
    }

    if (_currentIndex >= _playList.length) {
      final successCount = state.sessionStats['success'] ?? 0;
      final accuracy = (_initialTotalCount > 0) 
          ? (successCount / _initialTotalCount * 100).toInt() 
          : 0;

      return Scaffold(
        appBar: AppBar(title: const Text('Oturum Bitti')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.stars_rounded, color: AppTheme.sunnyYellow, size: 100),
            const SizedBox(height: 24),
            const Text('Oturum Tamamlandı!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
            const SizedBox(height: 16),
            Text('Doğruluk Oranı: %$accuracy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.skyBlue)),
            const SizedBox(height: 32),
            _summaryRow('Başarı', '$successCount / $_initialTotalCount', AppTheme.skyBlue),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('BİTİR')),
            ),
          ])),
        ),
      );
    }

    final word = _playList[_currentIndex];
    final promptText = isTrToEn ? word.turkish : word.english;
    final correctAnswer = isTrToEn ? word.english : word.turkish;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isReviewPhase ? 'Tekrar Dene' : '${_currentIndex + 1} / ${_playList.length}'),
        actions: [
          if (!_isReviewPhase)
            Padding(padding: const EdgeInsets.only(right: 16),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bolt_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 4),
                Text('${state.comboCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ])),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Stack(
                      children: [
                        Positioned(
                          top: 16, right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppTheme.grassGreen.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                            child: Text('Lv.${word.masteryLevel}', style: const TextStyle(color: AppTheme.grassGreen, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(promptText,
                              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppTheme.textMain),
                              textAlign: TextAlign.center),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  flex: 3,
                  child: ListView.builder(
                    itemCount: _currentChoices.length,
                    itemBuilder: (_, i) {
                      final choice = _currentChoices[i];
                      final selected = _selectedChoice == choice;
                      final isCorrect = choice == correctAnswer;
                      Color? bg;
                      Color? fg;
                      if (_selectedChoice != null) {
                        if (isCorrect) {
                          bg = AppTheme.grassGreen;
                          fg = Colors.white;
                        } else if (selected) {
                          bg = AppTheme.bubblegumPink;
                          fg = Colors.white;
                        } else {
                          bg = Colors.black.withAlpha(10);
                          fg = AppTheme.textMuted.withAlpha(100);
                        }
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: bg ?? Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: bg != null ? Colors.transparent : Colors.black12, width: 2),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTapDown: (_) => _onChoice(choice),
                            onTap: () {}, // Handled by onTapDown for lower latency
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                              child: Text(choice,
                                style: TextStyle(
                                  fontSize: 22, 
                                  fontWeight: FontWeight.bold, 
                                  color: fg ?? AppTheme.textMain),
                                textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (state.isCelebrating) _buildCelebrationOverlay(state.celebratedWordName ?? ""),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18, color: AppTheme.textMuted)),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildCelebrationOverlay(String wordName) {
    return Positioned.fill(
      child: Container(
        color: AppTheme.grassGreen.withAlpha(240),
        child: Center(
          child: ScaleTransition(
            scale: _celebScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 100, color: Colors.white),
                const SizedBox(height: 24),
                Text(wordName, 
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white)),
                const Text('ÖĞRENİLDİ!', 
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
