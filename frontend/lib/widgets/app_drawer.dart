import 'package:flutter/material.dart';
import 'package:frontend/screens/transactions/transactions_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/accounts/accounts_screen.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({
    Key? key,
    required this.currentRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    (authProvider.user?.fullName ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                accountName: Text(
                  authProvider.user?.fullName ?? 'User',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                accountEmail: Text(
                  authProvider.user?.email ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
              );
            },
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  isSelected: currentRoute == 'dashboard',
                  onTap: () {
                    if (currentRoute != 'dashboard') {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const DashboardScreen(),
                        ),
                      );
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                DrawerItem(
                  icon: Icons.account_balance_wallet,
                  title: 'Accounts',
                  isSelected: currentRoute == 'accounts',
                  onTap: () {
                    if (currentRoute != 'accounts') {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const AccountsScreen(),
                        ),
                      );
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                DrawerItem(
                  icon: Icons.receipt_long,
                  title: 'Transactions',
                  isSelected: currentRoute == 'transactions',
                  onTap: () {
                    if (currentRoute != 'transactions') {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const TransactionsScreen(), // Make sure to import this
                        ),
                      );
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                // DrawerItem(
                //   icon: Icons.analytics,
                //   title: 'Reports',
                //   isSelected: currentRoute == 'reports',
                //   onTap: () {
                //     Navigator.of(context).pop();
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(
                //         content: Text('Reports feature coming soon!'),
                //         backgroundColor: Colors.orange,
                //       ),
                //     );
                //   },
                // ),
                const Divider(height: 1),
                DrawerItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  isSelected: currentRoute == 'settings',
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings feature coming soon!'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                ),
                DrawerItem(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.of(context).pop();
                    _showHelpDialog(context);
                  },
                ),
              ],
            ),
          ),
          
          // Logout Section
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: DrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              textColor: Colors.red,
              onTap: () {
                Navigator.of(context).pop();
                _showLogoutDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const SignInScreen()),
                  (route) => false,
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Help & Support'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Finance Tracker v1.0.0'),
              SizedBox(height: 8),
              Text('Features:'),
              Text('• Manage financial accounts'),
              Text('• Track transactions (coming soon)'),
              Text('• Generate reports (coming soon)'),
              SizedBox(height: 12),
              Text('For support, contact: support@financetracker.com'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final Color? textColor;
  final VoidCallback onTap;

  const DrawerItem({
    Key? key,
    required this.icon,
    required this.title,
    this.isSelected = false,
    this.textColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected 
            ? Colors.blue.shade700 
            : (textColor ?? Colors.grey.shade700),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected 
              ? Colors.blue.shade700 
              : (textColor ?? Colors.grey.shade800),
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.blue.shade50,
      onTap: onTap,
    );
  }
}