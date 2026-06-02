class Product {
  final int? id;
  final String name;
  final String barcode;
  final double price;
  final double costPrice;
  final int stock;
  final String? category;
  final DateTime? createdAt;
  final bool isEceran;
  final double eceranPrice;
  final int isiPerBungkus;
  final int sisaBatang;
  final int minStock;

  const Product({
    this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.costPrice = 0.0,
    this.stock = 0,
    this.category,
    this.createdAt,
    this.isEceran = false,
    this.eceranPrice = 0.0,
    this.isiPerBungkus = 0,
    this.sisaBatang = 0,
    this.minStock = 2,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'cost_price': costPrice,
      'stock': stock,
      'category': category ?? '',
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'is_eceran': isEceran ? 1 : 0,
      'eceran_price': eceranPrice,
      'isi_per_bungkus': isiPerBungkus,
      'sisa_batang': sisaBatang,
      'min_stock': minStock,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] != null ? map['id'] as int : null,
      name: map['name'] as String? ?? 'Tanpa Nama',
      barcode: map['barcode'] as String? ?? '',
      price: map['price'] != null ? (map['price'] as num).toDouble() : 0.0,
      costPrice: map['cost_price'] != null ? (map['cost_price'] as num).toDouble() : 0.0,
      stock: map['stock'] != null ? (map['stock'] as num).toInt() : 0,
      category: map['category'] != null ? map['category'] as String : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
      isEceran: map['is_eceran'] == 1 || map['is_eceran'] == true,
      eceranPrice: map['eceran_price'] != null ? (map['eceran_price'] as num).toDouble() : 0.0,
      isiPerBungkus: map['isi_per_bungkus'] != null ? (map['isi_per_bungkus'] as num).toInt() : 0,
      sisaBatang: map['sisa_batang'] != null ? (map['sisa_batang'] as num).toInt() : 0,
      minStock: map['min_stock'] != null ? (map['min_stock'] as num).toInt() : 2,
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    double? price,
    double? costPrice,
    int? stock,
    String? category,
    DateTime? createdAt,
    bool? isEceran,
    double? eceranPrice,
    int? isiPerBungkus,
    int? sisaBatang,
    int? minStock,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isEceran: isEceran ?? this.isEceran,
      eceranPrice: eceranPrice ?? this.eceranPrice,
      isiPerBungkus: isiPerBungkus ?? this.isiPerBungkus,
      sisaBatang: sisaBatang ?? this.sisaBatang,
      minStock: minStock ?? this.minStock,
    );
  }
}
