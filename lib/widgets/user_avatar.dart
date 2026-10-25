import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pilihan warna avatar. Index disimpan di metadata akun ('avatar_style').
class AvatarStyles {
  static const List<List<Color>> palettes = [
    [Color(0xFFFF9EBF), Color(0xFFEC6F9B), Color(0xFFC85FA6)],
    [Color(0xFF4FC3F7), Color(0xFF3F8EF2), Color(0xFF6C5CE7)],
    [Color(0xFF66E0C4), Color(0xFF2FB5A0), Color(0xFF1E8E8A)],
    [Color(0xFFFFB74D), Color(0xFFFF8A50), Color(0xFFF2685A)],
    [Color(0xFFB39DFF), Color(0xFF8E6CEF), Color(0xFF6A4BD8)],
    [Color(0xFFA5D86E), Color(0xFF66BB6A), Color(0xFF2E9E5B)],
    [Color(0xFFFF8FB1), Color(0xFFF06292), Color(0xFFD81B60)],
    [Color(0xFF90A4AE), Color(0xFF607D8B), Color(0xFF455A64)],
  ];

  static int current() {
    final raw = Supabase.instance.client.auth.currentUser
        ?.userMetadata?['avatar_style'];
    final i = raw is num ? raw.toInt() : 0;
    return i.clamp(0, palettes.length - 1);
  }

  static LinearGradient gradient(int index) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: palettes[index.clamp(0, palettes.length - 1)],
  );
}

class UserAvatar extends StatelessWidget {
  final String name;
  final double size;

  /// Kalau null, dipakai pilihan yang tersimpan di akun.
  final int? styleIndex;

  /// Cincin putih tipis (untuk dipakai di atas kartu bergradien).
  final bool ring;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.styleIndex,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AvatarStyles.gradient(styleIndex ?? AvatarStyles.current()),
        shape: BoxShape.circle,
        border: ring
            ? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 3)
            : null,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}