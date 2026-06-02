import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import 'invoice_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late Color _onSurface;
  late Color _surface;
  late bool _isDark;
  late TabController _tabCtrl;
  List<TransactionModel> _lunas = [];
  List<TransactionModel> _hutang = [];
  List<TransactionModel> _dibatalkan = [];
  bool _loading = true;

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _dateFmt = DateFormat('dd MMM yyyy - HH:mm');

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final all = await DatabaseService.instance.getTransactions();
      if (!mounted) return;
      setState(() {
        _lunas = all.where((t) => t.status == 'lunas').toList();
        _hutang = all.where((t) => t.status == 'hutang').toList();
        _dibatalkan = all.where((t) => t.status == 'dibatalkan').toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data: $e', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFFFF4D6A),
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() => _loading = false);
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
          'Riwayat Transaksi',
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
            onPressed: _loadData,
            icon: Icon(Icons.refresh_rounded, color: _onSurface.withValues(alpha: 0.7)),
            tooltip: 'Refresh data',
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: _onSurface.withValues(alpha: _isDark ? 0.54 : 0.85),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 15),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Lunas'),
            Tab(text: 'Catatan Hutang'),
            Tab(text: 'Dibatalkan'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A67E)),
            )
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildList(_lunas, 'lunas'),
                _buildList(_hutang, 'hutang'),
                _buildList(_dibatalkan, 'dibatalkan'),
              ],
            ),
    );
  }

  Future<void> _confirmDelete(TransactionModel tx) async {
    final bool? doDelete = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Batalkan Transaksi',
          style: GoogleFonts.poppins(color: _onSurface),
        ),
        content: Text(
          'Transaksi ini akan dibatalkan dan stok barang dipulihkan. Lanjut?',
          style: GoogleFonts.poppins(color: _onSurface.withValues(alpha: 0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.poppins(color: _onSurface.withValues(alpha: _isDark ? 0.54 : 0.85))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D6A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Batalkan',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (doDelete == true && mounted) {
      try {
        await DatabaseService.instance.deleteTransaction(tx.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transaksi dibatalkan, stok dipulihkan!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFF00A67E),
          ),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal membatalkan transaksi: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFFF4D6A),
          ),
        );
      }
    }
  }

  Widget _buildList(List<TransactionModel> items, String type) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'lunas'
                  ? Icons.receipt_long_rounded
                  : type == 'hutang'
                      ? Icons.request_quote_rounded
                      : Icons.cancel_outlined,
              size: 80,
              color: _onSurface.withValues(alpha: 0.05),
            ),
            const SizedBox(height: 16),
            Text(
              type == 'lunas'
                  ? 'Belum ada riwayat lunas'
                  : type == 'hutang'
                      ? 'Belum ada catatan hutang'
                      : 'Belum ada transaksi dibatalkan',
              style: GoogleFonts.poppins(color: _onSurface.withValues(alpha: _isDark ? 0.38 : 0.7), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: _surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final tx = items[i];
          final isHutang = tx.status == 'hutang';
          final isCancelled = tx.status == 'dibatalkan';
          final fromDebt = tx.paymentMethod == 'hutang';
          final displayDate = isCancelled
              ? (tx.cancelledAt ?? tx.createdAt ?? DateTime.now())
              : (fromDebt && !isHutang && tx.settledAt != null
                    ? tx.settledAt!
                    : (tx.createdAt ?? DateTime.now()));

          return GestureDetector(
            onTap: isCancelled
                ? null
                : () async {
                    final changed = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => InvoiceScreen(transaction: tx)),
                    );
                    if (changed == true) {
                      _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Hutang ${tx.customerName ?? 'pelanggan'} berhasil dilunasi!',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: const Color(0xFF00A67E),
                          ),
                        );
                      }
                    }
                  },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _onSurface.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _dateFmt.format(displayDate),
                          style: GoogleFonts.poppins(
                            color: _onSurface.withValues(alpha: _isDark ? 0.38 : 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCancelled
                                  ? const Color(0xFFFF4D6A).withValues(alpha: 0.15)
                                  : isHutang
                                      ? const Color(0xFFFFB800).withValues(alpha: 0.15)
                                      : const Color(0xFF00A67E).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isCancelled
                                  ? 'DIBATALKAN'
                                  : isHutang
                                      ? 'HUTANG'
                                      : 'LUNAS',
                              style: GoogleFonts.poppins(
                                color: isCancelled
                                    ? const Color(0xFFFF4D6A)
                                    : isHutang
                                        ? const Color(0xFFFFB800)
                                        : const Color(0xFF00A67E),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          if (fromDebt && !isHutang && !isCancelled)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'PELUNASAN',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF6C63FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          if (type == 'lunas')
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: InkWell(
                                onTap: () => _confirmDelete(tx),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _onSurface.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: _onSurface.withValues(alpha: 0.38),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.person, color: _onSurface.withValues(alpha: _isDark ? 0.54 : 0.85), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tx.customerName ?? 'Tanpa Nama',
                          style: GoogleFonts.poppins(
                            color: _onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isHutang ? 'Sisa Hutang' : 'Total Transaksi',
                    style: GoogleFonts.poppins(color: _onSurface.withValues(alpha: _isDark ? 0.54 : 0.85), fontSize: 13),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          isHutang 
                              ? _currency.format(tx.totalAmount - tx.paidAmount) 
                              : _currency.format(tx.totalAmount),
                          style: GoogleFonts.poppins(
                            color: isHutang ? const Color(0xFFFF4D6A) : const Color(0xFF00A67E),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHutang && tx.paidAmount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A67E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Dicicil: ${_currency.format(tx.paidAmount)}',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF00A67E),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (isCancelled && tx.cancelledAt != null) ...[
                    const SizedBox(height: 10),
                    const Divider(color: Colors.black12, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dibatalkan',
                          style: GoogleFonts.poppins(color: _onSurface.withValues(alpha: 0.38), fontSize: 13),
                        ),
                        Text(
                          _dateFmt.format(tx.cancelledAt!),
                          style: GoogleFonts.poppins(
                            color: _onSurface.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!isHutang && !isCancelled && tx.paidAmount > 0) ...[
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 10),
                    if (fromDebt && tx.settledAt != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dilunasi',
                            style: GoogleFonts.poppins(color: _onSurface.withValues(alpha: _isDark ? 0.38 : 0.7), fontSize: 13),
                          ),
                          Text(
                            _dateFmt.format(tx.settledAt!),
                            style: GoogleFonts.poppins(
                              color: _onSurface.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Bayar', style: GoogleFonts.poppins(color: _onSurface.withValues(alpha: _isDark ? 0.38 : 0.7), fontSize: 13)),
                        Text(
                          _currency.format(tx.paidAmount),
                          style: GoogleFonts.poppins(
                            color: _onSurface.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kembalian',
                          style: GoogleFonts.poppins(color: _onSurface.withValues(alpha: _isDark ? 0.38 : 0.7), fontSize: 13),
                        ),
                        Text(
                          _currency.format(tx.changeAmount),
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF00A67E),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
