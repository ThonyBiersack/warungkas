# 🏪 WarungKas — Aplikasi Kasir & Manajemen Warung

> Aplikasi kasir dan manajemen keuangan untuk UMKM/warung, dibangun dengan Flutter. Dirancang ringan, offline-first, dan siap pakai tanpa koneksi internet.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat&logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Web-lightgrey?style=flat)
![Database](https://img.shields.io/badge/Database-SQLite-003B57?style=flat&logo=sqlite)
![License](https://img.shields.io/badge/License-Private-red?style=flat)

---
### 📥 Download Aplikasi

[![Download ARM64](https://img.shields.io/badge/Download-ARM64_APK-green?style=for-the-badge&logo=android)](https://github.com/ThonyBiersack/warungkas/releases/download/retail-app/app-arm64-v8a-release.apk) 
[![Download x86_64](https://img.shields.io/badge/Download-x86__64_APK-blue?style=for-the-badge&logo=android)](https://github.com/ThonyBiersack/warungkas/releases/download/retail-app/app-x86_64-release.apk)

## 📱 Tentang Aplikasi

**WarungKas** adalah aplikasi point-of-sale (POS) dan manajemen keuangan yang dirancang khusus untuk kebutuhan warung dan UMKM skala kecil-menengah. Aplikasi ini bekerja sepenuhnya secara **offline** menggunakan SQLite, sehingga tidak bergantung pada koneksi internet untuk operasional sehari-hari.

---

## ✨ Fitur Utama

### 🛒 Kasir & Transaksi
- Proses transaksi belanja dengan cepat
- **Barcode scanner** terintegrasi untuk input produk otomatis
- Kalkulasi total harga & kembalian secara real-time
- Riwayat transaksi lengkap dengan filter tanggal

### 📦 Manajemen Produk & Stok
- Tambah, edit, dan hapus produk
- Pengelolaan stok dengan notifikasi stok menipis
- Hitung modal otomatis per pack/dus
- Kategorisasi produk

### 📊 Laporan Keuangan
- Ringkasan profit dan omzet harian/bulanan
- Pencatatan piutang pelanggan
- Laporan transaksi terpadu
- Export laporan ke **PDF**

### 🔐 Sistem Keamanan
- Aktivasi lisensi offline yang aman
- Enkripsi data sensitif menggunakan `crypto` & `cryptography`
- Proteksi akses aplikasi

---

## 🛠️ Tech Stack

| Teknologi | Kegunaan |
|---|---|
| **Flutter** | Framework utama (cross-platform) |
| **Dart** | Bahasa pemrograman |
| **SQLite** (sqflite) | Database lokal offline |
| **mobile_scanner** | Barcode & QR code scanner |
| **pdf + printing** | Generate & cetak laporan PDF |
| **crypto + cryptography** | Enkripsi & keamanan data |
| **shared_preferences** | Penyimpanan preferensi lokal |
| **google_fonts** | Tipografi |
| **intl** | Format tanggal & mata uang |
| **share_plus** | Share laporan ke aplikasi lain |

---

## 📂 Struktur Project

```
warungkas/
├── lib/
│   ├── main.dart          # Entry point aplikasi
│   ├── models/            # Model data (Produk, Transaksi, dll)
│   ├── screens/           # Halaman UI
│   ├── widgets/           # Komponen UI reusable
│   ├── services/          # Business logic & database service
│   └── utils/             # Helper & utilitas
├── assets/
│   └── images/            # Asset gambar & logo
├── android/               # Konfigurasi Android
├── ios/                   # Konfigurasi iOS
└── windows/               # Konfigurasi Windows
```

---

## 🚀 Cara Menjalankan

### Prerequisites
- Flutter SDK `^3.11.4`
- Dart SDK `^3.11.4`
- Android Studio / VS Code
- Device/emulator Android atau iOS

### Langkah Instalasi

```bash
# 1. Clone repository
git clone https://github.com/ThonyBiersack/warungkas.git

# 2. Masuk ke direktori project
cd warungkas

# 3. Install dependencies
flutter pub get

# 4. Jalankan aplikasi
flutter run
```

### Build APK (Android)

```bash
flutter build apk --release
```

---

## 📸 Screenshots

> *Coming soon — dokumentasi screenshot UI akan ditambahkan*

---

## 🎯 Target Pengguna

Aplikasi ini dirancang untuk:
- Pemilik warung kelontong
- UMKM skala kecil-menengah
- Pedagang yang butuh sistem kasir sederhana tanpa biaya berlangganan

---

## 🔮 Roadmap

- [ ] Sinkronisasi data multi-device
- [ ] Dashboard analytics lebih lengkap
- [ ] Manajemen karyawan & shift
- [ ] Integrasi printer thermal bluetooth
- [ ] Backup data ke cloud (opsional)

---

## 👨‍💻 Developer

**Anthony Suryadjie**
- GitHub: [@ThonyBiersack](https://github.com/ThonyBiersack)
- Fokus: Mobile Development (Flutter) & Backend API (Node.js / Express / Hapi)

---

## 📄 Lisensi

Project ini bersifat privat. Seluruh hak cipta dimiliki oleh developer.
Dilarang mendistribusikan atau memodifikasi tanpa izin tertulis.
=======
