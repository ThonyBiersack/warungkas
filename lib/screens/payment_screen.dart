import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import 'pos_screen.dart';

class PaymentScreen extends StatefulWidget {
  final List<CartItem> cart;
  final double totalAmount;

  const PaymentScreen({super.key, required this.cart, required this.totalAmount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static final _inputFmt = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  String _paymentMethod = 'lunas';
  final _nameCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  bool _saving = false;
  late final List<CartItem> _cartSnapshot;
  late final double _totalAmountSnapshot;

  @override
  void initState() {
    super.initState();
    _cartSnapshot = widget.cart.map((item) {
      return CartItem(
        product: item.product,
        quantity: item.quantity,
        isEceranMode: item.isEceranMode,
      );
    }).toList(growable: false);
    _totalAmountSnapshot = widget.totalAmount;
  }

  double get _paidAmount {
    final raw = _cashCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(raw) ?? 0.0;
  }

  double get _changeAmount => _paidAmount - _totalAmountSnapshot;
  bool get _cashEnough => _paymentMethod == 'hutang' || _paidAmount >= _totalAmountSnapshot;

  // Quick cash suggestions
  List<double> get _suggestions {
    final total = _totalAmountSnapshot;
    final suggestions = <double>[];
    // round up to nearest 1k, 2k, 5k, 10k, 20k, 50k, 100k
    for (final denom in [1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000]) {
      final rounded = (total / denom).ceil() * denom.toDouble();
      if (!suggestions.contains(rounded) && suggestions.length < 4) {
        suggestions.add(rounded);
      }
    }
    return suggestions;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Nama pelanggan harus diisi!', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFFF4D6A),
      ));
      return;
    }

    if (_paymentMethod == 'lunas' && _paidAmount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Masukkan nominal uang yang dibayar!', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFFF4D6A),
      ));
      return;
    }

    if (_paymentMethod == 'lunas' && _paidAmount < _totalAmountSnapshot) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Uang kurang! Tagihan: ${_currency.format(_totalAmountSnapshot)}', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFFF4D6A),
      ));
      return;
    }

    setState(() => _saving = true);

    String finalStatus = _paymentMethod;
    if (finalStatus == 'hutang' && _paidAmount >= _totalAmountSnapshot) {
      finalStatus = 'lunas'; // Otomatis lunas jika bayar penuh atau lebih
    }

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    try {
      final tx = TransactionModel(
        totalAmount: _totalAmountSnapshot,
        status: finalStatus,
        paymentMethod: _paymentMethod,
        customerName: _nameCtrl.text.trim(),
        createdAt: DateTime.now(),
        paidAmount: _paidAmount,
        changeAmount: _changeAmount.clamp(0, double.infinity),
      );

      final items = _cartSnapshot.map((c) {
        double totalCost = 0.0;
        if (c.isEceranMode && c.product.isiPerBungkus > 0) {
          final packs = c.quantity ~/ c.product.isiPerBungkus;
          final sticks = c.quantity % c.product.isiPerBungkus;
          totalCost = (packs * c.product.costPrice) + (sticks * (c.product.costPrice / c.product.isiPerBungkus));
        } else {
          totalCost = c.product.costPrice * c.quantity;
        }
        
        return TransactionItem(
          productId: c.product.id!,
          productName: c.isEceranMode && c.product.isiPerBungkus > 0 && c.quantity >= c.product.isiPerBungkus
             ? '${c.product.name} (Mix Bks/Btg)'
             : (c.isEceranMode ? '${c.product.name} (Eceran)' : c.product.name),
          quantity: c.quantity,
          price: c.total / c.quantity,
          costPrice: c.quantity > 0 ? totalCost / c.quantity : c.product.costPrice,
          isEceranMode: c.isEceranMode,
        );
      }).toList();

      await DatabaseService.instance.saveTransaction(tx, items);

      if (!mounted) return;

      // Kalau lunas dan ada kembalian, tampilkan dialog kembalian dulu
      if (finalStatus == 'lunas' && _changeAmount > 0) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A67E).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00A67E), size: 48),
                ),
                const SizedBox(height: 16),
                Text('Pembayaran Berhasil!', style: GoogleFonts.poppins(color: onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _dialogRow('Total Belanja', _currency.format(_totalAmountSnapshot), onSurface.withValues(alpha: isDark ? 0.54 : 0.85)),
                      Divider(color: onSurface.withValues(alpha: 0.1), height: 20),
                      _dialogRow('Uang Bayar', _currency.format(_paidAmount), onSurface.withValues(alpha: isDark ? 0.7 : 0.9)),
                      Divider(color: onSurface.withValues(alpha: 0.1), height: 20),
                      _dialogRow('Kembalian', _currency.format(_changeAmount), const Color(0xFF00A67E), big: true),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A67E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Selesai', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalStatus == 'lunas'
                  ? 'Pembayaran berhasil disimpan.'
                  : 'Hutang berhasil dicatat.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFF00A67E),
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pembayaran gagal: $e', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFFFF4D6A),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dialogRow(String label, String value, Color valueColor, {bool big = false}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: onSurface.withValues(alpha: isDark ? 0.54 : 0.85), fontSize: 13)),
        Text(value, style: GoogleFonts.poppins(
          color: valueColor,
          fontSize: big ? 20 : 14,
          fontWeight: big ? FontWeight.w800 : FontWeight.w600,
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final change = _changeAmount;
    final isHutang = _paymentMethod == 'hutang';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Pembayaran', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: onSurface)),
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 18, color: onSurface), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF6C63FF), Color(0xFF5046E5)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  Text('TOTAL TAGIHAN', style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.7), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(_currency.format(_totalAmountSnapshot), style: GoogleFonts.poppins(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${_cartSnapshot.fold(0, (sum, i) => sum + i.quantity)} item', style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.54), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Metode Pembayaran
            Text('Metode Pembayaran', style: GoogleFonts.poppins(color: onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _paymentOption('lunas', 'Bayar Tunai', Icons.paid_rounded, const Color(0xFF00A67E))),
                const SizedBox(width: 12),
                Expanded(child: _paymentOption('hutang', 'Catat Hutang', Icons.request_quote_rounded, const Color(0xFFFFB800))),
              ],
            ),

            // Cash input section - Muncul untuk Lunas (wajib cukup) atau Hutang (opsional DP)
            SizedBox(height: 24),
            Text(isHutang ? 'Bayar Sebagian (DP / Opsional)' : 'Uang yang Dibayar', style: GoogleFonts.poppins(color: onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
              TextField(
                controller: _cashCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CurrencyFormatter(),
                ],
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.poppins(color: onSurface, fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.24), fontSize: 18),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('Rp', style: GoogleFonts.poppins(color: const Color(0xFF00A67E), fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF00A67E), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                ),
              ),
              const SizedBox(height: 12),
              // Quick suggestion chips
              Wrap(
                spacing: 8,
                children: _suggestions.map((amount) => GestureDetector(
                  onTap: () => setState(() {
                    _cashCtrl.text = _inputFmt.format(amount.toInt()).trim();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _currency.format(amount.toInt()),
                      style: GoogleFonts.poppins(color: const Color(0xFF6C63FF), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                )).toList(),
              ),

              // Kembalian card tampil live
              if (_paidAmount > 0) ...[
                const SizedBox(height: 20),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    color: change >= 0 ? Color(0xFF00A67E).withValues(alpha: 0.1) : Color(0xFFFF4D6A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: change >= 0 ? Color(0xFF00A67E).withValues(alpha: 0.5) : Color(0xFFFF4D6A).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            change >= 0 ? Icons.arrow_circle_down_rounded : Icons.warning_rounded,
                            color: change >= 0 ? const Color(0xFF00A67E) : const Color(0xFFFF4D6A),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            change >= 0 ? 'Kembalian' : 'Kurang',
                            style: GoogleFonts.poppins(
                              color: change >= 0 ? const Color(0xFF00A67E) : const Color(0xFFFF4D6A),
                              fontSize: 14, fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _currency.format(change.abs()),
                        style: GoogleFonts.poppins(
                          color: change >= 0 ? const Color(0xFF00A67E) : const Color(0xFFFF4D6A),
                          fontSize: 20, fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

             const SizedBox(height: 24),
            Text('Nama Pembeli / Penghutang', style: GoogleFonts.poppins(color: onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.poppins(color: onSurface, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Masukkan nama pelanggan...',
                hintStyle: GoogleFonts.poppins(color: onSurface.withValues(alpha: 0.3), fontSize: 14),
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF00A67E), size: 20),
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00A67E), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),

            const SizedBox(height: 32),
            GestureDetector(
              onTap: (_saving || (!isHutang && !_cashEnough)) ? null : _processPayment,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  gradient: (_saving || (!isHutang && !_cashEnough))
                      ? null
                      : LinearGradient(
                          colors: isHutang 
                              ? [const Color(0xFFFFB800), const Color(0xFFE5A600)]
                              : [const Color(0xFF00A67E), const Color(0xFF008966)],
                        ),
                  color: (_saving || (!isHutang && !_cashEnough)) ? onSurface.withValues(alpha: 0.12) : null,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: (_saving || (!isHutang && !_cashEnough))
                      ? []
                      : [
                          BoxShadow(
                            color: (isHutang ? const Color(0xFFFFB800) : const Color(0xFF00A67E)).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : Text(
                          isHutang 
                            ? (_paidAmount > 0 ? 'CATAT HUTANG DENGAN DP' : 'CATAT HUTANG') 
                            : 'SELESAIKAN PEMBAYARAN',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  Widget _paymentOption(String value, String title, IconData icon, Color color) {
    final isSelected = _paymentMethod == value;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    return GestureDetector(
      onTap: () => setState(() {
        _paymentMethod = value;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : onSurface.withValues(alpha: 0.05), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : onSurface.withValues(alpha: 0.38), size: 28),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.poppins(
              color: isSelected ? color : onSurface.withValues(alpha: 0.54),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            )),
          ],
        ),
      ),
    );
  }
}

class _CurrencyFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    final intVal = int.tryParse(newValue.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final formatted = _fmt.format(intVal).trim();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
