import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../models/license_status.dart';
import '../services/database_service.dart';
import 'home_screen.dart';

class LicenseScreen extends StatefulWidget {
  final LicenseStatus status;
  final bool isForced;

  const LicenseScreen({super.key, required this.status, this.isForced = true});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _keyController = TextEditingController();
  bool _isLoading = false;
  late LicenseStatus _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await DatabaseService.instance.activateLicense(key);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aktivasi berhasil! Terima kasih.', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFF00A67E),
        ),
      );
      
      if (widget.isForced) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFFB71C1C),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    final primary = const Color(0xFF00A67E);

    return WillPopScope(
      onWillPop: () async => !widget.isForced,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: widget.isForced ? null : AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: onSurface, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Informasi Lisensi',
            style: GoogleFonts.poppins(
              color: onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isForced) const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _currentStatus.isActivated 
                        ? primary.withValues(alpha: 0.1) 
                        : const Color(0xFFFFB800).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _currentStatus.isActivated ? Icons.verified_user_rounded : Icons.lock_clock_rounded,
                    size: 64,
                    color: _currentStatus.isActivated ? primary : const Color(0xFFFFB800),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  _currentStatus.isActivated 
                      ? 'Lisensi Aktif' 
                      : (_currentStatus.isTrialActive ? 'Masa Trial Berjalan' : 'Lisensi Kedaluwarsa!'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                
                Text(
                  _currentStatus.isActivated 
                      ? (_currentStatus.isLifetime ? 'Aplikasi ini memiliki lisensi penuh tanpa batas waktu.' : 'Aplikasi aktif dan dapat digunakan dengan normal.')
                      : (_currentStatus.isTrialActive 
                          ? 'Nikmati fitur lengkap selama sisa masa percobaan gratis.' 
                          : 'Waktu trial Anda sudah habis. Silakan aktivasi dengan kode lisensi untuk lanjut menggunakan aplikasi.'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: onSurface.withValues(alpha: 0.7),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: onSurface.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'KODE PERANGKAT',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _currentStatus.deviceCode,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.robotoMono(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy_rounded, color: primary),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _currentStatus.deviceCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Kode disalin!', style: GoogleFonts.poppins()),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                if (_currentStatus.isTrialActive && !_currentStatus.isActivated) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sisa Waktu Trial: ${_currentStatus.trialDaysRemaining} Hari',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                if (!_currentStatus.isActivated || !widget.isForced) ...[
                  Text(
                    'Punya Kode Lisensi?',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    maxLines: 2,
                    style: GoogleFonts.robotoMono(fontSize: 13, color: onSurface),
                    decoration: InputDecoration(
                      hintText: 'Tempel / Paste kode lisensi panjang di sini',
                      hintStyle: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.4), fontSize: 13),
                      filled: true,
                      fillColor: surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: onSurface.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: onSurface.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _activate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'AKTIVASI SEKARANG',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
