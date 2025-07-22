import 'package:flutter/foundation.dart';
import '../models/account_model.dart';
import '../services/account_service.dart';

class AccountProvider with ChangeNotifier {
  List<Account> _accounts = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<bool> createAccount({
    required String name,
    required String accountType,
    String? email,
    String? phoneNumber,
  }) async {
    _setLoading(true);
    _errorMessage = '';

    final result = await AccountService.createAccount(
      name: name,
      accountType: accountType,
      email: email,
      phoneNumber: phoneNumber,
    );

    if (result['success']) {
      await loadAccounts(); // Reload accounts after creation
      _setLoading(false);
      return true;
    } else {
      _errorMessage = result['message'];
      _setLoading(false);
      return false;
    }
  }

  Future<void> loadAccounts() async {
    _setLoading(true);
    _errorMessage = '';

    final result = await AccountService.getAccounts();

    if (result['success']) {
      _accounts = result['accounts'];
    } else {
      _errorMessage = result['message'];
      _accounts = [];
    }

    _setLoading(false);
  }


  Future<bool> updateAccount({
  required String accountId,
  required String name,
  required String accountType,
  String? email,
  String? phoneNumber,
}) async {
  _setLoading(true);
  _errorMessage = '';

  final result = await AccountService.updateAccount(
    accountId: accountId,
    name: name,
    accountType: accountType,
    email: email,
    phoneNumber: phoneNumber,
  );

  if (result['success']) {
    // Update the account in the local list
    final updatedAccount = result['account'] as Account;
    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index != -1) {
      _accounts[index] = updatedAccount;
      notifyListeners();
    }
    _setLoading(false);
    return true;
  } else {
    _errorMessage = result['message'];
    _setLoading(false);
    return false;
  }
}

  Future<bool> deleteAccount(String accountId) async {
    _setLoading(true);
    _errorMessage = '';

    final result = await AccountService.deleteAccount(accountId);

    if (result['success']) {
      _accounts.removeWhere((account) => account.id == accountId);
      _setLoading(false);
      return true;
    } else {
      _errorMessage = result['message'];
      _setLoading(false);
      return false;
    }
  }
}