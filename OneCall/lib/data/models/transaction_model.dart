import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { credit, debit }

class TransactionModel {
  final String id;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String description;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.date,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'type': type.toString().split('.').last, // 'credit' or 'debit'
      'date': Timestamp.fromDate(date),
      'description': description,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      amount: (map['amount'] ?? 0.0).toDouble(),
      type: map['type'] == 'credit' ? TransactionType.credit : TransactionType.debit,
      date: (map['date'] as Timestamp).toDate(),
      description: map['description'] ?? '',
    );
  }
}
