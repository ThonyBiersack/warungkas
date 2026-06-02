import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/invoice_share_print_service.dart';


class InvoiceScreen extends StatefulWidget {
  final TransactionModel transaction;

  const InvoiceScreen({super.key, required this.transaction});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _inputFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );
  static final _dateFmt = DateFormat('dd MMM yyyy - HH:mm');

  List<TransactionItem> _items = [];
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await DatabaseService.instance.getTransactionItems(
        widget.transaction.id!,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat rincian: $e', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFFFF4D6A),
        ),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _markAsLunas() async {
    final paidAmount = await _showSettlementDialog();
    if (paidAmount == null) return;

    setState(() => _updating = true);
    try {
      final remaining = widget.transaction.totalAmount - widget.transaction.paidAmount;
      final changeAmount = (paidAmount - remaining).clamp(
        0.0,
        double.infinity,
      );
      await DatabaseService.instance.settleTransaction(
        widget.transaction.id!,
        paidAmount: paidAmount,
        changeAmount: changeAmount,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pelunasan: $e', style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFFFF4D6A),
          ),
        );
        setState(() => _updating = false);
      }
    }
  }

  Future<double?> _showSettlementDialog() async {
    final remaining = widget.transaction.totalAmount - widget.transaction.paidAmount;
    final controller = TextEditingController(
      text: _inputFmt.format(remaining.toInt()).trim(),
    );

    return showDialog<double>(
      context: context,
      builder: (ctx) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            final raw = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
            final paidAmount = double.tryParse(raw) ?? 0.0;

            final onSurface = Theme.of(context).colorScheme.onSurface;
            final surface = Theme.of(context).colorScheme.surface;

            return AlertDialog(
              backgroundColor: surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Pelunasan Hutang',
                style: GoogleFonts.poppins(
                  color: onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total tagihan ${_currency.format(widget.transaction.totalAmount)}',
                    style: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CurrencyFormatter(),
                    ],
                    onChanged: (_) => setLocalState(() {
                      errorText = null;
                    }),
                    style: GoogleFonts.poppins(
                      color: onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Nominal dibayar',
                      labelStyle: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.54)),
                      errorText: errorText,
                      prefixText: 'Rp ',
                      prefixStyle: GoogleFonts.poppins(
                        color: const Color(0xFF00A67E),
                        fontWeight: FontWeight.w700,
                      ),
                      filled: true,
                      fillColor: onSurface.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF00A67E),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Terhutang',
                        style: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.54)),
                      ),
                      Text(
                        _currency.format(widget.transaction.totalAmount - widget.transaction.paidAmount),
                        style: GoogleFonts.poppins(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(builder: (context) {
                        final remaining = (widget.transaction.totalAmount - widget.transaction.paidAmount);
                        final isLunas = paidAmount >= remaining;
                        return Text(
                          isLunas ? 'Kembalian' : 'Sisa Hutang',
                          style: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.54)),
                        );
                      }),
                      Builder(builder: (context) {
                        final remaining = (widget.transaction.totalAmount - widget.transaction.paidAmount);
                        final sisa = remaining - paidAmount;
                        final isLunas = sisa <= 0;
                        
                        return Text(
                          _currency.format(sisa.abs()),
                          style: GoogleFonts.poppins(
                            color: isLunas
                                ? const Color(0xFF00A67E)
                                : const Color(0xFFFFB800),
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.54)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (paidAmount <= 0) {
                      setLocalState(() {
                        errorText = 'Nominal bayar harus lebih dari 0';
                      });
                      return;
                    }

                    Navigator.pop(ctx, paidAmount);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A67E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Simpan Pembayaran',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final isHutang = tx.status == 'hutang';
    final settledFromDebt = tx.paymentMethod == 'hutang' && tx.status == 'lunas';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: onSurface.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A67E).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFF00A67E),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'WarungKas',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Bukti Transaksi',
                style: GoogleFonts.poppins(fontSize: 13, color: onSurface.withValues(alpha: 0.54)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isHutang
                      ? const Color(0xFFFFB800).withValues(alpha: 0.15)
                      : const Color(0xFF00A67E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isHutang ? 'STATUS: HUTANG' : 'STATUS: LUNAS',
                  style: GoogleFonts.poppins(
                    color: isHutang
                        ? const Color(0xFFFFB800)
                        : const Color(0xFF00A67E),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _infoRow('Tanggal', _dateFmt.format(tx.createdAt ?? DateTime.now())),
                    const SizedBox(height: 12),
                    _infoRow('Pembeli', tx.customerName ?? 'Tanpa Nama', isBold: true),
                    if (isHutang && tx.paidAmount > 0) ...[
                      const SizedBox(height: 12),
                      _infoRow('Sudah Dicicil', _currency.format(tx.paidAmount), color: const Color(0xFF00A67E)),
                      const SizedBox(height: 4),
                      _infoRow('Sisa Piutang', _currency.format(tx.totalAmount - tx.paidAmount), color: const Color(0xFFFF4D6A), isBold: true),
                    ],
                    if (settledFromDebt && tx.settledAt != null) ...[
                      const SizedBox(height: 12),
                      _infoRow('Dilunasi', _dateFmt.format(tx.settledAt!)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Divider(color: onSurface.withValues(alpha: 0.12), thickness: 1, indent: 24, endIndent: 24),
              const SizedBox(height: 16),
              Text(
                'Rincian Belanja',
                style: GoogleFonts.poppins(
                  color: onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00A67E)),
                  ),
                )
              else if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Tidak ada rincian barang',
                    style: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.38)),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: _items
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: GoogleFonts.poppins(
                                          color: onSurface,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.quantity} x ${_currency.format(item.price)}',
                                        style: GoogleFonts.poppins(
                                          color: onSurface.withValues(alpha: 0.54),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _currency.format(item.quantity * item.price),
                                  style: GoogleFonts.poppins(
                                    color: onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              Divider(color: onSurface.withValues(alpha: 0.12), thickness: 1, indent: 24, endIndent: 24),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.54), fontSize: 15),
                        ),
                        Text(
                          _currency.format(tx.totalAmount),
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF00A67E),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (!isHutang && tx.paidAmount > 0) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.black12, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Uang Bayar',
                            style: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.38), fontSize: 13),
                          ),
                          Text(
                            _currency.format(tx.paidAmount),
                            style: GoogleFonts.poppins(
                              color: onSurface.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_circle_down_rounded,
                                color: Color(0xFF00A67E),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Kembalian',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF00A67E),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _currency.format(tx.changeAmount),
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF00A67E),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading || _items.isEmpty
                            ? null
                            : () async {
                                try {
                                  await InvoiceSharePrintService.shareInvoice(tx, _items);
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Gagal membagikan struk. Silakan matikan aplikasi sepenuhnya lalu jalankan ulang (rebuild) agar fitur baru terpasang sempurna.\nDetail: $e',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        backgroundColor: const Color(0xFFFF4D6A),
                                        duration: const Duration(seconds: 8),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: Text(
                          'Bagikan Struk',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00A67E),
                          side: const BorderSide(color: Color(0xFF00A67E), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loading || _items.isEmpty
                            ? null
                            : () async {
                                try {
                                  await InvoiceSharePrintService.printReceipt(tx, _items);
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Gagal mencetak struk. Silakan matikan aplikasi sepenuhnya lalu jalankan ulang (rebuild) agar fitur baru terpasang sempurna.\nDetail: $e',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        backgroundColor: const Color(0xFFFF4D6A),
                                        duration: const Duration(seconds: 8),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: Text(
                          'Cetak Struk',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A67E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isHutang
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton(
                  onPressed: _updating ? null : _markAsLunas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A67E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _updating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          (widget.transaction.paidAmount > 0) ? 'LANJUT CICILAN' : 'TERIMA PEMBAYARAN',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false, Color? color}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.38), fontSize: 13)),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color ?? onSurface,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _CurrencyFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    final intVal =
        int.tryParse(newValue.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final formatted = _fmt.format(intVal).trim();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
