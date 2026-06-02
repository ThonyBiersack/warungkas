import '../models/product.dart';
import '../models/transaction.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

abstract class AppRepository {
  Future<Product?> getProductByBarcode(String barcode);
  Future<List<Product>> getAllProducts();
  Future<int> insertProduct(Product product);
  Future<int> updateProduct(Product product);
  Future<int> deleteProduct(int id);
  Future<List<Product>> searchProducts(String query);

  Future<void> saveTransaction(TransactionModel tx, List<TransactionItem> items);
  Future<List<TransactionModel>> getTransactions({String? status});
  Future<List<TransactionItem>> getTransactionItems(int txId);
  Future<void> updateTransactionStatus(int txId, String status);
  Future<void> settleTransaction(int txId, {required double paidAmount, double changeAmount = 0.0});
  Future<void> deleteTransaction(int txId);
  Future<void> resetDatabase();

  Future<dynamic> getLicenseStatus();
  Future<void> activateLicense(String licenseKey);
}
