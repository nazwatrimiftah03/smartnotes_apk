import 'package:flutter/material.dart';

import '../../services/app_lock_service.dart';
import '../../widgets/pin_entry.dart';

enum PinFlowMode {
  /// Buat PIN baru (masukkan dua kali).
  create,

  /// Verifikasi PIN saat ini.
  verify,
}

/// Layar penuh untuk membuat atau memverifikasi PIN.
/// Hasil: `true` lewat Navigator.pop kalau berhasil.
class PinFlowScreen extends StatefulWidget {
  final PinFlowMode mode;
  final String? title;

  const PinFlowScreen({super.key, required this.mode, this.title});

  @override
  State<PinFlowScreen> createState() => _PinFlowScreenState();
}

class _PinFlowScreenState extends State<PinFlowScreen> {
  int _step = 0;
  String? _first;

  Future<String?> _onCreate(String pin) async {
    if (_step == 0) {
      setState(() {
        _first = pin;
        _step = 1;
      });
      return null;
    }

    if (pin != _first) {
      setState(() {
        _first = null;
        _step = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN tidak sama. Ulangi dari awal.')),
      );
      return null;
    }

    await appLockService.setPin(pin);
    if (!mounted) return null;
    Navigator.of(context).pop(true);
    return null;
  }

  Future<String?> _onVerify(String pin) async {
    if (appLockService.blockedSeconds > 0) return appLockService.failureMessage();

    if (appLockService.verify(pin)) {
      Navigator.of(context).pop(true);
      return null;
    }
    return appLockService.failureMessage();
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.mode == PinFlowMode.create;

    final String title;
    final String subtitle;
    if (isCreate) {
      title = _step == 0 ? 'Buat PIN baru' : 'Ulangi PIN';
      subtitle = _step == 0
          ? 'Masukkan ${AppLockService.pinLength} digit angka'
          : 'Masukkan PIN yang sama sekali lagi';
    } else {
      title = widget.title ?? 'Masukkan PIN saat ini';
      subtitle = 'Untuk melanjutkan, konfirmasi PIN kamu';
    }

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: PinEntry(
              key: ValueKey('${widget.mode.name}-$_step'),
              title: title,
              subtitle: subtitle,
              onSubmit: isCreate ? _onCreate : _onVerify,
            ),
          ),
        ),
      ),
    );
  }
}