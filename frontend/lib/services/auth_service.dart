import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = 'https://menmy.onrender.com'; // Change this to your API URL
  
  static Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': fullName,
          'email': email,
          'password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['access_token']);
        
        return {
          'success': true,
          'user': User.fromJson(responseData['user']),
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['detail'] ?? 'Sign up failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['access_token']);
        
        return {
          'success': true,
          'user': User.fromJson(responseData['user']),
        };
      } else {
        return {
          'success': false,
          'message': responseData['detail'] ?? 'Sign in failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}