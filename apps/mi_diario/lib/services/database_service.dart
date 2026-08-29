import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/diary_entry.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'mi_diario.db');

    _db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE diary_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entry_date TEXT NOT NULL,
            body TEXT NOT NULL DEFAULT '',
            reminder TEXT NOT NULL DEFAULT '',
            reminder_completed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        await db.execute('CREATE INDEX idx_diary_entries_date ON diary_entries(entry_date);');
        await db.execute('CREATE INDEX idx_diary_entries_body ON diary_entries(body);');
        await db.execute('CREATE INDEX idx_diary_entries_reminder ON diary_entries(reminder);');
        await db.execute('CREATE INDEX idx_diary_entries_reminder_completed ON diary_entries(reminder_completed);');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='diary_entries';",
        );

        if (tables.isEmpty) {
          await db.execute('''
            CREATE TABLE diary_entries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              entry_date TEXT NOT NULL,
              body TEXT NOT NULL DEFAULT '',
              reminder TEXT NOT NULL DEFAULT '',
              reminder_completed INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');
        }

        try {
          await db.execute(
            'ALTER TABLE diary_entries ADD COLUMN reminder_completed INTEGER NOT NULL DEFAULT 0;',
          );
        } catch (_) {}

        try {
          await db.execute('CREATE INDEX IF NOT EXISTS idx_diary_entries_date ON diary_entries(entry_date);');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_diary_entries_body ON diary_entries(body);');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_diary_entries_reminder ON diary_entries(reminder);');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_diary_entries_reminder_completed ON diary_entries(reminder_completed);');
        } catch (_) {}
      },
    );
  }

  Database get db {
    final current = _db;
    if (current == null) {
      throw StateError('DatabaseService no inicializado');
    }
    return current;
  }

  Future<int> saveEntry(DiaryEntry entry) async {
    final now = DateTime.now().toIso8601String();

    if (entry.id == null) {
      return db.insert('diary_entries', {
        'entry_date': entry.entryDate,
        'body': entry.body,
        'reminder': entry.reminder,
        'reminder_completed': entry.reminderCompleted ? 1 : 0,
        'created_at': entry.createdAt,
        'updated_at': now,
      });
    }

    await db.update(
      'diary_entries',
      {
        'entry_date': entry.entryDate,
        'body': entry.body,
        'reminder': entry.reminder,
        'reminder_completed': entry.reminderCompleted ? 1 : 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );

    return entry.id!;
  }

  Future<void> deleteEntry(int id) async {
    await db.delete('diary_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<DiaryEntry?> getEntryByDate(String yyyyMmDd) async {
    final rows = await db.query(
      'diary_entries',
      where: 'entry_date = ?',
      whereArgs: [yyyyMmDd],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return DiaryEntry.fromMap(rows.first);
  }

  Future<DiaryEntry?> getTodayEntry(String yyyyMmDd) async {
    return getEntryByDate(yyyyMmDd);
  }

  Future<List<DiaryEntry>> getAllEntries() async {
    final rows = await db.query('diary_entries', orderBy: 'entry_date DESC, id DESC');
    return rows.map(DiaryEntry.fromMap).toList();
  }

  Future<List<DiaryEntry>> getEntriesWithReminders() async {
    final rows = await db.query(
      'diary_entries',
      where: "TRIM(reminder) <> '' AND reminder_completed = 0",
      orderBy: 'entry_date DESC, id DESC',
    );

    return rows.map(DiaryEntry.fromMap).toList();
  }

  Future<void> completeReminder(int id) async {
    await db.update(
      'diary_entries',
      {
        'reminder_completed': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> uncompleteReminder(int id) async {
    await db.update(
      'diary_entries',
      {
        'reminder_completed': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<DiaryEntry>> searchEntries({
    required String text,
    DateTime? from,
    DateTime? to,
  }) async {
    final clean = text.trim().toLowerCase();
    final whereParts = <String>[];
    final args = <Object?>[];

    if (clean.isNotEmpty) {
      final words = clean.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();

      for (final word in words) {
        whereParts.add('(LOWER(body) LIKE ? OR LOWER(reminder) LIKE ?)');
        args.add('%$word%');
        args.add('%$word%');
      }
    }

    if (from != null) {
      whereParts.add('entry_date >= ?');
      args.add(_dateOnly(from));
    }

    if (to != null) {
      whereParts.add('entry_date <= ?');
      args.add(_dateOnly(to));
    }

    final where = whereParts.isEmpty ? null : whereParts.join(' AND ');

    final rows = await db.query(
      'diary_entries',
      where: where,
      whereArgs: args,
      orderBy: 'entry_date DESC, id DESC',
      limit: 300,
    );

    return rows.map(DiaryEntry.fromMap).toList();
  }

  Future<void> importEntriesDuplicatingDates(List<DiaryEntry> entries) async {
    final batch = db.batch();

    for (final entry in entries) {
      batch.insert('diary_entries', {
        'entry_date': entry.entryDate,
        'body': entry.body,
        'reminder': entry.reminder,
        'reminder_completed': entry.reminderCompleted ? 1 : 0,
        'created_at': entry.createdAt,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    await batch.commit(noResult: true);
  }

  String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
