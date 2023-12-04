// Import paket dart:convert untuk bekerja dengan JSON
import 'dart:convert';

// Import paket Flutter untuk widget dan HTTP requests
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Import kelas exception custom
import '../models/http_exception.dart';

// Import model produk
import './product.dart';

// Kelas `Products` yang mengimplementasikan ChangeNotifier untuk state management
class Products with ChangeNotifier {
  List<Product> _items = []; // Daftar produk
  final String authToken; // Token otentikasi
  final String userId; // ID pengguna

  // Konstruktor untuk membuat objek Products dengan token otentikasi dan ID pengguna
  Products(this.authToken, this.userId, this._items);

  List<Product> get items {
    return [..._items]; // Mengembalikan salinan daftar produk
  }

  // Getter untuk mendapatkan daftar produk favorit
  List<Product> get favoriteItems {
    return _items.where((prodItem) => prodItem.isFavorite).toList();
  }

  // Metode untuk mencari produk berdasarkan ID
  Product findById(String id) {
    return _items.firstWhere((prod) => prod.id == id);
  }

  // Metode untuk mengambil dan mengatur produk dari database
  Future<void> fetchAndSetProducts([bool filterByUser = false]) async {
    final filterString =
        filterByUser ? 'orderBy="creatorId"&equalTo="$userId"' : '';
    var url =
        'https://database-flutter-a6c8d-default-rtdb.firebaseio.com/products.json?auth=$authToken&$filterString';
    try {
      // Mengirim HTTP GET request untuk mendapatkan produk dari server
      final response = await http.get(url);
      final extractedData = json.decode(response.body) as Map<String, dynamic>;

      // Jika data yang diekstrak dari server null, kembalikan
      if (extractedData == null) {
        return;
      }

      // URL untuk mendapatkan produk favorit pengguna dari server
      url =
          'https://database-flutter-a6c8d-default-rtdb.firebaseio.com/userFavorites/$userId.json?auth=$authToken';

      // Mengirim HTTP GET request untuk mendapatkan produk favorit pengguna dari server
      final favoriteResponse = await http.get(url);
      final favoriteData = json.decode(favoriteResponse.body);
      final List<Product> loadedProducts = [];

      // Iterasi melalui data yang diekstrak dan membuat objek produk
      extractedData.forEach((prodId, prodData) {
        loadedProducts.add(Product(
          id: prodId,
          title: prodData['title'],
          description: prodData['description'],
          price: prodData['price'],
          isFavorite:
              favoriteData == null ? false : favoriteData[prodId] ?? false,
          imageUrl: prodData['imageUrl'],
        ));
      });

      // Mengatur daftar produk dengan produk yang diambil dari server
      _items = loadedProducts;
      notifyListeners();
    } catch (error) {
      throw (error);
    }
  }

  // Metode untuk menambahkan produk baru ke database
  Future<void> addProduct(Product product) async {
    final url =
        'https://database-flutter-a6c8d-default-rtdb.firebaseio.com/products.json?auth=$authToken';
    try {
      // Mengirim HTTP POST request untuk menambahkan produk baru ke server
      final response = await http.post(
        url,
        body: json.encode({
          'title': product.title,
          'description': product.description,
          'imageUrl': product.imageUrl,
          'price': product.price,
          'creatorId': userId,
        }),
      );

      // Membuat objek produk baru dari respons server
      final newProduct = Product(
        title: product.title,
        description: product.description,
        price: product.price,
        imageUrl: product.imageUrl,
        id: json.decode(response.body)['name'],
      );

      // Menambahkan produk baru ke daftar produk
      _items.add(newProduct);
      notifyListeners();
    } catch (error) {
      print(error);
      throw error;
    }
  }

  // Metode untuk memperbarui produk yang ada di database
  Future<void> updateProduct(String id, Product newProduct) async {
    // Menemukan indeks produk yang akan diperbarui
    final prodIndex = _items.indexWhere((prod) => prod.id == id);
    if (prodIndex >= 0) {
      // URL untuk memperbarui produk di server
      final url =
          'https://database-flutter-a6c8d-default-rtdb.firebaseio.com/products/$id.json?auth=$authToken';

      // Mengirim HTTP PATCH request untuk memperbarui produk di server
      await http.patch(url,
          body: json.encode({
            'title': newProduct.title,
            'description': newProduct.description,
            'imageUrl': newProduct.imageUrl,
            'price': newProduct.price
          }));

      // Mengganti produk yang lama dengan produk yang baru
      _items[prodIndex] = newProduct;
      notifyListeners();
    } else {
      print('...');
    }
  }

  // Metode untuk menghapus produk dari database
  Future<void> deleteProduct(String id) async {
    // URL untuk menghapus produk dari server
    final url =
        'https://database-flutter-a6c8d-default-rtdb.firebaseio.com/products/$id.json?auth=$authToken';

    // Menemukan indeks produk yang akan dihapus
    final existingProductIndex = _items.indexWhere((prod) => prod.id == id);
    var existingProduct = _items[existingProductIndex];

    // Menghapus produk dari daftar produk dan memberi tahu listener
    _items.removeAt(existingProductIndex);
    notifyListeners();

    // Mengirim HTTP DELETE request untuk menghapus produk dari server
    final response = await http.delete(url);

    // Jika status code dari respons server adalah 400 atau lebih, mengembalikan produk ke daftar produk
    if (response.statusCode >= 400) {
      _items.insert(existingProductIndex, existingProduct);
      notifyListeners();
      throw HttpException('Could not delete product.');
    }

    // Menghapus referensi ke produk yang dihapus
    existingProduct = null;
  }
}
