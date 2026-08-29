import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _keyAuthEnabled = 'auth_enabled';
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAuthEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAuthEnabled) ?? true;
  }

  Future<void> setAuthEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAuthEnabled, value);
  }

  Future<bool> unlockIfEnabled() async {
    final enabled = await isAuthEnabled();
    if (!enabled) return true;

    try {
      final supported = await _auth.isDeviceSupported();
      final canBiometric = await _auth.canCheckBiometrics;
      final biometrics = await _auth.getAvailableBiometrics();

      debugPrint('AUTH supported: $supported');
      debugPrint('AUTH canBiometric: $canBiometric');
      debugPrint('AUTH biometrics: $biometrics');

      if (!supported) {
        debugPrint('AUTH: dispositivo no soportado');
        return false;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Desbloquea Mi Diario para continuar',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      debugPrint('AUTH result: $ok');
      return ok;
    } catch (e) {
      debugPrint('AUTH error: $e');
      return false;
    }
  }
}