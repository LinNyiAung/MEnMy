import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/account_model.dart';
import 'auth_service.dart';

class AccountService {
  static const String baseUrl = 'http://10.80.21.130:8000';

  static Future<Map<String, dynamic>> createAccount({
    required String name,
    required String accountType,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No authentication token found',
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/accounts/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': name,
          'account_type': accountType,
          'email': email,
          'phone_number': phoneNumber,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'account': Account.fromJson(responseData['account']),
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['detail'] ?? 'Failed to create account',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getAccounts() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No authentication token found',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/accounts/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final List<Account> accounts = (responseData['accounts'] as List)
            .map((accountJson) => Account.fromJson(accountJson))
            .toList();

        return {
          'success': true,
          'accounts': accounts,
          'count': responseData['count'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['detail'] ?? 'Failed to fetch accounts',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }


  static Future<Map<String, dynamic>> updateAccount({
  required String accountId,
  required String name,
  required String accountType,
  String? email,
  String? phoneNumber,
}) async {
  try {
    final token = await AuthService.getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'No authentication token found',
      };
    }

    // Create update body - only include non-null fields
    final Map<String, dynamic> updateData = {
      'name': name,
      'account_type': accountType,
    };
    
    if (email != null && email.isNotEmpty) {
      updateData['email'] = email;
    }
    
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      updateData['phone_number'] = phoneNumber;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/accounts/$accountId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(updateData),
    );

    final responseData = json.decode(response.body);

    if (response.statusCode == 200) {
      return {
        'success': true,
        'account': Account.fromJson(responseData['account']),
        'message': responseData['message'],
      };
    } else {
      return {
        'success': false,
        'message': responseData['detail'] ?? 'Failed to update account',
      };
    }
  } catch (e) {
    return {
      'success': false,
      'message': 'Network error: $e',
    };
  }
}

  static Future<Map<String, dynamic>> deleteAccount(String accountId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No authentication token found',
        };
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/accounts/$accountId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['detail'] ?? 'Failed to delete account',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}