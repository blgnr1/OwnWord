import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/folder.dart';
import '../models/word_record.dart';
import '../models/gamification_models.dart';
import '../state/quest_state.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('own_words.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE words (
        id TEXT PRIMARY KEY,
        folderId TEXT NOT NULL,
        english TEXT NOT NULL,
        turkish TEXT NOT NULL,
        flashcardScore INTEGER NOT NULL DEFAULT 0,
        testScore INTEGER NOT NULL DEFAULT 0,
        spellingScore INTEGER NOT NULL DEFAULT 0,
        isBasket INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        nextReviewDate TEXT,
        consecutiveCorrect INTEGER NOT NULL DEFAULT 0,
        masteryLevel INTEGER NOT NULL DEFAULT 0,
        difficultCount INTEGER NOT NULL DEFAULT 0,
        testSuccessCount INTEGER NOT NULL DEFAULT 0,
        testAttemptCount INTEGER NOT NULL DEFAULT 0,
        spellingSuccessCount INTEGER NOT NULL DEFAULT 0,
        spellingAttemptCount INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (folderId) REFERENCES folders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_stats (
        date TEXT PRIMARY KEY,
        studied INTEGER NOT NULL DEFAULT 0,
        learned INTEGER NOT NULL DEFAULT 0,
        riveted INTEGER NOT NULL DEFAULT 0,
        basket INTEGER NOT NULL DEFAULT 0,
        totalActivity INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        id TEXT PRIMARY KEY,
        totalXP INTEGER NOT NULL DEFAULT 0,
        level INTEGER NOT NULL DEFAULT 1,
        currentStreak INTEGER NOT NULL DEFAULT 0,
        lastStudyDate TEXT,
        bossQuizProgress INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_missions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        target INTEGER NOT NULL,
        current INTEGER NOT NULL DEFAULT 0,
        xpReward INTEGER NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE words ADD COLUMN consecutiveCorrect INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_stats (
            date TEXT PRIMARY KEY,
            studied INTEGER NOT NULL DEFAULT 0,
            learned INTEGER NOT NULL DEFAULT 0,
            riveted INTEGER NOT NULL DEFAULT 0,
            basket INTEGER NOT NULL DEFAULT 0
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE words ADD COLUMN testScore INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE words ADD COLUMN spellingScore INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE words ADD COLUMN isBasket INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE daily_stats ADD COLUMN totalActivity INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE words ADD COLUMN masteryLevel INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE words ADD COLUMN difficultCount INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_profile (
            id TEXT PRIMARY KEY,
            totalXP INTEGER NOT NULL DEFAULT 0,
            level INTEGER NOT NULL DEFAULT 1,
            currentStreak INTEGER NOT NULL DEFAULT 0,
            lastStudyDate TEXT,
            bossQuizProgress INTEGER NOT NULL DEFAULT 0
          )
        ''');
      } catch (_) {}

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_missions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            target INTEGER NOT NULL,
            current INTEGER NOT NULL DEFAULT 0,
            xpReward INTEGER NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            date TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
          'ALTER TABLE words ADD COLUMN testSuccessCount INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE words ADD COLUMN testAttemptCount INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE words ADD COLUMN spellingSuccessCount INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE words ADD COLUMN spellingAttemptCount INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
    }
  }

  // ==== FOLDER CRUD ====
  Future<Folder> createFolder(String name) async {
    final db = await database;
    final folder = Folder(id: const Uuid().v4(), name: name);
    await db.insert('folders', folder.toMap());
    return folder;
  }

  Future<int> getTotalWordCount() async {
    final db = await instance.database;
    final res = await db.rawQuery('SELECT COUNT(*) FROM words');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<List<Folder>> getAllFolders() async {
    final db = await database;
    final maps = await db.query('folders');
    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<int> deleteFolder(String id) async {
    final db = await database;
    return await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // ==== WORD CRUD ====
  Future<WordRecord> insertWord(WordRecord word) async {
    final db = await database;
    final sanitizedEnglish = word.english
        .replaceFirst(RegExp(r'^[\d\p{P}\s]+', unicode: true), '')
        .trim();
    final sanitizedTurkish = word.turkish
        .replaceFirst(RegExp(r'^[\d\p{P}\s]+', unicode: true), '')
        .trim();
    final sanitizedWord = word.copyWith(
      english: sanitizedEnglish,
      turkish: sanitizedTurkish,
    );
    await db.insert(
      'words',
      sanitizedWord.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return sanitizedWord;
  }

  Future<List<WordRecord>> getWordsForFolder(String folderId) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'folderId = ?',
      whereArgs: [folderId],
    );
    return maps.map((map) => WordRecord.fromMap(map)).toList();
  }

  Future<List<WordRecord>> getWordsByCategory(
    String folderId,
    String category,
  ) async {
    final db = await database;

    // Global fetch for Difficult Words practice
    if (folderId == 'global' && category == 'difficult') {
      final res = await db.query('words');
      final allWords = res.map((json) => WordRecord.fromMap(json)).toList();
      // Filter by the new 66% success logic defined in WordRecord
      return allWords.where((w) => w.isDifficult).toList();
    }

    String where;
    List<dynamic> args;
    if (category == 'learned') {
      where = 'folderId = ? AND masteryLevel >= 3';
      args = [folderId];
    } else if (category == 'difficult') {
      where = 'folderId = ? AND difficultCount > 0';
      args = [folderId];
    } else {
      where = 'folderId = ?';
      args = [folderId];
    }

    final maps = await db.query('words', where: where, whereArgs: args);
    return maps.map((map) => WordRecord.fromMap(map)).toList();
  }

  Future<int> updateWord(WordRecord word) async {
    final db = await database;
    return await db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  Future<int> deleteWord(String id) async {
    final db = await database;
    return await db.delete('words', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertBatchWords(
    String folderId,
    List<String> englishWords,
    List<String> turkishWords,
  ) async {
    if (englishWords.length != turkishWords.length)
      throw Exception('Listeler aynı uzunlukta olmalıdır');
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < englishWords.length; i++) {
      final eng = englishWords[i]
          .replaceFirst(RegExp(r'^[\d\p{P}\s]+', unicode: true), '')
          .trim();
      final tr = turkishWords[i]
          .replaceFirst(RegExp(r'^[\d\p{P}\s]+', unicode: true), '')
          .trim();
      if (eng.isEmpty || tr.isEmpty) continue;
      final word = WordRecord(
        id: const Uuid().v4(),
        folderId: folderId,
        english: eng,
        turkish: tr,
        flashcardScore: 0,
        testScore: 0,
        spellingScore: 0,
      );
      batch.insert(
        'words',
        word.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // ==== DAILY STATS CRUD ====
  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<DayStats> getTodayStats() async {
    final db = await database;
    final today = _today();
    final maps = await db.query(
      'daily_stats',
      where: 'date = ?',
      whereArgs: [today],
    );
    if (maps.isEmpty) return DayStats(date: today);
    return DayStats.fromMap(maps.first);
  }

  Future<void> incrementDailyStat(String field) async {
    final db = await database;
    final today = _today();
    await db.execute(
      '''
      INSERT INTO daily_stats (date, studied, learned, riveted, basket, totalActivity)
        VALUES (?, 0, 0, 0, 0, 0) ON CONFLICT(date) DO NOTHING
    ''',
      [today],
    );

    if (field == 'studied' || field == 'learned') {
      await db.execute(
        'UPDATE daily_stats SET $field = $field + 1, totalActivity = totalActivity + 1 WHERE date = ?',
        [today],
      );
    } else {
      await db.execute(
        'UPDATE daily_stats SET totalActivity = totalActivity + 1 WHERE date = ?',
        [today],
      );
    }
  }

  Future<List<DayStats>> getStatsForMonth(int year, int month) async {
    final db = await database;
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final maps = await db.query(
      'daily_stats',
      where: "date LIKE ?",
      whereArgs: ['$prefix%'],
    );
    return maps.map((m) => DayStats.fromMap(m)).toList();
  }

  Future<int> getTotalLearned() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(learned) as total FROM daily_stats',
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getTotalRiveted() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(riveted) as total FROM daily_stats',
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getStreak() async {
    final db = await database;
    final all = await db.query('daily_stats', orderBy: 'date DESC');
    if (all.isEmpty) return 0;
    int streak = 0;
    DateTime current = DateTime.now();
    for (final row in all) {
      final date = DateTime.parse(row['date'] as String);
      final diff = current.difference(date).inDays;
      if (diff <= 1) {
        if ((row['studied'] as int? ?? 0) > 0) {
          streak++;
          current = date;
        } else {
          break;
        }
      } else {
        break;
      }
    }
    return streak;
  }

  // ==== PLAYER PROFILE CRUD ====
  Future<PlayerProfile> getPlayerProfile() async {
    final db = await database;
    final maps = await db.query('user_profile');
    if (maps.isEmpty) {
      final profile = PlayerProfile(id: 'default');
      await db.insert('user_profile', profile.toMap());
      return profile;
    }
    return PlayerProfile.fromMap(maps.first);
  }

  Future<void> updatePlayerProfile(PlayerProfile profile) async {
    final db = await database;
    await db.update(
      'user_profile',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  // ==== DAILY MISSIONS CRUD ====
  Future<List<DailyMission>> getMissionsForDate(String date) async {
    final db = await database;
    final maps = await db.query(
      'daily_missions',
      where: 'date = ?',
      whereArgs: [date],
    );
    return maps.map((m) => DailyMission.fromMap(m)).toList();
  }

  Future<void> insertMissions(List<DailyMission> missions) async {
    final db = await database;
    final batch = db.batch();
    for (var m in missions) {
      batch.insert('daily_missions', m.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateMission(DailyMission mission) async {
    final db = await database;
    await db.update(
      'daily_missions',
      mission.toMap(),
      where: 'id = ?',
      whereArgs: [mission.id],
    );
  }
}
