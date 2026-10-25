import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';
import 'core/supabase_config.dart';
import 'screens/splash/splash_screen.dart';
import 'services/theme_service.dart';
import 'widgets/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID');
  await appThemeService.loadTheme();

  if (SupabaseConfig.url.isEmpty || SupabaseConfig.publishableKey.isEmpty) {
    throw StateError(
      'Konfigurasi Supabase belum diisi. Jalankan aplikasi dengan '
          '--dart-define-from-file=env.json',
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const SmartnotesApp());
}

class SmartnotesApp extends StatelessWidget {
  const SmartnotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeService,
      builder: (context, child) {
        return MaterialApp(
          title: 'Smartnotes',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appThemeService.themeMode,
          // Layar kunci menutupi semua halaman.
          builder: (context, child) =>
              AppLockGate(child: child ?? const SizedBox.shrink()),
          home: const SplashScreen(),
        );
      },
    );
  }
}