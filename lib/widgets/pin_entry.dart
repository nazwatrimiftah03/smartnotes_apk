import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../services/app_lock_service.dart';

/// Papan PIN: titik indikator + tombol angka.
/// [onSubmit] dipanggil saat digit penuh. Kembalikan teks error (PIN akan
/// dikosongkan dan papan bergetar) atau null kalau berhasil.
class PinEntry extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<String?> Function(String pin) onSubmit;

  /// Kalau diisi, tombol sidik jari muncul di kiri bawah.
  final VoidCallback? onBiometric;

  const PinEntry({
    super.key,
    required this.title,
    required this.onSubmit,
    this.subtitle,
    this.onBiometric,
  });

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry>
    with SingleTickerProviderStateMixin {
  static const double _keySize = 70;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  String _pin = '';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap(String digit) {
    if (_busy || _pin.length >= AppLockService.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == AppLockService.pinLength) _submit();
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final err = await widget.onSubmit(_pin);
    if (!mounted) return;

    if (err != null) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      setState(() {
        _pin = '';
        _error = err;
        _busy = false;
      });
    } else {
      setState(() {
        _pin = '';
        _busy = false;
      });
    }
  }

  Widget _key({String? label, IconData? icon, VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;

    if (label == null && icon == null) {
      return const SizedBox(width: _keySize, height: _keySize);
    }

    return Material(
      color: icon == null ? scheme.surfaceContainerLow : Colors.transparent,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: _keySize,
          height: _keySize,
          child: Center(
            child: icon != null
                ? Icon(icon, color: scheme.onSurfaceVariant)
                : Text(
              label!,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = _error != null;

    Widget row(List<Widget> keys) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys,
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 26),
          AnimatedBuilder(
            animation: _shake,
            builder: (_, child) {
              final t = _shake.value;
              final dx = math.sin(t * math.pi * 6) * 12 * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < AppLockService.pinLength; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 9),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length
                          ? (hasError ? AppColors.expense : scheme.primary)
                          : Colors.transparent,
                      border: Border.all(
                        color: hasError
                            ? AppColors.expense
                            : (i < _pin.length
                            ? scheme.primary
                            : scheme.outline),
                        width: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: Center(
              child: hasError
                  ? Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error, fontSize: 12),
              )
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          row([
            _key(label: '1', onTap: () => _tap('1')),
            _key(label: '2', onTap: () => _tap('2')),
            _key(label: '3', onTap: () => _tap('3')),
          ]),
          row([
            _key(label: '4', onTap: () => _tap('4')),
            _key(label: '5', onTap: () => _tap('5')),
            _key(label: '6', onTap: () => _tap('6')),
          ]),
          row([
            _key(label: '7', onTap: () => _tap('7')),
            _key(label: '8', onTap: () => _tap('8')),
            _key(label: '9', onTap: () => _tap('9')),
          ]),
          row([
            widget.onBiometric == null
                ? _key()
                : _key(
              icon: Icons.fingerprint_rounded,
              onTap: widget.onBiometric,
            ),
            _key(label: '0', onTap: () => _tap('0')),
            _key(icon: Icons.backspace_outlined, onTap: _backspace),
          ]),
        ],
      ),
    );
  }
}