import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/transaction.dart';
import '../repositories/app_repository.dart';
import '../repositories/api_repository.dart';
import '../repositories/local_repository.dart';

class DatabaseService implements AppRepository {
  static DatabaseService? _instance;
  static DatabaseService get instance {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  static const String _configuredBaseUrl = String.fromEnvironment('WARUNGKAS_API_BASE_URL', defaultValue: '');
  static const String _defaultLanBaseUrl = String.fromEnvironment('WARUNGKAS_DEFAULT_LAN_API_BASE_URL', defaultValue: 'http://192.168.100.5:8000/api');
  static const String _apiBaseUrlKey = 'api_base_url';

  DatabaseService._internal();

  Database? _settingsDb;
  String? _savedBaseUrl;
  bool _settingsInitialized = false;
  
  bool isMonolithMode = !kIsWeb;

  late final ApiRepository _apiRepo = ApiRepository(this);
  late final LocalRepository _localRepo = LocalRepository();

  AppRepository get _repo => isMonolithMode ? _localRepo : _apiRepo;

  bool get canUseMonolithMode => !kIsWeb;

  Future<void> setMode({required bool monolith}) async {
    if (kIsWeb && monolith) return; // sqflite tidak support web
    isMonolithMode = monolith;
    if (monolith) {
      // Warm up local db
      await _localRepo.db;
    }
  }

  // --- CONFIG / APP SETTINGS ---
  String get activeApiBaseUrl => baseUrl;
  bool get hasCustomApiBaseUrl => (_savedBaseUrl ?? '').isNotEmpty;

  String get defaultApiBaseUrl {
    if (kIsWeb) return 'http://localhost:8000/api';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _normalizeBaseUrl(_defaultLanBaseUrl);
      default:
        return 'http://localhost:8000/api';
    }
  }

  String get apiBaseUrlSourceLabel {
    if (hasCustomApiBaseUrl) return 'Tersimpan di perangkat ini';
    if (_configuredBaseUrl.trim().isNotEmpty) return 'Dari build app';
    return 'Default aplikasi';
  }

  String get baseUrl {
    if ((_savedBaseUrl ?? '').isNotEmpty) return _savedBaseUrl!;
    if (_configuredBaseUrl.isNotEmpty) return _normalizeBaseUrl(_configuredBaseUrl);
    return defaultApiBaseUrl;
  }

  String _normalizeBaseUrl(String rawUrl) {
    var trimmed = rawUrl.trim();
    if (trimmed.isEmpty) throw Exception('Alamat server kosong.');
    var normalized = trimmed.replaceAll(RegExp(r'/+$'), '');
    if (!normalized.toLowerCase().endsWith('/api')) normalized = '$normalized/api';
    return normalized;
  }

  Future<void> initDB() async {
    if (_settingsInitialized) return;
    _settingsInitialized = true;

    if (!kIsWeb) {
      try {
        final dbPath = await getDatabasesPath();
        _settingsDb = await openDatabase(
          p.join(dbPath, 'warungkas_settings.db'),
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              )
            ''');
          },
        );

        final rows = await _settingsDb!.query('app_settings', where: 'key = ?', whereArgs: [_apiBaseUrlKey]);
        if (rows.isNotEmpty) {
          final val = rows.first['value'];
          if (val is String && val.trim().isNotEmpty) _savedBaseUrl = _normalizeBaseUrl(val);
        }

        final modeRows = await _settingsDb!.query('app_settings', where: 'key = ?', whereArgs: ['app_mode']);
        if (modeRows.isNotEmpty && !kIsWeb) {
           isMonolithMode = modeRows.first['value'] == 'monolith';
        }
      } catch (e) {
        debugPrint('Gagal memuat db settings: $e');
      }
    }
  }

  Future<void> toggleMode(bool monolith) async {
    await setMode(monolith: monolith);
    if (!kIsWeb && _settingsDb != null) {
      await _settingsDb!.insert('app_settings', {
        'key': 'app_mode',
        'value': monolith ? 'monolith' : 'server'
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> setApiBaseUrl(String rawUrl) async {
    final normalized = _normalizeBaseUrl(rawUrl);
    _savedBaseUrl = normalized;
    if (kIsWeb) return;
    await initDB();
    if (_settingsDb != null) {
      await _settingsDb!.insert('app_settings', {
        'key': _apiBaseUrlKey,
        'value': normalized,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> clearApiBaseUrl() async {
    _savedBaseUrl = null;
    if (kIsWeb) return;
    await initDB();
    if (_settingsDb != null) {
      await _settingsDb!.delete('app_settings', where: 'key = ?', whereArgs: [_apiBaseUrlKey]);
    }
  }

  Future<void> validateApiBaseUrl(String rawUrl) async {
    final normalized = _normalizeBaseUrl(rawUrl);
    try {
      final res = await http.get(Uri.parse('$normalized/products')).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('Respons tidak valid');
    } catch (_) {
      throw const ApiException('Tidak bisa terhubung ke server. Cek backend dan alamat API.');
    }
  }

  // --- APP REPOSITORY DELEGATES ---

  @override
  Future<Product?> getProductByBarcode(String barcode) => _repo.getProductByBarcode(barcode);

  @override
  Future<List<Product>> getAllProducts() => _repo.getAllProducts();

  @override
  Future<int> insertProduct(Product product) => _repo.insertProduct(product);

  @override
  Future<int> updateProduct(Product product) => _repo.updateProduct(product);

  @override
  Future<int> deleteProduct(int id) => _repo.deleteProduct(id);

  @override
  Future<List<Product>> searchProducts(String query) => _repo.searchProducts(query);

  @override
  Future<void> saveTransaction(TransactionModel tx, List<TransactionItem> items) => _repo.saveTransaction(tx, items);

  @override
  Future<List<TransactionModel>> getTransactions({String? status}) => _repo.getTransactions(status: status);

  @override
  Future<List<TransactionItem>> getTransactionItems(int txId) => _repo.getTransactionItems(txId);

  @override
  Future<void> updateTransactionStatus(int txId, String status) => _repo.updateTransactionStatus(txId, status);

  @override
  Future<void> settleTransaction(int txId, {required double paidAmount, double changeAmount = 0.0}) => _repo.settleTransaction(txId, paidAmount: paidAmount, changeAmount: changeAmount);

  @override
  Future<void> deleteTransaction(int txId) => _repo.deleteTransaction(txId);

  @override
  Future<void> resetDatabase() => _repo.resetDatabase();

  @override
  Future<dynamic> getLicenseStatus() => _repo.getLicenseStatus();

  @override
  Future<void> activateLicense(String licenseKey) => _repo.activateLicense(licenseKey);
}
