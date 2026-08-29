import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RemoteSecurityStatus {
  allowed,
  blockedRemoteDisabled,
  blockedVersion,
  blockedSignature,
  blockedExpired,
  blockedFirstCheckFailed,
  blockedClockInvalid,
  blockedRollback,
  error,
}

class RemoteSecurityResult {
  final RemoteSecurityStatus status;
  final String message;
  final bool onlineValidated;
  final int? remainingDays;

  const RemoteSecurityResult({
    required this.status,
    required this.message,
    this.onlineValidated = false,
    this.remainingDays,
  });

  bool get isAllowed => status == RemoteSecurityStatus.allowed;
}

class RemoteSecurity {
  static const bool _demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: true,
  );

  static const String policyUrl =
      'https://raw.githubusercontent.com/ATorbado/aguacatePP/main/policy.json';

  static const String signatureUrl =
      'https://raw.githubusercontent.com/ATorbado/aguacatePP/main/policy.sig';

  static const List<String> _publicKeyBase64s = [
    'LYD6OMyFYKaJW4qAoTidkFUNGt3shvpAYbAhTR67gW0=',
    'Fd7IhSk5HVXyfiJfKKkOm+XLbSyxaatm0hV8NmrKttY=',
  ];

  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxPolicyBytes = 64 * 1024;
  static const int _maxSignatureBytes = 4 * 1024;
  static const int _defaultTtlDays = 15;
  static const int _maximumTtlDays = 30;

  static const String _lastOkMsKey = 'remote_security_last_ok_ms';
  static const String _lastPolicyKey = 'remote_security_last_policy_json';
  static const String _lastSignatureKey =
      'remote_security_last_policy_signature';

  static Future<RemoteSecurityResult> check() async {
    if (_demoMode) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.allowed,
        message: 'Modo demostración local.',
      );
    }

    final prefs = await SharedPreferences.getInstance();

    late http.Response policyResponse;
    late http.Response signatureResponse;

    try {
      final responses = await Future.wait([
        http
            .get(
              Uri.parse(policyUrl),
              headers: const {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache',
              },
            )
            .timeout(_timeout),
        http
            .get(
              Uri.parse(signatureUrl),
              headers: const {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache',
              },
            )
            .timeout(_timeout),
      ]);
      policyResponse = responses[0];
      signatureResponse = responses[1];
    } catch (_) {
      return _checkOfflineGrace(prefs);
    }

    if (policyResponse.statusCode != 200 || signatureResponse.statusCode != 200) {
      return _checkOfflineGrace(prefs);
    }

    if (policyResponse.bodyBytes.isEmpty ||
        policyResponse.bodyBytes.length > _maxPolicyBytes ||
        signatureResponse.bodyBytes.isEmpty ||
        signatureResponse.bodyBytes.length > _maxSignatureBytes) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.error,
        message: 'La política de seguridad recibida no es válida.',
      );
    }

    final policyBytes = policyResponse.bodyBytes;
    late final String signatureBase64;
    try {
      signatureBase64 = utf8.decode(
        signatureResponse.bodyBytes,
        allowMalformed: false,
      ).trim();
    } catch (_) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedSignature,
        message: 'La firma de seguridad tiene un formato incorrecto.',
      );
    }

    final validSignature = await _verifySignature(
      policyBytes: policyBytes,
      signatureBase64: signatureBase64,
    );

    if (!validSignature) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedSignature,
        message: 'Aplicación bloqueada. La política de seguridad no es válida.',
      );
    }

    final Map<String, dynamic>? policy = _decodePolicy(policyBytes);
    if (policy == null) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.error,
        message: 'La política de seguridad tiene un formato incorrecto.',
      );
    }

    final DateTime? serverDateUtc = _getServerDate(policyResponse);
    if (serverDateUtc == null) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.error,
        message: 'No se pudo verificar la fecha del servidor de seguridad.',
      );
    }

    final policyTimestampUtc = _policyTimestamp(policy);
    if (policyTimestampUtc == null) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.error,
        message: 'La política de seguridad no tiene una fecha válida.',
      );
    }
    if (policyTimestampUtc.isAfter(
      serverDateUtc.add(const Duration(minutes: 5)),
    )) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedClockInvalid,
        message: 'La fecha de la política de seguridad no es válida.',
      );
    }
    if (await _isSignedPolicyRollback(prefs, policyTimestampUtc)) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedRollback,
        message: 'Se ha detectado una política de seguridad anterior.',
      );
    }

    final policyText = utf8.decode(policyBytes, allowMalformed: false);

    // Se guarda también una política firmada que bloquee la aplicación. Así,
    // una pérdida posterior de conexión no reactiva una política antigua.
    try {
      await prefs.setInt(_lastOkMsKey, serverDateUtc.millisecondsSinceEpoch);
      await prefs.setString(_lastPolicyKey, policyText);
      await prefs.setString(_lastSignatureKey, signatureBase64);
    } catch (_) {
      // La validación online sigue siendo válida; únicamente no habrá gracia
      // sin conexión hasta que el almacenamiento vuelva a estar disponible.
    }

    return _evaluatePolicy(
      policy,
      onlineValidated: true,
      remainingDays: _readTtlDays(policy),
    );
  }

  static Future<bool> _verifySignature({
    required List<int> policyBytes,
    required String signatureBase64,
  }) async {
    try {
      final signatureBytes = base64Decode(signatureBase64);
      if (signatureBytes.length != 64) return false;

      final algorithm = Ed25519();

      for (final publicKeyBase64 in _publicKeyBase64s) {
        final publicKeyBytes = base64Decode(publicKeyBase64);
        if (publicKeyBytes.length != 32) continue;

        final signature = Signature(
          signatureBytes,
          publicKey: SimplePublicKey(
            publicKeyBytes,
            type: KeyPairType.ed25519,
          ),
        );

        if (await algorithm.verify(policyBytes, signature: signature)) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isSignedPolicyRollback(
    SharedPreferences prefs,
    DateTime incomingTimestampUtc,
  ) async {
    final cachedPolicyJson = prefs.getString(_lastPolicyKey);
    final cachedSignature = prefs.getString(_lastSignatureKey);
    if (cachedPolicyJson == null || cachedSignature == null) return false;

    final cachedBytes = utf8.encode(cachedPolicyJson);
    final validCachedSignature = await _verifySignature(
      policyBytes: cachedBytes,
      signatureBase64: cachedSignature,
    );
    if (!validCachedSignature) return false;

    final cachedPolicy = _decodePolicy(cachedBytes);
    final cachedTimestampUtc =
        cachedPolicy == null ? null : _policyTimestamp(cachedPolicy);
    return cachedTimestampUtc != null &&
        incomingTimestampUtc.isBefore(cachedTimestampUtc);
  }

  static Future<RemoteSecurityResult> _checkOfflineGrace(
    SharedPreferences prefs,
  ) async {
    final int? lastOkMs = prefs.getInt(_lastOkMsKey);
    final String? cachedPolicyJson = prefs.getString(_lastPolicyKey);
    final String? cachedSignature = prefs.getString(_lastSignatureKey);

    if (lastOkMs == null ||
        cachedPolicyJson == null ||
        cachedSignature == null) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedFirstCheckFailed,
        message:
            'No se pudo validar la aplicación. Conecta a internet e inténtalo de nuevo.',
      );
    }

    final cachedPolicyBytes = utf8.encode(cachedPolicyJson);
    final validCachedSignature = await _verifySignature(
      policyBytes: cachedPolicyBytes,
      signatureBase64: cachedSignature,
    );

    if (!validCachedSignature) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedSignature,
        message: 'La política guardada ha sido modificada o está dañada.',
      );
    }

    final policy = _decodePolicy(cachedPolicyBytes);
    if (policy == null) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.error,
        message: 'La política guardada no tiene un formato válido.',
      );
    }

    final lastOkUtc = DateTime.fromMillisecondsSinceEpoch(
      lastOkMs,
      isUtc: true,
    );
    final nowUtc = DateTime.now().toUtc();

    if (nowUtc.isBefore(lastOkUtc.subtract(const Duration(minutes: 5)))) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedClockInvalid,
        message:
            'La fecha del dispositivo no es válida. Corrígela y vuelve a abrir la aplicación.',
      );
    }

    final policyResult = await _evaluatePolicy(
      policy,
      onlineValidated: false,
    );
    if (!policyResult.isAllowed) return policyResult;

    final ttlDays = _readTtlDays(policy);
    final elapsed = nowUtc.difference(lastOkUtc);
    final remainingDays = ttlDays - elapsed.inDays;

    if (elapsed <= Duration(days: ttlDays)) {
      return RemoteSecurityResult(
        status: RemoteSecurityStatus.allowed,
        message:
            'Aplicación autorizada temporalmente. No se pudo conectar con el servidor de seguridad.',
        onlineValidated: false,
        remainingDays: remainingDays.clamp(0, ttlDays).toInt(),
      );
    }

    return RemoteSecurityResult(
      status: RemoteSecurityStatus.blockedExpired,
      message:
          'Aplicación bloqueada. Han pasado más de $ttlDays días sin validar la seguridad.',
      onlineValidated: false,
      remainingDays: 0,
    );
  }

  static Future<RemoteSecurityResult> _evaluatePolicy(
    Map<String, dynamic> policy, {
    required bool onlineValidated,
    int? remainingDays,
  }) async {
    final schemaVersion = policy['v'];
    final enabled = policy['enabled'];
    final minVersion = policy['minVersion'];

    if (schemaVersion != 1 ||
        enabled is! bool ||
        minVersion is! String ||
        !_isValidVersion(minVersion) ||
        _policyTimestamp(policy) == null) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.error,
        message: 'La política de seguridad está incompleta.',
      );
    }

    if (!enabled) {
      return RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedRemoteDisabled,
        message: 'Aplicación bloqueada por seguridad.',
        onlineValidated: onlineValidated,
        remainingDays: remainingDays,
      );
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_compareVersions(currentVersion, minVersion) < 0) {
        return RemoteSecurityResult(
          status: RemoteSecurityStatus.blockedVersion,
          message:
              'Versión no autorizada. Actualiza la aplicación para continuar.',
          onlineValidated: onlineValidated,
          remainingDays: remainingDays,
        );
      }
    } catch (_) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.error,
        message: 'No se pudo comprobar la versión de la aplicación.',
      );
    }

    return RemoteSecurityResult(
      status: RemoteSecurityStatus.allowed,
      message: onlineValidated
          ? 'Aplicación autorizada.'
          : 'Aplicación autorizada temporalmente.',
      onlineValidated: onlineValidated,
      remainingDays: remainingDays,
    );
  }

  static Map<String, dynamic>? _decodePolicy(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static DateTime? _policyTimestamp(Map<String, dynamic> policy) {
    final raw = policy['ts'];
    if (raw is! String ||
        !RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
      return null;
    }

    final parsed = DateTime.tryParse(raw);
    return parsed?.toUtc();
  }

  static int _readTtlDays(Map<String, dynamic> policy) {
    final raw = policy['ttlDays'];
    final int? parsed = raw is int
        ? raw
        : raw is String
            ? int.tryParse(raw)
            : null;

    if (parsed == null || parsed <= 0) return _defaultTtlDays;
    return parsed.clamp(1, _maximumTtlDays).toInt();
  }

  static DateTime? _getServerDate(http.Response response) {
    final dateHeader = response.headers['date'];
    if (dateHeader == null || dateHeader.trim().isEmpty) return null;

    try {
      return HttpDate.parse(dateHeader).toUtc();
    } catch (_) {
      return null;
    }
  }

  static bool _isValidVersion(String version) {
    final cleanVersion = version.split('+').first;
    return RegExp(r'^\d+(?:\.\d+){0,2}$').hasMatch(cleanVersion);
  }

  static int _compareVersions(String current, String minimum) {
    final currentParts = _versionParts(current);
    final minimumParts = _versionParts(minimum);

    for (var index = 0; index < 3; index++) {
      if (currentParts[index] > minimumParts[index]) return 1;
      if (currentParts[index] < minimumParts[index]) return -1;
    }

    return 0;
  }

  static List<int> _versionParts(String version) {
    final cleanVersion = version.split('+').first;
    final parts = cleanVersion.split('.');

    return List<int>.generate(3, (index) {
      if (index >= parts.length) return 0;
      return int.tryParse(parts[index]) ?? 0;
    });
  }
}
