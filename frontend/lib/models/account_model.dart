class Account {
  final String id;
  final String name;
  final String accountType;
  final String? email;
  final String? phoneNumber;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.accountType,
    this.email,
    this.phoneNumber,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      name: json['name'],
      accountType: json['account_type'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'account_type': accountType,
      'email': email,
      'phone_number': phoneNumber,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class CreateAccountRequest {
  final String name;
  final String accountType;
  final String? email;
  final String? phoneNumber;

  CreateAccountRequest({
    required this.name,
    required this.accountType,
    this.email,
    this.phoneNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'account_type': accountType,
      'email': email,
      'phone_number': phoneNumber,
    };
  }
}

// Account type options
class AccountTypes {
  static const String bank = 'Bank';
  static const String creditCard = 'Credit Card';
  static const String cash = 'Cash';
  static const String investment = 'Investment';
  static const String savings = 'Savings';
  static const String loan = 'Loan';
  static const String other = 'Other';

  static const List<String> all = [
    bank,
    creditCard,
    cash,
    investment,
    savings,
    loan,
    other,
  ];
}