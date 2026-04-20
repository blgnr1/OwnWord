import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import '../services/database_service.dart';
import '../state/quest_controller.dart';
import '../state/quest_state.dart';
import '../theme/app_theme.dart';
import 'themes/flashcard_screen.dart';
import 'themes/test_screen.dart';
import 'themes/spelling_screen.dart';

class FolderDetailScreen extends ConsumerStatefulWidget {
  final Folder folder;
  const FolderDetailScreen({super.key, required this.folder});

  @override
  ConsumerState<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends ConsumerState<FolderDetailScreen> {
  final _db = DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(questProvider.notifier).loadFolder(widget.folder);
    });
  }

  void _showBatchImportBottomSheet() {
    final engController = TextEditingController();
    final trController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                const Text('Toplu Kelime Ekle', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textMain)),
                const SizedBox(height: 8),
                const Text('Her satıra bir kelime gelecek şekilde yazın.', style: TextStyle(color: AppTheme.textMuted)),
                const SizedBox(height: 24),
                
                _batchInputField('English (İngilizce)', engController, AppTheme.skyBlue),
                const SizedBox(height: 12),
                _batchInputField('Türkçe Karşılıkları', trController, AppTheme.bubblegumPink),
                
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.skyBlue,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () async {
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);
                      final eng = engController.text.trim().split('\n').where((s) => s.trim().isNotEmpty).toList();
                      final tr  = trController.text.trim().split('\n').where((s) => s.trim().isNotEmpty).toList();
                      if (eng.isEmpty || tr.isEmpty) return;
                      try {
                        await _db.insertBatchWords(widget.folder.id, eng, tr);
                        if (!ctx.mounted) return;
                        nav.pop();
                        ref.read(questProvider.notifier).loadFolder(widget.folder);
                        messenger.showSnackBar(const SnackBar(content: Text('Kelimeler başarıyla eklendi! 🚀')));
                      } catch (e) {
                        if (!ctx.mounted) return;
                        messenger.showSnackBar(SnackBar(content: Text('Hata: ${e.toString()}')));
                      }
                    },
                    child: const Text('İÇE AKTAR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _batchInputField(String label, TextEditingController controller, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ),
        TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'word 1\nword 2...',
            filled: true,
            fillColor: color.withAlpha(10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: color, width: 2)),
          ),
        ),
      ],
    );
  }

  /// Shows direction selection modal before launching a theme
  Future<void> _launchTheme(BuildContext context, String themeKey) async {
    StudyDirection? dir;
    
    if (themeKey == 'spelling_audio') {
      dir = StudyDirection.enToTr;
    } else {
      dir = await showModalBottomSheet<StudyDirection>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        builder: (ctx) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 60, height: 6,
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 32),
                  const Text('Antrenman Yönü', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24, color: AppTheme.textMain)),
                  const SizedBox(height: 32),
                  _directionButton(ctx, '🇹🇷  Türkçe → İngilizce', StudyDirection.trToEn, AppTheme.bubblegumPink),
                  const SizedBox(height: 16),
                  _directionButton(ctx, '🇬🇧  İngilizce → Türkçe', StudyDirection.enToTr, AppTheme.skyBlue),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      );
    }
    
    if (dir == null || !context.mounted) return;

    if (context.mounted) {
      ref.read(questProvider.notifier).setDirection(dir);
      ref.read(questProvider.notifier).setTheme(themeKey);
    }

    Widget screen;
    switch (themeKey) {
      case 'flashcards':        screen = const FlashcardScreen(); break;
      case 'test':              screen = const TestScreen();      break;
      case 'spelling_audio':    screen = const SpellingScreen(isAudioMode: true); break;
      default:                  screen = const SpellingScreen(isAudioMode: false);
    }
    Navigator.push(context, PageRouteBuilder(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (ctx, a, b) => screen,
    ));
  }

  Widget _directionButton(BuildContext ctx, String label, StudyDirection value, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: () => Navigator.pop(ctx, value),
        child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _themeCard(BuildContext context, {
    required String title, required String subtitle,
    required IconData icon, required Color color,
    required String themeKey, required bool disabled,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: disabled ? Colors.transparent : color.withAlpha(40), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: disabled ? null : () => _launchTheme(context, themeKey),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: disabled ? Colors.black12 : color.withAlpha(30),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: disabled ? Colors.black26 : color, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20,
                        color: disabled ? Colors.black26 : AppTheme.textMain)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(
                        fontSize: 15,
                        color: disabled ? Colors.black12 : AppTheme.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: disabled ? Colors.black12 : color),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questProvider);
    final hasWords = state.activeDeck.isNotEmpty || state.learnedDeck.isNotEmpty;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.skyBlue, size: 28),
            onPressed: _showBatchImportBottomSheet,
            tooltip: 'Kelime Ekle',
          )
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.bubblegumPink))
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
              children: [
                const Text('Antrenman Modları',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
                const SizedBox(height: 24),
                _themeCard(context,
                  title: 'Kartlar',
                  subtitle: 'Kaydırarak öğren',
                  icon: Icons.swipe_rounded,
                  color: AppTheme.bubblegumPink,
                  themeKey: 'flashcards',
                  disabled: state.activeDeck.isEmpty,
                ),
                _themeCard(context,
                  title: 'Çoktan Seçmeli',
                  subtitle: 'Bilgini test et',
                  icon: Icons.quiz_rounded,
                  color: AppTheme.skyBlue,
                  themeKey: 'test',
                  disabled: !hasWords,
                ),
                _themeCard(context,
                  title: 'Yazım (Anlam)',
                  subtitle: 'Anlamına bakarak yaz',
                  icon: Icons.translate_rounded,
                  color: Colors.orangeAccent,
                  themeKey: 'spelling',
                  disabled: !hasWords,
                ),
                _themeCard(context,
                  title: 'Yazım (Dinleme)',
                  subtitle: 'Duyduğunu harfle',
                  icon: Icons.volume_up_rounded,
                  color: AppTheme.skyBlue,
                  themeKey: 'spelling_audio',
                  disabled: !hasWords,
                ),
              ],
            ),
    );
  }
}
