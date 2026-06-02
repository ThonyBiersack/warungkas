import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import 'payment_screen.dart';

class CartItem {
  final Product product;
  int quantity;
  bool isEceranMode;
  CartItem({
    required this.product,
    this.quantity = 1,
    this.isEceranMode = false,
  });

  double get currentPrice => isEceranMode ? product.eceranPrice : product.price;

  double get total {
    if (isEceranMode && product.isiPerBungkus > 0) {
      int packs = quantity ~/ product.isiPerBungkus;
      int sticks = quantity % product.isiPerBungkus;
      return (packs * product.price) + (sticks * product.eceranPrice);
    }
    return currentPrice * quantity;
  }
}

class _CartRefreshResult {
  final List<CartItem> cartItems;
  final List<String> notices;
  final bool failed;

  const _CartRefreshResult({
    required this.cartItems,
    this.notices = const [],
    this.failed = false,
  });

  bool get cartChanged => notices.isNotEmpty;
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with WidgetsBindingObserver {
  late Color _onSurface;
  late Color _surface;
  late bool _isDark;
  final List<CartItem> _cart = [];
  List<Product> _allProducts = [];
  List<Product> _searchResults = [];
  Timer? _refreshTimer;
  Future<_CartRefreshResult>? _refreshTask;

  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchCtrl = TextEditingController();
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  String _searchQuery = '';
  bool _isProcessingScan = false;
  bool _isCheckoutFlow = false;

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  double get _grandTotal => _cart.fold(0, (sum, item) => sum + item.total);

  bool _hasAnySellableStock(Product product) {
    if (!product.isEceran) {
      return product.stock > 0;
    }
    return product.stock > 0 || product.sisaBatang > 0;
  }

  bool _shouldUseEceranByDefault(Product product) {
    return product.isEceran && product.stock <= 0 && product.sisaBatang > 0;
  }

  int _maxQtyFor(Product product, {required bool isEceranMode}) {
    if (isEceranMode) {
      final isiPerBungkus = product.isiPerBungkus > 0
          ? product.isiPerBungkus
          : 1;
      return (product.stock * isiPerBungkus) + product.sisaBatang;
    }
    return product.stock;
  }

  bool _canSwitchToBungkus(CartItem item) {
    return item.quantity <= _maxQtyFor(item.product, isEceranMode: false);
  }

  List<Product> _filterProducts(List<Product> products, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return <Product>[];
    }

    return products.where((p) {
      return p.name.toLowerCase().contains(normalizedQuery) ||
          p.barcode.contains(normalizedQuery);
    }).toList();
  }

  String _cartRefreshMessage(List<String> notices) {
    if (notices.isEmpty) {
      return '';
    }
    if (notices.length == 1) {
      return notices.first;
    }
    return '${notices.first} ${notices.length - 1} item lain juga disesuaikan.';
  }

  _CartRefreshResult _syncCartProducts(List<Product> latestProducts) {
    final productsById = <int, Product>{
      for (final product in latestProducts)
        if (product.id != null) product.id!: product,
    };
    final syncedItems = <CartItem>[];
    final notices = <String>[];

    for (final item in _cart) {
      final latest = item.product.id != null ? productsById[item.product.id!] : null;

      if (latest == null) {
        notices.add('${item.product.name} dihapus karena produk sudah tidak tersedia.');
        continue;
      }

      if (item.isEceranMode && !latest.isEceran) {
        notices.add('${latest.name} dihapus karena mode eceran sudah tidak tersedia.');
        continue;
      }

      final maxQty = _maxQtyFor(latest, isEceranMode: item.isEceranMode);
      if (maxQty <= 0) {
        notices.add(
          item.isEceranMode
              ? '${latest.name} dihapus karena stok eceran habis.'
              : '${latest.name} dihapus karena stok bungkus habis.',
        );
        continue;
      }

      final nextQty = item.quantity > maxQty ? maxQty : item.quantity;
      if (nextQty < item.quantity) {
        notices.add(
          'Qty ${latest.name} disesuaikan ke $nextQty karena stok terbaru berubah.',
        );
      }

      final syncedItem = CartItem(
        product: latest,
        quantity: nextQty,
        isEceranMode: item.isEceranMode,
      );

      if (nextQty == item.quantity &&
          (syncedItem.total - item.total).abs() > 0.001) {
        notices.add('Harga ${latest.name} berubah. Total keranjang diperbarui.');
      }

      syncedItems.add(syncedItem);
    }

    return _CartRefreshResult(cartItems: syncedItems, notices: notices);
  }


  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    if (_isCheckoutFlow) return;

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (!_isCheckoutFlow) {
          _refreshProducts(showError: false);
        }
      },
    );
  }

  void _pauseRealtimeSync() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshProducts(showError: false);
    _startRefreshTimer();
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  void _onSearchFocusChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseRealtimeSync();
    _stopScanner().then((_) => _scannerCtrl.dispose());
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _stopScanner() async {
    try {
      await _scannerCtrl.stop();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isCheckoutFlow) {
      _refreshProducts(showError: false);
      _startRefreshTimer();
    }

    if (state == AppLifecycleState.paused) {
      _pauseRealtimeSync();
    }
  }

  Future<_CartRefreshResult> _refreshProducts({
    bool showError = true,
    bool notifyCartChanges = true,
    bool forceFresh = false,
  }) {
    if (!forceFresh && _refreshTask != null) {
      return _refreshTask!;
    }

    if (forceFresh) {
      return _queueForcedRefresh(
        showError: showError,
        notifyCartChanges: notifyCartChanges,
      );
    }

    return _startRefreshTask(
      showError: showError,
      notifyCartChanges: notifyCartChanges,
    );
  }

  Future<_CartRefreshResult> _queueForcedRefresh({
    required bool showError,
    required bool notifyCartChanges,
  }) async {
    if (_refreshTask != null) {
      await _refreshTask;
    }

    return _startRefreshTask(
      showError: showError,
      notifyCartChanges: notifyCartChanges,
    );
  }

  Future<_CartRefreshResult> _startRefreshTask({
    required bool showError,
    required bool notifyCartChanges,
  }) {
    final task = _doRefreshProducts(
      showError: showError,
      notifyCartChanges: notifyCartChanges,
    );
    _refreshTask = task;
    task.whenComplete(() {
      if (_refreshTask == task) {
        _refreshTask = null;
      }
    });
    return task;
  }

  Future<_CartRefreshResult> _doRefreshProducts({
    bool showError = true,
    bool notifyCartChanges = true,
  }) async {

    try {
      final list = await DatabaseService.instance.getAllProducts();
      if (!mounted) {
        return const _CartRefreshResult(cartItems: []);
      }

      final refreshResult = _syncCartProducts(list);
      setState(() {
        _allProducts = list;
        _cart
          ..clear()
          ..addAll(refreshResult.cartItems);
        _searchResults = _filterProducts(list, _searchQuery);
      });

      if (notifyCartChanges && refreshResult.cartChanged && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _cartRefreshMessage(refreshResult.notices),
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFFFB800),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return refreshResult;
    } catch (e) {
      if (mounted && showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat produk terbaru: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFFF4D6A),
          ),
        );
      }
      return const _CartRefreshResult(cartItems: [], failed: true);
    } finally {
    }
  }

  void _search(String q) {
    setState(() {
      _searchQuery = q.trim();
      _searchResults = _filterProducts(_allProducts, _searchQuery);
    });
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessingScan || capture.barcodes.isEmpty) return;
    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null || barcode == '') return;

    setState(() => _isProcessingScan = true);

    try {
      final product = await DatabaseService.instance.getProductByBarcode(
        barcode,
      );
      if (product == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Scan: Produk tidak ditemukan!',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: const Color(0xFFFF4D6A),
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      } else {
        _addProductDirectly(product);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan gagal: $e', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFFFF4D6A),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _isProcessingScan = false);
      }
    }
  }

  void _addProductDirectly(Product product) {
    // Bug Fix #5: Untuk produk rokok eceran, cek sisa_batang juga — bungkus habis bukan berarti habis total
    final isStockEmpty = !_hasAnySellableStock(product);
    if (isStockEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stok ${product.name} abis bos!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFFFF4D6A),
        ),
      );
      return;
    }

    final defaultToEceran = _shouldUseEceranByDefault(product);
    final i = _cart.indexWhere(
      (c) => c.product.id == product.id && c.isEceranMode == defaultToEceran,
    );
    setState(() {
      if (i != -1) {
        // Bug Fix #3: Cart maxQty tidak perlu dikurangi qty yg ada karena qty IS the current qty
        // Validasi: qty di keranjang harus < stok yang tersedia
        final maxQty = _maxQtyFor(product, isEceranMode: defaultToEceran);
        if (_cart[i].quantity < maxQty) {
          _cart[i].quantity++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Stok tidak cukup! Maks: $maxQty',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: const Color(0xFFFFB800),
            ),
          );
        }
      } else {
        _cart.add(CartItem(product: product, isEceranMode: defaultToEceran));
        if (defaultToEceran) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${product.name} ditambahkan sebagai eceran karena stok bungkus habis.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: const Color(0xFF00A67E),
              duration: const Duration(milliseconds: 1400),
            ),
          );
        }
      }

      // Auto clear pencarian setelah nambahin barang biar balik ke keranjang
      if (_searchQuery != '') {
        _searchQuery = '';
        _searchResults.clear();
        _searchCtrl.clear();
        FocusScope.of(context).unfocus();
      }
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty || _isCheckoutFlow) return;

    _isCheckoutFlow = true;
    _pauseRealtimeSync();

    // Matikan kamera sebelum pindah ke layar pembayaran
    await _scannerCtrl.stop();

    try {
      final refreshResult = await _refreshProducts(
        showError: true,
        notifyCartChanges: false,
        forceFresh: true,
      );

      if (!mounted) return;

      if (refreshResult.failed) {
        return;
      }

      if (refreshResult.cartChanged) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _cart.isEmpty
                  ? 'Keranjang berubah karena stok terbaru. Tambahkan lagi item yang masih tersedia.'
                  : 'Keranjang disesuaikan ke stok terbaru. Cek ulang sebelum lanjut bayar.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFFFB800),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      if (_cart.isEmpty) {
        return;
      }

      final checkoutCart = _cart.map((e) => CartItem(
        product: e.product,
        quantity: e.quantity,
        isEceranMode: e.isEceranMode,
      )).toList();
      final checkoutTotal = checkoutCart.fold<double>(
        0,
        (sum, item) => sum + item.total,
      );

      final success = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            cart: checkoutCart,
            totalAmount: checkoutTotal,
          ),
        ),
      );

      if (success == true && mounted) {
        setState(() => _cart.clear());
      }

      await _refreshProducts(
        showError: false,
        notifyCartChanges: false,
        forceFresh: true,
      );
    } finally {
      _isCheckoutFlow = false;

      if (mounted) {
        _startRefreshTimer();
        await _scannerCtrl.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    _onSurface = Theme.of(context).colorScheme.onSurface;
    _surface = Theme.of(context).colorScheme.surface;
    final isSearchActive = _searchFocusNode.hasFocus || _searchQuery.isNotEmpty;

    return PopScope(
      canPop: !isSearchActive,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() {
          _searchFocusNode.unfocus();
          _searchCtrl.clear();
          _searchQuery = '';
          _searchResults.clear();
        });
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          title: Text(
            'Kasir Belanja',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: _onSurface,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () {
              if (isSearchActive) {
                setState(() {
                  _searchFocusNode.unfocus();
                  _searchCtrl.clear();
                  _searchQuery = '';
                  _searchResults.clear();
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _onSurface.withValues(alpha: 0.7)),
            onPressed: _isCheckoutFlow
                ? null
                : () => _refreshProducts(forceFresh: true),
            tooltip: 'Refresh stok',
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep_rounded, color: _onSurface.withValues(alpha: _isDark ? 0.38 : 0.7)),
            onPressed: _cart.isEmpty
                ? null
                : () async {
                    // Bug Fix #7: Konfirmasi sebelum hapus keranjang
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: _surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          'Kosongkan Keranjang?',
                          style: GoogleFonts.poppins(
                            color: _onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        content: Text(
                          'Semua ${_cart.length} item di keranjang akan dihapus.',
                          style: GoogleFonts.poppins(
                            color: _onSurface.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.poppins(color: Colors.white38),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4D6A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Kosongkan',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) setState(() => _cart.clear());
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // ROW 1: EMBEDDED KAMERA MINI
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isSearchActive ? 0 : 140, // Collapses to 0 when search is active
            margin: EdgeInsets.fromLTRB(
              16,
              isSearchActive ? 0 : 16,
              16,
              isSearchActive ? 0 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00A67E).withValues(alpha: isSearchActive ? 0.0 : 0.4),
                width: isSearchActive ? 0.0 : 1.5,
              ),
            ),
            clipBehavior: Clip.hardEdge,
            child: OverflowBox(
              minHeight: 140,
              maxHeight: 140,
              alignment: Alignment.topCenter,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerCtrl,
                    onDetect: _handleBarcode,
                  ),
                  // Instruksi tipis
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Arahkan ke Barcode',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isProcessingScan)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00A67E),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ROW 2: PENCARIAN
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              onChanged: _search,
              style: GoogleFonts.poppins(color: _onSurface, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Ketik nama produk untuk nambah...',
                hintStyle: GoogleFonts.poppins(color: _onSurface.withValues(alpha: _isDark ? 0.38 : 0.7)),
                prefixIcon: Icon(Icons.search, color: _onSurface.withValues(alpha: _isDark ? 0.54 : 0.85)),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          // ROW 3: LIST ITEM PRODUK / KERANJANG
          Expanded(
            child: _searchQuery != ''
                ? _buildSearchResults()
                : _buildCartList(),
          ),

          // BOTTOM STICKY: TOTAL & CHECKOUT
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isDark ? 0.5 : 0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Belanja',
                        style: GoogleFonts.poppins(
                          color: _onSurface.withValues(alpha: _isDark ? 0.54 : 0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _currency.format(_grandTotal),
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF00A67E),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _cart.isEmpty ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _onSurface.withValues(alpha: 0.05),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'BAYAR (${_cart.length})',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: 1,
                      ),
                    ),
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

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'Produk ga ketemu',
          style: GoogleFonts.poppins(color: _onSurface.withValues(alpha: _isDark ? 0.38 : 0.7)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) {
        final p = _searchResults[i];
        final stockBanyak = _hasAnySellableStock(p);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            onTap: () => _addProductDirectly(p),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: GoogleFonts.poppins(
                    color: _onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                () {
                  final isEmpty = p.stock <= 0 && (!p.isEceran || p.sisaBatang <= 0);
                  final isLow = p.stock <= 2;
                  if (!isLow) return const SizedBox.shrink();

                  final label = isEmpty ? '⚠ KOSONG' : '⚠ MENIPIS';
                  final color = isEmpty ? const Color(0xFFFF4D6A) : const Color(0xFFFFB800);

                  return Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }(),
              ],
            ),
            subtitle: Text(
              p.isEceran
                  ? (p.stock <= 0 && p.sisaBatang > 0
                        ? 'Sisa Stok: 0 Bungkus, ${p.sisaBatang} Batang (eceran)'
                        : 'Sisa Stok: ${p.stock} Bungkus, ${p.sisaBatang} Batang')
                  : 'Sisa Stok: ${p.stock}',
              style: GoogleFonts.poppins(
                color: stockBanyak 
                    ? (p.stock <= 2 ? const Color(0xFFFFB800) : _onSurface.withValues(alpha: _isDark ? 0.7 : 1.0))
                    : (_isDark ? const Color(0xFFFF4D6A) : const Color(0xFFB71C1C)),
                fontSize: 14,
                fontWeight: (p.stock <= 2) ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00A67E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+ Tambah',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00A67E),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.white.withValues(alpha: 0.05),
            ),
            const SizedBox(height: 16),
            Text(
              'Keranjang Kosong',
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _cart.length,
      itemBuilder: (context, index) {
        final item = _cart[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _onSurface.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: _onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.isEceranMode &&
                              item.product.isiPerBungkus > 0 &&
                              item.quantity >= item.product.isiPerBungkus
                          ? '${(item.quantity ~/ item.product.isiPerBungkus)} Bks, ${item.quantity % item.product.isiPerBungkus} Btg'
                          : '${item.quantity} x ${_currency.format(item.currentPrice)}',
                      style: GoogleFonts.poppins(
                        color: _onSurface.withValues(alpha: _isDark ? 0.54 : 0.85),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    () {
                      final isEmpty = item.product.stock <= 0 && (!item.product.isEceran || item.product.sisaBatang <= 0);
                      final isLow = item.product.stock <= 2;
                      final color = isEmpty 
                          ? const Color(0xFFFF4D6A) 
                          : (isLow ? const Color(0xFFFFB800) : _onSurface.withValues(alpha: _isDark ? 0.6 : 0.8));
                      
                      return Row(
                        children: [
                          Text(
                            item.product.isEceran
                                ? 'Stok: ${item.product.stock} Bks, ${item.product.sisaBatang} Btg'
                                : 'Stok: ${item.product.stock}',
                            style: GoogleFonts.poppins(
                              color: color,
                              fontSize: 10,
                              fontWeight: isLow ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                          if (isLow) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.warning_amber_rounded, color: color, size: 10),
                          ],
                        ],
                      );
                    }(),
                    if (item.product.isEceran) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              value: item.isEceranMode,
                              onChanged: (val) {
                                final nextValue = val ?? false;
                                if (!nextValue && !_canSwitchToBungkus(item)) {
                                  final maxBungkus = _maxQtyFor(
                                    item.product,
                                    isEceranMode: false,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        maxBungkus == 0
                                            ? 'Stok bungkus ${item.product.name} habis. Produk ini hanya bisa dijual eceran.'
                                            : 'Qty ${item.quantity} ${item.product.name} terlalu banyak untuk mode bungkus. Kurangi jumlah dulu atau tetap eceran.',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: const Color(0xFFFFB800),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => item.isEceranMode = nextValue);
                              },
                               activeColor: const Color(0xFF00A67E),
                              checkColor: Colors.white,
                              side: BorderSide(
                                color: _isDark ? Colors.white54 : Colors.black,
                                width: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Beli Eceran',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF00A67E),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                _currency.format(item.total),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF00A67E),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  _qtyBtn(
                    Icons.remove,
                    () => setState(() {
                      if (item.quantity > 1) {
                        item.quantity--;
                      } else {
                        _cart.removeAt(index);
                      }
                    }),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${item.quantity}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: _onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _qtyBtn(
                    Icons.add,
                    () => setState(() {
                      final maxQty = _maxQtyFor(
                        item.product,
                        isEceranMode: item.isEceranMode,
                      );

                      if (item.quantity < maxQty) {
                        item.quantity++;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Stok mentok bosque!',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: const Color(0xFFFFB800),
                            duration: const Duration(milliseconds: 500),
                          ),
                        );
                      }
                    }),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _onSurface.withValues(alpha: 0.7), size: 20),
      ),
    );
  }
}
