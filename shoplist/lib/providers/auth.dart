// Mendefinisikan kelas `Auth` yang merupakan bagian dari manajemen otentikasi
import 'dart:convert'; // Paket untuk mengonversi JSON
import 'dart:async'; // Paket untuk mengelola operasi asynchronous

import 'package:flutter/widgets.dart'; // Paket Flutter untuk pengembangan antarmuka pengguna
import 'package:http/http.dart' as http; // Paket untuk berinteraksi dengan API HTTP
import 'package:shared_preferences/shared_preferences.dart'; // Paket untuk menyimpan data lokal

import '../models/http_exception.dart'; // Import untuk exception kustom

// Kelas `Auth` yang menggunakan ChangeNotifier untuk memberi tahu perubahan pada state
class Auth with ChangeNotifier {
  String _token; // Token otentikasi pengguna
  DateTime _expiryDate; // Tanggal kedaluwarsa token
  String _userId; // ID pengguna
  Timer _authTimer; // Timer untuk otomatis logout

  // Getter untuk mengecek apakah pengguna sudah otentikasi atau belum
  bool get isAuth {
    return token != null;
  }

  // Getter untuk mendapatkan token
  String get token {
    if (_expiryDate != null &&
        _expiryDate.isAfter(DateTime.now()) &&
        _token != null) {
      return _token;
    }
    return null;
  }

  // Getter untuk mendapatkan ID pengguna
  String get userId {
    return _userId;
  }

  // Fungsi untuk melakukan otentikasi, menerima email, password, dan segmen URL sebagai parameter
  Future<void> _authenticate(
      String email, String password, String urlSegment) async {
    // URL endpoint untuk otentikasi menggunakan Firebase Authentication
    final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:$urlSegment?key=YOUR_API_KEY');

    try {
      // Mengirim HTTP POST request dengan informasi otentikasi
      final response = await http.post(
        url,
        body: json.encode(
          {
            'email': email,
            'password': password,
            'returnSecureToken': true,
          },
        ),
      );

      // Mendapatkan data respons dalam format JSON
      final responseData = json.decode(response.body);

      // Mengecek apakah respons mengandung error
      if (responseData['error'] != null) {
        throw HttpException(responseData['error']['message']);
      }

      // Mengatur token, ID pengguna, dan tanggal kedaluwarsa
      _token = responseData['idToken'];
      _userId = responseData['localId'];
      _expiryDate = DateTime.now().add(
        Duration(
          seconds: int.parse(
            responseData['expiresIn'],
          ),
        ),
      );

      // Menjalankan fungsi otomatis logout
      _autoLogout();
      // Memberi tahu listener bahwa terjadi perubahan
      notifyListeners();

      // Menyimpan informasi otentikasi pengguna secara lokal menggunakan shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userData = json.encode(
        {
          'token': _token,
          'userId': _userId,
          'expiryDate': _expiryDate.toIso8601String(),
        },
      );
      prefs.setString('userData', userData);
    } catch (error) {
      throw error;
    }
  }

  // Fungsi untuk mendaftar pengguna baru
  Future<void> signup(String email, String password) async {
    return _authenticate(email, password, 'signUp');
  }

  // Fungsi untuk login
  Future<void> login(String email, String password) async {
    return _authenticate(email, password, 'signInWithPassword');
  }

  // Fungsi untuk mencoba login otomatis
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return false;
    }
    final extractedUserData =
        json.decode(prefs.getString('userData')) as Map<String, Object>;
    final expiryDate = DateTime.parse(extractedUserData['expiryDate']);

    if (expiryDate.isBefore(DateTime.now())) {
      return false;
    }
    _token = extractedUserData['token'];
    _userId = extractedUserData['userId'];
    _expiryDate = expiryDate;
    notifyListeners();
    _autoLogout();
    return true;
  }

  // Fungsi untuk logout
  Future<void> logout() async {
    _token = null;
    _userId = null;
    _expiryDate = null;
    if (_authTimer != null) {
      _authTimer.cancel();
      _authTimer = null;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.clear(); // Menghapus semua data pengguna dari shared preferences
  }

  // Fungsi untuk menjalankan otomatis logout
  void _autoLogout() {
    if (_authTimer != null) {
      _authTimer.cancel();
    }
    final timeToExpiry = _expiryDate.difference(DateTime.now()).inSeconds;
    _authTimer = Timer(Duration(seconds: timeToExpiry), logout);
  }
}
