import 'dart:convert';

class Installment {
  final double amount;
  final DateTime date;

  const Installment({required this.amount, required this.date});

  factory Installment.fromMap(Map<String, dynamic> map) {
    return Installment(
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String).toLocal(),
    );
  }
}

class TransactionModel {
  final int? id;
  final double totalAmount;
  final String status;
  final String? customerName;
  final DateTime? createdAt;
  final List<TransactionItem>? items;
  final double paidAmount;
  final double changeAmount;
  final String paymentMethod;
  final DateTime? settledAt;
  final DateTime? cancelledAt;
  final List<Installment> installments;

  const TransactionModel({
    this.id,
    required this.totalAmount,
    required this.status,
    this.customerName,
    this.createdAt,
    this.items,
    this.paidAmount = 0.0,
    this.changeAmount = 0.0,
    this.paymentMethod = 'lunas',
    this.settledAt,
    this.cancelledAt,
    this.installments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'total_amount': totalAmount,
      'status': status,
      'customer_name': customerName,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'paid_amount': paidAmount,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'settled_at': settledAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    List<Installment> parsedInstallments = [];
    if (map['installments'] != null) {
      try {
        final List decoded = json.decode(map['installments'] as String);
        parsedInstallments = decoded.map((e) => Installment.fromMap(e)).toList();
      } catch (_) {}
    }

    return TransactionModel(
      id: map['id'] as int?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      status: map['status'] as String,
      customerName: map['customer_name'] as String?,
      // Bug Fix #6: Gunakan .toLocal() agar laporan "Hari Ini" tidak salah karena UTC vs lokal
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String)?.toLocal() : null,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      changeAmount: (map['change_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] as String? ?? (map['status'] as String? ?? 'lunas'),
      settledAt: map['settled_at'] != null ? DateTime.tryParse(map['settled_at'] as String)?.toLocal() : null,
      cancelledAt: map['cancelled_at'] != null ? DateTime.tryParse(map['cancelled_at'] as String)?.toLocal() : null,
      installments: parsedInstallments,
    );
  }

  TransactionModel copyWith({
    int? id,
    double? totalAmount,
    String? status,
    String? customerName,
    DateTime? createdAt,
    List<TransactionItem>? items,
    double? paidAmount,
    double? changeAmount,
    String? paymentMethod,
    DateTime? settledAt,
    DateTime? cancelledAt,
    List<Installment>? installments,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      paidAmount: paidAmount ?? this.paidAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      settledAt: settledAt ?? this.settledAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      installments: installments ?? this.installments,
    );
  }
}

class TransactionItem {
  final int? id;
  final int? transactionId;
  final int productId;
  final String productName; // denormalization untuk gampang nampilin
  final int quantity;
  final double price;
  final double costPrice;
  final bool isEceranMode;

  const TransactionItem({
    this.id,
    this.transactionId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.costPrice = 0.0,
    this.isEceranMode = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'cost_price': costPrice,
      'is_eceran_mode': isEceranMode ? 1 : 0,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      price: (map['price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      isEceranMode: map['is_eceran_mode'] == 1 || map['is_eceran_mode'] == true,
    );
  }
}
