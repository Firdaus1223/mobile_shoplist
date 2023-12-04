import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import './cart.dart';

class OrderItem {
  final String id;
  final double amount;
  final List<CartItem> products;
  final DateTime dateTime;

  OrderItem({
    @required this.id,
    @required this.amount,
    @required this.products,
    @required this.dateTime,
  });
}

class Orders with ChangeNotifier {
  List<OrderItem> _orders = [];
  final String authToken;
  final String userId;

  Orders(this.authToken, this.userId, this._orders);

  List<OrderItem> get orders {
    return [..._orders];
  }

Future<void> fetchAndSetOrders() async {
  // Mendefinisikan URL untuk mengambil pesanan dari server Firebase Realtime Database
  final url = 'https://database-flutter-a6c8d-default-rtdb.firebaseio.com/orders/$userId.json?auth=$authToken';
  
  // Mengirim HTTP GET request ke URL untuk mendapatkan data pesanan
  final response = await http.get(url);

  // Membuat list untuk menyimpan pesanan yang telah diambil dari server
  final List<OrderItem> loadedOrders = [];

  // Menguraikan respons JSON untuk mendapatkan data pesanan
  final extractedData = json.decode(response.body) as Map<String, dynamic>;

  // Memeriksa apakah tidak ada data pesanan yang ditemukan
  if (extractedData == null) {
    return;
  }

  // Iterasi melalui data pesanan yang diuraikan
  extractedData.forEach((orderId, orderData) {
    // Membuat instance OrderItem dari data pesanan dan menambahkannya ke list loadedOrders
    loadedOrders.add(
      OrderItem(
        id: orderId,
        amount: orderData['amount'],
        dateTime: DateTime.parse(orderData['dateTime']),
        products: (orderData['products'] as List<dynamic>)
            .map(
              (item) => CartItem(
                id: item['id'],
                price: item['price'],
                quantity: item['quantity'],
                title: item['title'],
              ),
            )
            .toList(),
      ),
    );
  });

  // Mengatur _orders dengan list pesanan yang telah diurutkan dari yang terbaru
  _orders = loadedOrders.reversed.toList();

  // Memberi tahu listener bahwa terjadi perubahan
  notifyListeners();
}

Future<void> addOrder(List<CartItem> cartProducts, double total) async {
  // Mendefinisikan URL untuk menambahkan pesanan baru ke server Firebase Realtime Database
  final url = 'https://database-flutter-a6c8d-default-rtdb.firebaseio.com/orders/$userId.json?auth=$authToken';

  // Mendapatkan timestamp (waktu dan tanggal pesanan)
  final timestamp = DateTime.now();

  // Mengirim HTTP POST request ke URL untuk menambahkan pesanan baru
  final response = await http.post(
    url,
    body: json.encode({
      'amount': total,
      'dateTime': timestamp.toIso8601String(),
      'products': cartProducts
          .map((cp) => {
                'id': cp.id,
                'title': cp.title,
                'quantity': cp.quantity,
                'price': cp.price,
              })
          .toList(),
    }),
  );

  // Menambahkan pesanan baru ke _orders dengan membuat instance OrderItem
  _orders.insert(
    0,
    OrderItem(
      id: json.decode(response.body)['name'],
      amount: total,
      dateTime: timestamp,
      products: cartProducts,
    ),
  );

  // Memberi tahu listener bahwa terjadi perubahan
  notifyListeners();
}
}
