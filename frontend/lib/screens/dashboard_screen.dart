// screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/transactions/transactions_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/account_provider.dart'; // Import AccountProvider
import '../providers/transaction_provider.dart'; // Import TransactionProvider
import '../widgets/app_drawer.dart';
import '../models/account_model.dart'; // Import Account model
import '../models/transaction_model.dart'; // Import Transaction model

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load data when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure accounts and transactions are loaded
      Provider.of<AccountProvider>(context, listen: false).loadAccounts();
      Provider.of<TransactionProvider>(context, listen: false).loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(currentRoute: 'dashboard'),
      body: Consumer3<AuthProvider, AccountProvider, TransactionProvider>(
        builder: (context, authProvider, accountProvider, transactionProvider, child) {
          // --- Data Loading and Error Handling ---
          if (accountProvider.isLoading || transactionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Combine error messages if both providers have errors
          String errorMessage = '';
          if (accountProvider.errorMessage.isNotEmpty) {
            errorMessage += 'Accounts: ${accountProvider.errorMessage}\n';
          }
          if (transactionProvider.errorMessage.isNotEmpty) {
            errorMessage += 'Transactions: ${transactionProvider.errorMessage}';
          }

          if (errorMessage.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
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
                      'Error loading data:',
                      style: TextStyle(fontSize: 18, color: Colors.red.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage.trim(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Retry loading both
                        Provider.of<AccountProvider>(context, listen: false).loadAccounts();
                        Provider.of<TransactionProvider>(context, listen: false).loadTransactions();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // --- Display Dashboard Content ---
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section (remains the same)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              (authProvider.user?.fullName ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  authProvider.user?.fullName ?? 'User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          authProvider.user?.email ?? '',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Dashboard Stats/Summary Cards
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        // --- Update Total Balance ---
                        title: 'Total Balance',
                        value: '\$${_calculateTotalBalance(accountProvider.accounts, transactionProvider).toStringAsFixed(2)}',
                        icon: Icons.account_balance_wallet,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        // --- Update This Month's Income/Expense ---
                        title: 'This Month',
                        value: '\$${_calculateMonthlyNetFlow(transactionProvider.transactions).toStringAsFixed(2)}',
                        icon: Icons.calendar_today, // Changed icon to be more generic for monthly summary
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        // --- Update Accounts Count ---
                        title: 'Accounts',
                        value: accountProvider.accounts.length.toString(),
                        icon: Icons.account_balance,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        // --- Update Transactions Count ---
                        title: 'Transactions',
                        value: transactionProvider.totalCount.toString(),
                        icon: Icons.receipt_long,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Recent Activity Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to TransactionsScreen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TransactionsScreen(),
                          ),
                        );
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Display Recent Transactions
                if (transactionProvider.transactions.isEmpty)
                  _buildEmptyRecentTransactions()
                else
                  _buildRecentTransactionsList(transactionProvider.transactions, accountProvider.accounts),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Helper methods to calculate data ---

  // Calculates total balance across all accounts
  double _calculateTotalBalance(List<Account> accounts, TransactionProvider transactionProvider) {
    double balance = 0.0;
    for (var account in accounts) {
      balance += transactionProvider.getAccountBalance(account.id);
    }
    return balance;
  }

  // Calculates net flow (inflow - outflow) for the current month
  double _calculateMonthlyNetFlow(List<Transaction> transactions) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0); // Last day of current month

    double totalInflow = 0.0;
    double totalOutflow = 0.0;

    for (var transaction in transactions) {
      // Check if transaction date is within the current month
      if (transaction.transactionDate.isAfter(startOfMonth.subtract(const Duration(days:1))) &&
          transaction.transactionDate.isBefore(endOfMonth.add(const Duration(days:1)))) {
        if (transaction.type == TransactionTypes.inflow) {
          totalInflow += transaction.amount;
        } else if (transaction.type == TransactionTypes.outflow) {
          totalOutflow += transaction.amount;
        }
      }
    }
    return totalInflow - totalOutflow;
  }

  // Helper to get account name from ID
  String _getAccountName(String? accountId, List<Account> accounts) {
    if (accountId == null) return 'N/A';
    try {
      final account = accounts.firstWhere((acc) => acc.id == accountId);
      return account.name;
    } catch (e) {
      return 'Unknown Account';
    }
  }

  // Widget to display when there are no recent transactions
  Widget _buildEmptyRecentTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No recent transactions',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget to build the list of recent transactions
  Widget _buildRecentTransactionsList(List<Transaction> transactions, List<Account> accounts) {
    // Sort transactions by date descending and take the latest 3 (or fewer if less than 3)
    final recentTransactions = transactions
        .toList() // Create a mutable copy
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate)); // Sort descending

    final displayTransactions = recentTransactions.take(3).toList();

    return ListView.builder(
      shrinkWrap: true, // Important when inside a Column
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling for this list
      itemCount: displayTransactions.length,
      itemBuilder: (context, index) {
        final transaction = displayTransactions[index];
        final isInflow = transaction.type == TransactionTypes.inflow;
        final fromAccountName = _getAccountName(transaction.fromAccountId, accounts);
        final toAccountName = _getAccountName(transaction.toAccountId, accounts);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isInflow ? Colors.green : Colors.red,
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
                      Text(
                        transaction.detail,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${transaction.type} - From: $fromAccountName, To: $toAccountName',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${isInflow ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isInflow ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Summary Card Widget (remains the same)
class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const SummaryCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}