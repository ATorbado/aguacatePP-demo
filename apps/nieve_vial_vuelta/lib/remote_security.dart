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
      final policy = jsonDecode(policyText) as Map<String, dynamic>;

      final enabled = policy['enabled'] == true;
      final minVersion = policy['minVersion']?.toString() ?? '0.0.0';
      final ttlDays = _readTtlDays(policy);

      if (!enabled) {
        return const RemoteSecurityResult(
          status: RemoteSecurityStatus.blockedRemoteDisabled,
          message: 'La aplicación ha sido deshabilitada por el administrador.',
        );
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_compareVersions(currentVersion, minVersion) < 0) {
        return const RemoteSecurityResult(
          status: RemoteSecurityStatus.blockedVersion,
          message: 'Actualiza la aplicación para continuar.',
        );
      }

      final nowUtc = _getServerDateOrNow(policyResponse);

      await prefs.setInt(_lastOkMsKey, nowUtc.millisecondsSinceEpoch);
      await prefs.setString(_lastPolicyKey, policyText);

      return RemoteSecurityResult(
        status: RemoteSecurityStatus.allowed,
        message: 'Aplicación autorizada.',
        onlineValidated: true,
        remainingDays: ttlDays,
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
    final lastOkMs = prefs.getInt(_lastOkMsKey);
    final cachedPolicyJson = prefs.getString(_lastPolicyKey);

    if (lastOkMs == null || cachedPolicyJson == null) {
      return const RemoteSecurityResult(
        status: RemoteSecurityStatus.blockedFirstCheckFailed,
        message:
            'No se pudo validar la aplicación por primera vez. Conéctate a internet e inténtalo de nuevo.',
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
    } catch (_) {
      ttlDays = 15;
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
