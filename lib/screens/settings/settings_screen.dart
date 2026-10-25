import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_events.dart';
import '../../core/app_theme.dart';
import '../../services/app_lock_service.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/user_avatar.dart';
import '../about/about_screen.dart';
import '../categories/categories_screen.dart';
import '../goals/goals_screen.dart';
import '../help/help_screen.dart';
import '../profile/change_password_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../security/app_lock_settings_screen.dart';
import '../wallets/wallets_screen.dart';
import '../recurring/recurring_screen.dart';
import '../export/export_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileService = ProfileService();
  ProfileStats? _stats;

  @override
  void initState() {
    super.initState();
    AppEvents.dataVersion.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    AppEvents.dataVersion.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    // Rebuild supaya nama/avatar terbaru ikut tampil.
    if (mounted) setState(() {});
    try {
      final s = await _profileService.getStats();
      if (!mounted) return;
      setState(() => _stats = s);
    } catch (_) {
      // Statistik hanya pelengkap; abaikan kalau gagal.
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu perlu masuk lagi untuk melihat catatanmu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (ok == true) await AuthService().signOut();
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?) ?? 'Pengguna';
    final bio = ((user?.userMetadata?['bio'] as String?) ?? '').trim();
    final email = user?.email ?? '-';
    final since = user == null
        ? null
        : DateTime.tryParse(user.createdAt.toString())?.toLocal();

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );

    Widget divider() => Divider(
      height: 1,
      indent: 72,
      endIndent: 16,
      color: scheme.outlineVariant,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ===== Kartu profil =====
          SoftCard(
            gradient: AppColors.heroGradient,
            padding: EdgeInsets.zero,
            radius: 28,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned(
                  left: -30,
                  bottom: -60,
                  child: _Glass(size: 130, alpha: 0.08),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      UserAvatar(name: name, size: 84, ring: true),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '“$bio”',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (since != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Bergabung ${DateFormat('MMMM yyyy', 'id_ID').format(since)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _open(const EditProfileScreen()),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                        ),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit profil'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ===== Statistik =====
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF42A5F5),
                  value: _stats?.transactions,
                  label: 'Transaksi',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.income,
                  value: _stats?.wallets,
                  label: 'Dompet',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.category_rounded,
                  color: const Color(0xFFAB47BC),
                  value: _stats?.categories,
                  label: 'Kategori',
                ),
              ),
            ],
          ),
          if (_stats?.firstTransaction != null) ...[
            const SizedBox(height: 10),
            Text(
              'Mencatat sejak ${DateFormat('d MMMM yyyy', 'id_ID').format(_stats!.firstTransaction!)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 24),

          // ===== Kelola data =====
          sectionTitle('Kelola data'),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.income,
                  title: 'Dompet',
                  subtitle: 'Tunai, bank, e-wallet',
                  onTap: () => _open(const WalletsScreen()),
                ),
                divider(),
                _MenuTile(
                  icon: Icons.category_rounded,
                  color: const Color(0xFFAB47BC),
                  title: 'Kategori',
                  subtitle: 'Ikon dan warna sesukamu',
                  onTap: () => _open(const CategoriesScreen()),
                ),
                divider(),
                _MenuTile(
                  icon: Icons.flag_rounded,
                  color: const Color(0xFFFF7043),
                  title: 'Target tabungan',
                  subtitle: 'Liburan, gadget, dana darurat',
                  onTap: () => _open(const GoalsScreen()),
                ),
                divider(),
                _MenuTile(
                  icon: Icons.file_download_rounded,
                  color: const Color(0xFF29B6F6),
                  title: 'Ekspor data',
                  subtitle: 'Simpan ke CSV untuk Excel',
                  onTap: () => _open(const ExportScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ===== Keamanan =====
          sectionTitle('Keamanan'),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.person_rounded,
                  color: AppColors.primary,
                  title: 'Edit profil',
                  subtitle: 'Nama, bio, dan warna avatar',
                  onTap: () => _open(const EditProfileScreen()),
                ),
                divider(),
                _MenuTile(
                  icon: Icons.lock_rounded,
                  color: const Color(0xFFFFA726),
                  title: 'Ubah password',
                  subtitle: 'Jaga akunmu tetap aman',
                  onTap: () => _open(const ChangePasswordScreen()),
                ),
                divider(),
                ListenableBuilder(
                  listenable: appLockService,
                  builder: (context, _) => _MenuTile(
                    icon: Icons.pin_rounded,
                    color: const Color(0xFF26A69A),
                    title: 'Kunci aplikasi',
                    subtitle: appLockService.enabled
                        ? 'Aktif • PIN ${AppLockService.pinLength} digit'
                        : 'Belum aktif',
                    onTap: () => _open(const AppLockSettingsScreen()),
                  ),
                ),
                divider(),
                _MenuTile(
                  icon: Icons.slideshow_rounded,
                  color: const Color(0xFFEC407A),
                  title: 'Lihat pengantar',
                  subtitle: 'Perkenalan singkat Smartnotes',
                  onTap: () => _open(const OnboardingScreen(replay: true)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ===== Tampilan =====
          sectionTitle('Tampilan'),
          SoftCard(
            child: ListenableBuilder(
              listenable: appThemeService,
              builder: (context, _) {
                return Center(
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Otomatis'),
                        icon: Icon(Icons.brightness_auto_rounded),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Terang'),
                        icon: Icon(Icons.light_mode_rounded),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Gelap'),
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                    ],
                    selected: {appThemeService.themeMode},
                    onSelectionChanged: (s) =>
                        appThemeService.setThemeMode(s.first),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // ===== Bantuan =====
          sectionTitle('Bantuan'),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.help_rounded,
                  color: const Color(0xFF26C6DA),
                  title: 'Panduan & FAQ',
                  subtitle: 'Cara memakai Smartnotes',
                  onTap: () => _open(const HelpScreen()),
                ),
                divider(),
                _MenuTile(
                  icon: Icons.info_rounded,
                  color: const Color(0xFF78909C),
                  title: 'Tentang aplikasi',
                  subtitle: 'Versi ${AboutScreen.version}',
                  onTap: () => _open(const AboutScreen()),
                ),
                divider(),
                _MenuTile(
                  icon: Icons.event_repeat_rounded,
                  color: const Color(0xFF5C6BC0),
                  title: 'Transaksi berulang',
                  subtitle: 'Tagihan dan gaji otomatis',
                  onTap: () => _open(const RecurringScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ===== Keluar =====
          SoftCard(
            padding: EdgeInsets.zero,
            onTap: _confirmLogout,
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: scheme.error),
              title: Text(
                'Keluar',
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final double size;
  final double alpha;

  const _Glass({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int? value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value?.toString() ?? '-',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}