import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../state/quest_controller.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../models/word_record.dart';
import '../../services/audio_service.dart';


class SpeedModeScreen extends ConsumerStatefulWidget {
  const SpeedModeScreen({super.key});

  @override
  ConsumerState<SpeedModeScreen> createState() => _SpeedModeScreenState();
}

class _SpeedModeScreenState extends ConsumerState<SpeedModeScreen> {
  List<WordRecord> _allWords = [];
  WordRecord? _currentWord;
  List<String> _choices = [];
  int _score = 0;
  int _timeLeft = 30;
  Timer? _timer;
  bool _isGameOver = false;
  bool _isQuestionTrToEn = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startGame());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startGame() async {
    final db = DatabaseService.instance;
    // Fetch all words globally
    final allFiles = await db.getAllFolders();
    final List<WordRecord> allLib = [];
    for (var f in allFiles) {
      final words = await db.getWordsForFolder(f.id);
      allLib.addAll(words);
    }
    
    if (allLib.length < 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hız modu için en az 4 farklı kelime gerekiyor.')));
        Navigator.pop(context);
      }
      return;
    }
    
    if (mounted) {
      setState(() {
        _allWords = allLib;
      });
      _nextWord();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft > 0) {
        if (mounted) setState(() => _timeLeft--);
      } else {
        t.cancel();
        if (mounted) setState(() => _isGameOver = true);
      }
    });
  }

  void _nextWord() {
    final rand = math.Random();
    _currentWord = _allWords[rand.nextInt(_allWords.length)];
    _isQuestionTrToEn = rand.nextBool();
    
    final correct = _isQuestionTrToEn ? _currentWord!.english : _currentWord!.turkish;
    
    final distractors = _allWords
        .where((w) => w.id != _currentWord!.id)
        .map((w) => _isQuestionTrToEn ? w.english : w.turkish)
        .where((val) => val.isNotEmpty)
        .toSet()
        .toList()..shuffle();

    if (mounted) {
      setState(() {
        _choices = [correct, ...distractors.take(3)]..shuffle();
      });
    }
  }

  void _onChoice(String choice) {
    if (_isGameOver) return;
    
    final correct = _isQuestionTrToEn ? _currentWord!.english : _currentWord!.turkish;
    final isCorrect = choice == correct;

    if (isCorrect) {
      ref.read(audioServiceProvider).playTestCorrect();
    } else {
      ref.read(audioServiceProvider).playTestWrong();
    }

    if (isCorrect) {
      _score++;
      ref.read(questProvider.notifier).testCorrect(_currentWord!);
    } else {
      if (_score > 0) _score--;
      ref.read(questProvider.notifier).answerIncorrect(_currentWord!);
    }

    _nextWord();
  }

  @override
  Widget build(BuildContext context) {
    if (_isGameOver) return _buildHeaderSummary();

    return Scaffold(
      backgroundColor: AppTheme.skyBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('HIZ MODU', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        leading: CloseButton(onPressed: () => Navigator.pop(context), color: Colors.white),
      ),
      body: Column(
        children: [
          _buildTimerHUD(),
          const Spacer(),
          if (_currentWord != null) _buildQuestionArea(),
          const Spacer(),
          _buildChoiceGrid(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildTimerHUD() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Text('$_timeLeft', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.skyBlue)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(20)),
            child: Text('SKOR: $_score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionArea() {
    return Column(
      children: [
        Text(_isQuestionTrToEn ? _currentWord!.turkish : _currentWord!.english,
          style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white),
          textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(_isQuestionTrToEn ? 'İngilizcesini Seç' : 'Türkçesini Seç', 
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildChoiceGrid() {
    if (_choices.length < 4) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              _speedButton(_choices[0]),
              const SizedBox(width: 16),
              _speedButton(_choices[1]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _speedButton(_choices[2]),
              const SizedBox(width: 16),
              _speedButton(_choices[3]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _speedButton(String text) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _onChoice(text),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(text, 
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.skyBlue), 
            textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _buildHeaderSummary() {
    return Scaffold(
      backgroundColor: AppTheme.skyBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_off_rounded, size: 100, color: Colors.white),
            const SizedBox(height: 24),
            const Text('SÜRE DOLDU!', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 12),
            Text('Toplam Skorun: $_score', style: const TextStyle(fontSize: 24, color: Colors.white70)),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.skyBlue, padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
              child: const Text('TAMAM', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
