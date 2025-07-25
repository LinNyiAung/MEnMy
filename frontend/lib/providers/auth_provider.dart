import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false; // Add this to track initialization
  String _errorMessage = '';

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized; // Getter for initialization state
  String get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null && _token != null;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Add method to initialize auth state on app startup
  Future<void> initializeAuth() async {
    if (_isInitialized) return; // Prevent multiple initializations

    _setLoading(true);

    try {
      final token = await AuthService.getToken();
      if (token != null) {
        // Token exists, verify it's still valid by getting user info
        final result = await AuthService.getCurrentUser();
        if (result['success']) {
          _user = result['user'];
          _token = token;
        } else {
          // Token is invalid, clear it
          await AuthService.logout();
        }
      }
    } catch (e) {
      print('Error initializing auth: $e');
      // If there's an error, clear any stored data
      await AuthService.logout();
    }

    _isInitialized = true;
    _setLoading(false);
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

  // Update checkAuthStatus to be more robust
  Future<void> checkAuthStatus() async {
    final token = await AuthService.getToken();
    if (token == null) {
      _user = null;
      _token = null;
      notifyListeners();
    } else {
      // Verify token is still valid
      final result = await AuthService.getCurrentUser();
      if (result['success']) {
        _user = result['user'];
        _token = token;
      } else {
        // Token is invalid, clear it
        await AuthService.logout();
        _user = null;
        _token = null;
      }
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