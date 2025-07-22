import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String _errorMessage = '';
  int _totalCount = 0;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get totalCount => _totalCount;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<bool> createTransaction({
    required String type,
    required double amount,
    String? fromAccountId,
    String? toAccountId,
    required String detail,
    String? documentRecord,
    DateTime? transactionDate,
  }) async {
    _setLoading(true);
    _errorMessage = '';

    final result = await TransactionService.createTransaction(
      type: type,
      amount: amount,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      detail: detail,
      documentRecord: documentRecord,
      transactionDate: transactionDate,
    );

    if (result['success']) {
      await loadTransactions(); // Reload transactions after creation
      _setLoading(false);
      return true;
    } else {
      _errorMessage = result['message'];
      _setLoading(false);
      return false;
    }
  }

  Future<bool> createMultipleTransactions({
    required List<CreateTransactionRequest> transactions,
  }) async {
    _setLoading(true);
    _errorMessage = '';

    final result = await TransactionService.createMultipleTransactions(
      transactions: transactions,
    );

    if (result['success']) {
      await loadTransactions(); // Reload transactions after creation
      _setLoading(false);
      return true;
    } else {
      _errorMessage = result['message'];
      _setLoading(false);
      return false;
    }
  }

  Future<void> loadTransactions({
    int? limit,
    int? offset,
    String? accountId,
  }) async {
    _setLoading(true);
    _errorMessage = '';

    final result = await TransactionService.getTransactions(
      limit: limit,
      offset: offset,
      accountId: accountId,
    );

    if (result['success']) {
      _transactions = result['transactions'];
      _totalCount = result['total'] ?? result['count'];
    } else {
      _errorMessage = result['message'];
      _transactions = [];
      _totalCount = 0;
    }

    _setLoading(false);
  }

  Future<bool> deleteTransaction(String transactionId) async {
    _setLoading(true);
    _errorMessage = '';

    final result = await TransactionService.deleteTransaction(transactionId);

    if (result['success']) {
      _transactions.removeWhere((transaction) => transaction.id == transactionId);
      _totalCount = _totalCount > 0 ? _totalCount - 1 : 0;
      _setLoading(false);
      return true;
    } else {
      _errorMessage = result['message'];
      _setLoading(false);
      return false;
    }
  }

  // Helper methods
  List<Transaction> getTransactionsByAccount(String accountId) {
    return _transactions.where((transaction) =>
        transaction.fromAccountId == accountId ||
        transaction.toAccountId == accountId).toList();
  }

  double getTotalInflowByAccount(String accountId) {
    return _transactions
        .where((transaction) =>
            transaction.type == TransactionTypes.inflow &&
            transaction.toAccountId == accountId)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double getTotalOutflowByAccount(String accountId) {
    return _transactions
        .where((transaction) =>
            transaction.type == TransactionTypes.outflow &&
            transaction.fromAccountId == accountId)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double getAccountBalance(String accountId) {
    final inflow = getTotalInflowByAccount(accountId);
    final outflow = getTotalOutflowByAccount(accountId);
    return inflow - outflow;
  }
}