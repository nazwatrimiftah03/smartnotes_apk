import 'package:flutter/material.dart';

import '../../services/onboarding_service.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/soft_backdrop.dart';
import '../auth/auth_gate.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goNext();
  }

  Future<void> _goNext() async {
    final results = await Future.wait<dynamic>([
      Future.delayed(const Duration(milliseconds: 1600)),
      OnboardingService.isDone(),
    ]);
    if (!mounted) return;

    final done = results[1] as bool;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => done ? const AuthGate() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SoftBackdrop(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 104),
              const SizedBox(height: 24),
              Text(
                'Smartnotes',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Catat keuangan, lebih tenang',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}