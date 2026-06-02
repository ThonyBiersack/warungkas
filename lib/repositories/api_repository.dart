import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import 'app_repository.dart';

class ApiRepository implements AppRepository {
  final DatabaseService _service;
  static const Duration _timeout = Duration(seconds: 10);

  ApiRepository(this._service);

  String get _baseUrl => _service.activeApiBaseUrl;

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(_timeout);
    } catch (_) {
      throw const ApiException(
        'Tidak bisa terhubung ke server. Cek backend dan alamat API.',
      );
    }
  }

  dynamic _decodeBody(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      return json.decode(res.body);
    } catch (_) {
      return null;
    }
  }

  void _ensureSuccess(http.Response res, {List<int> successCodes = const [200]}) {
    if (successCodes.contains(res.statusCode)) return;

    final payload = _decodeBody(res);
    final message =
        payload is Map<String, dynamic>
            ? (payload['error'] ?? payload['message'])?.toString()
            : null;

    throw ApiException(
      message ?? 'Request gagal dengan status ${res.statusCode}',
      statusCode: res.statusCode,
    );
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    final res = await _send(
      http.get(Uri.parse('$_baseUrl/products/search?barcode=${Uri.encodeQueryComponent(barcode)}')),
    );
    if (res.statusCode == 404) return null;
    _ensureSuccess(res);
    return Product.fromMap(json.decode(res.body));
  }

  @override
  Future<List<Product>> getAllProducts() async {
    final res = await _send(http.get(Uri.parse('$_baseUrl/products')));
    _ensureSuccess(res);
    final List list = json.decode(res.body);
    return list.map((e) => Product.fromMap(e)).toList();
  }

  @override
  Future<int> insertProduct(Product product) async {
    final res = await _send(
      http.post(
        Uri.parse('$_baseUrl/products'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(product.toMap()),
      ),
    );
    _ensureSuccess(res, successCodes: const [201]);
    final data = json.decode(res.body);
    return data['id'] as int;
  }

  @override
  Future<int> updateProduct(Product product) async {
    final res = await _send(
      http.put(
        Uri.parse('$_baseUrl/products/${product.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(product.toMap()),
      ),
    );
    _ensureSuccess(res);
    return 1;
  }

  @override
  Future<int> deleteProduct(int id) async {
    final res = await _send(http.delete(Uri.parse('$_baseUrl/products/$id')));
    _ensureSuccess(res);
    return 1;
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    final res = await _send(
      http.get(Uri.parse('$_baseUrl/products?q=${Uri.encodeQueryComponent(query)}')),
    );
    _ensureSuccess(res);
    final List list = json.decode(res.body);
    return list.map((e) => Product.fromMap(e)).toList();
  }

  @override
  Future<void> saveTransaction(TransactionModel tx, List<TransactionItem> items) async {
    final Map<String, dynamic> body = tx.toMap();
    body['items'] = items.map((i) => i.toMap()).toList();

    final res = await _send(
      http.post(
        Uri.parse('$_baseUrl/transactions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ),
    );
    _ensureSuccess(res, successCodes: const [201]);
  }

  @override
  Future<List<TransactionModel>> getTransactions({String? status}) async {
    final res = await _send(http.get(Uri.parse('$_baseUrl/transactions')));
    _ensureSuccess(res);
    final List list = json.decode(res.body);
    var results = list.map((e) => TransactionModel.fromMap(e)).toList();
    if (status != null) {
      results = results.where((t) => t.status == status).toList();
    }
    return results;
  }

  @override
  Future<List<TransactionItem>> getTransactionItems(int txId) async {
    final res = await _send(http.get(Uri.parse('$_baseUrl/transactions/$txId/items')));
    _ensureSuccess(res);
    final List list = json.decode(res.body);
    return list.map((e) => TransactionItem.fromMap(e)).toList();
  }

  @override
  Future<void> updateTransactionStatus(int txId, String status) async {
    final res = await _send(
      http.put(
        Uri.parse('$_baseUrl/transactions/$txId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      ),
    );
    _ensureSuccess(res);
  }

  @override
  Future<void> settleTransaction(
    int txId, {
    required double paidAmount,
    double changeAmount = 0.0,
  }) async {
    final res = await _send(
      http.put(
        Uri.parse('$_baseUrl/transactions/$txId/settle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'paid_amount': paidAmount,
          'change_amount': changeAmount,
        }),
      ),
    );
    _ensureSuccess(res);
  }

  @override
  Future<void> deleteTransaction(int txId) async {
    final res = await _send(http.delete(Uri.parse('$_baseUrl/transactions/$txId')));
    _ensureSuccess(res);
  }

  @override
  Future<void> resetDatabase() async {
    final res = await _send(
      http.post(Uri.parse('$_baseUrl/system/reset')),
    );
    _ensureSuccess(res);
  }

  @override
  Future<dynamic> getLicenseStatus() async {
    final res = await _send(http.get(Uri.parse('$_baseUrl/system/license')));
    _ensureSuccess(res);
    return json.decode(res.body);
  }

  @override
  Future<void> activateLicense(String licenseKey) async {
    final res = await _send(
      http.post(
        Uri.parse('$_baseUrl/system/license'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'license_key': licenseKey}),
      ),
    );
    _ensureSuccess(res, successCodes: const [200]);
  }
}
