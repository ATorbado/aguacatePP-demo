import 'dart:convert';
import 'dart:io';

import 'package:agenda_estado/local_data_cipher.dart';
import 'package:path/path.dart' as path_util;
import 'package:path_provider/path_provider.dart';

enum QueueSendDisposition { sent, retryableFailure, permanentFailure }

class QueueSendResult {
  final QueueSendDisposition disposition;
  final int? statusCode;

  const QueueSendResult.sent()
    : disposition = QueueSendDisposition.sent,
      statusCode = null;

  const QueueSendResult.retryable({this.statusCode})
    : disposition = QueueSendDisposition.retryableFailure;

  const QueueSendResult.permanent({this.statusCode})
    : disposition = QueueSendDisposition.permanentFailure;
}

class QueueDrainReport {
  final int sent;
  final int quarantined;
  final bool retryPending;

  const QueueDrainReport({
    required this.sent,
    required this.quarantined,
    required this.retryPending,
  });
}

typedef QueueSender =
    Future<QueueSendResult> Function(
      Map<String, String> fields,
      List<QueuedPhoto> photos,
    );

class QueuedPhoto {
  final String filename;
  final List<int> bytes;

  const QueuedPhoto({required this.filename, required this.bytes});
}

class OfflineQueueException implements Exception {
  final String message;

  const OfflineQueueException(this.message);

  @override
  String toString() => message;
}

class OfflineQueue {
  static const int defaultMaxEntries = 100;
  static const int defaultMaxQueueBytes = 2 * 1024 * 1024;
  static const int defaultMaxPhotoBytes = 200 * 1024 * 1024;
  static const int defaultMaxSinglePhotoBytes = 30 * 1024 * 1024;
  static final List<int> _queueAssociatedData = utf8.encode(
    'agenda_estado/offline_queue/v1',
  );
  static final List<int> _quarantineAssociatedData = utf8.encode(
    'agenda_estado/offline_quarantine/v1',
  );

  final File queueFile;
  final Directory photoDirectory;
  final Directory failedDirectory;
  final LocalDataCipher cipher;
  final int maxEntries;
  final int maxQueueBytes;
  final int maxPhotoBytes;
  final int maxSinglePhotoBytes;
  Future<void> _pendingOperation = Future.value();
  int _failedSequence = 0;

  OfflineQueue({
    required this.queueFile,
    required this.photoDirectory,
    required this.cipher,
    Directory? failedDirectory,
    this.maxEntries = defaultMaxEntries,
    this.maxQueueBytes = defaultMaxQueueBytes,
    this.maxPhotoBytes = defaultMaxPhotoBytes,
    this.maxSinglePhotoBytes = defaultMaxSinglePhotoBytes,
  }) : failedDirectory =
           failedDirectory ?? Directory('${queueFile.path}.failed');

  static Future<OfflineQueue> openDefault() async {
    final documents = await getApplicationDocumentsDirectory();
    return OfflineQueue(
      queueFile: File('${documents.path}/queued_forms.json'),
      photoDirectory: Directory('${documents.path}/queued_photos'),
      failedDirectory: Directory('${documents.path}/queued_failed'),
      cipher: LocalDataCipher.secure(),
    );
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _pendingOperation.then((_) => action());
    _pendingOperation = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> add(
    Map<String, String> fields,
    List<String> sourcePhotoPaths,
  ) => _serialized(() async {
    _validateEntry({
      'fields': fields,
      'photos': sourcePhotoPaths,
      'queuedAt': DateTime.now().toUtc().toIso8601String(),
    });

    final entries = await _read();
    if (entries.length >= maxEntries) {
      throw const OfflineQueueException(
        'La cola local está llena. Reintenta el envío antes de añadir más datos.',
      );
    }

    final copiedPhotos = <String>[];
    try {
      await photoDirectory.create(recursive: true);
      var projectedBytes = await _photoBytesInUse();
      final batchId = DateTime.now().toUtc().microsecondsSinceEpoch;

      for (var index = 0; index < sourcePhotoPaths.length; index++) {
        final source = File(sourcePhotoPaths[index]);
        if (!await source.exists()) {
          throw const OfflineQueueException(
            'Una foto seleccionada ya no está disponible.',
          );
        }
        final sourceBytes = await source.length();
        if (sourceBytes > maxSinglePhotoBytes) {
          throw const OfflineQueueException(
            'Una foto supera el tamaño máximo permitido.',
          );
        }
        projectedBytes += cipher.encryptedLength(sourceBytes);
        if (projectedBytes > maxPhotoBytes) {
          throw const OfflineQueueException(
            'Las fotos pendientes superan el espacio máximo permitido.',
          );
        }

        final extension = _safeExtension(source.path);
        final target = File(
          '${photoDirectory.path}${Platform.pathSeparator}'
          '${batchId}_$index$extension',
        );
        await _encryptFile(source, target);
        copiedPhotos.add(target.path);
      }

      final newEntry = _validateEntry({
        'fields': Map<String, String>.from(fields),
        'photos': copiedPhotos,
        'queuedAt': DateTime.now().toUtc().toIso8601String(),
      });
      entries.add(newEntry);
      await _write(entries);
    } catch (_) {
      await _deleteManagedPhotos(copiedPhotos);
      rethrow;
    }
  });

  Future<QueueDrainReport> drain(QueueSender sender) => _serialized(() async {
    final entries = await _read();
    var sentCount = 0;
    var quarantinedCount = 0;

    while (entries.isNotEmpty) {
      final entry = entries.first;
      final fields = Map<String, String>.from(entry['fields'] as Map);
      final photos = List<String>.from(entry['photos'] as List);
      final photosReady = await _photosAreManagedAndPresent(photos);

      if (!photosReady) {
        await _quarantine(entry, reason: 'missing_or_unmanaged_photo');
        entries.removeAt(0);
        await _write(entries);
        quarantinedCount++;
        continue;
      }

      List<QueuedPhoto> decryptedPhotos;
      try {
        decryptedPhotos = await _decryptPhotos(photos);
      } on LocalDataCipherException catch (error) {
        throw OfflineQueueException(error.message);
      }

      final result = await sender(fields, decryptedPhotos);
      switch (result.disposition) {
        case QueueSendDisposition.sent:
          entries.removeAt(0);
          await _write(entries);
          await _deleteManagedPhotos(photos);
          sentCount++;
          continue;
        case QueueSendDisposition.permanentFailure:
          await _quarantine(
            entry,
            reason: 'permanent_http_failure',
            statusCode: result.statusCode,
          );
          entries.removeAt(0);
          await _write(entries);
          quarantinedCount++;
          continue;
        case QueueSendDisposition.retryableFailure:
          return QueueDrainReport(
            sent: sentCount,
            quarantined: quarantinedCount,
            retryPending: true,
          );
      }
    }

    return QueueDrainReport(
      sent: sentCount,
      quarantined: quarantinedCount,
      retryPending: false,
    );
  });

  Future<int> count() => _serialized(() async => (await _read()).length);

  Future<List<Map<String, dynamic>>> _read() async {
    await _recoverInterruptedWrite();
    if (!await queueFile.exists()) {
      return <Map<String, dynamic>>[];
    }
    if (await queueFile.length() > maxQueueBytes + LocalDataCipher.overhead) {
      throw const OfflineQueueException(
        'La cola local supera el tamaño permitido y no se modificó.',
      );
    }

    try {
      final stored = await queueFile.readAsBytes();
      final wasEncrypted = cipher.isEncrypted(stored);
      final clearBytes =
          wasEncrypted
              ? await cipher.decrypt(
                stored,
                associatedData: _queueAssociatedData,
              )
              : stored;
      final decoded = jsonDecode(utf8.decode(clearBytes));
      if (decoded is! List) {
        throw const FormatException('La raíz de la cola no es una lista.');
      }
      final entries =
          decoded.map<Map<String, dynamic>>(_validateEntry).toList();
      final photosChanged = await _migrateLegacyPhotos(entries);
      if (!wasEncrypted || photosChanged) {
        await _write(entries);
      }
      return entries;
    } on LocalDataCipherException catch (error) {
      throw OfflineQueueException(error.message);
    } on OfflineQueueException {
      rethrow;
    } catch (_) {
      throw const OfflineQueueException(
        'La cola local está dañada y se conservó sin sobrescribir.',
      );
    }
  }

  Future<bool> _migrateLegacyPhotos(List<Map<String, dynamic>> entries) async {
    final copiedDuringMigration = <String>[];
    var changed = false;
    var projectedBytes = await _photoBytesInUse();

    try {
      for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
        final entry = entries[entryIndex];
        final photos = List<String>.from(entry['photos'] as List);
        final migratedPhotos = <String>[];
        for (var photoIndex = 0; photoIndex < photos.length; photoIndex++) {
          final source = File(photos[photoIndex]);
          if (_isManagedPhoto(source)) {
            if (await source.exists() && !await _isEncryptedPhoto(source)) {
              await _encryptManagedFileInPlace(source);
            }
            migratedPhotos.add(source.path);
            continue;
          }
          if (!await source.exists()) {
            migratedPhotos.add(source.path);
            continue;
          }

          final sourceBytes = await source.length();
          final encryptedBytes = cipher.encryptedLength(sourceBytes);
          if (sourceBytes > maxSinglePhotoBytes ||
              projectedBytes + encryptedBytes > maxPhotoBytes) {
            migratedPhotos.add(source.path);
            continue;
          }

          await photoDirectory.create(recursive: true);
          final target = File(
            '${photoDirectory.path}${Platform.pathSeparator}'
            'legacy_${DateTime.now().toUtc().microsecondsSinceEpoch}_'
            '${entryIndex}_$photoIndex${_safeExtension(source.path)}',
          );
          await _encryptFile(source, target);
          migratedPhotos.add(target.path);
          copiedDuringMigration.add(target.path);
          projectedBytes += encryptedBytes;
          changed = true;
        }

        entry['photos'] = migratedPhotos;
        if (entry['queuedAt'] is! String) {
          entry['queuedAt'] = DateTime.now().toUtc().toIso8601String();
          changed = true;
        }
      }
      return changed;
    } catch (_) {
      await _deleteManagedPhotos(copiedDuringMigration);
      rethrow;
    }
  }

  Map<String, dynamic> _validateEntry(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('Entrada de cola inválida.');
    }
    final rawFields = raw['fields'];
    final rawPhotos = raw['photos'];
    if (rawFields is! Map || rawPhotos is! List) {
      throw const FormatException('Campos de cola inválidos.');
    }

    final fields = <String, String>{};
    for (final entry in rawFields.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Campo de formulario inválido.');
      }
      if ((entry.key as String).length > 100 ||
          (entry.value as String).length > 20000) {
        throw const FormatException('Campo de formulario demasiado grande.');
      }
      fields[entry.key as String] = entry.value as String;
    }

    final photos = <String>[];
    for (final value in rawPhotos) {
      if (value is! String || value.length > 4096) {
        throw const FormatException('Ruta de foto inválida.');
      }
      photos.add(value);
    }

    return {
      'fields': fields,
      'photos': photos,
      if (raw['queuedAt'] is String) 'queuedAt': raw['queuedAt'],
    };
  }

  Future<void> _write(List<Map<String, dynamic>> entries) async {
    final clearBytes = utf8.encode(jsonEncode(entries));
    if (clearBytes.length > maxQueueBytes) {
      throw const OfflineQueueException(
        'La cola local supera el tamaño permitido.',
      );
    }

    await queueFile.parent.create(recursive: true);
    final temporary = File('${queueFile.path}.tmp');
    final backup = File('${queueFile.path}.bak');
    final encrypted = await cipher.encrypt(
      clearBytes,
      associatedData: _queueAssociatedData,
    );
    await temporary.writeAsBytes(encrypted, flush: true);

    if (await backup.exists()) {
      await backup.delete();
    }
    if (await queueFile.exists()) {
      await queueFile.rename(backup.path);
    }
    try {
      await temporary.rename(queueFile.path);
      if (await backup.exists()) {
        await backup.delete();
      }
    } catch (_) {
      if (!await queueFile.exists() && await backup.exists()) {
        await backup.rename(queueFile.path);
      }
      rethrow;
    }
  }

  Future<void> _quarantine(
    Map<String, dynamic> entry, {
    required String reason,
    int? statusCode,
  }) async {
    await failedDirectory.create(recursive: true);
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final target = File(
      '${failedDirectory.path}${Platform.pathSeparator}'
      '${timestamp}_${_failedSequence++}.enc',
    );
    final temporary = File('${target.path}.tmp');
    final clearBytes = utf8.encode(
      jsonEncode({
        ...entry,
        'failedAt': DateTime.now().toUtc().toIso8601String(),
        'reason': reason,
        if (statusCode != null) 'statusCode': statusCode,
      }),
    );
    final encrypted = await cipher.encrypt(
      clearBytes,
      associatedData: _quarantineAssociatedData,
    );
    await temporary.writeAsBytes(encrypted, flush: true);
    await temporary.rename(target.path);
  }

  Future<void> _recoverInterruptedWrite() async {
    final backup = File('${queueFile.path}.bak');
    final temporary = File('${queueFile.path}.tmp');
    if (!await queueFile.exists() && await backup.exists()) {
      await backup.rename(queueFile.path);
      return;
    }
    if (!await queueFile.exists() && await temporary.exists()) {
      await temporary.rename(queueFile.path);
    }
  }

  Future<void> _encryptFile(File source, File target) async {
    final clearBytes = await source.readAsBytes();
    final encrypted = await cipher.encrypt(
      clearBytes,
      associatedData: _photoAssociatedData(target),
    );
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(encrypted, flush: true);
    await temporary.rename(target.path);
  }

  Future<void> _encryptManagedFileInPlace(File source) async {
    final clearBytes = await source.readAsBytes();
    final encrypted = await cipher.encrypt(
      clearBytes,
      associatedData: _photoAssociatedData(source),
    );
    final temporary = File('${source.path}.encrypting');
    final backup = File('${source.path}.plaintext.bak');
    await temporary.writeAsBytes(encrypted, flush: true);

    if (await backup.exists()) {
      throw const OfflineQueueException(
        'Existe una migración de foto incompleta; los datos se conservaron.',
      );
    }
    await source.rename(backup.path);
    try {
      await temporary.rename(source.path);
      await backup.delete();
    } catch (_) {
      if (!await source.exists() && await backup.exists()) {
        await backup.rename(source.path);
      }
      rethrow;
    }
  }

  Future<bool> _isEncryptedPhoto(File file) async {
    final bytes = await file.readAsBytes();
    return cipher.isEncrypted(bytes);
  }

  Future<List<QueuedPhoto>> _decryptPhotos(List<String> paths) async {
    final result = <QueuedPhoto>[];
    for (final path in paths) {
      final file = File(path);
      final encrypted = await file.readAsBytes();
      final clearBytes = await cipher.decrypt(
        encrypted,
        associatedData: _photoAssociatedData(file),
      );
      result.add(
        QueuedPhoto(filename: _filename(file.path), bytes: clearBytes),
      );
    }
    return result;
  }

  List<int> _photoAssociatedData(File file) =>
      utf8.encode('agenda_estado/offline_photo/v1/${_filename(file.path)}');

  Future<int> _photoBytesInUse() async {
    if (!await photoDirectory.exists()) return 0;
    var total = 0;
    await for (final entity in photoDirectory.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<bool> _photosAreManagedAndPresent(List<String> photos) async {
    for (final path in photos) {
      final file = File(path);
      if (!_isManagedPhoto(file) || !await file.exists()) {
        return false;
      }
    }
    return true;
  }

  Future<void> _deleteManagedPhotos(List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (await file.exists() && _isManagedPhoto(file)) {
        await file.delete();
      }
    }
  }

  bool _isManagedPhoto(File file) {
    final managedRoot = path_util.normalize(photoDirectory.absolute.path);
    final candidate = path_util.normalize(file.absolute.path);
    return path_util.isWithin(managedRoot, candidate);
  }

  static String _filename(String path) => path.split(RegExp(r'[/\\]')).last;

  static String _safeExtension(String path) {
    final name = _filename(path);
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '';
    final extension = name.substring(dot).toLowerCase();
    const allowed = {'.jpg', '.jpeg', '.png', '.heic', '.webp'};
    return allowed.contains(extension) ? extension : '';
  }
}
