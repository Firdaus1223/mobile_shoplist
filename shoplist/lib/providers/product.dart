// Import paket dart:convert untuk bekerja dengan JSON
import 'dart:convert';

// Import paket Flutter untuk state management
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Kelas `Product` yang mengimplementasikan ChangeNotifier untuk memberi tahu perubahan state
class Product with ChangeNotifier {
  final String id; // ID produk
  final String title; // Judul produk
  final String description; // Deskripsi produk
  final double price; // Harga produk
  final String imageUrl; // URL gambar produk
  bool isFavorite; // Status favorit produk

  // Konstruktor untuk membuat objek Product
  Product({
    @required this.id,
    @required this.title,
    @required this.description,
    @required this.price,
    @required this.imageUrl,
    this.isFavorite = false,
  });

  // Metode privat untuk mengatur nilai isFavorite dan memberi tahu listener
  void _setFavValue(bool newValue) {
    isFavorite = newValue;
    notifyListeners();
  }

  // Metode untuk mengganti status favorit produk dan menyimpan perubahan ke server
  Future<void> toggleFavoriteStatus(String token, String userId) async {
    final oldStatus = isFavorite; // Menyimpan status favorit sebelum perubahan
    isFavorite = !isFavorite; // Mengubah status favorit menjadi kebalikan dari status sebelumnya
    notifyListeners(); // Memberi tahu listener bahwa terjadi perubahan

    // URL untuk menyimpan status favorit pengguna pada produk tertentu ke database
    final url =
        'https://database-flutter-a6c8d-default-rtdb.firebaseio.com/userFavorites/$userId/$id.json?auth=$token';

    try {
      // Mengirim HTTP PUT request untuk menyimpan perubahan status favorit ke server
      final response = await http.put(
        url,
        body: json.encode(
          isFavorite,
        ),
      );

      // Jika status code dari respons server adalah 400 atau lebih, mengembalikan status favorit ke nilai sebelumnya
      if (response.statusCode >= 400) {
        _setFavValue(oldStatus);
      }
    } catch (error) {
      // Jika terjadi error, mengembalikan status favorit ke nilai sebelumnya
      _setFavValue(oldStatus);
    }
  }
}
