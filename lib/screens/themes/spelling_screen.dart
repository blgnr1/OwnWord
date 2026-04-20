import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../state/quest_controller.dart';
import '../../state/quest_state.dart';
import '../../theme/app_theme.dart';
import '../../models/word_record.dart';
import '../../services/audio_service.dart';

class SpellingScreen extends ConsumerStatefulWidget {
  final bool isAudioMode;
  const SpellingScreen({super.key, this.isAudioMode = false});

  @override
  ConsumerState<SpellingScreen> createState() => _SpellingScreenState();
}

class _SpellingScreenState extends ConsumerState<SpellingScreen> with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  List<WordRecord> _playList = [];
  int _currentIndex = 0;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Color _cardColor = AppTheme.skyBlue.withAlpha(10);
  Color _cardSideColor = AppTheme.skyBlue.withAlpha(30);
  bool _inputLocked = false;
  bool _showErrorOverlay = false;
  String _errorWord = '';
  late bool _isAudioMode;
  final Set<WordRecord> _incorrectWords = {};
  bool _isReviewPhase = false;
  int _initialTotalCount = 0;


  @override
  void initState() {
    super.initState();
    _isAudioMode = widget.isAudioMode;
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeck();
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
      if (_isAudioMode) {
        Future.delayed(const Duration(milliseconds: 300), _speak);
      }
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _tts.stop();
    super.dispose();
  }

  void _initDeck() {
    final s = ref.read(questProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(questProvider.notifier).resetSessionStats();
    });

    final candidates = [...s.activeDeck, ...s.learnedDeck]..shuffle();
    setState(() {
      _playList = candidates;
      _initialTotalCount = _playList.length;
    });
  }

  Future<void> _speak() async {
    if (_playList.isEmpty) return;
    await _tts.speak(_playList[_currentIndex].english);
  }

  Future<void> _submit() async {
    if (_inputLocked || _controller.text.trim().isEmpty) return;
    final word = _playList[_currentIndex];
    final result = await ref.read(questProvider.notifier).submitSpelling(word, _controller.text, isAudioDictation: _isAudioMode);

    if (result == 'correct') {
      ref.read(audioServiceProvider).playSpellingCorrect();
      // No questProvider update in review phase
      setState(() {
        _cardColor = AppTheme.grassGreen.withAlpha(40);
        _cardSideColor = AppTheme.grassGreen;
      });
      _advance();
    } else {
      ref.read(audioServiceProvider).playSpellingWrong();
      if (!_isReviewPhase) {
        _incorrectWords.add(word);
      }
      final targetWord = (_isAudioMode || ref.read(questProvider).direction == StudyDirection.trToEn) ? word.english : word.turkish;
      setState(() {
        _inputLocked = true;
        _showErrorOverlay = true;
        _errorWord = targetWord;
        _cardColor = Colors.redAccent.withAlpha(40);
        _cardSideColor = Colors.redAccent;
      });
      
      // Aggressively re-assert focus BEFORE state change to keep keyboard alive
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _inputLocked = false;
          _showErrorOverlay = false;
        });
        _advance();
      });
    }
  }

  void _advance() {
    // Re-assert focus immediately before the delay to keep keyboard alive
    _focusNode.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.show');

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      // Focus call BEFORE setState can help bridge the gap
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
      
      setState(() {
        _currentIndex++;
        _controller.clear();
        _cardColor = AppTheme.skyBlue.withAlpha(10);
        _cardSideColor = AppTheme.skyBlue.withAlpha(30);

        if (_currentIndex >= _playList.length && _incorrectWords.isNotEmpty) {
          _isReviewPhase = true;
          _playList = _incorrectWords.toList()..shuffle();
          _incorrectWords.clear();
          _currentIndex = 0;
        }

        if (_currentIndex < _playList.length) {
          _focusNode.requestFocus();
          SystemChannels.textInput.invokeMethod('TextInput.show');
          if (_isAudioMode) {
            _speak();
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questProvider);

    if (_playList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yazım Atölyesi')),
        body: Center(child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Geri Dön'))),
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
            const Icon(Icons.workspace_premium_rounded, color: AppTheme.sunnyYellow, size: 100),
            const SizedBox(height: 24),
            const Text('Oturum Tamamlandı!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
            const SizedBox(height: 16),
            Text('Doğruluk Oranı: %$accuracy', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.skyBlue)),
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

    return Scaffold(
      resizeToAvoidBottomInset: true, 
      appBar: AppBar(
        title: Text(_isReviewPhase ? 'Tekrar Dene' : 'Yazım · ${_currentIndex + 1}/${_playList.length}'),
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
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildWordHUD(word, state),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _buildInputArea(),
            ],
          ),
          if (_showErrorOverlay) _buildErrorOverlay(),
        ],
      ),
    );
  }

  Widget _buildWordHUD(WordRecord word, LinguistQuestState state) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardSideColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_isAudioMode) ...[
              IconButton.filled(
                iconSize: 56,
                onPressed: _speak,
                icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: AppTheme.skyBlue),
              ),
              const SizedBox(height: 12),
              const Text('Duyduğun kelimeyi yaz', style: TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.bold)),
            ] else ...[
              Text(state.direction == StudyDirection.trToEn ? word.turkish : word.english,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppTheme.textMain),
                textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(state.direction == StudyDirection.trToEn ? 'İngilizce çevirisini yaz' : 'Türkçe Karşılığını yaz', style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, -4))]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            readOnly: _inputLocked,
            onTap: () {
               // Ensure keyboard stays up
               SystemChannels.textInput.invokeMethod('TextInput.show');
            },
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: _inputLocked ? 'Doğru cevap bekleniyor...' : 'Cevabı yaz ve Gönder',
              filled: true,
              fillColor: AppTheme.skyBlue.withAlpha(5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.skyBlue, width: 2)),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.send,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _inputLocked ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.skyBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('GÖNDER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(100),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                const SizedBox(height: 16),
                const Text('Yanlış Cevap', style: TextStyle(fontSize: 18, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_errorWord, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.redAccent), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text('Doğru cevap yukarıdadır.', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
