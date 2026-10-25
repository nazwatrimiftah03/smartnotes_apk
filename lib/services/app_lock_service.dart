import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kunci aplikasi dengan PIN. Disimpan di perangkat (bukan di server):
/// yang tersimpan hanya hash PIN yang diberi garam acak.
class AppLockService extends ChangeNotifier {
  static const int pinLength = 4;
  static const int maxAttempts = 5;
  static const int cooldownSeconds = 30;

  static const String _kEnabled = 'lock_enabled';
  static const String _kHash = 'lock_hash';
  static const String _kSalt = 'lock_salt';
  static const String _kTimeout = 'lock_timeout';
  static const String _kBio = 'lock_bio';

  bool _enabled = false;
  String? _hash;
  String? _salt;
  int _timeoutSeconds = 30;
  bool _biometric = false;

  int _failed = 0;
  DateTime? _blockedUntil;

  bool get enabled => _enabled;

  /// Boleh membuka kunci dengan sidik jari / wajah.
  bool get biometricEnabled => _enabled && _biometric;

  /// Berapa detik aplikasi boleh di latar belakang sebelum terkunci lagi.
  int get timeoutSeconds => _timeoutSeconds;

  int get remainingAttempts => maxAttempts - _failed;

  int get blockedSeconds {
    final b = _blockedUntil;
    if (b == null) return 0;
    final diff = b.difference(DateTime.now());
    if (diff.isNegative) {
      _blockedUntil = null;
      return 0;
    }
    return (diff.inMilliseconds / 1000).ceil();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _hash = prefs.getString(_kHash);
    _salt = prefs.getString(_kSalt);
    _enabled = (prefs.getBool(_kEnabled) ?? false) && _hash != null && _salt != null;
    _timeoutSeconds = prefs.getInt(_kTimeout) ?? 30;
    _biometric = prefs.getBool(_kBio) ?? false;
    notifyListeners();
  }

  String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    final hash = _hashPin(pin, salt);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSalt, salt);
    await prefs.setString(_kHash, hash);
    await prefs.setBool(_kEnabled, true);

    _salt = salt;
    _hash = hash;
    _enabled = true;
    _failed = 0;
    _blockedUntil = null;
    notifyListeners();
  }

  Future<void> setTimeout(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTimeout, seconds);
    _timeoutSeconds = seconds;
    notifyListeners();
  }

  Future<void> setBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBio, value);
    _biometric = value;
    notifyListeners();
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBio);
    await prefs.remove(_kHash);
    await prefs.remove(_kSalt);
    await prefs.setBool(_kEnabled, false);

    _hash = null;
    _salt = null;
    _enabled = false;
    _biometric = false;
    _failed = 0;
    _blockedUntil = null;
    notifyListeners();
  }

  /// Cek PIN. Salah [maxAttempts] kali berturut-turut = diblokir sementara.
  bool verify(String pin) {
    if (!_enabled || _hash == null || _salt == null) return true;
    if (blockedSeconds > 0) return false;

    if (_hashPin(pin, _salt!) == _hash) {
      _failed = 0;
      return true;
    }

    _failed++;
    if (_failed >= maxAttempts) {
      _blockedUntil = DateTime.now().add(const Duration(seconds: cooldownSeconds));
      _failed = 0;
    }
    return false;
  }

  /// Pesan error standar setelah PIN salah / sedang diblokir.
  String failureMessage() {
    final b = blockedSeconds;
    if (b > 0) return 'Terlalu banyak percobaan. Coba lagi dalam $b detik.';
    return 'PIN salah. Sisa percobaan: $remainingAttempts';
  }
}

final AppLockService appLockService = AppLockService();