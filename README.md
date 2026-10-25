# Smartnotes

Aplikasi Android untuk mencatat keuangan pribadi yang simpel, rapi, dan menyenangkan dipakai. Catat pemasukan dan pengeluaran di banyak dompet, atur anggaran per kategori, pantau target tabungan, lihat laporan, dan ekspor data ke CSV atau PDF. Dibuat dengan **Flutter** dan **Supabase**.

## Fitur

| Fitur | Isi |
|---|---|
| **Transaksi** | Catat pemasukan dan pengeluaran dalam hitungan detik: nominal, kategori, dompet, tanggal, dan catatan |
| **Banyak dompet** | Tunai, bank, dan e-wallet. Saldo dihitung dari saldo awal ditambah pemasukan dikurangi pengeluaran |
| **Kategori** | Buat kategori sendiri dengan ikon dan warna sesukamu |
| **Anggaran bulanan** | Batas per kategori. Bar berubah oranye di 80% dan merah saat melebihi batas. Ada tombol salin dari bulan lalu |
| **Target tabungan** | Tentukan target, tenggat, dan setor tabungan bertahap |
| **Transaksi berulang** | Tagihan dan gaji otomatis: harian, mingguan, bulanan, atau tahunan |
| **Laporan** | Selisih bulan ini, tren 6 bulan, pengeluaran harian, rincian per kategori, hari terboros, dan kategori terbesar |
| **Ekspor data** | Bagikan laporan sebagai PDF atau CSV (bisa dibuka di Excel), untuk bulan ini, bulan lalu, atau semua data |
| **Kunci aplikasi** | PIN 4 digit (disimpan sebagai hash ber-salt), buka dengan sidik jari atau wajah, dan pengatur waktu kunci otomatis |
| **Akun** | Daftar dan masuk, edit profil, ubah password |
| **Tampilan** | Mode terang, gelap, atau otomatis mengikuti HP |
| **Lainnya** | Splash screen, onboarding, halaman Bantuan, dan halaman Tentang aplikasi |

Navigasi utama terdiri dari lima tab: **Beranda**, **Transaksi**, **Anggaran**, **Laporan**, dan **Akun**.

## Teknologi

- **Flutter** dan **Dart**
- **Supabase**: autentikasi dan database PostgreSQL
- `supabase_flutter` untuk koneksi ke Supabase
- `fl_chart` untuk grafik
- `pdf` dan `share_plus` untuk membuat dan membagikan laporan
- `local_auth` untuk sidik jari atau wajah
- `crypto` untuk hash PIN
- `shared_preferences` untuk pengaturan lokal
- `intl` untuk format tanggal dan angka (bahasa Indonesia)

## Memulai

### 1. Persiapan

- [Flutter SDK](https://docs.flutter.dev/get-started/install) dan Android Studio (atau emulator Android)
- Akun [Supabase](https://supabase.com) dengan satu proyek

### 2. Unduh proyek

```bash
git clone https://github.com/NAMA-KAMU/smartnotes.git
cd smartnotes
flutter pub get
```

### 3. Siapkan database Supabase

Aplikasi memakai tabel dan tampilan (view) berikut. Semuanya harus ada di proyek Supabase-mu, dengan **Row Level Security aktif** supaya tiap pengguna hanya bisa mengakses datanya sendiri.

| Nama | Kolom yang dipakai aplikasi |
|---|---|
| `wallets` | `id`, `user_id`, `name`, `type`, `initial_balance` |
| `wallet_balances` (view) | saldo tiap dompet |
| `categories` | `id`, `user_id`, `name`, `type`, `icon`, `color` |
| `transactions` | `id`, `user_id`, `wallet_id`, `category_id`, `type`, `amount`, `note`, `trx_date` |
| `budgets` | `id`, `user_id`, `category_id`, `month`, `amount_limit` (unik per `user_id, category_id, month`) |
| `savings_goals` | `id`, `user_id`, `name`, `target_amount`, `saved_amount`, `deadline`, `icon`, `color` |
| `recurring_rules` | `id`, `user_id`, `name`, `type`, `amount`, `wallet_id`, `category_id`, `frequency`, `anchor_day`, `next_date`, `active` |

Nilai `type` pada transaksi dan transaksi berulang adalah `income` atau `expense`. Nilai `frequency` adalah `daily`, `weekly`, `monthly`, atau `yearly`.

> **Catatan:** skrip SQL pembuatan tabel belum disertakan di repositori ini. Disarankan menyimpannya di folder `supabase/` agar orang lain bisa menyiapkan database dengan satu langkah.

### 4. Isi kunci Supabase

Aplikasi membaca alamat dan kunci Supabase dari parameter saat dijalankan, bukan dari dalam kode.

1. Salin `env.example.json` menjadi `env.json`.
2. Isi dengan data proyekmu (Supabase: **Project Settings**, lalu **API Keys**):

```json
{
  "SUPABASE_URL": "https://PROJECT-ID.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

Gunakan hanya kunci **publishable**. Jangan pernah memasukkan kunci **secret** ke aplikasi. File `env.json` sudah diabaikan oleh Git, jadi tidak ikut ter-upload.

### 5. Jalankan

```bash
flutter run --dart-define-from-file=env.json
```

Di Android Studio, isi **Additional run args** pada konfigurasi Run dengan `--dart-define-from-file=env.json` agar tombol Play bisa dipakai langsung.

## Membangun APK

```bash
flutter build apk --release --split-per-abi --dart-define-from-file=env.json
```

Hasilnya ada di `build/app/outputs/flutter-apk/`. Untuk kebanyakan HP Android modern, pakai `app-arm64-v8a-release.apk`.

## Struktur proyek

```
lib/
├── core/       tema, format angka dan tanggal, konfigurasi Supabase
├── models/     model data (transaksi, dompet, anggaran, target, aturan berulang)
├── screens/    layar aplikasi
│   ├── home, transactions, budgets, reports, main (navigasi bawah)
│   ├── wallets, categories, goals, recurring
│   ├── export, security, settings, profile
│   └── auth, onboarding, splash, help, about
├── services/   akses ke Supabase, ekspor PDF dan CSV, kunci aplikasi, biometrik
├── widgets/    komponen bersama
└── main.dart
```

## Keamanan

- Data tiap pengguna dilindungi Row Level Security di Supabase.
- PIN kunci aplikasi tidak disimpan polos. Yang disimpan hanya hash ber-salt, dan percobaan salah berulang akan ditahan sementara.
- Kunci rahasia Supabase tidak pernah dipakai di aplikasi.

## Rencana berikutnya

- [ ] Ganti ID aplikasi `com.example.smartnotes` dan siapkan tanda tangan rilis
- [ ] Simpan skrip SQL database di folder `supabase/`
- [ ] Tes otomatis untuk perhitungan saldo dan anggaran
- [ ] Dukungan bahasa Inggris

## Pembuat

Dibuat sebagai proyek belajar pengembangan aplikasi mobile.