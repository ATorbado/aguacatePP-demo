import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mailer/mailer.dart';
import 'package:path_provider/path_provider.dart';

import 'email_config.dart';

class OfflineEmailQueue {
  static const int _maxQueuedEmails = 25;
  static const int _maxSubjectCharacters = 200;
  static const int _maxTextBytes = 200 * 1024;
  static const int _maxAttachmentBytes = 10 * 1024 * 1024;
  static const int _maxTotalAttachmentBytes = 25 * 1024 * 1024;
  static const Duration _sendTimeout = Duration(seconds: 30);
  static Future<void> _operationChain = Future<void>.value();

  static Future<void> _synchronized(Future<void> Function() action) {
    final completer = Completer<void>();
    _operationChain = _operationChain.then((_) async {
      try {
        await action();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static Future<Directory> _queueDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/offline_email_queue');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<File> _queueFile() async {
    final directory = await _queueDirectory();
    return File('${directory.path}/queue.json');
  }

  static Future<File> _legacyQueueFile() async {
    final documents = await getApplicationDocumentsDirectory();
    return File('${documents.path}/offline_emails.json');
  }

  static Future<Directory> _attachmentsDirectory() async {
    final directory = await _queueDirectory();
    final attachments = Directory('${directory.path}/attachments');
    if (!await attachments.exists()) {
      await attachments.create(recursive: true);
    }
    return attachments;
  }

  static Future<bool> hasNetworkConnection() async {
    final dynamic result = await Connectivity().checkConnectivity();

    // Compatible con connectivity_plus antiguo (un resultado) y moderno
    // (lista de resultados).
    if (result is List<ConnectivityResult>) {
      return result.any((value) => value != ConnectivityResult.none);
    }
    return result != ConnectivityResult.none;
  }

  static Future<void> saveEmail({
    required String subject,
    required String text,
    required List<File> attachments,
  }) {
    return _synchronized(
      () => _saveEmailInternal(
        subject: subject,
        text: text,
        attachments: attachments,
      ),
    );
  }

  static Future<void> _saveEmailInternal({
    required String subject,
    required String text,
    required List<File> attachments,
  }) async {
    await _migrateLegacyQueueIfNeeded();

    final normalizedSubject = subject.trim();
    if (normalizedSubject.isEmpty ||
        normalizedSubject.length > _maxSubjectCharacters ||
        text.trim().isEmpty ||
        utf8.encode(text).length > _maxTextBytes) {
      throw ArgumentError('El asunto o el texto del correo no son válidos.');
    }

    final queue = await _readQueue();
    final attachmentsDirectory = await _attachmentsDirectory();
    final id = _newId();
    final savedNames = <String>[];
    var totalBytes = 0;

    try {
      for (var index = 0; index < attachments.length; index++) {
        final source = attachments[index];
        if (!await source.exists()) continue;

        final length = await source.length();
        if (length <= 0 || length > _maxAttachmentBytes) {
          throw StateError('Adjunto vacío o demasiado grande.');
        }

        totalBytes += length;
        if (totalBytes > _maxTotalAttachmentBytes) {
          throw StateError('El conjunto de adjuntos supera el límite permitido.');
        }

        final extension = _safeExtension(source.path);
        final fileName = '${id}_$index$extension';
        final destination = File('${attachmentsDirectory.path}/$fileName');
        await source.copy(destination.path);
        savedNames.add(fileName);
      }

      queue.add({
        'id': id,
        'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
        'subject': normalizedSubject,
        'text': text,
        'attachments': savedNames,
        'attempts': 0,
      });

      while (queue.length > _maxQueuedEmails) {
        final removed = queue.removeAt(0);
        await _deleteAttachments(removed);
      }

      await _writeQueue(queue);
    } catch (_) {
      await _deleteAttachmentNames(savedNames);
      rethrow;
    }
  }

  static Future<void> trySendStoredEmails() async {
    try {
      await _synchronized(_trySendStoredEmailsInternal);
    } catch (_) {
      // La sincronización en segundo plano nunca debe cerrar la aplicación.
    }
  }

  static Future<void> _trySendStoredEmailsInternal() async {
    if (!EmailConfig.isConfigured || !await hasNetworkConnection()) return;

    await _migrateLegacyQueueIfNeeded();
    final queue = await _readQueue();
    if (queue.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    final smtpServer = EmailConfig.createSmtpServer();

    for (final data in queue) {
      try {
        final subject = data['subject'];
        final text = data['text'];
        if (subject is! String ||
            subject.trim().isEmpty ||
            subject.length > _maxSubjectCharacters ||
            text is! String ||
            text.trim().isEmpty ||
            utf8.encode(text).length > _maxTextBytes) {
          await _deleteAttachments(data);
          continue;
        }

        final files = await _safeAttachmentFiles(data);
        final message = Message()
          ..from = Address(EmailConfig.senderAddress)
          ..recipients.addAll(EmailConfig.toRecipients)
          ..ccRecipients.addAll(EmailConfig.ccRecipients)
          ..subject = subject
          ..text = text
          ..attachments = files.map((file) => FileAttachment(file)).toList();

        await send(message, smtpServer).timeout(_sendTimeout);
        await _deleteAttachments(data);
      } catch (_) {
        final updated = Map<String, dynamic>.from(data);
        final attempts = updated['attempts'];
        updated['attempts'] = attempts is int ? attempts + 1 : 1;
        remaining.add(updated);
      }
    }

    await _writeQueue(remaining);
  }

  static Future<void> _migrateLegacyQueueIfNeeded() async {
    final legacyFile = await _legacyQueueFile();
    if (!await legacyFile.exists()) return;

    try {
      if (await legacyFile.length() > _maxTextBytes * 5) {
        throw const FormatException('Cola antigua demasiado grande.');
      }

      final decoded = jsonDecode(await legacyFile.readAsString());
      if (decoded is! List) throw const FormatException('Cola antigua no válida.');

      final queue = await _readQueue();
      for (final raw in decoded.whereType<Map>()) {
        final data = Map<String, dynamic>.from(raw);
        final subject = data['subject'];
        final text = data['text'];
        if (subject is! String ||
            subject.trim().isEmpty ||
            subject.length > _maxSubjectCharacters ||
            text is! String ||
            text.trim().isEmpty ||
            utf8.encode(text).length > _maxTextBytes) {
          continue;
        }

        queue.add({
          'id': _newId(),
          'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
          'subject': subject.trim(),
          'text': text,
          'attachments': <String>[],
          'legacyNoAttachments': true,
          'attempts': 0,
        });
      }

      while (queue.length > _maxQueuedEmails) {
        final removed = queue.removeAt(0);
        await _deleteAttachments(removed);
      }
      await _writeQueue(queue);
      await legacyFile.delete();
    } catch (_) {
      final corrupt = File(
        '${legacyFile.path}.corrupt_${DateTime.now().millisecondsSinceEpoch}',
      );
      try {
        await legacyFile.rename(corrupt.path);
      } catch (_) {
        try {
          await legacyFile.delete();
        } catch (_) {}
      }
    }
  }

  static Future<List<Map<String, dynamic>>> _readQueue() async {
    final file = await _queueFile();
    if (!await file.exists()) {
      final backup = File('${file.path}.bak');
      if (await backup.exists()) {
        try {
          await backup.rename(file.path);
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      } else {
        return <Map<String, dynamic>>[];
      }
    }

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Cola no válida');

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: true);
    } catch (_) {
      final corrupt = File(
        '${file.path}.corrupt_${DateTime.now().millisecondsSinceEpoch}',
      );
      try {
        await file.rename(corrupt.path);
      } catch (_) {
        try {
          await file.delete();
        } catch (_) {}
      }
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    final file = await _queueFile();
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');

    if (queue.isEmpty) {
      if (await temporary.exists()) await temporary.delete();
      if (await backup.exists()) await backup.delete();
      if (await file.exists()) await file.delete();
      return;
    }

    await temporary.writeAsString(jsonEncode(queue), flush: true);
    if (await backup.exists()) await backup.delete();
    if (await file.exists()) await file.rename(backup.path);

    try {
      await temporary.rename(file.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }

  static Future<List<File>> _safeAttachmentFiles(
    Map<String, dynamic> data,
  ) async {
    final rawNames = data['attachments'];
    if (rawNames is! List) {
      throw const FormatException('La cola no contiene adjuntos.');
    }
    if (rawNames.isEmpty) {
      if (data['legacyNoAttachments'] == true) return <File>[];
      throw const FormatException('La cola no contiene adjuntos.');
    }

    final directory = await _attachmentsDirectory();
    final files = <File>[];
    var totalBytes = 0;

    for (final rawName in rawNames) {
      if (rawName is! String || !_isSafeFileName(rawName)) {
        throw const FormatException('Nombre de adjunto no válido.');
      }

      final file = File('${directory.path}/$rawName');
      if (!await file.exists()) {
        throw FileSystemException('Falta un adjunto de la cola.');
      }

      final length = await file.length();
      if (length <= 0 || length > _maxAttachmentBytes) {
        throw FileSystemException('Adjunto de la cola no válido.');
      }

      totalBytes += length;
      if (totalBytes > _maxTotalAttachmentBytes) {
        throw FileSystemException('Los adjuntos superan el límite.');
      }
      files.add(file);
    }

    return files;
  }

  static Future<void> _deleteAttachments(Map<String, dynamic> data) async {
    final rawNames = data['attachments'];
    if (rawNames is! List) return;
    await _deleteAttachmentNames(rawNames.whereType<String>());
  }

  static Future<void> _deleteAttachmentNames(Iterable<String> names) async {
    final directory = await _attachmentsDirectory();
    for (final name in names) {
      if (!_isSafeFileName(name)) continue;
      final file = File('${directory.path}/$name');
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  static bool _isSafeFileName(String value) {
    return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value) &&
        !value.contains('..');
  }

  static String _safeExtension(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return '.bin';

    final extension = fileName.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(extension)
        ? extension
        : '.bin';
  }

  static String _newId() {
    final random = Random.secure();
    final suffix = List<int>.generate(8, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }
}
