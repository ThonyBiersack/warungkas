import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import 'scanner_screen.dart';

class CurrencyInputFormatter extends TextInputFormatter {
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
    final intValue =
        int.tryParse(newValue.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final formatted = _fmt.format(intValue).trim();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  final String? initialBarcode;
  const AddEditProductScreen({super.key, this.product, this.initialBarcode});
  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  static const List<String> _defaultCategories = [
    'Peralatan Mandi',
    'Sembako',
    'Beras',
    'Minyak',
    'Telur',
    'Mie Instan',
    'Snack',
    'Minuman',
    'Rokok',
    'Bumbu Dapur',
    'Sabun / Detergen',
    'Kebutuhan Rumah',
    'Lain-lain',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _price;
  late final TextEditingController _costPrice;
  late final TextEditingController _packTotalCost;
  late final TextEditingController _packQuantity;
  late final TextEditingController _stock;
  bool _isModalPerPack = false;
  late final TextEditingController _category;
  late final FocusNode _categoryFocusNode;
  late final TextEditingController _eceranPrice;
  late final TextEditingController _isiPerBungkus;

  bool _saving = false;
  bool _isEceran = false;
  bool _showCategorySuggestions = false;
  List<String> _categorySuggestions = List<String>.from(_defaultCategories);

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product?.name ?? '');

    var initialBc = widget.product?.barcode ?? widget.initialBarcode ?? '';
    if (initialBc.startsWith('GEN-')) initialBc = '';
    _barcode = TextEditingController(text: initialBc);

    _stock = TextEditingController(
      text: widget.product != null ? widget.product!.stock.toString() : '',
    );
    final pPrice = widget.product?.price.toInt();
    _price = TextEditingController(
      text: pPrice != null
          ? NumberFormat.currency(
              locale: 'id_ID',
              symbol: '',
              decimalDigits: 0,
            ).format(pPrice).trim()
          : '',
    );
    final pCostPrice = widget.product?.costPrice.toInt();
    _costPrice = TextEditingController(
      text: pCostPrice != null && pCostPrice > 0
          ? NumberFormat.currency(
              locale: 'id_ID',
              symbol: '',
              decimalDigits: 0,
            ).format(pCostPrice).trim()
          : '',
    );
    _category = TextEditingController(text: widget.product?.category ?? '');
    _category.addListener(
      () => setState(() {}),
    ); // trigger rebuild for condition
    _categoryFocusNode = FocusNode();
    _loadCategorySuggestions();

    _packTotalCost = TextEditingController();
    _packQuantity = TextEditingController();

    _isEceran = widget.product?.isEceran ?? false;
    final ecPrice = widget.product?.eceranPrice.toInt();
    _eceranPrice = TextEditingController(
      text: ecPrice != null && ecPrice > 0
          ? NumberFormat.currency(
              locale: 'id_ID',
              symbol: '',
              decimalDigits: 0,
            ).format(ecPrice).trim()
          : '',
    );
    _isiPerBungkus = TextEditingController(
      text: widget.product != null && widget.product!.isiPerBungkus > 0
          ? widget.product!.isiPerBungkus.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _price.dispose();
    _costPrice.dispose();
    _packTotalCost.dispose();
    _packQuantity.dispose();
    _stock.dispose();
    _category.dispose();
    _categoryFocusNode.dispose();
    _eceranPrice.dispose();
    _isiPerBungkus.dispose();

    super.dispose();
  }

  Future<void> _loadCategorySuggestions() async {
    try {
      final products = await DatabaseService.instance.getAllProducts();
      if (!mounted) return;

      final merged = <String>{..._defaultCategories};
      for (final product in products) {
        final category = product.category?.trim();
        if (category != null && category.isNotEmpty) {
          merged.add(category);
        }
      }

      final sorted = merged.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      setState(() => _categorySuggestions = sorted);
    } catch (_) {
      // Tetap pakai kategori default kalau server belum bisa diakses.
    }
  }

  Future<void> _delete() async {
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
          'Yakin hapus "${_name.text}"?',
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
      setState(() => _saving = true);
      try {
        await DatabaseService.instance.deleteProduct(widget.product!.id!);
        if (!mounted) return;
        Navigator.pop(context); // Close screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk dihapus', style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFFFF4D6A),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal hapus: $e', style: GoogleFonts.poppins()),
              backgroundColor: const Color(0xFFFF4D6A),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final rawPriceStr = _price.text.replaceAll(RegExp(r'[^0-9]'), '');

      double finalCostPrice = 0.0;
      if (_isModalPerPack) {
        final rawPackCost = _packTotalCost.text.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        final rawPackQty = _packQuantity.text.replaceAll(RegExp(r'[^0-9]'), '');
        final pCost = double.tryParse(rawPackCost) ?? 0.0;
        final pQty = int.tryParse(rawPackQty) ?? 1;
        if (pQty > 0) finalCostPrice = pCost / pQty;
      } else {
        final rawCostPriceStr = _costPrice.text.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        finalCostPrice = double.tryParse(rawCostPriceStr) ?? 0.0;
      }

      final rawStockStr = _stock.text.replaceAll(RegExp(r'[^0-9]'), '');

      final bcStr = _barcode.text.trim();
      final finalBarcode = bcStr.isEmpty
          ? 'GEN-${DateTime.now().millisecondsSinceEpoch}'
          : bcStr;

      final rawEceranPriceStr = _eceranPrice.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final rawIsiStr = _isiPerBungkus.text.replaceAll(RegExp(r'[^0-9]'), '');
      final isRokok = _category.text.trim().toLowerCase() == 'rokok';

      final p = Product(
        id: widget.product?.id,
        name: _name.text.trim(),
        barcode: finalBarcode,
        price: double.parse(rawPriceStr.isEmpty ? '0' : rawPriceStr),
        costPrice: finalCostPrice,
        stock: int.parse(rawStockStr.isEmpty ? '0' : rawStockStr),
        category: _category.text.trim(),
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        isEceran: isRokok ? _isEceran : false,
        eceranPrice: (isRokok && _isEceran)
            ? double.parse(rawEceranPriceStr.isEmpty ? '0' : rawEceranPriceStr)
            : 0.0,
        isiPerBungkus: (isRokok && _isEceran)
            ? int.parse(rawIsiStr.isEmpty ? '0' : rawIsiStr)
            : 0,
        // Bug Fix #1: Preserve sisa_batang existing saat edit — jangan reset ke 0!
        sisaBatang: (isRokok && _isEceran)
            ? (widget.product?.sisaBatang ?? 0)
            : 0,
        minStock: 2,
      );
      if (_isEditing) {
        await DatabaseService.instance.updateProduct(p);
      } else {
        await DatabaseService.instance.insertProduct(p);
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Produk diperbarui!' : 'Produk ditambahkan!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFF00A67E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan produk: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFFFF4D6A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () {
          setState(() => _showCategorySuggestions = false);
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
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
                          color: onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: onSurface,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Produk' : 'Tambah Produk',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isEditing)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFFF4D6A),
                        ),
                        onPressed: _saving ? null : _delete,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _field(
                          'Nama Produk',
                          _name,
                          'contoh: Indomie Goreng',
                          Icons.label_outline,
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Nama wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          'Barcode (Opsional)',
                          _barcode,
                          'Kosongkan jika tidak ada barcode',
                          Icons.qr_code,
                          keyboard: TextInputType.number,
                          suffix: IconButton(
                            icon: Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () async {
                              final scanned = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ScannerScreen(returnBarcode: true),
                                ),
                              );
                              if (scanned != null && scanned.isNotEmpty) {
                                setState(() => _barcode.text = scanned);
                              }
                            },
                          ),
                          validator: (v) => null,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          'Harga Jual (Rp)',
                          _price,
                          'contoh: 3.500',
                          Icons.payments_outlined,
                          keyboard: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CurrencyInputFormatter(),
                          ],
                          validator: (v) {
                            if (v!.trim().isEmpty) {
                              return 'Harga jual wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Mode Input Modal
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1F2937)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: onSurface.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Input Modal per Dus/Pack',
                                style: GoogleFonts.poppins(
                                  color: onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Switch(
                                value: _isModalPerPack,
                                activeThumbColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onChanged: (val) => setState(() {
                                  _isModalPerPack = val;
                                  // clear inputs on switch so user doesn't get confused
                                  if (val) {
                                    _packTotalCost.clear();
                                    _packQuantity.clear();
                                  } else {
                                    // optionally clear costPrice? keeping it is safer
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_isModalPerPack) ...[
                          _field(
                            'Total Harga Beli 1 Dus/Pack (Rp)',
                            _packTotalCost,
                            'contoh: 50.000',
                            Icons.inventory_2_outlined,
                            keyboard: TextInputType.number,
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              CurrencyInputFormatter(),
                            ],
                            validator: (v) {
                              final raw =
                                  v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                              if (raw.isEmpty) {
                                return 'Total harga pack wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _field(
                            'Isi dalam 1 Dus/Pack (Pcs)',
                            _packQuantity,
                            'contoh: 10',
                            Icons.format_list_numbered_rounded,
                            keyboard: TextInputType.number,
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) {
                              final raw =
                                  v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                              if (raw.isEmpty) return 'Isi pack wajib diisi';
                              if (int.tryParse(raw) == 0) {
                                return 'Isi pack tidak boleh 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (ctx) {
                              double computed = 0;
                              final rawCost = _packTotalCost.text.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              final rawQty = _packQuantity.text.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              if (rawCost.isNotEmpty && rawQty.isNotEmpty) {
                                final cost = double.tryParse(rawCost) ?? 0;
                                final qty = int.tryParse(rawQty) ?? 1;
                                if (qty > 0) computed = cost / qty;
                              }
                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  bottom: 8,
                                ),
                                child: Text(
                                  'Modal per Satuan: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(computed)}',
                                  style: GoogleFonts.poppins(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ] else ...[
                          _field(
                            'Harga Modal (Rp)',
                            _costPrice,
                            'opsional, isi untuk hitung laba',
                            Icons.inventory_outlined,
                            keyboard: TextInputType.number,
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              CurrencyInputFormatter(),
                            ],
                            validator: (v) {
                              final raw =
                                  v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                              if (raw.isEmpty) return null;
                              if (double.tryParse(raw) == null) {
                                return 'Harga modal harus berupa angka';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        _field(
                          'Stok Tersedia',
                          _stock,
                          'contoh: 50',
                          Icons.inventory_2_outlined,
                          keyboard: TextInputType.number,
                          formatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Stok wajib diisi';
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),
                        _buildCategoryField(),
                        if (_category.text.trim().toLowerCase() == 'rokok') ...[
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            title: Text(
                              'Bisa diecer (batangan)?',
                              style: GoogleFonts.poppins(
                                color: onSurface,
                                fontSize: 16,
                              ),
                            ),
                            value: _isEceran,
                            onChanged: (val) =>
                                setState(() => _isEceran = val ?? false),
                            checkColor: Colors.black,
                            activeColor: Theme.of(context).colorScheme.primary,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            side: BorderSide(
                              color: onSurface.withValues(
                                alpha: isDark ? 0.38 : 0.7,
                              ),
                            ),
                          ),
                          if (_isEceran) ...[
                            const SizedBox(height: 8),
                            _field(
                              'Harga Eceran per Batang (Rp)',
                              _eceranPrice,
                              'contoh: 2.500',
                              Icons.payments_outlined,
                              keyboard: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CurrencyInputFormatter(),
                              ],
                              validator: (v) {
                                final raw =
                                    v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                                if (raw.isEmpty) {
                                  return 'Harga eceran wajib diisi';
                                }
                                if (double.tryParse(raw) == 0) {
                                  return 'Harga eceran tidak boleh 0';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _field(
                              'Isi per Bungkus (Batang)',
                              _isiPerBungkus,
                              'contoh: 12, 16, atau 20',
                              Icons.format_list_numbered_outlined,
                              keyboard: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) {
                                // Bug Fix #8: Pastikan isiPerBungkus > 0 untuk cegah divide by zero
                                if (v!.trim().isEmpty) {
                                  return 'Isi per bungkus wajib diisi';
                                }
                                final val = int.tryParse(v.trim());
                                if (val == null || val <= 0) {
                                  return 'Isi per bungkus harus lebih dari 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isEditing
                                        ? 'Simpan Perubahan'
                                        : 'Tambah Produk',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _filteredCategorySuggestions {
    final query = _category.text.trim().toLowerCase();
    final results = _categorySuggestions.where((category) {
      if (query.isEmpty) return true;
      return category.toLowerCase().contains(query);
    }).toList();

    results.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      final aStarts = query.isNotEmpty && aLower.startsWith(query);
      final bStarts = query.isNotEmpty && bLower.startsWith(query);

      if (aStarts != bStarts) {
        return aStarts ? -1 : 1;
      }

      return aLower.compareTo(bLower);
    });

    return results.take(6).toList(growable: false);
  }

  void _selectCategory(String category) {
    _category.value = TextEditingValue(
      text: category,
      selection: TextSelection.collapsed(offset: category.length),
    );
    setState(() => _showCategorySuggestions = false);
    FocusScope.of(context).unfocus();
  }

  Widget _buildCategoryField() {
    final filteredSuggestions = _filteredCategorySuggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori (opsional)',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _category,
          focusNode: _categoryFocusNode,
          style: GoogleFonts.poppins(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
          ),
          onTap: () => setState(() => _showCategorySuggestions = true),
          onChanged: (_) => setState(() => _showCategorySuggestions = true),
          decoration: InputDecoration(
            hintText: 'Pilih atau ketik kategori',
            hintStyle: GoogleFonts.poppins(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.24),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.category_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            suffixIcon: IconButton(
              onPressed: () {
                FocusScope.of(context).requestFocus(_categoryFocusNode);
                setState(() {
                  _showCategorySuggestions = !_showCategorySuggestions;
                });
              },
              icon: Icon(
                _showCategorySuggestions
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.54
                      : 0.85,
                ),
              ),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00A67E),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
        ),
        if (_showCategorySuggestions) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: filteredSuggestions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Kategori belum ada. Kamu bisa lanjut ketik kategori baru.',
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(
                              alpha:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.54
                                  : 0.85,
                            ),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredSuggestions.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      final category = filteredSuggestions[index];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _selectCategory(category),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            category,
                            style: GoogleFonts.poppins(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          inputFormatters: formatters,
          validator: validator,
          style: GoogleFonts.poppins(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 17,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.24),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            suffixIcon: suffix,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00A67E),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF4D6A)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF4D6A)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }
}
