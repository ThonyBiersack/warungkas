import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../services/trial_storage_service.dart';
import 'app_repository.dart';

class LocalRepository implements AppRepository {
  static Database? _db;

  static const _publicKeyHex = '82446a691d91a8f3e2ece89228ae8a560d5bdf1e2cd5e5460f57f1a836f189a2';

  static Future<bool> _verifyEd25519({
    required String data,
    required String signatureHex,
  }) async {
    try {
      final algorithm = Ed25519();
      final pubKeyBytes = _hexDecode(_publicKeyHex);
      final publicKey = SimplePublicKey(pubKeyBytes, type: KeyPairType.ed25519);
      final sigBytes = _hexDecode(signatureHex);
      final signature = Signature(sigBytes, publicKey: publicKey);
      final messageBytes = utf8.encode(data);
      return await algorithm.verify(
        messageBytes,
        signature: signature,
      );
    } catch (_) {
      return false;
    }
  }

  static List<int> _hexDecode(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    String path;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final docDir = await getApplicationSupportDirectory();
      path = p.join(docDir.path, 'warungkas_core.db');
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, 'warungkas_core.db');
    }

    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('PRAGMA foreign_keys = ON;');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            barcode TEXT NOT NULL UNIQUE,
            price REAL NOT NULL,
            cost_price REAL DEFAULT 0,
            stock INTEGER DEFAULT 0,
            category TEXT DEFAULT '',
            created_at TEXT NOT NULL,
            min_stock INTEGER DEFAULT 5,
            is_eceran INTEGER DEFAULT 0,
            eceran_price REAL DEFAULT 0,
            isi_per_bungkus INTEGER DEFAULT 0,
            sisa_batang INTEGER DEFAULT 0
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            total_amount REAL NOT NULL,
            status TEXT NOT NULL,
            customer_name TEXT,
            created_at TEXT NOT NULL,
            payment_method TEXT DEFAULT '',
            settled_at TEXT,
            cancelled_at TEXT,
            paid_amount REAL DEFAULT 0,
            change_amount REAL DEFAULT 0,
            installments TEXT DEFAULT '[]'
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS transaction_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            product_name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            price REAL NOT NULL,
            cost_price REAL DEFAULT 0,
            is_eceran_mode INTEGER DEFAULT 0,
            FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS system_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          );
        ''');
        
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Do nothing, let it succeed to use existing backend DB
      },
    );
    return database;
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    final database = await db;
    final res = await database.query('products', where: 'barcode = ?', whereArgs: [barcode]);
    if (res.isEmpty) return null;
    return Product.fromMap(res.first);
  }

  @override
  Future<List<Product>> getAllProducts() async {
    final database = await db;
    final res = await database.query('products', orderBy: 'id DESC');
    return res.map((e) => Product.fromMap(e)).toList();
  }

  @override
  Future<int> insertProduct(Product product) async {
    final database = await db;
    final map = product.toMap();
    map.remove('id'); // Ensure auto increment
    return await database.insert('products', map);
  }

  @override
  Future<int> updateProduct(Product product) async {
    final database = await db;
    final map = product.toMap();
    return await database.update('products', map, where: 'id = ?', whereArgs: [product.id]);
  }

  @override
  Future<int> deleteProduct(int id) async {
    final database = await db;
    return await database.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    final database = await db;
    final res = await database.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'id DESC',
    );
    return res.map((e) => Product.fromMap(e)).toList();
  }

  @override
  Future<void> saveTransaction(TransactionModel tx, List<TransactionItem> items) async {
    final database = await db;
    final createdAt = DateTime.now().toIso8601String();

    await database.transaction((txn) async {
      double calculatedTotal = 0;
      final resolvedItems = <Map<String, dynamic>>[];

      // Resolve items and subtract stock
      for (final item in items) {
        final productRes = await txn.query('products', where: 'id = ?', whereArgs: [item.productId]);
        if (productRes.isEmpty) throw Exception('Produk dengan id ${item.productId} tidak ditemukan');
        final p = productRes.first;
        
        final isEceran = (p['is_eceran'] as int?) == 1;
        final isiPerBungkus = (p['isi_per_bungkus'] as int?) ?? 1;
        final isEceranMode = item.isEceranMode ? 1 : 0;
        final pCostPrice = (p['cost_price'] as num?)?.toDouble() ?? 0;
        final pPrice = (p['price'] as num?)?.toDouble() ?? 0;
        final pEceranPrice = (p['eceran_price'] as num?)?.toDouble() ?? 0;
        
        String resolvedName = item.productName;
        double resolvedPrice = item.price;
        double resolvedCost = item.costPrice;
        double lineTotal = 0;

        if (isEceranMode == 1) {
          if (!isEceran) throw Exception('${p['name']} tidak mendukung eceran');
          final packs = item.quantity ~/ isiPerBungkus;
          final sticks = item.quantity % isiPerBungkus;
          lineTotal = (packs * pPrice) + (sticks * pEceranPrice);
          resolvedPrice = lineTotal / item.quantity;
          resolvedCost = pCostPrice / isiPerBungkus;
          resolvedName = item.quantity >= isiPerBungkus ? '${p['name']} (Mix Bks/Btg)' : '${p['name']} (Eceran)';
        } else {
          resolvedName = p['name'] as String;
          resolvedPrice = pPrice;
          resolvedCost = pCostPrice;
          lineTotal = pPrice * item.quantity;
        }

        calculatedTotal += lineTotal;
        resolvedItems.add({
          'product_id': item.productId,
          'product_name': resolvedName,
          'quantity': item.quantity,
          'price': resolvedPrice,
          'cost_price': resolvedCost,
          'is_eceran_mode': isEceranMode,
        });

        // Stock Logic
        if (isEceranMode == 1) {
          int reqBatang = item.quantity;
          int sisaBatang = (p['sisa_batang'] as int?) ?? 0;
          int stockBungkus = (p['stock'] as int?) ?? 0;
          
          if (sisaBatang < reqBatang) {
            int kekurangan = reqBatang - sisaBatang;
            int packNeeded = (kekurangan / isiPerBungkus).ceil();
            if (stockBungkus < packNeeded) throw Exception('Stok tidak mencukupi untuk eceran');
            stockBungkus -= packNeeded;
            sisaBatang += (packNeeded * isiPerBungkus);
          }
          sisaBatang -= reqBatang;
          await txn.update('products', {'stock': stockBungkus, 'sisa_batang': sisaBatang}, where: 'id = ?', whereArgs: [item.productId]);
        } else {
          int stock = (p['stock'] as int?) ?? 0;
          if (stock < item.quantity) throw Exception('Stok ${p['name']} tidak cukup');
          await txn.update('products', {'stock': stock - item.quantity}, where: 'id = ?', whereArgs: [item.productId]);
        }
      }

      double paidAmount = tx.paidAmount;

      if (tx.status == 'lunas' && paidAmount < calculatedTotal) {
        throw Exception('Nominal dibayar kurang dari total transaksi untuk status Lunas');
      }

      double changeAmount = (tx.status == 'lunas' || paidAmount >= calculatedTotal) ? (paidAmount - calculatedTotal).clamp(0, double.infinity) : 0;
      
      String initialInstallments = '[]';
      if (paidAmount > 0) {
        initialInstallments = json.encode([{'amount': paidAmount - changeAmount, 'date': createdAt}]);
      }

      final txId = await txn.insert('transactions', {
        'total_amount': calculatedTotal,
        'status': tx.status,
        'customer_name': tx.customerName,
        'paid_amount': paidAmount - changeAmount,
        'change_amount': changeAmount,
        'created_at': createdAt,
        'payment_method': tx.paymentMethod.isNotEmpty ? tx.paymentMethod : tx.status,
        'settled_at': tx.status == 'lunas' ? createdAt : null,
        'cancelled_at': null,
        'installments': initialInstallments,
      });

      for (var map in resolvedItems) {
        map['transaction_id'] = txId;
        await txn.insert('transaction_items', map);
      }
    });
  }

  @override
  Future<List<TransactionModel>> getTransactions({String? status}) async {
    final database = await db;
    String? where;
    List<dynamic>? whereArgs;
    if (status != null) {
      where = 'status = ?';
      whereArgs = [status];
    }
    final res = await database.query('transactions', where: where, whereArgs: whereArgs, orderBy: 'COALESCE(settled_at, created_at) DESC');
    return res.map((e) => TransactionModel.fromMap(e)).toList();
  }

  @override
  Future<List<TransactionItem>> getTransactionItems(int txId) async {
    final database = await db;
    final res = await database.query('transaction_items', where: 'transaction_id = ?', whereArgs: [txId]);
    return res.map((e) => TransactionItem.fromMap(e)).toList();
  }

  @override
  Future<void> updateTransactionStatus(int txId, String status) async {
    final database = await db;
    await database.update('transactions', {'status': status}, where: 'id = ?', whereArgs: [txId]);
  }

  @override
  Future<void> settleTransaction(int txId, {required double paidAmount, double changeAmount = 0.0}) async {
    final database = await db;
    await database.transaction((txn) async {
      final txRow = await txn.query('transactions', where: 'id = ?', whereArgs: [txId]);
      if (txRow.isEmpty) throw Exception('Transaksi tidak ditemukan');
      
      final txData = txRow.first;
      if (txData['status'] == 'lunas' || txData['status'] == 'dibatalkan') throw Exception('Hanya transaksi hutang yang bisa dicicil');
      
      double prevPaid = (txData['paid_amount'] as num?)?.toDouble() ?? 0;
      double total = (txData['total_amount'] as num?)?.toDouble() ?? 0;
      
      double newPaid = prevPaid + paidAmount;
      double newChange = 0.0;
      String newStatus = 'hutang';
      String? settledAt;

      if (newPaid >= total) {
        newStatus = 'lunas';
        newChange = newPaid - total;
        settledAt = DateTime.now().toIso8601String();
      }

      List insts = [];
      try {
        final raw = txData['installments'] as String? ?? '[]';
        insts = json.decode(raw);
      } catch(_) {}
      
      double netPayment = paidAmount - newChange;
      if (netPayment > 0) {
        insts.add({
          'amount': netPayment,
          'date': DateTime.now().toIso8601String()
        });
      }

      await txn.update('transactions', {
        'status': newStatus,
        'paid_amount': newPaid - newChange,
        'change_amount': newChange,
        'settled_at': settledAt,
        'installments': json.encode(insts)
      }, where: 'id = ?', whereArgs: [txId]);
    });
  }

  @override
  Future<void> deleteTransaction(int txId) async {
    final database = await db;
    await database.transaction((txn) async {
      final txRow = await txn.query('transactions', where: 'id = ?', whereArgs: [txId]);
      if (txRow.isEmpty || txRow.first['status'] == 'dibatalkan') return; // Prevent double stock restore
      
      final items = await txn.query('transaction_items', where: 'transaction_id = ?', whereArgs: [txId]);
      for (final item in items) {
        final pResult = await txn.query('products', where: 'id = ?', whereArgs: [item['product_id']]);
        if (pResult.isNotEmpty) {
           final p = pResult.first;
           int qty = (item['quantity'] as int?) ?? 0;
           if ((item['is_eceran_mode'] as int?) == 1) {
             int sisaBatang = (p['sisa_batang'] as int?) ?? 0;
             int stock = (p['stock'] as int?) ?? 0;
             int isi = (p['isi_per_bungkus'] as int?) ?? 1;
             
             sisaBatang += qty;
             stock += (sisaBatang ~/ isi);
             sisaBatang = sisaBatang % isi;
             await txn.update('products', {'stock': stock, 'sisa_batang': sisaBatang}, where: 'id = ?', whereArgs: [p['id']]);
           } else {
             await txn.execute('UPDATE products SET stock = stock + ? WHERE id = ?', [qty, p['id']]);
           }
        }
      }
      await txn.update('transactions', {'status': 'dibatalkan', 'cancelled_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [txId]);
    });
  }

  @override
  Future<void> resetDatabase() async {
    final database = await db;
    await database.execute('DELETE FROM transaction_items');
    await database.execute('DELETE FROM transactions');
    await database.execute('DELETE FROM products');
    try {
      await database.execute('DELETE FROM sqlite_sequence');
    } catch (_) {}
  }

  @override
  Future<dynamic> getLicenseStatus() async {
    final database = await db;
    final rows = await database.query('system_settings');
    final dict = {for (var r in rows) r['key'] as String: r['value'] as String};

    // ── Step 1: Read from persistent storage (survives app uninstall) ─────────
    final persistent = await TrialStorageService.instance.read();

    // ── Step 2: Resolve device_code (priority: persistent > SQLite > derive) ──
    // The persistent file is the single source of truth after our fix is deployed.
    // SQLite is used only as a migration path for users who already had data
    // before this fix was introduced.
    String deviceCode = persistent['device_code'] ?? dict['device_code'] ?? '';
    if (deviceCode.isEmpty) {
      // Derive from hostname so the code is stable even if trial.dat is lost.
      deviceCode = TrialStorageService.deriveDeviceCode();
    }

    // ── Step 3: Resolve trial_start_date ─────────────────────────────────────
    // Persistent file wins: this prevents reinstall from resetting the trial.
    // If the persistent file is empty (first-ever install, or pre-fix migration
    // from SQLite), we seed it now and it will be read on every subsequent run.
    String trialStartStr = persistent['trial_start_date'] ?? dict['trial_start_date'] ?? '';
    String licenseKey = dict['license_payload'] ?? '';
    final now = DateTime.now();

    if (trialStartStr.isEmpty) {
      // Brand-new device — start the trial clock and persist it immediately.
      trialStartStr = now.toIso8601String();
      await TrialStorageService.instance.write({
        'device_code': deviceCode,
        'trial_start_date': trialStartStr,
      });
      await database.insert('system_settings', {'key': 'device_code', 'value': deviceCode},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await database.insert('system_settings', {'key': 'trial_start_date', 'value': trialStartStr},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } else if (persistent.isEmpty) {
      // Migration path: existing user whose data lives only in SQLite.
      // Copy it into the persistent file so future reinstalls won't reset the trial.
      await TrialStorageService.instance.write({
        'device_code': deviceCode,
        'trial_start_date': trialStartStr,
      });
    } else {
      // Normal path: persistent file exists. Re-sync SQLite to match so the
      // rest of the codebase (license key validation, etc.) keeps working.
      await database.insert('system_settings', {'key': 'device_code', 'value': deviceCode},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await database.insert('system_settings', {'key': 'trial_start_date', 'value': trialStartStr},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    DateTime trialStart = DateTime.tryParse(trialStartStr) ?? now;

    // Prevent clock-forward tampering: if trial start is in the future, expire immediately.
    if (trialStart.isAfter(now)) {
      trialStart = now.subtract(const Duration(days: 7));
      await TrialStorageService.instance.write(
          {'trial_start_date': trialStart.toIso8601String()});
    }

    // ── Step 4: Anti-clock-rewind check ──────────────────────────────────────
    // We compare last_seen from BOTH sources and take whichever is later.
    // This prevents an attacker from deleting the persistent file and then
    // rewinding the clock to extend their trial.
    final lastSeenPersistent = persistent['last_seen_date'];
    final lastSeenSqlite = dict['last_seen_date'];
    String lastSeenStr = lastSeenPersistent ?? lastSeenSqlite ?? now.toIso8601String();
    if (lastSeenPersistent != null && lastSeenSqlite != null) {
      final lp = DateTime.tryParse(lastSeenPersistent);
      final ls = DateTime.tryParse(lastSeenSqlite);
      if (lp != null && ls != null) {
        // Use whichever timestamp is further in the future
        lastSeenStr = lp.isAfter(ls) ? lastSeenPersistent : lastSeenSqlite;
      }
    }
    final lastSeen = DateTime.tryParse(lastSeenStr) ?? now;

    if (now.isBefore(lastSeen)) {
      // Clock was rewound — force trial expiry.
      trialStart = now.subtract(const Duration(days: 7));
      await TrialStorageService.instance.write(
          {'trial_start_date': trialStart.toIso8601String()});
    } else {
      // Update last_seen in BOTH locations so neither can be trivially gamed.
      final nowStr = now.toIso8601String();
      await TrialStorageService.instance.write({'last_seen_date': nowStr});
      await database.insert(
        'system_settings',
        {'key': 'last_seen_date', 'value': nowStr},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // ── Step 5: Compute trial window ─────────────────────────────────────────
    final trialEndsAt = trialStart.add(const Duration(days: 7));
    final isTrialActive = now.isBefore(trialEndsAt);
    final trialDaysRemaining = isTrialActive ? trialEndsAt.difference(now).inDays : 0;

    // ── Step 6: Validate license key ────────────────────────
    bool isValid = false;
    DateTime? licenseExpiry;
    bool isLifetime = false;

    if (licenseKey.isNotEmpty) {
      final parts = licenseKey.trim().toUpperCase().split('-');
      if (parts.length == 3) {
        final licShortCode = parts[0];
        final expiryB36 = parts[1];
        final signature = parts[2];
        final expectedShort = deviceCode.replaceFirst('WAK-', '');
        if (licShortCode == expectedShort) {
          final isSignatureValid = await _verifyEd25519(
            data: '$deviceCode|$expiryB36',
            signatureHex: signature.toLowerCase(),
          );
          if (isSignatureValid) {
            final expiryTimestamp = int.tryParse(expiryB36, radix: 36) ?? 0;
            if (expiryTimestamp == 0 || now.millisecondsSinceEpoch <= expiryTimestamp) {
              isValid = true;
              isLifetime = expiryTimestamp == 0;
              if (expiryTimestamp > 0) {
                licenseExpiry = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
              }
            }
          }
        }
      }
    }

    return {
      'device_code': deviceCode,
      'trial_start_date': trialStart.toIso8601String(),
      'trial_ends_at': trialEndsAt.toIso8601String(),
      'is_trial_active': isTrialActive,
      'trial_days_remaining': trialDaysRemaining,
      'is_activated': isValid,
      'license_expiry': licenseExpiry?.toIso8601String(),
      'is_lifetime': isLifetime,
      'license_payload': licenseKey,
    };
  }

  @override
  Future<void> activateLicense(String licenseKey) async {
    final status = await getLicenseStatus();
    final deviceCode = status['device_code'] as String;
    
    final parts = licenseKey.trim().toUpperCase().split('-');
    if (parts.length != 3) throw Exception('License key tidak valid');
    
    final isSignatureValid = await _verifyEd25519(
      data: '$deviceCode|${parts[1]}',
      signatureHex: parts[2].toLowerCase(),
    );
    
    if (!isSignatureValid || parts[0] != deviceCode.replaceFirst('WAK-', '')) {
      throw Exception('License key tidak valid atau salah perangkat');
    }
    
    int expiry = int.tryParse(parts[1], radix: 36) ?? 0;
    if (expiry > 0 && DateTime.now().millisecondsSinceEpoch > expiry) {
      throw Exception('License key sudah expired');
    }

    final database = await db;
    final rows = await database.query('system_settings', where: 'key = ?', whereArgs: ['license_payload']);
    if (rows.isEmpty) {
      await database.insert('system_settings', {'key': 'license_payload', 'value': licenseKey});
    } else {
      await database.update('system_settings', {'value': licenseKey}, where: 'key = ?', whereArgs: ['license_payload']);
    }
  }
}
