import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../state/quest_controller.dart';
import '../../state/quest_state.dart';
import '../../theme/app_theme.dart';
import '../../models/word_record.dart';
import '../../services/database_service.dart';
import '../../services/audio_service.dart';


class BossQuizScreen extends ConsumerStatefulWidget {
  const BossQuizScreen({super.key});

  @override
  ConsumerState<BossQuizScreen> createState() => _BossQuizScreenState();
}

class _BossQuizScreenState extends ConsumerState<BossQuizScreen> with TickerProviderStateMixin {
  List<WordRecord> _quizWords = [];
  int _currentIndex = 0;
  String _currentMode = 'test'; // test, spelling
  bool _isQuestionTrToEn = true;
  List<String> _choices = [];
  String? _selectedChoice;
  final _spellController = TextEditingController();
  final _spellFocus = FocusNode();
  
  late AnimationController _celebController;
  late Animation<double> _celebScale;

  @override
  void initState() {
    super.initState();
    _celebController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _celebScale = CurvedAnimation(parent: _celebController, curve: Curves.elasticOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initQuiz());
  }

  @override
  void dispose() {
    _celebController.dispose();
    _spellController.dispose();
    _spellFocus.dispose();
    super.dispose();
  }

  Future<void> _initQuiz() async {
    final db = DatabaseService.instance;
    ref.read(questProvider.notifier).resetSessionStats();
    
    // Fetch all words globally for the "Boss" experience
    final folders = await db.getAllFolders();
    final List<WordRecord> allWords = [];
    for (var f in folders) {
      final words = await db.getWordsForFolder(f.id);
      allWords.addAll(words);
    }

    if (allWords.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      final rand = math.Random();
      final List<WordRecord> selected = [];
      
      if (allWords.length >= 40) {
        // Select 40 unique random words
        final pool = [...allWords]..shuffle();
        selected.addAll(pool.take(40));
      } else {
        // Repeat words until we reach 40
        while (selected.length < 40) {
          final pool = [...allWords]..shuffle();
          final remaining = 40 - selected.length;
          selected.addAll(pool.take(remaining));
        }
      }
      
      _quizWords = selected;
      if (_quizWords.isNotEmpty) _setupQuestion();
    });
  }

  void _setupQuestion() {
    if (_currentIndex >= _quizWords.length) return;
    
    // Modes restricted to Multiple Choice and Spelling
    final modes = ['test', 'spelling'];
    _currentMode = modes[math.Random().nextInt(modes.length)];
    
    // Randomize direction per question
    _isQuestionTrToEn = math.Random().nextBool();
    
    if (_currentMode == 'test') {
      _generateTestChoices();
    } else if (_currentMode == 'spelling') {
      _spellController.clear();
      _spellFocus.requestFocus();
    }
    _selectedChoice = null;
  }

  void _generateTestChoices() {
    final word = _quizWords[_currentIndex];
    final correct = _isQuestionTrToEn ? word.english : word.turkish;
    
    final s = ref.read(questProvider);
    final allCandidates = [...s.activeDeck, ...s.learnedDeck];
    final distractors = allCandidates
        .where((w) => w.id != word.id)
        .map((w) => _isQuestionTrToEn ? w.english : w.turkish)
        .where((val) => val.isNotEmpty)
        .toSet()
        .toList()..shuffle();

    _choices = [correct, ...distractors.take(3)]..shuffle();
  }

  Future<void> _handleAnswer(bool correct) async {
    final word = _quizWords[_currentIndex];
    final qCtrl = ref.read(questProvider.notifier);

    if (correct) {
      if (_currentMode == 'test') {
        ref.read(audioServiceProvider).playTestCorrect();
      } else {
        ref.read(audioServiceProvider).playSpellingCorrect();
      }
    } else {
      if (_currentMode == 'test') {
        ref.read(audioServiceProvider).playTestWrong();
      } else {
        ref.read(audioServiceProvider).playSpellingWrong();
      }
    }

    if (correct) {
      if (_currentMode == 'test') {
        await qCtrl.testCorrect(word);
      } else {
        await qCtrl.submitSpelling(word, _spellController.text);
      }
    } else {
      await qCtrl.answerIncorrect(word, isTest: _currentMode == 'test');
    }

    if (ref.read(questProvider).isCelebrating) _celebController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _currentIndex++;
        if (_currentIndex < _quizWords.length) _setupQuestion();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questProvider);
    if (_quizWords.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_currentIndex >= _quizWords.length) return _buildSummary(state);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('BOSS QUIZ · ${_currentIndex + 1}/40', style: const TextStyle(color: Colors.white)),
        leading: CloseButton(onPressed: () => Navigator.pop(context), color: Colors.white),
      ),
      body: Stack(
        children: [
          _buildQuestionContent(state),
          if (state.isCelebrating) _buildCelebrationOverlay(state.celebratedWordName ?? ""),
        ],
      ),
    );
  }

  Widget _buildQuestionContent(LinguistQuestState state) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildModeBadge(),
          const SizedBox(height: 24),
          Expanded(child: _buildModeUI(state)),
        ],
      ),
    );
  }

  Widget _buildModeBadge() {
    String label = '';
    IconData icon = Icons.help;
    Color color = Colors.white;

    if (_currentMode == 'test') { label = 'ÇOKTAN SEÇMELİ'; icon = Icons.quiz_rounded; color = Colors.purpleAccent; }
    else { label = 'YAZIM'; icon = Icons.spellcheck_rounded; color = AppTheme.sunnyYellow; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withAlpha(50), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withAlpha(100))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildModeUI(LinguistQuestState state) {
    final word = _quizWords[_currentIndex];
    final prompt = _isQuestionTrToEn ? word.turkish : word.english;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(_isQuestionTrToEn ? 'İngilizce Karşılığını Seç/Yaz' : 'Türkçe Karşılığını Seç/Yaz', style: const TextStyle(color: Colors.white38, fontSize: 14)),
        const SizedBox(height: 48),
        if (_currentMode == 'test') ..._choices.map((c) => _testOption(c, word, state))
        else ...[
          TextField(
            controller: _spellController,
            focusNode: _spellFocus,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Cevabı buraya yaz...',
              hintStyle: const TextStyle(color: Colors.white24),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.sunnyYellow)),
            ),
            onSubmitted: (val) {
              final target = _isQuestionTrToEn ? word.english : word.turkish;
              _handleAnswer(val.trim().toLowerCase() == target.trim().toLowerCase());
            },
            textInputAction: TextInputAction.send,
          ),
        ],
      ],
    );
  }

  Widget _testOption(String choice, WordRecord word, LinguistQuestState state) {
    final correct = _isQuestionTrToEn ? word.english : word.turkish;
    final isSelected = _selectedChoice == choice;
    
    Color bg = Colors.white10;
    if (_selectedChoice != null) {
      if (choice == correct) {
        bg = AppTheme.grassGreen;
      } else if (isSelected) {
        bg = Colors.redAccent;
      }
    }

    return GestureDetector(
      onTapDown: (_) {
        if (_selectedChoice != null) return;
        setState(() => _selectedChoice = choice);
        _handleAnswer(choice == correct);
      },
      onTap: () {}, // Handled by onTapDown
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
        child: Text(choice, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildSummary(LinguistQuestState state) {
    final score = state.sessionStats['success'] ?? 0;
    // Calculate total XP earned from this session
    // Boss quiz questions give 10-20 XP. On average ~15 XP * 40 sets = ~600 XP.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 120, color: AppTheme.sunnyYellow),
            const SizedBox(height: 24),
            const Text('BOSS MAĞLUP EDİLDİ!', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Text('40 Sorudan $score Doğru', style: const TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 12),
            const Text('Efsanevi XP kazanıldı!', style: TextStyle(color: AppTheme.sunnyYellow, fontWeight: FontWeight.bold)),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 0;
                      _setupQuestion();
                    });
                    _initQuiz(); // Shuffle and reset words
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white24)),
                  ),
                  child: const Text('YENİDEN OYNA', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bubblegumPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('ÖDÜLLERİ AL', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
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
                const Icon(Icons.flash_on_rounded, size: 100, color: Colors.white),
                const SizedBox(height: 24),
                Text(wordName, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white)),
                const Text('BOSS LEVEL ATLANDI!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
