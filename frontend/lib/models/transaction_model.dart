class Transaction {
  final String id;
  final String type;
  final double amount;
  final String? fromAccountId;
  final String? toAccountId;
  final String detail;
  final List<String>? documentFiles;  // Changed from documentRecord
  final String userId;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.fromAccountId,
    this.toAccountId,
    required this.detail,
    this.documentFiles,  // Changed from documentRecord
    required this.userId,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String? ?? 'N/A',
      type: json['type'] as String? ?? TransactionTypes.inflow,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      fromAccountId: json['from_account_id'] as String?,
      toAccountId: json['to_account_id'] as String?,
      detail: json['detail'] as String? ?? 'No details provided',
      documentFiles: json['document_files'] != null 
          ? List<String>.from(json['document_files'] as List)
          : null,  // Changed from documentRecord
      userId: json['user_id'] as String? ?? 'N/A',
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'detail': detail,
      'document_files': documentFiles,  // Changed from document_record
      'user_id': userId,
      'transaction_date': transactionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class CreateTransactionRequest {
  final String type;
  final double amount;
  final String? fromAccountId;
  final String? toAccountId;
  final String detail;
  final List<String>? documentFiles;  // Changed from documentRecord
  final DateTime? transactionDate;

  CreateTransactionRequest({
    required this.type,
    required this.amount,
    this.fromAccountId,
    this.toAccountId,
    required this.detail,
    this.documentFiles,  // Changed from documentRecord
    this.transactionDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'detail': detail,
      'document_files': documentFiles,  // Changed from document_record
      'transaction_date': (transactionDate ?? DateTime.now()).toIso8601String(),
    };
  }
}

class CreateMultipleTransactionsRequest {
  final List<CreateTransactionRequest> transactions;

  CreateMultipleTransactionsRequest({
    required this.transactions,
  });

  Map<String, dynamic> toJson() {
    return {
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
  }
}


class UpdateTransactionRequest {
  final String? type;
  final double? amount;
  final String? fromAccountId;
  final String? toAccountId;
  final String? detail;
  final List<String>? documentFiles;  // Changed from documentRecord
  final DateTime? transactionDate;

  UpdateTransactionRequest({
    this.type,
    this.amount,
    this.fromAccountId,
    this.toAccountId,
    this.detail,
    this.documentFiles,  // Changed from documentRecord
    this.transactionDate,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (type != null) map['type'] = type;
    if (amount != null) map['amount'] = amount;
    if (fromAccountId != null) map['from_account_id'] = fromAccountId;
    if (toAccountId != null) map['to_account_id'] = toAccountId;
    if (detail != null) map['detail'] = detail;
    if (documentFiles != null) map['document_files'] = documentFiles;  // Changed from document_record
    if (transactionDate != null) map['transaction_date'] = transactionDate!.toIso8601String();
    return map;
  }
}

class TransactionTypes {
  static const String inflow = 'Inflow';
  static const String outflow = 'Outflow';

  static const List<String> all = [
    inflow,
    outflow,
  ];
}