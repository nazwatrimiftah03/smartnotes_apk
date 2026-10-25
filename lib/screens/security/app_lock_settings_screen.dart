import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/app_lock_service.dart';
import '../../services/biometric_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/soft_card.dart';
import 'pin_flow_screen.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final _bio = BiometricService();
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _bio.isAvailable().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
  }

  Future<void> _toggleBio(BuildContext context, bool value) async {
    if (value) {
      final ok = await _bio.authenticate('Aktifkan buka kunci biometrik');
      if (!ok) {
        if (context.mounted) _toast(context, 'Verifikasi biometrik gagal.');
        return;
      }
    }
    await appLockService.setBiometric(value);
  }

  static const List<(String, int)> _timeouts = [
    ('Langsung', 0),
    ('30 detik', 30),
    ('1 menit', 60),
    ('5 menit', 300),
  ];

  Future<bool> _push(BuildContext context, PinFlowScreen screen) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => screen),
    );
    return ok == true;
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _enable(BuildContext context) async {
    final ok = await _push(context, const PinFlowScreen(mode: PinFlowMode.create));
    if (ok && context.mounted) _toast(context, 'Kunci aplikasi aktif.');
  }

  Future<void> _change(BuildContext context) async {
    final verified = await _push(
      context,
      const PinFlowScreen(mode: PinFlowMode.verify),
    );
    if (!verified || !context.mounted) return;

    final ok = await _push(context, const PinFlowScreen(mode: PinFlowMode.create));
    if (ok && context.mounted) _toast(context, 'PIN berhasil diubah.');
  }

  Future<void> _disable(BuildContext context) async {
    final verified = await _push(
      context,
      const PinFlowScreen(
        mode: PinFlowMode.verify,
        title: 'Konfirmasi untuk mematikan',
      ),
    );
    if (!verified || !context.mounted) return;

    final sure = await showConfirmDialog(
      context,
      title: 'Matikan kunci aplikasi?',
      message: 'Aplikasi bisa dibuka tanpa PIN.',
      confirmLabel: 'Matikan',
    );
    if (!sure) return;

    await appLockService.disable();
    if (context.mounted) _toast(context, 'Kunci aplikasi dimatikan.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kunci aplikasi')),
      body: ListenableBuilder(
        listenable: appLockService,
        builder: (context, _) {
          final on = appLockService.enabled;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              SoftCard(
                gradient: on ? AppColors.heroGradient : null,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: on
                            ? Colors.white.withValues(alpha: 0.25)
                            : scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        on ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 28,
                        color: on ? Colors.white : scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            on ? 'Kunci aktif' : 'Kunci belum aktif',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: on ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            on
                                ? 'Smartnotes meminta PIN ${AppLockService.pinLength} digit saat dibuka.'
                                : 'Lindungi catatan keuanganmu dengan PIN.',
                            style: TextStyle(
                              color: on
                                  ? Colors.white.withValues(alpha: 0.92)
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!on)
                FilledButton.icon(
                  onPressed: () => _enable(context),
                  icon: const Icon(Icons.pin_rounded),
                  label: const Text('Aktifkan PIN'),
                )
              else ...[
                Text(
                  'Kunci otomatis',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seberapa lama aplikasi boleh ditinggalkan sebelum meminta PIN lagi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                SoftCard(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _timeouts)
                        ChoiceChip(
                          label: Text(t.$1),
                          selected: appLockService.timeoutSeconds == t.$2,
                          showCheckmark: false,
                          onSelected: (_) => appLockService.setTimeout(t.$2),
                        ),
                    ],
                  ),
                ),
                if (_bioAvailable) ...[
                  const SizedBox(height: 20),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SwitchListTile(
                      secondary: Icon(
                        Icons.fingerprint_rounded,
                        color: scheme.primary,
                      ),
                      title: const Text('Sidik jari / wajah'),
                      subtitle: const Text('Buka kunci tanpa mengetik PIN'),
                      value: appLockService.biometricEnabled,
                      onChanged: (v) => _toggleBio(context, v),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.edit_rounded, color: scheme.primary),
                        title: const Text('Ubah PIN'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _change(context),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        endIndent: 16,
                        color: scheme.outlineVariant,
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.lock_open_rounded,
                          color: scheme.error,
                        ),
                        title: Text(
                          'Matikan kunci',
                          style: TextStyle(color: scheme.error),
                        ),
                        onTap: () => _disable(context),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'PIN hanya tersimpan di perangkat ini dan tidak bisa dilihat kembali. Kalau lupa, keluar dari akun lalu masuk lagi untuk mengatur ulang.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}