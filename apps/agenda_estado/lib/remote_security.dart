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
  blockedPolicyInvalid,
  blockedPolicyExpired,
  blockedExpired,
  blockedFirstCheckFailed,
  blockedClockInvalid,
  error,
}

enum PolicyTimestampStatus { valid, missingOrInvalid, future, expired }

class PolicyTimestampValidation {
  final PolicyTimestampStatus status;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final int remainingDays;

  const PolicyTimestampValidation({
    required this.status,
    this.issuedAt,
    this.expiresAt,
    this.remainingDays = 0,
  });
}

PolicyTimestampValidation validatePolicyTimestamp({
  required Map<String, dynamic> policy,
  required DateTime nowUtc,
  required int ttlDays,
}) {
  final rawTimestamp = policy['ts'];
  if (rawTimestamp is! String || rawTimestamp.trim().isEmpty || ttlDays <= 0) {
    return const PolicyTimestampValidation(
      status: PolicyTimestampStatus.missingOrInvalid,
    );
  }

  final issuedAt = DateTime.tryParse(rawTimestamp.trim());
  if (issuedAt == null || !issuedAt.isUtc) {
    return const PolicyTimestampValidation(
      status: PolicyTimestampStatus.missingOrInvalid,
    );
  }

  final normalizedNow = nowUtc.toUtc();
  if (issuedAt.isAfter(normalizedNow.add(const Duration(minutes: 5)))) {
    return PolicyTimestampValidation(
      status: PolicyTimestampStatus.future,
      issuedAt: issuedAt,
    );
  }

  final expiresAt = issuedAt.add(Duration(days: ttlDays));
  if (normalizedNow.isAfter(expiresAt)) {
    return PolicyTimestampValidation(
      status: PolicyTimestampStatus.expired,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
    );
  }

  final remainingSeconds = expiresAt.difference(normalizedNow).inSeconds;
  final remainingDays =
      (remainingSeconds + Duration.secondsPerDay - 1) ~/ Duration.secondsPerDay;
  return PolicyTimestampValidation(
    status: PolicyTimestampStatus.valid,
    issuedAt: issuedAt,
    expiresAt: expiresAt,
    remainingDays: remainingDays,
  );
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

  static const String _lastOkMsKey = 'remote_security_last_ok_ms';
  static const String _lastPolicyKey = 'remote_security_last_policy_json';

  static Future<RemoteSecurityResult> check() async {
    if (_demoMode) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.allowed,
        message: 'Modo demostración local.',
      );
    }

    final prefs = await SharedPreferences.getInstance();

    try {
      final policyResponse = await http
          .get(
            Uri.parse(policyUrl),
            headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          )
          .timeout(_timeout);

      final sigResponse = await http
          .get(
            Uri.parse(signatureUrl),
            headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          )
          .timeout(_timeout);

      if (policyResponse.statusCode != 200 || sigResponse.statusCode != 200) {
        return _checkOfflineGrace(prefs);
      }

      final policyBytes = policyResponse.bodyBytes;
      final signatureBase64 = utf8.decode(sigResponse.bodyBytes).trim();

      final validSignature = await _verifySignature(
        policyBytes: policyBytes,
        signatureBase64: signatureBase64,
      );

      if (!validSignature) {
        return const RemoteSecurityResult(
          status: RemoteSecurityStatus.blockedSignature,
          message:
              'Aplicación bloqueada. La política de seguridad no es válida.',
        );
      }

      final policyText = utf8.decode(policyBytes);
      final Map<String, dynamic> policy = jsonDecode(policyText);

      final bool enabled = policy['enabled'] == true;
      final String minVersion = policy['minVersion']?.toString() ?? '0.0.0';
      final int ttlDays = _readTtlDays(policy);
      final nowUtc = _getServerDateOrNow(policyResponse);
      final timestampValidation = validatePolicyTimestamp(
        policy: policy,
        nowUtc: nowUtc,
        ttlDays: ttlDays,
      );

      final timestampBlock = _timestampBlockResult(timestampValidation);
      if (timestampBlock != null) {
        return timestampBlock;
      }

      if (!enabled) {
        return const RemoteSecurityResult(
          status: RemoteSecurityStatus.blockedRemoteDisabled,
          message: 'Aplicación bloqueada por seguridad.',
        );
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_compareVersions(currentVersion, minVersion) < 0) {
        return const RemoteSecurityResult(
          status: RemoteSecurityStatus.blockedVersion,
          message:
              'Versión no autorizada. Actualiza la aplicación para continuar.',
        );
      }

      await prefs.setInt(_lastOkMsKey, nowUtc.millisecondsSinceEpoch);
      await prefs.setString(_lastPolicyKey, policyText);

      return RemoteSecurityResult(
        status: RemoteSecurityStatus.allowed,
        message: 'Aplicación autorizada.',
        onlineValidated: true,
        remainingDays: timestampValidation.remainingDays,
      );
    } catch (_) {
      return _checkOfflineGrace(prefs);
    }
  }

  static Future<bool> _verifySignature({
    required List<int> policyBytes,
    required String signatureBase64,
  }) async {
    try {
      final signatureBytes = base64Decode(signatureBase64);
      final algorithm = Ed25519();

      for (final publicKeyBase64 in _publicKeyBase64s) {
        final signature = Signature(
          signatureBytes,
          publicKey: SimplePublicKey(
            base64Decode(publicKeyBase64),
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

  static Future<RemoteSecurityResult> _checkOfflineGrace(
    SharedPreferences prefs,
  ) async {
    final int? lastOkMs = prefs.getInt(_lastOkMsKey);
    final String? cachedPolicyJson = prefs.getString(_lastPolicyKey);

    if (lastOkMs == null || cachedPolicyJson == null) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedFirstCheckFailed,
        message:
            'No se pudo validar la aplicación por primera vez. Conecta a internet e inténtalo de nuevo.',
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
            'La fecha del dispositivo no es válida. Corrige la fecha y vuelve a abrir la aplicación.',
      );
    }

    int ttlDays = 15;

    try {
      final cachedPolicy = jsonDecode(cachedPolicyJson) as Map<String, dynamic>;
      ttlDays = _readTtlDays(cachedPolicy);
      final timestampValidation = validatePolicyTimestamp(
        policy: cachedPolicy,
        nowUtc: nowUtc,
        ttlDays: ttlDays,
      );
      final timestampBlock = _timestampBlockResult(timestampValidation);
      if (timestampBlock != null) {
        return timestampBlock;
      }
    } catch (_) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedPolicyInvalid,
        message:
            'Aplicación bloqueada. La fecha de la política de seguridad no es válida.',
      );
    }

    final elapsed = nowUtc.difference(lastOkUtc);
    final remainingDays = ttlDays - elapsed.inDays;

    if (elapsed <= Duration(days: ttlDays)) {
      return RemoteSecurityResult(
        status: RemoteSecurityStatus.allowed,
        message:
            'Aplicación autorizada temporalmente. No se pudo conectar con el servidor de seguridad.',
        onlineValidated: false,
        remainingDays: remainingDays < 0 ? 0 : remainingDays,
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

  static int _readTtlDays(Map<String, dynamic> policy) {
    final raw = policy['ttlDays'];

    if (raw is int && raw > 0) {
      return raw;
    }

    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return 15;
  }

  static RemoteSecurityResult? _timestampBlockResult(
    PolicyTimestampValidation validation,
  ) {
    return switch (validation.status) {
      PolicyTimestampStatus.valid => null,
      PolicyTimestampStatus.missingOrInvalid => const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedPolicyInvalid,
        message:
            'Aplicación bloqueada. La fecha de la política de seguridad no es válida.',
      ),
      PolicyTimestampStatus.future => const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedClockInvalid,
        message:
            'La fecha de la política está en el futuro. Revisa la fecha y la firma.',
      ),
      PolicyTimestampStatus.expired => const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedPolicyExpired,
        message:
            'Aplicación bloqueada. La política de seguridad firmada ha caducado.',
      ),
    };
  }

  static DateTime _getServerDateOrNow(http.Response response) {
    final dateHeader = response.headers['date'];

    if (dateHeader == null || dateHeader.trim().isEmpty) {
      return DateTime.now().toUtc();
    }

    try {
      return HttpDate.parse(dateHeader).toUtc();
    } catch (_) {
      return DateTime.now().toUtc();
    }
  }

  static int _compareVersions(String current, String minimum) {
    final currentParts = _versionParts(current);
    final minimumParts = _versionParts(minimum);

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] > minimumParts[i]) return 1;
      if (currentParts[i] < minimumParts[i]) return -1;
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
