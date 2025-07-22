// services/transaction_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import 'auth_service.dart';

class TransactionService {
  static const String baseUrl = 'http://10.80.21.130:8000'; // Ensure this is correct

  static Future<Map<String, dynamic>> createTransaction({
    required String type,
    required double amount,
    String? fromAccountId,
    String? toAccountId,
    required String detail,
    String? documentRecord,
    DateTime? transactionDate,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final transaction = CreateTransactionRequest(
        type: type,
        amount: amount,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        detail: detail,
        documentRecord: documentRecord,
        transactionDate: transactionDate,
      );

      final response = await http.post(
        Uri.parse('$baseUrl/transactions/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(transaction.toJson()),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'transaction': Transaction.fromJson(responseData['transaction']),
          'message': responseData['message'] as String? ?? 'Transaction created',
        };
      } else {
        return {
          'success': false,
          'message': responseData['detail'] as String? ?? 'Failed to create transaction',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createMultipleTransactions({
    required List<CreateTransactionRequest> transactions,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final request = CreateMultipleTransactionsRequest(transactions: transactions);

      final response = await http.post(
        Uri.parse('$baseUrl/transactions/multiple'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Safely parse the list of transactions
        final List<dynamic> transactionsData = responseData['transactions'] ?? [];
        final List<Transaction> createdTransactions = transactionsData
            .map((transactionJson) {
          if (transactionJson is Map<String, dynamic>) {
            return Transaction.fromJson(transactionJson);
          } else {
            print('Warning: Received non-map item in transactions list: $transactionJson');
            return null; // Indicate an issue with this item
          }
        })
            .whereType<Transaction>() // Filter out any nulls
            .toList();

        return {
          'success': true,
          'transactions': createdTransactions,
          'message': responseData['message'] as String? ?? 'Multiple transactions created',
        };
      } else {
        // Safely access 'detail' and provide a fallback message
        final responseData = json.decode(response.body);
        return {
          'success': false,
          'message': responseData['detail'] as String? ?? 'Failed to create transactions',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getTransactions({
    int? limit,
    int? offset,
    String? accountId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      String url = '$baseUrl/transactions/';
      List<String> queryParams = [];

      if (limit != null) queryParams.add('limit=$limit');
      if (offset != null) queryParams.add('offset=$offset');
      if (accountId != null) queryParams.add('account_id=$accountId');

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> transactionsData = responseData['transactions'] ?? [];
        final List<Transaction> transactions = transactionsData
            .map((transactionJson) {
          if (transactionJson is Map<String, dynamic>) {
            return Transaction.fromJson(transactionJson);
          } else {
            print('Warning: Received non-map item in transactions list for getTransactions: $transactionJson');
            return null;
          }
        })
            .whereType<Transaction>()
            .toList();

        return {
          'success': true,
          'transactions': transactions,
          'count': responseData['count'] as int? ?? 0,
          'total': responseData['total'] as int? ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': responseData['detail'] as String? ?? 'Failed to fetch transactions',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteTransaction(String transactionId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/transactions/$transactionId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] as String? ?? 'Transaction deleted',
        };
      } else {
        return {
          'success': false,
          'message': responseData['detail'] as String? ?? 'Failed to delete transaction',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}