import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import 'add_edit_product_screen.dart';

class ProductResultScreen extends StatelessWidget {
  final String barcode;
  final Product? product;

  const ProductResultScreen({super.key, required this.barcode, this.product});

  static final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final found = product != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    found ? 'Produk Ditemukan ✓' : 'Produk Tidak Ditemukan',
                    style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(child: found ? _foundView(context) : _notFoundView(context)),
          ],
        ),
      ),
    );
  }

  Widget _foundView(BuildContext context) {
    final p = product!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Big price display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0D2B22), Color(0xFF111827)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00A67E).withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.category != null && p.category!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(p.category!, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF6C63FF), fontWeight: FontWeight.w500)),
                  ),
                Text(p.name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.qr_code, color: Colors.white24, size: 13),
                    const SizedBox(width: 5),
                    Text(p.barcode, style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.white30)),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('HARGA JUAL', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38, letterSpacing: 2, fontWeight: FontWeight.w500)),
                    Text(_currency.format(p.price), style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFF00A67E))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('STOK TERSEDIA', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38, letterSpacing: 2, fontWeight: FontWeight.w500)),
                        () {
                          final isEmpty = p.stock <= 0 && (!p.isEceran || p.sisaBatang <= 0);
                          final isLow = p.stock <= p.minStock;
                          if (!isLow) return const SizedBox.shrink();

                          final label = isEmpty ? 'KOSONG' : 'STOK MENIPIS';
                          final color = isEmpty ? const Color(0xFFFF4D6A) : const Color(0xFFFFB800);

                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          );
                        }(),
                      ],
                    ),
                    Text(
                      p.isEceran ? '${p.stock} Bks, ${p.sisaBatang} Btg' : '${p.stock}', 
                      style: GoogleFonts.poppins(
                        fontSize: 20, 
                        fontWeight: FontWeight.w800, 
                        color: () {
                          final isEmpty = p.stock <= 0 && (!p.isEceran || p.sisaBatang <= 0);
                          final isLow = p.stock <= p.minStock;
                          if (isEmpty) return const Color(0xFFFF4D6A);
                          if (isLow) return const Color(0xFFFFB800);
                          return const Color(0xFF00A67E);
                        }(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // Scan Again
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text('Scan Lagi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A67E), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notFoundView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D6A).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, color: Color(0xFFFF4D6A), size: 56),
          ),
          const SizedBox(height: 20),
          Text('Produk Belum Terdaftar', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Barcode ini belum ada di database warung kamu.', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white38, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code, color: Colors.white30, size: 14),
                const SizedBox(width: 8),
                Text(barcode, style: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AddEditProductScreen(initialBarcode: barcode))),
              icon: const Icon(Icons.add_rounded),
              label: Text('Tambah Produk Ini', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: Text('Scan Lagi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white60, side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
