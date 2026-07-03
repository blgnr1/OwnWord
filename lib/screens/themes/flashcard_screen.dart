import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../state/quest_controller.dart';
import '../../state/quest_state.dart';
import '../../theme/app_theme.dart';
import '../../models/word_record.dart';
import '../../services/audio_service.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen>
    with TickerProviderStateMixin {
  List<WordRecord> _playDeck = [];
  bool _isFlipped = false;

  late AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDeck());
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _initDeck() {
    final s = ref.read(questProvider);
    setState(() {
      _playDeck = [...s.activeDeck]..shuffle();
      _isFlipped = false;
    });
  }

  void _toggleFlip() {
    ref.read(audioServiceProvider).playCardFlip();
    if (_flipController.isAnimating) return;
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  Future<void> _onSwiped(DismissDirection direction) async {
    if (_playDeck.isEmpty) return;
    final word = _playDeck.removeAt(0);
    setState(() {
      _isFlipped = false;
      _flipController.reset();
    });

    if (direction == DismissDirection.up) {
      await ref.read(questProvider.notifier).markAsKnown(word);
    } else {
      await ref.read(questProvider.notifier).markForReview(word);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questProvider);
    final isTrToEn = state.direction == StudyDirection.trToEn;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTrToEn ? '🇹🇷 Kartlar' : '🇬🇧 Kartlar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)),
                child: Text('${_playDeck.length} Kart', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
      body: _playDeck.isEmpty
          ? _buildSummary(state)
          : Stack(
              children: [
                if (_playDeck.length > 1)
                  Positioned.fill(
                    child: Center(
                      child: Transform.scale(
                        scale: 0.92,
                        child: Transform.translate(
                          offset: const Offset(0, 15),
                          child: Opacity(
                            opacity: 0.6,
                            child: _buildCardFace(_playDeck[1], isTrToEn, false, state),
                          ),
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: Dismissible(
                    key: ValueKey(_playDeck.first.id),
                    direction: DismissDirection.vertical,
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.up) {
                        ref.read(audioServiceProvider).playCardUp();
                      } else {
                        ref.read(audioServiceProvider).playCardDown();
                      }
                      return true;
                    },
                    onDismissed: _onSwiped,
                    child: GestureDetector(
                      onTap: _toggleFlip,
                      child: AnimatedBuilder(
                        animation: _flipController,
                        builder: (ctx, child) {
                          final angle = _flipController.value * math.pi;
                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            alignment: Alignment.center,
                            child: angle < math.pi / 2
                                ? _buildCardFace(_playDeck.first, isTrToEn, false, state)
                                : Transform(
                                    transform: Matrix4.identity()..rotateY(math.pi),
                                    alignment: Alignment.center,
                                    child: _buildCardFace(_playDeck.first, isTrToEn, true, state),
                                  ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummary(LinguistQuestState state) {
    // Total cards played = sum of session stats (simpler approach here is just showing success)
    final successCount = state.sessionStats['success'] ?? 0;
    // For flashcards, accuracy is success / (success + failures), but let's keep it simple
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 100, color: AppTheme.sunnyYellow),
            const SizedBox(height: 24),
            const Text('Oturum Tamamlandı!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Text('Öğrenilen: $successCount Kelime', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.skyBlue)),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('BİTİR'),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCardFace(WordRecord word, bool isTrToEn, bool isBack, LinguistQuestState state) {
    final text = isBack
        ? (isTrToEn ? word.english : word.turkish)
        : (isTrToEn ? word.turkish : word.english);

    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 420,
        child: Stack(
          children: [
            Positioned(
              top: 16, left: 16,
              child: state.comboCount > 0 ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.orange, size: 16),
                    Text('${state.comboCount} Kombo', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ) : const SizedBox.shrink(),
            ),
            Positioned(
              top: 16, left: 0, right: 0,
              child: Column(
                children: [
                  const Icon(Icons.keyboard_arrow_up_rounded, color: AppTheme.skyBlue, size: 32),
                  Text('BİLİYORUM', style: TextStyle(color: AppTheme.skyBlue, fontWeight: FontWeight.bold, fontSize: 10)),
                ],
              ),
            ),
            Positioned(
              bottom: 16, left: 0, right: 0,
              child: Column(
                children: [
                  Text('ÖĞRENMEDİM', style: TextStyle(color: AppTheme.bubblegumPink, fontWeight: FontWeight.bold, fontSize: 10)),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.bubblegumPink, size: 32),
                ],
              ),
            ),
            Positioned(
              top: 24, right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.grassGreen.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: Text('Lv.${word.masteryLevel}', style: const TextStyle(color: AppTheme.grassGreen, fontWeight: FontWeight.bold)),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(text,
                      style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: AppTheme.textMain),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Text(isBack ? 'Anlamı' : 'Dokun ve Çevir',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
