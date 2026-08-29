import 'dart:convert';
import 'dart:io';

import 'package:agenda_estado/local_data_cipher.dart';
import 'package:agenda_estado/offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late OfflineQueue queue;
  late MemoryLocalKeyStore keyStore;
  late LocalDataCipher cipher;

  OfflineQueue createQueue({
    int maxEntries = OfflineQueue.defaultMaxEntries,
    int maxQueueBytes = OfflineQueue.defaultMaxQueueBytes,
    int maxPhotoBytes = OfflineQueue.defaultMaxPhotoBytes,
    int maxSinglePhotoBytes = OfflineQueue.defaultMaxSinglePhotoBytes,
  }) => OfflineQueue(
    queueFile: File('${temporaryDirectory.path}/queued_forms.json'),
    photoDirectory: Directory('${temporaryDirectory.path}/queued_photos'),
    failedDirectory: Directory('${temporaryDirectory.path}/queued_failed'),
    cipher: cipher,
    maxEntries: maxEntries,
    maxQueueBytes: maxQueueBytes,
    maxPhotoBytes: maxPhotoBytes,
    maxSinglePhotoBytes: maxSinglePhotoBytes,
  );

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'agenda_queue_test_',
    );
    keyStore = MemoryLocalKeyStore();
    cipher = LocalDataCipher(keyStore: keyStore);
    queue = createQueue();
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('copia las fotos y elimina la copia después de enviar', () async {
    final original = File('${temporaryDirectory.path}/selected.jpg');
    await original.writeAsBytes([1, 2, 3]);

    await queue.add({'carretera': 'N-120'}, [original.path]);
    await original.delete();

    final encryptedPhoto =
        await queue.photoDirectory
            .list()
            .where((e) => e is File)
            .cast<File>()
            .single;
    expect(cipher.isEncrypted(await encryptedPhoto.readAsBytes()), isTrue);
    expect(await encryptedPhoto.readAsBytes(), isNot([1, 2, 3]));

    final report = await queue.drain((fields, photos) async {
      expect(fields, {'carretera': 'N-120'});
      expect(photos, hasLength(1));
      expect(photos.single.bytes, [1, 2, 3]);
      expect(photos.single.filename, endsWith('.jpg'));
      return const QueueSendResult.sent();
    });

    expect(report.sent, 1);
    expect(report.quarantined, 0);
    expect(report.retryPending, isFalse);
    expect(await queue.count(), 0);
    expect(await encryptedPhoto.exists(), isFalse);
  });

  test('conserva la entrada ante un fallo reintentable', () async {
    await queue.add({'pk': '10+000'}, const []);

    final report = await queue.drain(
      (fields, photos) async =>
          const QueueSendResult.retryable(statusCode: 503),
    );

    expect(report.sent, 0);
    expect(report.retryPending, isTrue);
    expect(await queue.count(), 1);
  });

  test('migra una foto de la cola antigua antes de enviarla', () async {
    final original = File('${temporaryDirectory.path}/legacy.jpg');
    await original.writeAsBytes([4, 5, 6]);
    await queue.queueFile.writeAsString(
      jsonEncode([
        {
          'fields': {'pk': '20+000'},
          'photos': [original.path],
        },
      ]),
      flush: true,
    );

    String? migratedFilename;
    final report = await queue.drain((fields, photos) async {
      migratedFilename = photos.single.filename;
      expect(migratedFilename, isNot('legacy.jpg'));
      expect(photos.single.bytes, [4, 5, 6]);
      return const QueueSendResult.sent();
    });

    expect(report.sent, 1);
    expect(await original.exists(), isTrue);
    expect(await queue.photoDirectory.list().isEmpty, isTrue);
  });

  test('cifra una foto gestionada antigua aunque ya tenga queuedAt', () async {
    await queue.photoDirectory.create(recursive: true);
    final managed = File('${queue.photoDirectory.path}/managed.jpg');
    await managed.writeAsBytes([7, 8, 9]);
    await queue.queueFile.writeAsString(
      jsonEncode([
        {
          'fields': {'pk': '25+000'},
          'photos': [managed.path],
          'queuedAt': DateTime.utc(2026).toIso8601String(),
        },
      ]),
      flush: true,
    );

    expect(await queue.count(), 1);
    expect(cipher.isEncrypted(await managed.readAsBytes()), isTrue);
    expect(cipher.isEncrypted(await queue.queueFile.readAsBytes()), isTrue);

    final report = await queue.drain((fields, photos) async {
      expect(photos.single.bytes, [7, 8, 9]);
      return const QueueSendResult.sent();
    });
    expect(report.sent, 1);
    expect(await managed.exists(), isFalse);
  });

  test('aísla una foto antigua ausente y continúa con la siguiente', () async {
    await queue.queueFile.writeAsString(
      jsonEncode([
        {
          'fields': {'pk': 'ausente'},
          'photos': ['${temporaryDirectory.path}/missing.jpg'],
        },
        {
          'fields': {'pk': 'válida'},
          'photos': <String>[],
        },
      ]),
      flush: true,
    );

    final report = await queue.drain((fields, photos) async {
      expect(fields['pk'], 'válida');
      return const QueueSendResult.sent();
    });

    expect(report.sent, 1);
    expect(report.quarantined, 1);
    expect(await queue.count(), 0);
    expect(
      await queue.failedDirectory.list().where((e) => e is File).length,
      1,
    );
  });

  test('un rechazo permanente no bloquea entradas posteriores', () async {
    await queue.add({'pk': 'rechazada'}, const []);
    await queue.add({'pk': 'válida'}, const []);
    var calls = 0;

    final report = await queue.drain((fields, photos) async {
      calls++;
      return fields['pk'] == 'rechazada'
          ? const QueueSendResult.permanent(statusCode: 400)
          : const QueueSendResult.sent();
    });

    expect(calls, 2);
    expect(report.sent, 1);
    expect(report.quarantined, 1);
    expect(report.retryPending, isFalse);
    expect(await queue.count(), 0);
  });

  test('valida una entrada antes de escribirla', () async {
    final invalidFields = {List.filled(101, 'k').join(): 'valor'};

    await expectLater(
      queue.add(invalidFields, const []),
      throwsA(isA<FormatException>()),
    );
    expect(await queue.count(), 0);
  });

  test('limita el espacio total de fotografías pendientes', () async {
    queue = createQueue(maxPhotoBytes: 2, maxSinglePhotoBytes: 10);
    final original = File('${temporaryDirectory.path}/large.jpg');
    await original.writeAsBytes([1, 2, 3]);

    await expectLater(
      queue.add({'pk': '10+000'}, [original.path]),
      throwsA(isA<OfflineQueueException>()),
    );
    expect(await queue.count(), 0);
  });

  test('serializa altas concurrentes sin perder entradas', () async {
    await Future.wait([
      for (var index = 0; index < 20; index++)
        queue.add({'pk': '$index'}, const []),
    ]);

    expect(await queue.count(), 20);
  });

  test('recupera el backup si una escritura quedó interrumpida', () async {
    final backup = File('${queue.queueFile.path}.bak');
    await backup.writeAsString(
      jsonEncode([
        {
          'fields': {'pk': 'recuperada'},
          'photos': <String>[],
          'queuedAt': DateTime.utc(2026).toIso8601String(),
        },
      ]),
      flush: true,
    );

    expect(await queue.count(), 1);
    expect(await queue.queueFile.exists(), isTrue);
    expect(await backup.exists(), isFalse);
    expect(cipher.isEncrypted(await queue.queueFile.readAsBytes()), isTrue);
  });

  test('no sobrescribe una cola dañada', () async {
    await queue.queueFile.writeAsString('{contenido dañado', flush: true);

    await expectLater(queue.count(), throwsA(isA<OfflineQueueException>()));
    expect(await queue.queueFile.readAsString(), '{contenido dañado');
  });

  test('cifra los campos de la cola en reposo', () async {
    await queue.add({'comentarios': 'dato especialmente sensible'}, const []);

    final stored = await queue.queueFile.readAsBytes();
    expect(cipher.isEncrypted(stored), isTrue);
    expect(
      utf8.decode(stored, allowMalformed: true),
      isNot(contains('sensible')),
    );
  });

  test('detecta manipulación y conserva la cola cifrada', () async {
    await queue.add({'pk': '30+000'}, const []);
    final original = await queue.queueFile.readAsBytes();
    final tampered = List<int>.from(original)..[original.length - 1] ^= 1;
    await queue.queueFile.writeAsBytes(tampered, flush: true);

    await expectLater(queue.count(), throwsA(isA<OfflineQueueException>()));
    expect(await queue.queueFile.readAsBytes(), tampered);
  });

  test('si falta la clave no crea otra ni sobrescribe los datos', () async {
    await queue.add({'pk': '40+000'}, const []);
    final original = await queue.queueFile.readAsBytes();
    keyStore.clear();

    await expectLater(queue.count(), throwsA(isA<OfflineQueueException>()));
    expect(await keyStore.read(), isNull);
    expect(await queue.queueFile.readAsBytes(), original);
  });

  test('cifra también las entradas puestas en cuarentena', () async {
    await queue.add({'pk': 'dato-rechazado'}, const []);
    await queue.drain(
      (fields, photos) async =>
          const QueueSendResult.permanent(statusCode: 400),
    );

    final failed =
        await queue.failedDirectory
            .list()
            .where((e) => e is File)
            .cast<File>()
            .single;
    final stored = await failed.readAsBytes();
    expect(cipher.isEncrypted(stored), isTrue);
    expect(
      utf8.decode(stored, allowMalformed: true),
      isNot(contains('dato-rechazado')),
    );
  });
}
