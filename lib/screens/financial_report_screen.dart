import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import 'invoice_screen.dart';
import 'package:share_plus/share_plus.dart';

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  late Color _onSurface;
  late Color _surface;
  late bool _isDark;

  int _selectedTab =
      3; // 0: Hari Ini, 1: 7 Hari Terakhir, 2: Bulan Ini, 3: Semua Waktu
  bool _loading = true;
  bool _exporting = false;

  double _totalOmzet = 0.0;
  double _totalProfit = 0.0;
  double _totalPiutang = 0.0;
  int _transactionCount = 0;
  List<MapEntry<String, int>> _topProducts = [];
  List<TransactionModel> _filteredTransactions = [];

  String _formatCurrencyCsv(double value) {
    return value.toStringAsFixed(0);
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('"')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _csvRow(List<String> cells) {
    return cells.map(_csvCell).join(',');
  }

  String _buildReportCsv() {
    final rangeName = _selectedTab == 0
        ? 'Hari Ini'
        : (_selectedTab == 1
              ? '7 Hari Terakhir'
              : (_selectedTab == 2 ? 'Bulan Ini' : 'Semua Waktu'));

    final totalTerbayar = _filteredTransactions.fold(
      0.0,
      (sum, tx) => sum + tx.paidAmount,
    );
    final totalSisaPiutang = _filteredTransactions.fold(
      0.0,
      (sum, tx) =>
          sum + (tx.status == 'hutang' ? tx.totalAmount - tx.paidAmount : 0.0),
    );

    final rows = <List<String>>[
      <String>['LAPORAN KEUANGAN WARUNGKAS'],
      <String>[
        'Tanggal Ekspor',
        DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now()),
      ],
      <String>['Periode Laporan', rangeName],
      <String>[],
      <String>['RINGKASAN METRIK KEUANGAN'],
      <String>['Nama Metrik', 'Nilai'],
      <String>['Total Pendapatan (Omzet)', _formatCurrencyCsv(_totalOmzet)],
      <String>['Keuntungan Bersih (Profit)', _formatCurrencyCsv(_totalProfit)],
      <String>[
        'Total Piutang Berhasil Ditagih (Terbayar)',
        _formatCurrencyCsv(totalTerbayar),
      ],
      <String>[
        'Total Piutang Belum Lunas (Outstanding)',
        _formatCurrencyCsv(totalSisaPiutang),
      ],
      <String>['Total Transaksi Berhasil', '$_transactionCount'],
      <String>[],
      <String>['5 PRODUK TERLARIS PERIODE INI'],
      <String>['Peringkat', 'Nama Produk', 'Jumlah Terjual'],
      ..._topProducts.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final name = entry.value.key;
        final qty = entry.value.value;
        return <String>['$rank', name, '$qty unit'];
      }),
      <String>[],
      <String>['RINCIAN DAFTAR TRANSAKSI PENJUALAN'],
      <String>[
        'No',
        'ID Transaksi',
        'Tanggal & Waktu',
        'Nama Pelanggan',
        'Status Bayar',
        'Metode Bayar',
        'Total Belanja (Rp)',
        'Jumlah Dibayar (Rp)',
        'Sisa Piutang (Rp)',
      ],
      ..._filteredTransactions.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final tx = entry.value;
        final dateStr = tx.createdAt != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(tx.createdAt!)
            : '-';
        final custName = tx.customerName?.trim().isNotEmpty == true
            ? tx.customerName!
            : 'Tanpa Nama';
        final statusStr = tx.status.toUpperCase();
        final sisaHutang = tx.status == 'hutang'
            ? (tx.totalAmount - tx.paidAmount)
            : 0.0;

        return <String>[
          '$index',
          'TX-${tx.id ?? index}',
          dateStr,
          custName,
          statusStr,
          tx.paymentMethod.toUpperCase(),
          _formatCurrencyCsv(tx.totalAmount),
          _formatCurrencyCsv(tx.paidAmount),
          _formatCurrencyCsv(sisaHutang),
        ];
      }),
      <String>[],
      <String>[
        'TOTAL KESELURUHAN',
        '',
        '',
        '',
        '',
        '',
        _formatCurrencyCsv(_totalOmzet),
        _formatCurrencyCsv(totalTerbayar),
        _formatCurrencyCsv(totalSisaPiutang),
      ],
    ];

    return rows.map(_csvRow).join('\n');
  }

  Future<Directory> _resolveExportDirectory() async {
    Directory? baseDir;
    try {
      baseDir = await getDownloadsDirectory();
    } catch (_) {
      baseDir = null;
    }
    baseDir ??= await getApplicationDocumentsDirectory();

    final exportDir = Directory(p.join(baseDir.path, 'warungkas_reports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  Future<void> _exportReportAsCsv() async {
    if (_loading || _exporting) return;
    setState(() => _exporting = true);

    try {
      final exportDir = await _resolveExportDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'laporan-keuangan-$timestamp.csv';
      final file = File(p.join(exportDir.path, fileName));
      await file.writeAsString(_buildReportCsv());

      if (mounted) {
        if (Platform.isAndroid || Platform.isIOS) {
          // Buka dialog Share agar user bisa langsung menyimpan ke mana saja (WhatsApp, Google Drive, File Manager, dll)
          await Share.shareXFiles([
            XFile(file.path),
          ], subject: 'Laporan Keuangan WarungKas');
        } else {
          // Pada Desktop (Windows), simpan langsung ke Downloads dan beri notifikasi path
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Laporan Excel (.csv) berhasil diekspor ke ${file.path}',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: const Color(0xFF00A67E),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengekspor laporan: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFFF4D6A),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _loading = true);
    try {
      final allTx = await DatabaseService.instance.getTransactions();
      final now = DateTime.now();

      // Filter tanggal berdasarkan tab terpilih
      DateTime? filterStart;
      if (_selectedTab == 0) {
        // Hari Ini (mulai pukul 00:00:00)
        filterStart = DateTime(now.year, now.month, now.day);
      } else if (_selectedTab == 1) {
        // 7 Hari Terakhir
        filterStart = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 7));
      } else if (_selectedTab == 2) {
        // Bulan Ini (mulai tanggal 1)
        filterStart = DateTime(now.year, now.month, 1);
      } else {
        // Semua Waktu
        filterStart = null;
      }

      final filteredTx = allTx.where((tx) {
        if (tx.createdAt == null || tx.status == 'dibatalkan') return false;
        if (filterStart == null) return true;
        // tx.createdAt harus sama atau setelah filterStart
        return tx.createdAt!.isAfter(filterStart) ||
            tx.createdAt!.isAtSameMomentAs(filterStart);
      }).toList();

      double omzet = 0.0;
      double profit = 0.0;
      final Map<String, int> productSales = {};

      for (final tx in filteredTx) {
        omzet += tx.totalAmount;

        final items = await DatabaseService.instance.getTransactionItems(
          tx.id!,
        );
        for (final item in items) {
          final lineProfit = (item.price - item.costPrice) * item.quantity;
          profit += lineProfit;

          productSales[item.productName] =
              (productSales[item.productName] ?? 0) + item.quantity;
        }
      }

      // Hitung piutang aktif sepanjang waktu (kumulatif seluruh database)
      double piutang = 0.0;
      for (final tx in allTx) {
        if (tx.status == 'hutang') {
          piutang += (tx.totalAmount - tx.paidAmount);
        }
      }

      // Urutkan produk terlaris secara descending
      final sortedProducts = productSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mounted) {
        setState(() {
          _totalOmzet = omzet;
          _totalPiutang = piutang;
          _totalProfit = profit;
          _topProducts = sortedProducts.take(5).toList();
          _transactionCount = filteredTx.length;
          _filteredTransactions = filteredTx;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat laporan: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFFF4D6A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    _onSurface = Theme.of(context).colorScheme.onSurface;
    _surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: Text(
          'Laporan Keuangan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: _onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: (_loading || _exporting) ? null : _exportReportAsCsv,
            tooltip: 'Ekspor Excel (.csv)',
            icon: _exporting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _onSurface.withValues(alpha: 0.7),
                    ),
                  )
                : Icon(
                    Icons.file_download_outlined,
                    color: _onSurface.withValues(alpha: 0.7),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Periode Waktu
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _filterChip(0, 'Hari Ini'),
                    const SizedBox(width: 8),
                    _filterChip(1, '7 Hari'),
                    const SizedBox(width: 8),
                    _filterChip(2, 'Bulan Ini'),
                    const SizedBox(width: 8),
                    _filterChip(3, 'Semua Waktu'),
                  ],
                ),
              ),
            ),

            // Konten Utama Laporan (Single View)
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00A67E),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReportData,
                      color: const Color(0xFF00A67E),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. RINGKASAN OMZET (PENDAPATAN KOTOR)
                            _summaryCard(
                              title: 'Total Pendapatan (Omzet)',
                              amount: _totalOmzet,
                              icon: Icons.payments_rounded,
                              gradient: const [
                                Color(0xFF00A67E),
                                Color(0xFF00C853),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 2. GRID UNTUK PROFIT DAN PIUTANG
                            Row(
                              children: [
                                Expanded(
                                  child: _gridSummaryCard(
                                    title: 'Keuntungan Bersih',
                                    amount: _totalProfit,
                                    icon: Icons.trending_up_rounded,
                                    color: const Color(0xFF6C63FF),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _gridSummaryCard(
                                    title: 'Piutang (Hutang Belum Lunas)',
                                    amount: _totalPiutang,
                                    icon: Icons.assignment_late_rounded,
                                    color: const Color(0xFFFF4D6A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // 3. STATISTIK PENJUALAN
                            Text(
                              'Statistik Penjualan',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _onSurface.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF6C63FF,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_rounded,
                                      color: Color(0xFF6C63FF),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Transaksi Berhasil',
                                          style: GoogleFonts.poppins(
                                            color: _onSurface.withValues(
                                              alpha: _isDark ? 0.54 : 0.85,
                                            ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '$_transactionCount Transaksi',
                                          style: GoogleFonts.poppins(
                                            color: _onSurface,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 4. PRODUK TERLARIS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '5 Produk Terlaris',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: _onSurface,
                                  ),
                                ),
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFB800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_topProducts.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 36,
                                ),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _onSurface.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.analytics_outlined,
                                        size: 48,
                                        color: _onSurface.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Belum ada data barang terjual',
                                        style: GoogleFonts.poppins(
                                          color: _onSurface.withValues(
                                            alpha: _isDark ? 0.38 : 0.7,
                                          ),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _topProducts.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final entry = _topProducts[index];
                                  return _topProductTile(
                                    index + 1,
                                    entry.key,
                                    entry.value,
                                  );
                                },
                              ),
                            const SizedBox(height: 24),

                            // 5. REKAPAN PENJUALAN
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Daftar Transaksi Penjualan',
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: _onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF6C63FF,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$_transactionCount Transaksi',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF6C63FF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_filteredTransactions.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 48,
                                ),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _onSurface.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 56,
                                        color: _onSurface.withValues(
                                          alpha: 0.15,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Belum ada transaksi di periode ini',
                                        style: GoogleFonts.poppins(
                                          color: _onSurface.withValues(
                                            alpha: _isDark ? 0.38 : 0.7,
                                          ),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Semua transaksi penjualan Anda akan muncul di sini',
                                        style: GoogleFonts.poppins(
                                          color: _onSurface.withValues(
                                            alpha: _isDark ? 0.25 : 0.5,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filteredTransactions.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final tx = _filteredTransactions[index];
                                  return _transactionRecapTile(tx);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(int index, String label) {
    final active = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = index);
        _loadReportData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00A67E) : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? Colors.transparent
                : _onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: active
                ? Colors.white
                : (_isDark ? Colors.white70 : Colors.black87),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _currency.format(amount),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _gridSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _onSurface.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.05 : 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: _onSurface.withValues(alpha: _isDark ? 0.54 : 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currency.format(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: _onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topProductTile(int rank, String name, int qty) {
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFB800); // Gold
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
    } else {
      rankColor = _onSurface.withValues(alpha: 0.4);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: GoogleFonts.poppins(
                  color: rankColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: _onSurface,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00A67E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$qty unit',
              style: GoogleFonts.poppins(
                color: const Color(0xFF00A67E),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionRecapTile(TransactionModel tx) {
    final isLunas = tx.status == 'lunas';
    final dateStr = tx.createdAt != null
        ? DateFormat('dd MMM, HH:mm').format(tx.createdAt!)
        : '-';

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _onSurface.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InvoiceScreen(transaction: tx)),
          );
          _loadReportData(); // Reload saat kembali jika ada cicilan terbayar
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon Status
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (isLunas
                              ? const Color(0xFF00A67E)
                              : const Color(0xFFFFB800))
                          .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLunas
                      ? Icons.check_circle_outline_rounded
                      : Icons.history_edu_rounded,
                  color: isLunas
                      ? const Color(0xFF00A67E)
                      : const Color(0xFFFFB800),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Detail Pelanggan & Waktu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.customerName?.trim().isNotEmpty == true
                          ? tx.customerName!
                          : 'Tanpa Nama',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: _onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateStr • ${tx.paymentMethod.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _onSurface.withValues(
                          alpha: _isDark ? 0.45 : 0.7,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Nominal Transaksi & Chevron
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currency.format(tx.totalAmount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF00A67E),
                          fontSize: 14,
                        ),
                      ),
                      if (!isLunas) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Sisa ${_currency.format(tx.totalAmount - tx.paidAmount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFF4D6A),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
