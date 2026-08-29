import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diary_entry.dart';
import 'database_service.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _lastAutoBackupKey = 'last_auto_backup_date';

  Future<Directory> _backupDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<File> createBackup({bool automatic = false}) async {
    final entries = await DatabaseService.instance.getAllEntries();
    final backupDir = await _backupDir();
    final now = DateTime.now();

    final fileName = automatic
        ? 'mi_diario_auto_${_stamp(now)}.json'
        : 'mi_diario_manual_${_stamp(now)}.json';
    final file = File(p.join(backupDir.path, fileName));
    final data = {
      'app': 'Mi Diario',
      'version': 1,
      'exportedAt': now.toIso8601String(),
      'entries': entries.map((entry) => entry.toBackupJson()).toList(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    await _keepOnlyLastFiveBackups();
    return file;
  }

  Future<void> createBackupIfDue() async {
    final now = DateTime.now();
    if (!_isSundayAfterNine(now)) return;

    final prefs = await SharedPreferences.getInstance();
    final today = _dateOnly(now);
    if (prefs.getString(_lastAutoBackupKey) == today) return;

    await createBackup(automatic: true);
    await prefs.setString(_lastAutoBackupKey, today);
  }

  Future<void> shareManualBackup() async {
    final file = await createBackup();
    await SharePlus.instance.share(
      ShareParams(
        text: 'Copia de seguridad de Mi Diario',
        files: [XFile(file.path)],
      ),
    );
  }

  Future<int> importBackupFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return 0;

    final raw = await File(result.files.single.path!).readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final entriesRaw = decoded['entries'] as List<dynamic>? ?? [];
    final entries = entriesRaw
        .whereType<Map<String, dynamic>>()
        .map(DiaryEntry.fromBackupJson)
        .toList();
    await DatabaseService.instance.importEntriesDuplicatingDates(entries);
    return entries.length;
  }

  Future<List<File>> listBackups() async {
    final dir = await _backupDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => p.basename(file.path).endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<void> _keepOnlyLastFiveBackups() async {
    final files = await listBackups();
    for (final file in files.skip(5)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  bool _isSundayAfterNine(DateTime date) =>
      date.weekday == DateTime.sunday && date.hour >= 21;

  String _stamp(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$year$month${day}_$hour$minute$second';
  }

  String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
