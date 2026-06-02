import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Import themeNotifier
// import 'scanner_screen.dart';
import 'manage_products_screen.dart';
import 'pos_screen.dart';
import 'history_screen.dart';
import 'server_settings_screen.dart';
import 'financial_report_screen.dart';
import '../services/database_service.dart';
import '../models/license_status.dart' as import_license_status;
import 'license_screen.dart' as import_license;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _shopName = 'Warung';
  int? _trialDays;
  bool _showTrialBanner = false;

  @override
  void initState() {
    super.initState();
    _loadShopName();
  }

  Future<void> _loadShopName() async {
    final prefs = await SharedPreferences.getInstance();
    int? trialDays;
    bool showBanner = false;

    try {
      final res = await DatabaseService.instance.getLicenseStatus();
      final status = import_license_status.LicenseStatus.fromMap(res);
      if (status.isTrialActive && !status.isActivated) {
        trialDays = status.trialDaysRemaining;
        showBanner = true;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _shopName = prefs.getString('shop_name') ?? 'WarungKas';
        _trialDays = trialDays;
        _showTrialBanner = showBanner;
      });
    }
  }

  Future<void> _goToFinancialReport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FinancialReportScreen()),
    );
  }

  Future<void> _goToManage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageProductsScreen()),
    );
  }

  Future<void> _goToPos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PosScreen()),
    );
  }

  void _goToHistory() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const HistoryScreen()),
  );
  Future<void> _goToServerSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
    );

    _loadShopName();
  }

  Future<void> _toggleTheme() async {
    final isDark = themeNotifier.value == ThemeMode.dark;
    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', !isDark);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Mini
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/warungkas-logo.png',
                      width: 50,
                      height: 50,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WARUNGKAS',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF00A67E),
                            letterSpacing: 1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Kasir & Scanner',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleTheme,
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    tooltip: 'Ganti Tema',
                  ),
                  IconButton(
                    onPressed: _goToServerSettings,
                    icon: Icon(
                      Icons.settings_rounded,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    tooltip: 'Pengaturan Sistem',
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    if (_showTrialBanner) ...[
                      GestureDetector(
                        onTap: () async {
                          try {
                            final res = await DatabaseService.instance
                                .getLicenseStatus();
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => import_license.LicenseScreen(
                                  status: import_license_status
                                      .LicenseStatus.fromMap(res),
                                  isForced: false,
                                ),
                              ),
                            ).then((_) => _loadShopName());
                          } catch (_) {}
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFFB800).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Color(0xFFFFB800),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Masa Trial Sisa $_trialDays Hari. Tap Untuk Info.',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFFB800),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Logo Besar WarungKas
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00A67E), Color(0xFF00C853)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00A67E,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _shopName,
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Sistem Kasir WarungKas',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: isDark ? Colors.white54 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Quick actions Menu
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Menu Utama',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _actionCard(
                          Icons.point_of_sale_rounded,
                          'Kasir\nBelanja',
                          const Color(0xFF00A67E),
                          _goToPos,
                        ),
                        const SizedBox(width: 16),
                        _actionCard(
                          Icons.history_rounded,
                          'Riwayat\nTransaksi',
                          const Color(0xFF6C63FF),
                          _goToHistory,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _actionCard(
                          Icons.bar_chart_rounded,
                          'Laporan\nKeuangan',
                          const Color(0xFFFFB800),
                          _goToFinancialReport,
                        ),
                        const SizedBox(width: 16),
                        _actionCard(
                          Icons.inventory_2_outlined,
                          'Kelola\nProduk',
                          const Color(0xFFFF4D6A),
                          _goToManage,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 44),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
