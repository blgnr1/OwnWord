import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/folder.dart';
import '../models/gamification_models.dart';
import '../state/gamification_controller.dart';
import 'folder_detail_screen.dart';
import 'word_list_screen.dart';
import 'themes/boss_quiz_screen.dart';
import 'themes/speed_mode_screen.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _db = DatabaseService.instance;
  List<Folder> _folders = [];
  Map<String, int> _wordCounts = {};
  List<bool> _weekStudyDays = List.filled(7, false);

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await _loadFolders();
    final weekDays = await _getWeekStudyDays();
    if (mounted) {
      setState(() {
        _weekStudyDays = weekDays;
      });
    }
    ref.read(gamificationProvider.notifier).init();
  }

  Future<void> _loadFolders() async {
    final folders = await _db.getAllFolders();
    final counts = await _db.getFolderWordCounts();
    if (mounted) {
      setState(() {
        _folders = folders;
        _wordCounts = counts;
      });
    }
  }

  Future<List<bool>> _getWeekStudyDays() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final List<bool> studiedDays = List.filled(7, false);

    try {
      final stats = await _db.getStatsForMonth(now.year, now.month);
      
      final prevMonth = now.subtract(const Duration(days: 7));
      if (prevMonth.month != now.month) {
        final prevStats = await _db.getStatsForMonth(prevMonth.year, prevMonth.month);
        stats.addAll(prevStats);
      }

      for (int i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        final dateStr = day.toIso8601String().substring(0, 10);
        final hasStudied = stats.any((s) => s.date == dateStr && s.studied > 0);
        studiedDays[i] = hasStudied;
      }
    } catch (e) {
      print('Error getting week study days: $e');
    }
    return studiedDays;
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Yeni Klasör Ekle',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kelime gruplarını düzenlemek için yeni bir kategori oluşturun.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Klasör Adı',
                  hintText: 'Örn: Almanca Temel, İş İngilizcesi',
                  filled: true,
                  fillColor: AppTheme.skyBlue.withAlpha(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppTheme.skyBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(color: Colors.black.withAlpha(20)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'İptal',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.skyBlue,
                        foregroundColor: Colors.white,
                        shadowColor: AppTheme.skyBlue.withAlpha(80),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () async {
                        if (controller.text.trim().isNotEmpty) {
                          await _db.createFolder(controller.text.trim());
                          ref.read(gamificationProvider.notifier).updateProgress('create_folder', 1);
                          _refreshAll();
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      child: const Text(
                        'Oluştur',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteFolder(String folderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Klasörü Sil'),
        content: const Text('Bu klasörü ve içindeki tüm kelimeleri silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await _db.deleteFolder(folderId);
              _refreshAll();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gState = ref.watch(gamificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OwnWords',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 0.5),
        ),
      ),
      body: gState.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.bubblegumPink,
              ),
            )
          : RefreshIndicator(
              color: AppTheme.bubblegumPink,
              onRefresh: _refreshAll,
              child: ListView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  40 + MediaQuery.of(context).viewPadding.bottom,
                ),
                children: [
                  _buildGamificationHeader(gState.profile),
                  const SizedBox(height: 20),
                  _buildStreakCalendar(),
                  const SizedBox(height: 28),
                  _buildMissionsList(gState.todayMissions),
                  const SizedBox(height: 28),
                  _buildFoldersSection(),
                  const SizedBox(height: 28),
                  _buildNewGamesSection(gState.profile),
                ],
              ),
            ),
    );
  }

  Widget _buildGamificationHeader(PlayerProfile profile) {
    final currentLevelXP = 100 * math.pow(profile.level - 1, 2).toInt();
    final nextLevelXP = 100 * math.pow(profile.level, 2).toInt();
    final totalNeeded = nextLevelXP - currentLevelXP;
    final gainedInCurrent = profile.totalXP - currentLevelXP;
    final progress = (gainedInCurrent / totalNeeded).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6C63FF),
            AppTheme.bubblegumPink,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppTheme.bubblegumPink.withAlpha(60),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toplam Puan',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${profile.totalXP} XP',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.amber,
                      size: 22,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.currentStreak} GÜN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${profile.level}',
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Seviye ${profile.level}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Seviye ${profile.level + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withAlpha(50),
                        color: Colors.white,
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bir sonraki seviye için $gainedInCurrent / $totalNeeded XP',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCalendar() {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1; // 0 (Mon) to 6 (Sun)
    final daysOfWeek = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.premiumShadow,
        border: Border.all(color: const Color(0xFFEFEFEF), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Haftalık İlerleme',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Haftayı tamamlamak için her gün çalış!',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Icon(Icons.calendar_month_rounded, color: AppTheme.skyBlue, size: 26),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final dayName = daysOfWeek[i];
                final studied = _weekStudyDays[i];
                final isToday = i == todayIndex;
                final isFuture = i > todayIndex;

                Color circleColor = Colors.transparent;
                Color textColor = AppTheme.textMain;
                Widget iconChild = Text(
                  dayName.substring(0, 1),
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
                );

                if (isFuture) {
                  circleColor = Colors.transparent;
                  textColor = AppTheme.textMuted.withAlpha(100);
                  iconChild = Text(
                    dayName.substring(0, 1),
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
                  );
                } else if (studied) {
                  circleColor = AppTheme.grassGreen;
                  iconChild = const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 16);
                } else if (isToday) {
                  circleColor = AppTheme.bubblegumPink.withAlpha(20);
                  textColor = AppTheme.bubblegumPink;
                  iconChild = Text(
                    dayName.substring(0, 1),
                    style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 15),
                  );
                } else {
                  circleColor = Colors.black.withAlpha(10);
                  textColor = AppTheme.textMuted;
                  iconChild = const Icon(Icons.close_rounded, color: Colors.black26, size: 14);
                }

                return Column(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: circleColor,
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(color: AppTheme.bubblegumPink, width: 2)
                            : studied
                                ? null
                                : Border.all(color: Colors.black.withAlpha(15), width: 1.5),
                        boxShadow: studied
                            ? [
                                BoxShadow(
                                  color: AppTheme.grassGreen.withAlpha(80),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: iconChild,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday
                            ? AppTheme.bubblegumPink
                            : isFuture
                                ? AppTheme.textMuted.withAlpha(100)
                                : AppTheme.textMuted,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoldersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Klasörlerim',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.textMain,
              ),
            ),
            IconButton(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.skyBlue, size: 30),
              tooltip: 'Yeni Klasör Ekle',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _folders.isEmpty
            ? _buildEmptyFoldersCard()
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _folders.length + 1,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (ctx, i) {
                  if (i == _folders.length) {
                    return _buildAddFolderGridCard();
                  }
                  final f = _folders[i];
                  final count = _wordCounts[f.id] ?? 0;
                  return _buildFolderGridCard(f, count);
                },
              ),
      ],
    );
  }

  Widget _buildEmptyFoldersCard() {
    return InkWell(
      onTap: _showAddDialog,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFEFEFEF), width: 1.0),
          boxShadow: AppTheme.premiumShadow,
        ),
        child: Column(
          children: [
            const Icon(Icons.create_new_folder_rounded, size: 48, color: AppTheme.skyBlue),
            const SizedBox(height: 12),
            const Text(
              'Klasörünüz Bulunmuyor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Kelime eklemek için önce bir klasör oluşturun.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderGridCard(Folder folder, int count) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEFEFEF), width: 1.0),
        boxShadow: AppTheme.premiumShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => FolderDetailScreen(folder: folder),
            ),
          ).then((_) => _refreshAll());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.skyBlue.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder_rounded,
                      color: AppTheme.skyBlue,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => _deleteFolder(folder.id),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$count Kelime',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => WordListScreen(
                                folderId: folder.id,
                                category: 'all',
                                title: '${folder.name} Kelimeleri',
                              ),
                            ),
                          ).then((_) => _refreshAll());
                        },
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: AppTheme.skyBlue,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddFolderGridCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.skyBlue.withAlpha(10),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.skyBlue.withAlpha(100),
          width: 1.5,
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.skyBlue.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _showAddDialog,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppTheme.skyBlue,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Klasör Ekle',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.skyBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionsList(List<DailyMission> missions) {
    if (missions.isEmpty) return const SizedBox.shrink();

    final typeIcons = {
      'learn_words': Icons.auto_stories_rounded,
      'answer_questions': Icons.checklist_rtl_rounded,
      'do_spelling': Icons.edit_note_rounded,
      'speed_mode': Icons.timer_rounded,
      'combo_streak': Icons.bolt_rounded,
      'create_folder': Icons.create_new_folder_rounded,
      'difficult_practice': Icons.psychology_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Günlük Görevler',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 12),
        ...missions.map(
          (m) {
            final icon = typeIcons[m.type] ?? Icons.stars_rounded;
            final iconColor = m.isCompleted ? Colors.green : AppTheme.skyBlue;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: m.isCompleted ? const Color(0xFFE8F5E9).withAlpha(120) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppTheme.premiumShadow,
                border: Border.all(
                  color: m.isCompleted
                      ? const Color(0xFFC8E6C9)
                      : const Color(0xFFEFEFEF),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: m.isCompleted ? Colors.green.withAlpha(20) : AppTheme.skyBlue.withAlpha(15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: m.isCompleted ? TextDecoration.lineThrough : null,
                            color: m.isCompleted ? Colors.black54 : AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (m.target > 0) ? (m.current / m.target) : 0,
                            backgroundColor: Colors.black12,
                            color: m.isCompleted ? Colors.green : AppTheme.skyBlue,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on_rounded, color: Colors.orange, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              '+${m.xpReward} XP',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${math.min(m.current, m.target)}/${m.target}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNewGamesSection(PlayerProfile profile) {
    return FutureBuilder<int>(
      future: _db.getTotalWordCount(),
      builder: (context, snapshot) {
        final totalWords = snapshot.data ?? 0;
        final isBossLocked = totalWords < 40;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Oyun Modları',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 16),
            _gameTile(
              'Boss Quiz',
              isBossLocked
                  ? '40 Kelime Gerekli ($totalWords/40)'
                  : 'Karışık 40 Soru / Test & Yazım',
              isBossLocked ? Icons.lock_rounded : Icons.workspace_premium_rounded,
              isBossLocked
                  ? const [Colors.grey, Colors.blueGrey]
                  : const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
              isBossLocked
                  ? () {}
                  : () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: Duration.zero,
                          pageBuilder: (ctx, a, b) => const BossQuizScreen(),
                        ),
                      ).then((_) => _refreshAll()),
            ),
            const SizedBox(height: 12),
            _gameTile(
              'Hız Modu',
              totalWords < 4
                  ? '4 Kelime Gerekli ($totalWords/4)'
                  : '30 Saniyede Maksimum Skor',
              totalWords < 4 ? Icons.lock_rounded : Icons.timer_rounded,
              totalWords < 4
                  ? const [Colors.grey, Colors.blueGrey]
                  : const [Color(0xFF00E5FF), Color(0xFF2979FF)],
              totalWords < 4
                  ? () {}
                  : () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: Duration.zero,
                          pageBuilder: (ctx, a, b) => const SpeedModeScreen(),
                        ),
                      ).then((_) {
                        // Trigger dynamic mission progress for speed mode completion
                        ref.read(gamificationProvider.notifier).updateProgress('speed_mode', 1);
                        _refreshAll();
                      }),
            ),
            const SizedBox(height: 12),
            _gameTile(
              'Zorlanılan Kelimeler',
              'Hatalı ve Zor Kelimeler Pratiği',
              Icons.psychology_rounded,
              const [Color(0xFFFF5252), Color(0xFFFF1744)],
              () => Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: Duration.zero,
                  pageBuilder: (ctx, a, b) => const WordListScreen(
                    folderId: 'global',
                    category: 'difficult',
                    title: 'Zorlanılan Kelimeler',
                  ),
                ),
              ).then((_) => _refreshAll()),
            ),
          ],
        );
      },
    );
  }

  Widget _gameTile(
    String title,
    String subtitle,
    IconData icon,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradientColors[0].withAlpha(20),
            gradientColors[1].withAlpha(20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gradientColors[1].withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: gradientColors[1].withAlpha(30), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[1].withAlpha(80),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: gradientColors[1].withAlpha(120),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
