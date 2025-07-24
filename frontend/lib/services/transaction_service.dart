// services/transaction_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction_model.dart';
import 'auth_service.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class TransactionService {
  static const String baseUrl = 'http://10.80.21.130:8000';

  static Future<void> downloadFileToPath(String url, String path, {String? authToken}) async {
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: authToken != null ? {
        'Authorization': 'Bearer $authToken',
      } : {},
    );

    if (response.statusCode == 200) {
      final file = File(path);
      await file.writeAsBytes(response.bodyBytes);
    } else {
      throw Exception('Failed to download file: HTTP ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to download file: $e');
  }
}

// Also add this helper method for better caching
static Future<String> downloadFileToCache(String filename, {String? authToken}) async {
  try {
    final token = authToken ?? await AuthService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final directory = await getTemporaryDirectory();
    final fileName = filename.split('_').last; // Extract original filename
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);

    // Check if file already exists in cache
    if (await file.exists()) {
      // Check if file is recent (less than 1 hour old)
      final fileStat = await file.stat();
      final now = DateTime.now();
      final fileAge = now.difference(fileStat.modified);
      
      if (fileAge.inHours < 1) {
        return filePath; // Return cached file if it's recent
      }
    }

    // Download the file
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/files/$filename'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } else {
      throw Exception('Failed to download file: HTTP ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to download file to cache: $e');
  }
}

  static Future<Map<String, dynamic>> createTransaction({
    required String type,
    required double amount,
    String? fromAccountId,
    String? toAccountId,
    required String detail,
    List<String>? documentFiles,
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
        documentFiles: documentFiles,
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

  static Future<Map<String, dynamic>> uploadTransactionFiles({
    required List<File> files,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/transactions/upload-files'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      for (File file in files) {
        final mimeType = lookupMimeType(file.path);
        final multipartFile = await http.MultipartFile.fromPath(
          'files',
          file.path,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> filesData = responseData['files'] ?? [];
        final List<String> filePaths = filesData
            .map((fileData) => fileData['stored_filename'] as String)
            .toList();

        return {
          'success': true,
          'file_paths': filePaths,
          'message': responseData['message'] as String? ?? 'Files uploaded successfully',
        };
      } else {
        return {
          'success': false,
          'message': responseData['detail'] as String? ?? 'Failed to upload files',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // UPDATED: Improved download with better permission handling
  static Future<Map<String, dynamic>> downloadTransactionFile({
    required String filename,
    String? customFileName,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      // Get appropriate directory based on platform and Android version
      Directory? targetDirectory;
      String targetPath;

      if (Platform.isAndroid) {
        // For Android 10+ (API 29+), use app-specific external storage
        // This doesn't require WRITE_EXTERNAL_STORAGE permission
        final appDir = await getExternalStorageDirectory();
        if (appDir != null) {
          // Create Downloads folder in app directory
          targetDirectory = Directory('${appDir.path}/Downloads');
          if (!await targetDirectory.exists()) {
            await targetDirectory.create(recursive: true);
          }
        } else {
          // Fallback to app documents directory
          targetDirectory = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        targetDirectory = await getApplicationDocumentsDirectory();
      }

      if (targetDirectory == null) {
        return {'success': false, 'message': 'Could not access storage directory'};
      }

      // Use custom filename or extract original filename
      final originalFilename = customFileName ?? filename.split('_').last;
      targetPath = '${targetDirectory.path}/$originalFilename';

      // Download the file
      final response = await http.get(
        Uri.parse('$baseUrl/transactions/files/$filename'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Write file to app-specific directory
        final file = File(targetPath);
        await file.writeAsBytes(response.bodyBytes);

        return {
          'success': true,
          'message': 'File downloaded successfully',
          'file_path': targetPath,
          'filename': originalFilename,
          'directory_type': Platform.isAndroid ? 'app_external' : 'app_documents',
        };
      } else {
        final responseData = json.decode(response.body);
        return {
          'success': false,
          'message': responseData['detail'] as String? ?? 'Failed to download file',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Download error: $e'};
    }
  }

  // NEW: Alternative download method for public Downloads folder (requires permission)
  static Future<Map<String, dynamic>> downloadToPublicDownloads({
    required String filename,
    String? customFileName,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      // Request storage permission for public downloads
      PermissionStatus permission;
      
      if (Platform.isAndroid) {
        // Check Android version
        if (await _getAndroidSdkVersion() >= 30) {
          // Android 11+ (API 30+) - use MANAGE_EXTERNAL_STORAGE
          permission = await Permission.manageExternalStorage.request();
        } else {
          // Android 10 and below - use WRITE_EXTERNAL_STORAGE
          permission = await Permission.storage.request();
        }
        
        if (!permission.isGranted) {
          return {
            'success': false, 
            'message': 'Storage permission is required to download to public Downloads folder. You can still download to app folder.',
            'permission_denied': true,
          };
        }
      }

      // Download the file
      final response = await http.get(
        Uri.parse('$baseUrl/transactions/files/$filename'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        Directory? downloadsDirectory;
        
        if (Platform.isAndroid) {
          // Try to access public Downloads directory
          downloadsDirectory = Directory('/storage/emulated/0/Download');
          if (!downloadsDirectory.existsSync()) {
            // Fallback to external storage
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              downloadsDirectory = Directory('${externalDir.path}/Download');
              if (!await downloadsDirectory.exists()) {
                await downloadsDirectory.create(recursive: true);
              }
            }
          }
        } else if (Platform.isIOS) {
          downloadsDirectory = await getApplicationDocumentsDirectory();
        }

        if (downloadsDirectory == null) {
          return {'success': false, 'message': 'Could not access Downloads directory'};
        }

        final originalFilename = customFileName ?? filename.split('_').last;
        final filePath = '${downloadsDirectory.path}/$originalFilename';

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        return {
          'success': true,
          'message': 'File downloaded to Downloads folder',
          'file_path': filePath,
          'filename': originalFilename,
          'directory_type': 'public_downloads',
        };
      } else {
        final responseData = json.decode(response.body);
        return {
          'success': false,
          'message': responseData['detail'] as String? ?? 'Failed to download file',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Download error: $e'};
    }
  }

  // Helper method to get Android SDK version
  static Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;
    
    try {
      final process = await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(process.stdout.toString().trim()) ?? 0;
    } catch (e) {
      return 0; // Default to 0 if we can't determine
    }
  }

  static Future<Map<String, dynamic>> getFileInfo({
    required String filename,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final response = await http.head(
        Uri.parse('$baseUrl/transactions/files/$filename'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final originalFilename = filename.split('_').last;
        final contentLength = response.headers['content-length'];
        final contentType = response.headers['content-type'];
        
        return {
          'success': true,
          'filename': originalFilename,
          'stored_filename': filename,
          'content_type': contentType,
          'content_length': contentLength,
          'size_kb': contentLength != null ? (int.parse(contentLength) / 1024).toStringAsFixed(1) : 'Unknown',
        };
      } else {
        return {'success': false, 'message': 'File not found'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error getting file info: $e'};
    }
  }

  static String getFileUrl(String filename) {
    return '$baseUrl/transactions/files/$filename';
  }

  // ... rest of your existing methods remain the same ...
  
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

        final List<dynamic> transactionsData = responseData['transactions'] ?? [];
        final List<Transaction> createdTransactions = transactionsData
            .map((transactionJson) {
          if (transactionJson is Map<String, dynamic>) {
            return Transaction.fromJson(transactionJson);
          } else {
            print('Warning: Received non-map item in transactions list: $transactionJson');
            return null;
          }
        })
            .whereType<Transaction>()
            .toList();

        return {
          'success': true,
          'transactions': createdTransactions,
          'message': responseData['message'] as String? ?? 'Multiple transactions created',
        };
      } else {
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

  static Future<Map<String, dynamic>> updateTransaction({
    required String transactionId,
    required String type,
    required double amount,
    String? fromAccountId,
    String? toAccountId,
    required String detail,
    List<String>? documentFiles,
    DateTime? transactionDate,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token found'};
      }

      final updateRequest = UpdateTransactionRequest(
        type: type,
        amount: amount,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        detail: detail,
        documentFiles: documentFiles,
        transactionDate: transactionDate,
      );

      final response = await http.put(
        Uri.parse('$baseUrl/transactions/$transactionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updateRequest.toJson()),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'transaction': Transaction.fromJson(responseData['transaction']),
          'message': responseData['message'] as String? ?? 'Transaction updated',
        };
      } else {
        return {
          'success': false,
          'message': responseData['detail'] as String? ?? 'Failed to update transaction',
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