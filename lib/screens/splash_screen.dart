import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'shop_setup_screen.dart';
import '../models/license_status.dart';
import '../services/database_service.dart';
import 'license_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    try {
      await DatabaseService.instance.initDB();

      bool isLicenseValid = false; // Default fail-safe closed
      LicenseStatus? status;
      
      try {
        final res = await DatabaseService.instance.getLicenseStatus();
        status = LicenseStatus.fromMap(res);
        isLicenseValid = !status.isExpired;
      } catch (e) {
        // FAIL-SAFE CLOSED: Do not allow entry if license check fails
        isLicenseValid = false; 
        debugPrint('License check failed: $e');
      }

      await Future.delayed(const Duration(milliseconds: 2000));

      final prefs = await SharedPreferences.getInstance();
      final shopName = prefs.getString('shop_name');
      
      if (!mounted) return;
      
      if (status == null || !isLicenseValid) {
        // If status is null (error reading DB), still force them to LicenseScreen 
        // to prevent silently breaking into the app.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LicenseScreen(status: status ?? LicenseStatus.fromMap({}), isForced: true)),
        );
        return;
      }

      if (shopName == null || shopName.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ShopSetupScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Gagal memulai sistem: ${e.toString()} \nRestart aplikasi.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo aplikasi
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/warungkas-logo.png',
                width: 140,
                height: 140,
              ),
            ),
            const SizedBox(height: 24),
            
            // Teks WARUNGKAS
            Text(
              'WARUNGKAS',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: onSurface,
                letterSpacing: 4,
              ),
            ),
            Text(
              'Smart POS System',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: onSurface.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.54 : 0.85),
                letterSpacing: 2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              // Loading indicator kecil di bawah
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Color(0xFF00A67E),
                  strokeWidth: 2.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
