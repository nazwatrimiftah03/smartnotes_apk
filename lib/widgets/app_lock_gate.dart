import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import 'brand_logo.dart';
import 'pin_entry.dart';
import 'soft_backdrop.dart';

/// Dipasang di MaterialApp.builder supaya layar kunci menutupi SEMUA halaman.
/// Terkunci saat aplikasi dibuka, dan saat kembali dari latar belakang
/// setelah melewati batas waktu yang dipilih.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _ready = false;
  bool _locked = false;
  DateTime? _pausedAt;
  StreamSubscription<AuthState>? _sub;

  bool get _hasSession => Supabase.instance.client.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await appLockService.load();
    if (!mounted) return;

    appLockService.addListener(_onLockChanged);
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedOut && _locked && mounted) {
        setState(() => _locked = false);
      }
    });

    setState(() {
      _locked = appLockService.enabled && _hasSession;
      _ready = true;
    });
  }

  void _onLockChanged() {
    if (!appLockService.enabled && _locked && mounted) {
      setState(() => _locked = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appLockService.removeListener(_onLockChanged);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final at = _pausedAt;
      _pausedAt = null;
      if (at == null || _locked || !_ready) return;
      if (!appLockService.enabled || !_hasSession) return;

      final away = DateTime.now().difference(at).inSeconds;
      if (away >= appLockService.timeoutSeconds) {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return ColoredBox(color: Theme.of(context).colorScheme.surface);
    }

    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: _LockScreen(
              onUnlocked: () => setState(() => _locked = false),
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const _LockScreen({required this.onUnlocked});

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final _bio = BiometricService();
  bool _forgot = false;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    if (appLockService.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    if (_prompting || !mounted) return;
    _prompting = true;
    final ok = await _bio.authenticate('Buka kunci Smartnotes');
    _prompting = false;
    if (ok && mounted) widget.onUnlocked();
  }

  Future<String?> _verify(String pin) async {
    final blocked = appLockService.blockedSeconds;
    if (blocked > 0) return appLockService.failureMessage();

    if (appLockService.verify(pin)) {
      widget.onUnlocked();
      return null;
    }
    return appLockService.failureMessage();
  }

  Future<void> _resetByLogout() async {
    await appLockService.disable();
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SoftBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(size: 64),
                  const SizedBox(height: 20),
                  if (!_forgot) ...[
                    PinEntry(
                      title: 'Masukkan PIN',
                      subtitle: 'Buka kunci Smartnotes',
                      onSubmit: _verify,
                      onBiometric: appLockService.biometricEnabled
                          ? _tryBiometric
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _forgot = true),
                      child: const Text('Lupa PIN?'),
                    ),
                  ] else ...[
                    Text(
                      'Reset PIN',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Untuk mengatur ulang PIN, kamu perlu keluar dari akun lalu masuk lagi. Data catatanmu tetap aman.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _resetByLogout,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      child: const Text('Keluar dan reset PIN'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _forgot = false),
                      child: const Text('Batal'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}