import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Pembuka kunci dengan sidik jari / wajah (biometrik bawaan perangkat).
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// True kalau perangkat mendukung dan sudah punya biometrik terdaftar.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final list = await _auth.getAvailableBiometrics();
      return list.isNotEmpty;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}