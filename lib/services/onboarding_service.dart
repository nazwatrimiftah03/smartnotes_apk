import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan apakah layar pengantar sudah pernah dilihat di perangkat ini.
class OnboardingService {
  static const String _key = 'onboarding_done';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}