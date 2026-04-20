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

  @override
  void initState() {
    super.initState();
    _loadFolders();
    Future.microtask(() {
      ref.read(gamificationProvider.notifier).init();
    });
  }

  Future<void> _refreshAll() async {
    await _loadFolders();
    if (mounted) setState(() {}); // Triggers FutureBuilder for word count
    ref.read(gamificationProvider.notifier).init();
  }

  Future<void> _loadFolders() async {
    final folders = await _db.getAllFolders();
    if (mounted) {
      setState(() {
        _folders = folders;
      });
    }
  }

  void _showFoldersScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) =>
          _FoldersView(folders: _folders, onRefresh: _refreshAll, db: _db),
    ).then((_) => _refreshAll());
  }

  @override
  Widget build(BuildContext context) {
    final gState = ref.watch(gamificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OwnWords',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.folder_open_rounded,
            color: AppTheme.skyBlue,
            size: 28,
          ),
          onPressed: _showFoldersScreen,
        ),
        actions: [const SizedBox(width: 8)],
      ),
      body: Stack(
        children: [
          (gState.isLoading)
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.bubblegumPink,
                  ),
                )
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    40 + MediaQuery.of(context).viewPadding.bottom,
                  ),
                  children: [
                    _buildGamificationHeader(gState.profile),
                    const SizedBox(height: 24),
                    _buildMissionsList(gState.todayMissions),
                    const SizedBox(height: 32),
                    _buildNewGamesSection(gState.profile),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildGamificationHeader(PlayerProfile profile) {
    // TotalXP = 100 * Level^2.
    // Need current level start XP and next level start XP
    final currentLevelXP = 100 * math.pow(profile.level - 1, 2).toInt();
    final nextLevelXP = 100 * math.pow(profile.level, 2).toInt();
    final totalNeeded = nextLevelXP - currentLevelXP;
    final gainedInCurrent = profile.totalXP - currentLevelXP;
    final progress = (gainedInCurrent / totalNeeded).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bubblegumPink.withAlpha(240),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.bubblegumPink.withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 8),
              Text(
                '${profile.currentStreak}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${profile.level}',
                  style: const TextStyle(
                    color: AppTheme.bubblegumPink,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seviye ${profile.level}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withAlpha(50),
                        color: Colors.white,
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$gainedInCurrent / $totalNeeded XP to Level ${profile.level + 1}',
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
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 16),
            _gameTile(
              'Boss Quiz',
              isBossLocked
                  ? '40 Kelime Gerekli ($totalWords/40)'
                  : 'Karışık 40 Soru / Test & Yazım',
              isBossLocked
                  ? Icons.lock_rounded
                  : Icons.workspace_premium_rounded,
              isBossLocked ? Colors.grey : Colors.deepPurpleAccent,
              isBossLocked
                  ? () {}
                  : () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        transitionDuration: Duration.zero,
                        pageBuilder: (ctx, a, b) => BossQuizScreen(),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            _gameTile(
              'Hız Modu',
              totalWords < 4
                  ? '4 Kelime Gerekli ($totalWords/4)'
                  : '30 Saniyede Maksimum Skor',
              totalWords < 4 ? Icons.lock_rounded : Icons.timer_rounded,
              totalWords < 4 ? Colors.grey : AppTheme.skyBlue,
              totalWords < 4
                  ? () {}
                  : () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        transitionDuration: Duration.zero,
                        pageBuilder: (ctx, a, b) => const SpeedModeScreen(),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            _gameTile(
              'Zorlanılan Kelimeler',
              'Hatalı ve Zor Kelimeler Pratiği',
              Icons.psychology_rounded,
              Colors.redAccent,
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
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
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
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color.withAlpha(100),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionsList(List<DailyMission> missions) {
    if (missions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Günlük Görevler',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 12),
        ...missions.map(
          (m) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: m.isCompleted ? Colors.green.withAlpha(20) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: m.isCompleted
                    ? Colors.green.withAlpha(50)
                    : Colors.black.withAlpha(10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  m.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: m.isCompleted ? Colors.green : Colors.black12,
                  size: 28,
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
                          fontSize: 16,
                          decoration: m.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: m.current / m.target,
                        backgroundColor: Colors.black12,
                        color: AppTheme.skyBlue,
                        minHeight: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${math.min(m.current, m.target)}/${m.target}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FoldersView extends StatefulWidget {
  final List<Folder> folders;
  final VoidCallback onRefresh;
  final DatabaseService db;
  const _FoldersView({
    required this.folders,
    required this.onRefresh,
    required this.db,
  });

  @override
  State<_FoldersView> createState() => _FoldersViewState();
}

class _FoldersViewState extends State<_FoldersView> {
  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Klasör'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Klasör Adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await widget.db.createFolder(controller.text);
                widget.onRefresh();
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Klasörlerim',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: _showAddDialog,
                icon: const Icon(
                  Icons.add_box_rounded,
                  color: AppTheme.bubblegumPink,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: widget.folders.isEmpty
                ? const Center(child: Text('Henüz klasörünüz yok.'))
                : ListView.builder(
                    itemCount: widget.folders.length,
                    itemBuilder: (ctx, i) {
                      final f = widget.folders[i];
                      return Dismissible(
                        key: Key(f.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          padding: const EdgeInsets.only(right: 24),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        onDismissed: (_) async {
                          await widget.db.deleteFolder(f.id);
                          widget.onRefresh();
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.folder_rounded,
                              color: AppTheme.skyBlue,
                            ),
                            title: Text(
                              f.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) =>
                                      FolderDetailScreen(folder: f),
                                ),
                              ).then((_) => widget.onRefresh());
                            },
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.info_outline,
                                color: AppTheme.skyBlue,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => WordListScreen(
                                      folderId: f.id,
                                      category: 'all',
                                      title: '${f.name} Kelimeleri',
                                    ),
                                  ),
                                ).then((_) => widget.onRefresh());
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
