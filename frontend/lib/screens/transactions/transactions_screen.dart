// screens/transactions/transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/transactions/edit_transaction_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/account_model.dart';
import '../../widgets/app_drawer.dart';
import 'add_transaction_screen.dart'; // Ensure this import is correct

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String? _selectedFilterValue; // Renamed for clarity, can be accountId or type
  String? _selectedFilterType; // To differentiate if the filter is for account or type

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
      final accountProvider = Provider.of<AccountProvider>(context, listen: false);

      // Load accounts if not already loaded for the filter dropdown
      if (accountProvider.accounts.isEmpty) {
        accountProvider.loadAccounts();
      }
      // Load all transactions initially
      transactionProvider.loadTransactions();
    });
  }

  void _editTransaction(Transaction transaction) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(transaction: transaction),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // Reload transactions to reflect the changes
      _applyFilters();
    }
  }

  // Method to trigger loading based on current filters
  void _applyFilters() {
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);

    if (_selectedFilterType == 'account') {
      transactionProvider.loadTransactions(accountId: _selectedFilterValue);
    } else if (_selectedFilterType == 'type') {
      // Note: The backend doesn't currently support type filtering directly in getTransactions.
      // We'll handle this by filtering locally IF backend doesn't support it.
      // For now, we assume we might need to adapt the backend or filter locally.
      // If backend is updated: transactionProvider.loadTransactions(type: _selectedFilterValue);
      // For now, let's call loadTransactions() to get all, then we'll filter them locally.
      transactionProvider.loadTransactions();
    } else {
      // No filter or 'All' selected
      transactionProvider.loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: Colors.blue.shade700, // Changed to blue
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'all_accounts') {
                setState(() {
                  _selectedFilterValue = null;
                  _selectedFilterType = null;
                });
                _applyFilters();
              } else if (value == TransactionTypes.inflow) {
                setState(() {
                  _selectedFilterValue = TransactionTypes.inflow;
                  _selectedFilterType = 'type';
                });
                _applyFilters(); // Will call loadTransactions() and then filter locally
              } else if (value == TransactionTypes.outflow) {
                setState(() {
                  _selectedFilterValue = TransactionTypes.outflow;
                  _selectedFilterType = 'type';
                });
                _applyFilters(); // Will call loadTransactions() and then filter locally
              } else {
                // Assume it's an account ID
                setState(() {
                  _selectedFilterValue = value;
                  _selectedFilterType = 'account';
                });
                _applyFilters();
              }
            },
            itemBuilder: (context) {
              final accountProvider = Provider.of<AccountProvider>(context, listen: false);
              return [
                // Filter by Account
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'all_accounts',
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive),
                      SizedBox(width: 8),
                      Text('All Accounts'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ...accountProvider.accounts.map((account) => PopupMenuItem<String>(
                  value: account.id,
                  child: Row(
                    children: [
                      Icon(_getAccountTypeIcon(account.accountType)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
                const PopupMenuDivider(),
                // Filter by Type
                PopupMenuItem<String>(
                  value: TransactionTypes.inflow,
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_downward, color: Colors.green), // Keep transaction type colors
                      const SizedBox(width: 8),
                      Text('Inflow (${TransactionTypes.inflow})'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: TransactionTypes.outflow,
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_upward, color: Colors.red), // Keep transaction type colors
                      const SizedBox(width: 8),
                      Text('Outflow (${TransactionTypes.outflow})'),
                    ],
                  ),
                ),
              ];
            },
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'transactions'),
      body: Consumer2<TransactionProvider, AccountProvider>(
        builder: (context, transactionProvider, accountProvider, child) {
          List<Transaction> filteredTransactions = transactionProvider.transactions;

          // Local filtering for transaction type if backend doesn't support it directly
          if (_selectedFilterType == 'type' && _selectedFilterValue != null) {
            filteredTransactions = filteredTransactions.where((tx) => tx.type == _selectedFilterValue).toList();
          }

          if (transactionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (transactionProvider.errorMessage.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${transactionProvider.errorMessage}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _applyFilters(), // Retry with filters
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Determine the message for the empty state
          String emptyMessage = 'No transactions yet';
          String emptySubMessage = 'Create your first transaction to get started';
          if (_selectedFilterType == 'account' && _selectedFilterValue != null) {
            final accountName = _getAccountName(accountProvider.accounts, _selectedFilterValue!);
            emptyMessage = 'No transactions for "$accountName"';
            emptySubMessage = 'Add transactions to this account to see them here';
          } else if (_selectedFilterType == 'type' && _selectedFilterValue != null) {
            emptyMessage = 'No ${_selectedFilterValue!.toLowerCase()} transactions';
            emptySubMessage = 'Add ${_selectedFilterValue!.toLowerCase()} transactions to see them here';
          }

          if (filteredTransactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptySubMessage,
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToAddTransaction(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Transaction'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Summary Card (Only show if no filters applied or only account filter)
              if (_selectedFilterType == null || _selectedFilterType == 'account') ...[
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // Changed gradient to blue to match dashboard
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Transactions',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${transactionProvider.totalCount}', // Display total count from provider
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.receipt_long,
                        color: Colors.white70,
                        size: 32,
                      ),
                    ],
                  ),
                ),
              ],

              // Filter indicator
              if (_selectedFilterValue != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_selectedFilterType == 'account' ? Icons.account_balance_wallet : Icons.filter_alt, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _selectedFilterType == 'account'
                            ? 'Account: ${_getAccountName(accountProvider.accounts, _selectedFilterValue!)}'
                            : 'Type: ${_selectedFilterValue!}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilterValue = null;
                            _selectedFilterType = null;
                          });
                          _applyFilters();
                        },
                        child: const Icon(Icons.close, size: 16),
                      ),
                    ],
                  ),
                ),
              ],

              // Transactions List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = filteredTransactions[index];
                    return TransactionCard(
                      transaction: transaction,
                      accounts: accountProvider.accounts,
                      onDelete: () => _deleteTransaction(transaction),
                      onEdit: () => _editTransaction(transaction),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddTransaction(),
        backgroundColor: Colors.blue.shade700, // Changed to blue
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _getAccountName(List<Account> accounts, String accountId) {
    try {
      final account = accounts.firstWhere((acc) => acc.id == accountId);
      return account.name;
    } catch (e) {
      return 'Unknown Account'; // Fallback if account not found
    }
  }

  void _navigateToAddTransaction() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddTransactionScreen(),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction(s) created successfully!'),
          backgroundColor: Colors.green, // Green for success
        ),
      );
      // Reload transactions to reflect the new entry
      _applyFilters();
    }
  }

  void _deleteTransaction(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete this ${transaction.type.toLowerCase()} transaction of \$${transaction.amount.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await Provider.of<TransactionProvider>(context, listen: false)
          .deleteTransaction(transaction.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully!'),
            backgroundColor: Colors.green, // Green for success
          ),
        );
        _applyFilters(); // Reload transactions after deletion
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<TransactionProvider>(context, listen: false).errorMessage,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper methods for account type icons (keep as is)
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

// Keep the TransactionCard widget as is from the previous response
class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final List<Account> accounts;
  final VoidCallback onDelete;
  final VoidCallback onEdit; // Add onEdit callback

  const TransactionCard({
    Key? key,
    required this.transaction,
    required this.accounts,
    required this.onDelete,
    required this.onEdit, // Add this parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isInflow = transaction.type == TransactionTypes.inflow;
    final fromAccount = transaction.fromAccountId != null
        ? accounts.firstWhere(
            (acc) => acc.id == transaction.fromAccountId,
            orElse: () => Account(
              id: '',
              name: 'Unknown Account',
              accountType: '',
              userId: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          )
        : null;
    final toAccount = transaction.toAccountId != null
        ? accounts.firstWhere(
            (acc) => acc.id == transaction.toAccountId,
            orElse: () => Account(
              id: '',
              name: 'Unknown Account',
              accountType: '',
              userId: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          )
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isInflow ? Colors.green : Colors.red, // Transaction type colors
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isInflow ? Icons.arrow_downward : Icons.arrow_upward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            transaction.type,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isInflow ? Colors.green : Colors.red,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '\$${transaction.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isInflow ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.detail,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit(); // Call the edit callback
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (fromAccount != null) ...[
                        const Text(
                          'From:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${fromAccount.name} (${fromAccount.accountType})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                      if (toAccount != null) ...[
                        const Text(
                          'To:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${toAccount.name} (${toAccount.accountType})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${transaction.transactionDate.day}/${transaction.transactionDate.month}/${transaction.transactionDate.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (transaction.documentRecord != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attachment, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            transaction.documentRecord!,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}