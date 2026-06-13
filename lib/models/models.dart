class Product {
  String id; String name; double price; double costPrice; int quantity; String barcode;
  Product({required this.id, required this.name, required this.price, required this.costPrice, required this.quantity, this.barcode = ''});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'costPrice': costPrice, 'quantity': quantity, 'barcode': barcode};
  factory Product.fromJson(Map<String, dynamic> j) => Product(id: j['id'], name: j['name'], price: (j['price'] as num).toDouble(), costPrice: (j['costPrice'] as num).toDouble(), quantity: j['quantity'] as int, barcode: j['barcode'] ?? '');
}
class CartItem {
  Product product; int qty;
  CartItem({required this.product, this.qty = 1});
  double get total => product.price * qty;
}
class SaleRecord {
  String id; DateTime dateTime; List<CartItem> items; double totalAmount;
  SaleRecord({required this.id, required this.dateTime, required this.items, required this.totalAmount});
  Map<String, dynamic> toJson() => {'id': id, 'dateTime': dateTime.toIso8601String(), 'totalAmount': totalAmount, 'items': items.map((c) => {'productId': c.product.id, 'productName': c.product.name, 'price': c.product.price, 'qty': c.qty}).toList()};
}
class DebtRecord {
  String id; String clientName; String phone; double amount; DateTime createdAt; bool isPaid;
  DebtRecord({required this.id, required this.clientName, required this.phone, required this.amount, required this.createdAt, this.isPaid = false});
  Map<String, dynamic> toJson() => {'id': id, 'clientName': clientName, 'phone': phone, 'amount': amount, 'createdAt': createdAt.toIso8601String(), 'isPaid': isPaid};
  factory DebtRecord.fromJson(Map<String, dynamic> j) => DebtRecord(id: j['id'], clientName: j['clientName'], phone: j['phone'] ?? '', amount: (j['amount'] as num).toDouble(), createdAt: DateTime.parse(j['createdAt']), isPaid: j['isPaid'] ?? false);
}
