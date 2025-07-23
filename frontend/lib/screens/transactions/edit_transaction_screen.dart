// screens/transactions/edit_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/account_model.dart';
import 'package:intl/intl.dart'; // For date formatting

class EditTransactionScreen extends StatefulWidget {
  final Transaction transaction;

  const EditTransactionScreen({Key? key, required this.transaction}) : super(key: key);

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _detailController;
  late TextEditingController _documentController;
  late String _selectedType;
  String? _selectedFromAccountId;
  String? _selectedToAccountId;
  late DateTime _selectedTransactionDate;

  @override
  void initState() {
    super.initState();
    // Initialize controllers and values with existing transaction data
    _amountController = TextEditingController(text: widget.transaction.amount.toString());
    _detailController = TextEditingController(text: widget.transaction.detail);
    _documentController = TextEditingController(text: widget.transaction.documentRecord ?? '');
    _selectedType = widget.transaction.type;
    _selectedFromAccountId = widget.transaction.fromAccountId;
    _selectedToAccountId = widget.transaction.toAccountId;
    _selectedTransactionDate = widget.transaction.transactionDate;

    // Load accounts if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accountProvider = Provider.of<AccountProvider>(context, listen: false);
      if (accountProvider.accounts.isEmpty) {
        accountProvider.loadAccounts();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _detailController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);

      // Re-validate account selection based on type
      if (_selectedType == TransactionTypes.outflow && _selectedFromAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a "From" account for outflow.'), backgroundColor: Colors.red),
        );
        return;
      }
      if (_selectedType == TransactionTypes.inflow && _selectedToAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a "To" account for inflow.'), backgroundColor: Colors.red),
        );
        return;
      }

      final success = await transactionProvider.updateTransaction(
        transactionId: widget.transaction.id,
        type: _selectedType,
        amount: double.parse(_amountController.text),
        fromAccountId: _selectedFromAccountId,
        toAccountId: _selectedToAccountId,
        detail: _detailController.text.trim(),
        documentRecord: _documentController.text.trim().isEmpty ? null : _documentController.text.trim(),
        transactionDate: _selectedTransactionDate,
      );

      if (success) {
        Navigator.of(context).pop(true); // Return true to indicate success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(transactionProvider.errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = Provider.of<AccountProvider>(context).accounts;
    final transactionProvider = Provider.of<TransactionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Transaction'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveTransaction,
            child: Text(
              'Save',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column( // Changed from ListView to Column to place button row at bottom
          children: [
            Expanded( // Use Expanded for the scrollable content
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Transaction Form Fields (same as before) ---
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Inflow'),
                          value: TransactionTypes.inflow,
                          groupValue: _selectedType,
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value!;
                              _selectedFromAccountId = null;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Outflow'),
                          value: TransactionTypes.outflow,
                          groupValue: _selectedType,
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value!;
                              _selectedToAccountId = null;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money), hintText: '0.00'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter an amount';
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) return 'Please enter a valid amount greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildAccountDropdown(
                    labelText: 'From Account ${(_selectedType == TransactionTypes.outflow || _selectedType == TransactionTypes.inflow) ? '*' : ''}',
                    value: _selectedFromAccountId,
                    items: accounts,
                    onChanged: (value) {
                      setState(() => _selectedFromAccountId = value);
                    },
                    validator: (value) {
                      if (_selectedType == TransactionTypes.outflow && (value == null || value.isEmpty)) {
                        return 'Please select a "From" account for outflow';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildAccountDropdown(
                    labelText: 'To Account ${(_selectedType == TransactionTypes.inflow || _selectedType == TransactionTypes.outflow) ? '*' : ''}',
                    value: _selectedToAccountId,
                    items: accounts,
                    onChanged: (value) {
                      setState(() => _selectedToAccountId = value);
                    },
                    validator: (value) {
                      if (_selectedType == TransactionTypes.inflow && (value == null || value.isEmpty)) {
                        return 'Please select a "To" account for inflow';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _detailController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Detail *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description), hintText: 'Transaction description...'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Please enter transaction details';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _documentController,
                    decoration: const InputDecoration(labelText: 'Document Record (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attachment), hintText: 'Reference number, receipt ID, etc.'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Transaction Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          controller: TextEditingController(
                            text: DateFormat('dd/MM/yyyy').format(_selectedTransactionDate),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedTransactionDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null && picked != _selectedTransactionDate) {
                            setState(() => _selectedTransactionDate = picked);
                          }
                        },
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text('Change'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                  // Add some padding at the bottom to ensure the last field is visible
                  const SizedBox(height: 100),
                ],
              ),
            ),

            // --- Bottom Action Buttons ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: transactionProvider.isLoading ? null : _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: transactionProvider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Update Transaction', // Renamed button text
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDropdown({
    required String labelText,
    required String? value,
    required List<Account> items,
    required ValueChanged<String?> onChanged,
    required FormFieldValidator<String?> validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.account_balance_wallet),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      ),
      items: items.map((Account account) {
        return DropdownMenuItem<String>(
          value: account.id,
          child: Row(
            children: [
              Icon(
                _getAccountTypeIcon(account.accountType),
                size: 20,
                color: _getAccountTypeColor(account.accountType),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${account.name} (${account.accountType})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
    );
  }

  Color _getAccountTypeColor(String type) {
    switch (type) {
      case 'Bank': return Colors.blue;
      case 'Credit Card': return Colors.red;
      case 'Cash': return Colors.green;
      case 'Investment': return Colors.purple;
      case 'Savings': return Colors.orange;
      case 'Loan': return Colors.brown;
      default: return Colors.grey;
    }
  }

  IconData _getAccountTypeIcon(String type) {
    switch (type) {
      case 'Bank': return Icons.account_balance;
      case 'Credit Card': return Icons.credit_card;
      case 'Cash': return Icons.money;
      case 'Investment': return Icons.trending_up;
      case 'Savings': return Icons.savings;
      case 'Loan': return Icons.request_quote;
      default: return Icons.account_balance_wallet;
    }
  }
}