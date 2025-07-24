import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  String _errorMessage = '';

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null && _token != null;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = '';

    final result = await AuthService.signUp(
      fullName: fullName,
      email: email,
      password: password,
    );

    if (result['success']) {
      _user = result['user'];
      _token = await AuthService.getToken(); // Get the stored token
      _setLoading(false);
      return true;
    } else {
      _errorMessage = result['message'];
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = '';

    final result = await AuthService.signIn(
      email: email,
      password: password,
    );

    if (result['success']) {
      _user = result['user'];
      _token = await AuthService.getToken(); // Get the stored token
      _setLoading(false);
      return true;
    } else {
      _errorMessage = result['message'];
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _token = null;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      _user = null;
      _token = null;
      notifyListeners();
    } else {
      // If still logged in, try to get the current token
      _token = await AuthService.getToken();
      notifyListeners();
    }
  }

  // Helper method to refresh token if needed
  Future<void> refreshToken() async {
    _token = await AuthService.getToken();
    notifyListeners();
  }

  // Method to clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}