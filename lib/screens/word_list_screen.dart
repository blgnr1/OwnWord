import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:own_words/models/word_record.dart';
import 'package:own_words/services/database_service.dart';
import 'package:own_words/theme/app_theme.dart';
import 'package:own_words/state/quest_controller.dart';
import 'package:own_words/state/quest_state.dart';
import 'package:own_words/screens/themes/flashcard_screen.dart';
import 'package:own_words/screens/themes/test_screen.dart';
import 'package:own_words/screens/themes/spelling_screen.dart';

class WordListScreen extends ConsumerStatefulWidget {
  final String folderId;
  final String category;
  final String title;

  const WordListScreen({
    super.key,
    required this.folderId,
    required this.category,
    required this.title,
  });

  @override
  ConsumerState<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends ConsumerState<WordListScreen> {
  final _db = DatabaseService.instance;
  List<WordRecord> _words = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final words = await _db.getWordsByCategory(widget.folderId, widget.category);
    if (!mounted) return;
    setState(() {
      _words = words;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.bubblegumPink))
          : _words.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _words.length,
                  itemBuilder: (ctx, i) {
                    final w = _words[i];
                    return Dismissible(
                      key: Key(w.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.only(right: 24),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                      ),
                      onDismissed: (_) async {
                        await _db.deleteWord(w.id);
                        setState(() {
                          _words.removeAt(i);
                        });
                      },
                      child: _WordItem(word: w),
                    );
                  },
                ),
      floatingActionButton: (_words.isNotEmpty && widget.category == 'difficult')
          ? FloatingActionButton.extended(
              onPressed: () => _showModeSelection(context),
              backgroundColor: Colors.redAccent,
              icon: const Icon(Icons.bolt_rounded, color: Colors.white),
              label: const Text('Hemen Çalış', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  void _showModeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Çalışma Modunu Seç', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
              const SizedBox(height: 24),
              _modeItem(ctx, 'Kartlar', Icons.swipe_rounded, AppTheme.bubblegumPink, 'flashcards'),
              _modeItem(ctx, 'Çoktan Seçmeli', Icons.quiz_rounded, AppTheme.skyBlue, 'test'),
              _modeItem(ctx, 'Yazım (Anlam)', Icons.translate_rounded, Colors.orangeAccent, 'spelling'),
              _modeItem(ctx, 'Yazım (Dinleme)', Icons.volume_up_rounded, AppTheme.skyBlue, 'spelling_audio'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeItem(BuildContext ctx, String title, IconData icon, Color color, String themeKey) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        Navigator.pop(ctx);
        StudyDirection? dir;
        if (themeKey == 'spelling_audio') {
          dir = StudyDirection.enToTr;
        } else {
          dir = await showModalBottomSheet<StudyDirection>(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            builder: (c) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Antrenman Yönü', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 24),
                    _directionBtn(c, '🇹🇷 TR → EN', StudyDirection.trToEn, AppTheme.bubblegumPink),
                    const SizedBox(height: 12),
                    _directionBtn(c, '🇬🇧 EN → TR', StudyDirection.enToTr, AppTheme.skyBlue),
                  ],
                ),
              ),
            ),
          );
        }
        
        if (dir == null) return;
        
        ref.read(questProvider.notifier).setDirection(dir);
        ref.read(questProvider.notifier).setTheme(themeKey);
        await ref.read(questProvider.notifier).loadSpecialCategory(widget.title, _words);
        
        if (!context.mounted) return;
        
        Widget screen;
        switch (themeKey) {
          case 'flashcards': screen = const FlashcardScreen(); break;
          case 'test':       screen = const TestScreen();      break;
          case 'spelling_audio': screen = const SpellingScreen(isAudioMode: true); break;
          default:           screen = const SpellingScreen(isAudioMode: false);
        }
        
        Navigator.push(context, PageRouteBuilder(transitionDuration: Duration.zero, pageBuilder: (a, b, c) => screen));
      },
    );
  }

  Widget _directionBtn(BuildContext ctx, String label, StudyDirection val, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: () => Navigator.pop(ctx, val),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_stories_rounded, size: 80, color: Colors.black12),
          const SizedBox(height: 16),
          Text('Bu kategoride kelime yok.', style: TextStyle(color: AppTheme.textMuted, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _WordItem extends StatelessWidget {
  final WordRecord word;

  const _WordItem({required this.word});

  @override
  Widget build(BuildContext context) {

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(word.english, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
                      Text(word.turkish, style: const TextStyle(fontSize: 16, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                if (word.isDifficult)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.redAccent.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                        const SizedBox(width: 4),
                        Text('ZORLANILAN', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMasteryProgress(),
          ],
        ),
      ),
    );
  }

  Widget _buildMasteryProgress() {
    final level = word.masteryLevel;
    final labels = ['Yeni', 'Görüldü', 'Tanıdık', 'Öğrenildi', 'Usta'];
    final colors = [
      Colors.black12,
      AppTheme.skyBlue,
      Colors.orangeAccent,
      AppTheme.grassGreen,
      Colors.deepPurpleAccent,
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(labels[level], style: TextStyle(fontWeight: FontWeight.bold, color: colors[level], fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(4, (index) {
            final isActive = index < level;
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                decoration: BoxDecoration(
                  color: isActive ? colors[level] : Colors.black.withAlpha(10),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

