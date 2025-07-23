// models/transaction_model.dart
class Transaction {
  final String id;
  final String type;
  final double amount;
  final String? fromAccountId;
  final String? toAccountId;
  final String detail;
  final String? documentRecord;
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
    this.documentRecord,
    required this.userId,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      // Explicitly handle potential nulls for String fields that should be non-null
      // Fallbacks are provided, but ideally, the backend should ensure these are never null.
      id: json['id'] as String? ?? 'N/A',
      type: json['type'] as String? ?? TransactionTypes.inflow, // Default type as fallback
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      fromAccountId: json['from_account_id'] as String?, // Optional, can be null
      toAccountId: json['to_account_id'] as String?,   // Optional, can be null
      detail: json['detail'] as String? ?? 'No details provided',
      documentRecord: json['document_record'] as String?, // Optional, can be null
      userId: json['user_id'] as String? ?? 'N/A',
      // DateTime parsing is already good if the format is consistent ISO8601
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
      'document_record': documentRecord,
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
  final String? documentRecord;
  final DateTime? transactionDate;

  CreateTransactionRequest({
    required this.type,
    required this.amount,
    this.fromAccountId,
    this.toAccountId,
    required this.detail,
    this.documentRecord,
    this.transactionDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'detail': detail,
      'document_record': documentRecord,
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
  final String? documentRecord;
  final DateTime? transactionDate;

  UpdateTransactionRequest({
    this.type,
    this.amount,
    this.fromAccountId,
    this.toAccountId,
    this.detail,
    this.documentRecord,
    this.transactionDate,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (type != null) map['type'] = type;
    if (amount != null) map['amount'] = amount;
    if (fromAccountId != null) map['from_account_id'] = fromAccountId;
    if (toAccountId != null) map['to_account_id'] = toAccountId;
    if (detail != null) map['detail'] = detail;
    if (documentRecord != null) map['document_record'] = documentRecord;
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