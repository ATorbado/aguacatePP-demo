import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalDataCipherException implements Exception {
  final String message;

  const LocalDataCipherException(this.message);

  @override
  String toString() => message;
}

abstract class LocalKeyStore {
  Future<List<int>?> read();

  Future<void> write(List<int> keyBytes);
}

class SecureStorageLocalKeyStore implements LocalKeyStore {
  static const _keyName = 'offline_queue_aes256_key_v1';

  final FlutterSecureStorage storage;

  SecureStorageLocalKeyStore({FlutterSecureStorage? storage})
    : storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: false,
              migrateOnAlgorithmChange: true,
              migrateWithBackup: true,
              storageNamespace: 'agenda_estado_offline_queue_v1',
            ),
          );

  @override
  Future<List<int>?> read() async {
    final encoded = await storage.read(key: _keyName);
    if (encoded == null) return null;
    try {
      final decoded = base64Decode(encoded);
      if (decoded.length != 32) throw const FormatException();
      return decoded;
    } catch (_) {
      throw const LocalDataCipherException(
        'La clave local guardada no es válida; los datos no se modificaron.',
      );
    }
  }

  @override
  Future<void> write(List<int> keyBytes) =>
      storage.write(key: _keyName, value: base64Encode(keyBytes));
}

class MemoryLocalKeyStore implements LocalKeyStore {
  List<int>? _keyBytes;

  MemoryLocalKeyStore([List<int>? keyBytes])
    : _keyBytes = keyBytes == null ? null : List<int>.from(keyBytes);

  @override
  Future<List<int>?> read() async =>
      _keyBytes == null ? null : List<int>.from(_keyBytes!);

  @override
  Future<void> write(List<int> keyBytes) async {
    _keyBytes = List<int>.from(keyBytes);
  }

  void clear() => _keyBytes = null;
}

class LocalDataCipher {
  static final List<int> _magic = ascii.encode('AGENC001');
  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int overhead = 8 + nonceLength + macLength;

  final LocalKeyStore keyStore;
  final AesGcm _algorithm;

  LocalDataCipher({required this.keyStore})
    : _algorithm = AesGcm.with256bits(nonceLength: nonceLength);

  factory LocalDataCipher.secure() =>
      LocalDataCipher(keyStore: SecureStorageLocalKeyStore());

  bool isEncrypted(List<int> bytes) {
    if (bytes.length < overhead) return false;
    for (var index = 0; index < _magic.length; index++) {
      if (bytes[index] != _magic[index]) return false;
    }
    return true;
  }

  int encryptedLength(int clearLength) => clearLength + overhead;

  Future<List<int>> encrypt(
    List<int> clearText, {
    required List<int> associatedData,
  }) async {
    final keyBytes = await _keyForEncryption();
    final secretBox = await _algorithm.encrypt(
      clearText,
      secretKey: SecretKey(keyBytes),
      aad: associatedData,
    );
    return <int>[
      ..._magic,
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ];
  }

  Future<List<int>> decrypt(
    List<int> encrypted, {
    required List<int> associatedData,
  }) async {
    if (!isEncrypted(encrypted)) {
      throw const LocalDataCipherException(
        'El archivo local no tiene un formato cifrado válido.',
      );
    }
    final keyBytes = await keyStore.read();
    if (keyBytes == null) {
      throw const LocalDataCipherException(
        'Falta la clave local; los datos cifrados se conservaron sin cambios.',
      );
    }
    if (keyBytes.length != 32) {
      throw const LocalDataCipherException(
        'La clave local no es válida; los datos cifrados se conservaron.',
      );
    }

    final nonceStart = _magic.length;
    final macStart = nonceStart + nonceLength;
    final cipherTextStart = macStart + macLength;
    try {
      return await _algorithm.decrypt(
        SecretBox(
          encrypted.sublist(cipherTextStart),
          nonce: encrypted.sublist(nonceStart, macStart),
          mac: Mac(encrypted.sublist(macStart, cipherTextStart)),
        ),
        secretKey: SecretKey(keyBytes),
        aad: associatedData,
      );
    } catch (_) {
      throw const LocalDataCipherException(
        'No se pudo autenticar el archivo cifrado; se conservó sin cambios.',
      );
    }
  }

  Future<List<int>> _keyForEncryption() async {
    final existing = await keyStore.read();
    if (existing != null) {
      if (existing.length != 32) {
        throw const LocalDataCipherException('La clave local no es válida.');
      }
      return existing;
    }

    final secretKey = await _algorithm.newSecretKey();
    final generated = await secretKey.extractBytes();
    await keyStore.write(generated);
    final persisted = await keyStore.read();
    if (persisted == null || persisted.length != 32) {
      throw const LocalDataCipherException(
        'No se pudo guardar la clave local de cifrado.',
      );
    }
    return persisted;
  }
}
