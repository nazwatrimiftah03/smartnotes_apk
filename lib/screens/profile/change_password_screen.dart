import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/soft_card.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();
  final _service = ProfileService();

  bool _hideOld = true;
  bool _hideNew = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _oldC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _service.changePassword(
        oldPassword: _oldC.text,
        newPassword: _newC.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diganti.')),
      );
    } catch (e) {
      if (!mounted) return;
      var msg = AuthService.friendlyError(e);
      if (e is AuthException &&
          e.message.toLowerCase().contains('invalid login')) {
        msg = 'Password lama salah.';
      }
      setState(() {
        _error = msg;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ubah password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SoftCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.lock_rounded,
                        color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gunakan password yang kuat dan jangan dibagikan ke siapa pun.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _oldC,
                    obscureText: _hideOld,
                    decoration: InputDecoration(
                      labelText: 'Password lama',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hideOld = !_hideOld),
                        icon: Icon(_hideOld
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Password lama wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _newC,
                    obscureText: _hideNew,
                    decoration: InputDecoration(
                      labelText: 'Password baru',
                      prefixIcon: const Icon(Icons.key_rounded),
                      helperText: 'Minimal 6 karakter.',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hideNew = !_hideNew),
                        icon: Icon(_hideNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Minimal 6 karakter';
                      }
                      if (v == _oldC.text) {
                        return 'Password baru harus berbeda dari yang lama';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmC,
                    obscureText: _hideNew,
                    decoration: const InputDecoration(
                      labelText: 'Ulangi password baru',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                    validator: (v) =>
                    v != _newC.text ? 'Password tidak sama' : null,
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
                  : const Text('Ganti password'),
            ),
          ],
        ),
      ),
    );
  }
}