import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import 'add_edit_product_screen.dart';
import 'scanner_screen.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});
  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  late Color _onSurface;
  late Color _surface;
  late bool _isDark;
  List<Product> _products = [];
  List<Product> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await DatabaseService.instance.getAllProducts();
      if (!mounted) return;
      setState(() {
        _products = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error load data: $e', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFFF4D6A),
      ));
      setState(() => _loading = false);
    }
  }

  void _search(String q) async {
    if (q.isEmpty) {
      setState(() => _filtered = _products);
      return;
    }
    final res = await DatabaseService.instance.searchProducts(q);
    setState(() => _filtered = res);
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(returnBarcode: true),
      ),
    );

    if (barcode != null && barcode.isNotEmpty) {
      _searchCtrl.text = barcode;
      _search(barcode);
    }
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Produk',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Yakin hapus "${p.name}"?',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Hapus',
              style: GoogleFonts.poppins(color: const Color(0xFFFF4D6A)),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await DatabaseService.instance.deleteProduct(p.id!);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${p.name} dihapus', style: GoogleFonts.poppins()),
              backgroundColor: const Color(0xFFFF4D6A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal hapus produk: $e', style: GoogleFonts.poppins()),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
          );
          _load();
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Tambah',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: _onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daftar Produk',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_filtered.length} produk terdaftar',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _onSurface.withValues(alpha: _isDark ? 0.4 : 0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _search,
                style: GoogleFonts.poppins(color: _onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Cari nama, barcode, atau kategori...',
                  hintStyle: GoogleFonts.poppins(
                    color: _onSurface.withValues(alpha: _isDark ? 0.3 : 0.7),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _onSurface.withValues(alpha: _isDark ? 0.3 : 0.7),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFF00A67E),
                    ),
                    onPressed: _scanBarcode,
                    tooltip: 'Scan Barcode',
                  ),
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00A67E),
                      ),
                    )
                  : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 60,
                            color: _onSurface.withValues(alpha: 0.1),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Belum ada produk',
                            style: GoogleFonts.poppins(
                              color: _onSurface.withValues(alpha: _isDark ? 0.4 : 0.8),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap + untuk tambah produk baru',
                            style: GoogleFonts.poppins(
                              color: _onSurface.withValues(alpha: _isDark ? 0.3 : 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _tile(_filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Product p) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditProductScreen(product: p),
          ),
        );
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _onSurface.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00A67E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF00A67E),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    p.barcode.startsWith('GEN-') ? 'Tanpa Barcode' : p.barcode,
                    style: GoogleFonts.robotoMono(
                      fontSize: 13,
                      color: _onSurface.withValues(alpha: _isDark ? 0.3 : 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (p.category != null && p.category!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF6C63FF).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(p.category!, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6C63FF))),
                        ),
                      () {
                        final isEmpty = p.stock <= 0 && (!p.isEceran || p.sisaBatang <= 0);
                        final isLow = p.stock <= 2;
                        final color = isEmpty
                            ? const Color(0xFFFF4D6A) // Red for empty
                            : (isLow ? const Color(0xFFFFB800) : const Color(0xFF00A67E)); // Yellow for low, Green for OK
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            p.isEceran ? 'Stok: ${p.stock} Bks, ${p.sisaBatang} Btg' : 'Stok: ${p.stock}',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                          ),
                        );
                      }(),
                      () {
                        final isEmpty = p.stock <= 0 && (!p.isEceran || p.sisaBatang <= 0);
                        final isLow = p.stock <= 2;
                        if (!isLow) return const SizedBox.shrink();

                        final label = isEmpty ? 'KOSONG' : 'MENIPIS';
                        final color = isEmpty ? const Color(0xFFFF4D6A) : const Color(0xFFFFB800);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        );
                      }(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currency.format(p.price),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF00A67E),
                  ),
                ),
                if (p.costPrice > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Modal ${_currency.format(p.costPrice)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _onSurface.withValues(alpha: _isDark ? 0.54 : 0.85),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _tileBtn(
                  Icons.delete_outline,
                  const Color(0xFFFF4D6A),
                  () => _delete(p),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
