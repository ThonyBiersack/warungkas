import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'license_screen.dart' as import_license;
import '../models/license_status.dart' as import_license_status;

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _shopNameCtrl;
  bool _isSaving = false;
  bool _isTesting = false;
  
  int _devTapCount = 0;
  bool _isDevMode = false;

  bool get _isBusy => _isSaving || _isTesting;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(
      text: DatabaseService.instance.activeApiBaseUrl,
    );
    _shopNameCtrl = TextEditingController();
    _loadShopName();
  }

  Future<void> _loadShopName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopNameCtrl.text = prefs.getString('shop_name') ?? 'Warung';
    });
  }

  Future<void> _saveShopName() async {
     final name = _shopNameCtrl.text.trim();
     if (name.isEmpty) return;
     final prefs = await SharedPreferences.getInstance();
     await prefs.setString('shop_name', name);
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama warung berhasil diubah!'), backgroundColor: Color(0xFF00A67E)));
     }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _shopNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (_isBusy) return;

    FocusScope.of(context).unfocus();
    setState(() => _isTesting = true);

    try {
      await DatabaseService.instance.validateApiBaseUrl(_urlCtrl.text);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Koneksi ke server WarungKas berhasil!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFF00A67E),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Koneksi gagal bos: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFFFF4D6A),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<void> _save() async {
    if (_isBusy) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      await DatabaseService.instance.setApiBaseUrl(_urlCtrl.text);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alamat server berhasil disimpan.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFF00A67E),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan alamat server: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFFFF4D6A),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _useDefault() async {
    if (_isBusy) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      await DatabaseService.instance.clearApiBaseUrl();
      if (!mounted) return;

      _urlCtrl.text = DatabaseService.instance.defaultApiBaseUrl;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alamat server dikembalikan ke default aplikasi.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFFFFB800),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memakai default: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFFFF4D6A),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  Future<void> _resetData() async {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surface,
        title: Text('Reset Seluruh Data?', style: GoogleFonts.poppins(color: onSurface, fontWeight: FontWeight.bold)),
        content: Text(
          'Tindakan ini akan menghapus SELURUH produk, riwayat transaksi, dan hutang secara permanen. Kamu tidak bisa membatalkan aksi ini.',
          style: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal', style: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.5)))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('YA, HAPUS SEMUA', style: GoogleFonts.poppins(color: const Color(0xFFFF4D6A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (_isBusy) return;

    setState(() => _isSaving = true);
    try {
      await DatabaseService.instance.resetDatabase();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sistem berhasil direset ke kondisi awal.', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFF00A67E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal reset: $e', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFFFF4D6A),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = DatabaseService.instance;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: GestureDetector(
          onTap: () {
            _devTapCount++;
            if (_devTapCount == 7) {
              setState(() => _isDevMode = true);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Developer Mode Activated'),
                backgroundColor: Color(0xFF00A67E),
              ));
            }
          },
          child: Text(
            'Pengaturan Sistem',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profil Warung',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: onSurface.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                   TextField(
                    controller: _shopNameCtrl,
                    style: GoogleFonts.poppins(color: onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Nama Warung / Toko',
                      labelStyle: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.38)),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                        onPressed: _saveShopName,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isDevMode) ...[
              const SizedBox(height: 32),
              Text(
                'Mode Aplikasi',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              if (!service.canUseMonolithMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: onSurface.withValues(alpha: 0.06)),
                  ),
                  child: Text(
                    'Mode Mandiri (Monolith) hanya tersedia di aplikasi Desktop (Windows/Mac/Linux) atau Android. Saat ini berjalan di mode Server.',
                    style: GoogleFonts.poppins(fontSize: 13, color: onSurface.withValues(alpha: 0.6)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: onSurface.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        title: Text('Mode Server Lokal / Jaringan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: onSurface)),
                        subtitle: Text('Data terpusat di server backend (Express.js) via jaringan', style: GoogleFonts.poppins(fontSize: 12, color: onSurface.withValues(alpha: 0.6))),
                        value: false,
                        groupValue: service.isMonolithMode,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: _isBusy ? null : (v) async {
                          setState(() => _isSaving = true);
                          await service.toggleMode(v!);
                          if (!context.mounted) return;
                          setState(() => _isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil ganti ke Mode Server', style: GoogleFonts.poppins()), backgroundColor: const Color(0xFF00A67E)));
                        },
                      ),
                      const Divider(),
                      RadioListTile<bool>(
                        title: Text('Mode Mandiri (Offline / Monolith)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: onSurface)),
                        subtitle: Text('Simpan data transaksi mandiri di device ini. Cocok kalau tanpa API Server.', style: GoogleFonts.poppins(fontSize: 12, color: onSurface.withValues(alpha: 0.6))),
                        value: true,
                        groupValue: service.isMonolithMode,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: _isBusy ? null : (v) async {
                          setState(() => _isSaving = true);
                          await service.toggleMode(v!);
                          if (!context.mounted) return;
                          setState(() => _isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil ganti ke Mode Mandiri (Monolith)', style: GoogleFonts.poppins()), backgroundColor: const Color(0xFF00A67E)));
                        },
                      ),
                    ],
                  ),
                ),
              if (!service.isMonolithMode) ...[
                const SizedBox(height: 32),
                Text(
                  'Koneksi Server',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                    fontSize: 16,
                  ),
                ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: onSurface.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'URL aktif',
                    style: GoogleFonts.poppins(
                      color: onSurface.withValues(alpha: 0.54),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    service.activeApiBaseUrl,
                    style: GoogleFonts.poppins(
                      color: onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service.apiBaseUrlSourceLabel,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF00A67E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Alamat Server',
              style: GoogleFonts.poppins(
                color: onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              style: GoogleFonts.poppins(
                color: onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'http://192.168.100.5:8000/api',
                hintStyle: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.3)),
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF00A67E),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Gunakan format http://IP-SERVER:8000. Kalau /api belum kamu tulis, aplikasi akan menambahkannya otomatis.',
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Default aplikasi saat ini: ${service.defaultApiBaseUrl}',
              style: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isBusy ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A67E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Simpan URL Server',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isBusy ? null : _testConnection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                  side: const BorderSide(color: Color(0xFF6C63FF)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isTesting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6C63FF),
                        ),
                      )
                    : Text(
                        'Tes Koneksi',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isBusy ? null : _useDefault,
                child: Text(
                  'Gunakan URL Default',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFB800),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ],
            ],
            const SizedBox(height: 40),
            Text(
              'Lisensi & Keamanan',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                 onPressed: _isBusy ? null : () async {
                  setState(() => _isSaving = true);
                  try {
                    final res = await DatabaseService.instance.getLicenseStatus();
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => import_license.LicenseScreen(
                          status: import_license_status.LicenseStatus.fromMap(res), 
                          isForced: false
                        )
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mengecek lisensi: $e', style: GoogleFonts.poppins()), backgroundColor: const Color(0xFFFF4D6A)),
                    );
                  } finally {
                    if (context.mounted) setState(() => _isSaving = false);
                  }
                },
                icon: const Icon(Icons.verified_user_rounded),
                label: Text(
                  'Status Lisensi & Aktivasi',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A67E).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFF00A67E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF00A67E)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Divider(color: Colors.white10),
            const SizedBox(height: 20),
            Text(
              'Zona Bahaya',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF4D6A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBusy ? null : _resetData,
                icon: const Icon(Icons.delete_forever_rounded),
                label: Text(
                  'RESET SELURUH DATA',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D6A).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFFFF4D6A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFFF4D6A)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
