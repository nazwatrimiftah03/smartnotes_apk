import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../services/profile_service.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _bioC = TextEditingController();
  final _service = ProfileService();

  late int _style;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _nameC.text = (user?.userMetadata?['full_name'] as String?) ?? '';
    _bioC.text = (user?.userMetadata?['bio'] as String?) ?? '';
    _style = AvatarStyles.current();
    _nameC.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameC.dispose();
    _bioC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _service.updateProfile(
        name: _nameC.text,
        avatarStyle: _style,
        bio: _bioC.text,
      );
      AppEvents.notifyDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Center(
              child: UserAvatar(
                name: _nameC.text,
                size: 96,
                styleIndex: _style,
                ring: true,
              ),
            ),
            const SizedBox(height: 18),
            SoftCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Warna avatar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (var i = 0; i < AvatarStyles.palettes.length; i++)
                        GestureDetector(
                          onTap: () => setState(() => _style = i),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AvatarStyles.gradient(i),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _style == i
                                    ? scheme.onSurface
                                    : Colors.transparent,
                                width: 2.4,
                              ),
                            ),
                            child: _style == i
                                ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 22)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameC,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama lengkap',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      counterText: '',
                    ),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Nama minimal 2 karakter'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _bioC,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Bio singkat (opsional)',
                      hintText: 'Contoh: Lagi nabung buat liburan',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: email,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                      helperText: 'Email tidak bisa diubah.',
                    ),
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
                  : const Text('Simpan perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}