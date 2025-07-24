import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/services/transaction_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/account_model.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({Key? key}) : super(key: key);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  List<TransactionFormData> _transactions = [TransactionFormData()];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
    _scrollController.dispose();
    for (var transaction in _transactions) {
      transaction.dispose();
    }
    super.dispose();
  }

  void _addMoreTransaction() {
    setState(() {
      _transactions.add(TransactionFormData());
    });

    // Scroll to the bottom to show the new transaction form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _removeTransaction(int index) {
    if (_transactions.length > 1) {
      setState(() {
        _transactions[index].dispose();
        _transactions.removeAt(index);
      });
    }
  }

  
  Future<void> _submitTransactions() async {
  if (_formKey.currentState!.validate()) {
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);

    // Validate that each transaction has proper account selection
    for (int i = 0; i < _transactions.length; i++) {
      final transaction = _transactions[i];
      if (transaction.type == TransactionTypes.inflow && transaction.toAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a "To" account for transaction ${i + 1}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (transaction.type == TransactionTypes.outflow && transaction.fromAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a "From" account for transaction ${i + 1}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Upload files and create transactions
    final List<CreateTransactionRequest> transactionRequests = [];
    
    for (final transaction in _transactions) {
      List<String>? uploadedFilePaths;
      
      // Upload files if any are selected
      if (transaction.selectedFiles.isNotEmpty) {
        final uploadResult = await TransactionService.uploadTransactionFiles(
          files: transaction.selectedFiles,
        );
        
        if (uploadResult['success']) {
          uploadedFilePaths = List<String>.from(uploadResult['file_paths']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload files: ${uploadResult['message']}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      transactionRequests.add(CreateTransactionRequest(
        type: transaction.type,
        amount: double.parse(transaction.amountController.text),
        fromAccountId: transaction.fromAccountId,
        toAccountId: transaction.toAccountId,
        detail: transaction.detailController.text.trim(),
        documentFiles: uploadedFilePaths,  // Changed from documentRecord
        transactionDate: transaction.transactionDate,
      ));
    }

    bool success;
    if (transactionRequests.length == 1) {
      final request = transactionRequests.first;
      success = await transactionProvider.createTransaction(
        type: request.type,
        amount: request.amount,
        fromAccountId: request.fromAccountId,
        toAccountId: request.toAccountId,
        detail: request.detail,
        documentFiles: request.documentFiles,  // Changed from documentRecord
        transactionDate: request.transactionDate,
      );
    } else {
      success = await transactionProvider.createMultipleTransactions(
        transactions: transactionRequests,
      );
    }

    if (success) {
      Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Transaction${_transactions.length > 1 ? 's' : ''}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          Consumer<TransactionProvider>(
            builder: (context, transactionProvider, child) {
              return TextButton(
                onPressed: transactionProvider.isLoading ? null : _submitTransactions,
                child: Text(
                  _transactions.length == 1 ? 'Save' : 'Save All',
                  style: TextStyle(
                    color: transactionProvider.isLoading ? Colors.white54 : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<AccountProvider>(
        builder: (context, accountProvider, child) {
          if (accountProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (accountProvider.accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No accounts found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create an account first to add transactions',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      return TransactionFormCard(
                        key: ValueKey(index),
                        transaction: _transactions[index],
                        accounts: accountProvider.accounts,
                        index: index,
                        canRemove: _transactions.length > 1,
                        onRemove: () => _removeTransaction(index),
                      );
                    },
                  ),
                ),
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _addMoreTransaction,
                              icon: const Icon(Icons.add),
                              label: const Text('Add More Transaction'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Consumer<TransactionProvider>(
                              builder: (context, transactionProvider, child) {
                                return ElevatedButton(
                                  onPressed: transactionProvider.isLoading
                                      ? null
                                      : _submitTransactions,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: transactionProvider.isLoading
                                      ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Saving...'),
                                    ],
                                  )
                                      : Text(
                                    _transactions.length == 1
                                        ? 'Save Transaction'
                                        : 'Save All Transactions (${_transactions.length})',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TransactionFormData {
  final TextEditingController amountController;
  final TextEditingController detailController;
  List<File> selectedFiles;  // Replace documentController with this
  String type;
  String? fromAccountId;
  String? toAccountId;
  DateTime transactionDate;

  TransactionFormData()
      : amountController = TextEditingController(),
        detailController = TextEditingController(),
        selectedFiles = [],  // Initialize empty list
        type = TransactionTypes.inflow,
        transactionDate = DateTime.now();

  void dispose() {
    amountController.dispose();
    detailController.dispose();
  }
}

class TransactionFormCard extends StatefulWidget {
  final TransactionFormData transaction;
  final List<Account> accounts;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  const TransactionFormCard({
    Key? key,
    required this.transaction,
    required this.accounts,
    required this.index,
    required this.canRemove,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<TransactionFormCard> createState() => _TransactionFormCardState();
}

class _TransactionFormCardState extends State<TransactionFormCard> {


  Future<void> _pickImageFromCamera() async {
  try {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        widget.transaction.selectedFiles.add(File(image.path));
      });
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error taking photo: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _pickImageFromGallery() async {
  try {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    
    if (images.isNotEmpty) {
      setState(() {
        for (final image in images) {
          widget.transaction.selectedFiles.add(File(image.path));
        }
      });
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error picking images: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _pickFiles() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'gif'],
    );

    if (result != null) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null) {
            widget.transaction.selectedFiles.add(File(file.path!));
          }
        }
      });
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error picking files: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Transaction ${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.canRemove)
                  IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Transaction Type Radio Buttons
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Inflow'),
                    value: TransactionTypes.inflow,
                    groupValue: widget.transaction.type,
                    onChanged: (value) {
                      setState(() {
                        widget.transaction.type = value!;
                        // Clear relevant account field when type changes
                        widget.transaction.fromAccountId = null;
                        // Reset toAccountId for inflow if it was set as fromAccountId for outflow
                        // widget.transaction.toAccountId = null; // Only if you want to enforce distinct accounts for transfers
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
                    groupValue: widget.transaction.type,
                    onChanged: (value) {
                      setState(() {
                        widget.transaction.type = value!;
                        // Clear relevant account field when type changes
                        widget.transaction.toAccountId = null;
                        // Reset fromAccountId for outflow if it was set as toAccountId for inflow
                        // widget.transaction.fromAccountId = null; // Only if you want to enforce distinct accounts for transfers
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount TextFormField
            TextFormField(
              controller: widget.transaction.amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                hintText: '0.00',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // From Account Dropdown (Always shown for selection)
            _buildAccountDropdown(
              labelText: 'From Account ${widget.transaction.type == TransactionTypes.outflow || widget.transaction.type == TransactionTypes.inflow ? '*' : ''}', // Made required for all for now, adjust as needed
              value: widget.transaction.fromAccountId,
              items: widget.accounts,
              onChanged: (value) {
                setState(() {
                  widget.transaction.fromAccountId = value;
                });
              },
              validator: (value) {
                // Make 'From' required for Outflow transactions
                if (widget.transaction.type == TransactionTypes.outflow &&
                    (value == null || value.isEmpty)) {
                  return 'Please select a "From" account for outflow';
                }
                // Optional: Make it required for Inflow if it's a transfer
                // if (widget.transaction.type == TransactionTypes.inflow && value == null) {
                //   return 'Please select a "From" account for transfers';
                // }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // To Account Dropdown (Always shown for selection)
            _buildAccountDropdown(
              labelText: 'To Account ${widget.transaction.type == TransactionTypes.inflow || widget.transaction.type == TransactionTypes.outflow ? '*' : ''}', // Made required for all for now, adjust as needed
              value: widget.transaction.toAccountId,
              items: widget.accounts,
              onChanged: (value) {
                setState(() {
                  widget.transaction.toAccountId = value;
                });
              },
              validator: (value) {
                // Make 'To' required for Inflow transactions
                if (widget.transaction.type == TransactionTypes.inflow &&
                    (value == null || value.isEmpty)) {
                  return 'Please select a "To" account for inflow';
                }
                // Optional: Make it required for Outflow if it's a transfer
                // if (widget.transaction.type == TransactionTypes.outflow && value == null) {
                //   return 'Please select a "To" account for transfers';
                // }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Detail TextFormField
            TextFormField(
              controller: widget.transaction.detailController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Detail *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                hintText: 'Transaction description...',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter transaction details';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Document Record TextFormField (Optional)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_file, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text(
                        'Documents & Images',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'camera') {
                            await _pickImageFromCamera();
                          } else if (value == 'gallery') {
                            await _pickImageFromGallery();
                          } else if (value == 'files') {
                            await _pickFiles();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'camera',
                            child: Row(
                              children: [
                                Icon(Icons.camera_alt),
                                SizedBox(width: 8),
                                Text('Take Photo'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'gallery',
                            child: Row(
                              children: [
                                Icon(Icons.photo_library),
                                SizedBox(width: 8),
                                Text('Choose from Gallery'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'files',
                            child: Row(
                              children: [
                                Icon(Icons.folder),
                                SizedBox(width: 8),
                                Text('Choose Files'),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Add',
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.transaction.selectedFiles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'No files selected',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  else
                    ...widget.transaction.selectedFiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      final fileName = file.path.split('/').last;
                      final isImage = ['jpg', 'jpeg', 'png', 'gif'].contains(
                        fileName.split('.').last.toLowerCase(),
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isImage ? Icons.image : Icons.insert_drive_file,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  widget.transaction.selectedFiles.removeAt(index);
                                });
                              },
                              icon: const Icon(Icons.close, size: 18),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Transaction Date Picker
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
                      text: '${widget.transaction.transactionDate.day}/${widget.transaction.transactionDate.month}/${widget.transaction.transactionDate.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: widget.transaction.transactionDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(), // Allow selecting up to today
                    );
                    if (picked != null && picked != widget.transaction.transactionDate) {
                      setState(() {
                        widget.transaction.transactionDate = picked;
                      });
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
          ],
        ),
      ),
    );
  }

  // Helper for Account Dropdown
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
      isExpanded: true, // Allows dropdown to take full width
    );
  }

  // Helper methods for account type colors and icons
  Color _getAccountTypeColor(String type) {
    switch (type) {
      case 'Bank':
        return Colors.blue;
      case 'Credit Card':
        return Colors.red;
      case 'Cash':
        return Colors.green;
      case 'Investment':
        return Colors.purple;
      case 'Savings':
        return Colors.orange;
      case 'Loan':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  IconData _getAccountTypeIcon(String type) {
    switch (type) {
      case 'Bank':
        return Icons.account_balance;
      case 'Credit Card':
        return Icons.credit_card;
      case 'Cash':
        return Icons.money;
      case 'Investment':
        return Icons.trending_up;
      case 'Savings':
        return Icons.savings;
      case 'Loan':
        return Icons.request_quote;
      default:
        return Icons.account_balance_wallet;
    }
  }
}