import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cryptography/cryptography.dart';

const policyUrl = String.fromEnvironment('POLICY_URL');
const sigUrl = String.fromEnvironment('POLICY_SIGNATURE_URL');
const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

const _publicKeyB64s = [
  'LYD6OMyFYKaJW4qAoTidkFUNGt3shvpAYbAhTR67gW0=',
  'Fd7IhSk5HVXyfiJfKKkOm+XLbSyxaatm0hV8NmrKttY=',
];

final _publicKeys = _publicKeyB64s
    .map((key) => SimplePublicKey(base64Decode(key), type: KeyPairType.ed25519))
    .toList(growable: false);
final _algo = Ed25519();

enum GateStatus {
  allowed,
  blockedByRemote,
  blockedByVersion,
  blockedByOffline,
  unknown,
}

class PolicyGuard {
  static Future<GateStatus> evaluate() async {
    if (demoMode) return GateStatus.allowed;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    Map<String, dynamic>? policy = await _fetchPolicy();

    if (policy != null) {
      await prefs.setString('policy_json', jsonEncode(policy));
      await prefs.setString('policy_last_ok', now.toIso8601String());
    } else {
      final cached = prefs.getString('policy_json');
      if (cached != null) policy = jsonDecode(cached);
    }
    if (policy == null) return GateStatus.blockedByOffline;

    if (policy['enabled'] != true) return GateStatus.blockedByRemote;

    final info = await PackageInfo.fromPlatform();
    final minV = (policy['minVersion'] ?? '0.0.0') as String;
    if (_cmp(info.version, minV) < 0) return GateStatus.blockedByVersion;

    final ttl = policy['ttlDays'] is int ? policy['ttlDays'] as int : 15;
    final lastStr = prefs.getString('policy_last_ok');
    if (lastStr == null) return GateStatus.blockedByOffline;
    final lastOk = DateTime.parse(lastStr);
    if (now.difference(lastOk).inDays >= ttl) {
      return GateStatus.blockedByOffline;
    }

    return GateStatus.allowed;
  }

  static Future<Map<String, dynamic>?> _fetchPolicy() async {
    final cb = DateTime.now().millisecondsSinceEpoch; // anticache
    final rJson = await http
        .get(Uri.parse('$policyUrl?cb=$cb'))
        .timeout(const Duration(seconds: 6));
    final rSig = await http
        .get(Uri.parse('$sigUrl?cb=$cb'))
        .timeout(const Duration(seconds: 6));
    if (rJson.statusCode != 200 || rSig.statusCode != 200) return null;

    final body = utf8.decode(rJson.bodyBytes);
    final sigB64 = rSig.body.trim();
    final signatureBytes = base64Decode(sigB64);
    var ok = false;
    for (final publicKey in _publicKeys) {
      ok = await _algo.verify(
        utf8.encode(body),
        signature: Signature(signatureBytes, publicKey: publicKey),
      );
      if (ok) break;
    }
    return ok ? jsonDecode(body) as Map<String, dynamic> : null;
  }

  static int _cmp(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final va = i < pa.length ? pa[i] : 0, vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va > vb ? 1 : -1;
    }
    return 0;
  }
}
