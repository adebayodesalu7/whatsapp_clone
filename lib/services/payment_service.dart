import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';

class PaymentService extends ChangeNotifier {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  double _balance = 12500.00; // Starting with a decent test balance
  final List<Transaction> _transactions = [
    Transaction(
      id: '1',
      type: 'receive',
      amount: 5000.0,
      recipient: 'Chinelo Okafor',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Transaction(
      id: '2',
      type: 'send',
      amount: 1200.0,
      recipient: 'MTN Airtime',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  double get balance => _balance;
  List<Transaction> get transactions => List.unmodifiable(_transactions);

  Future<void> topUp(double amount) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network
    _balance += amount;
    _transactions.insert(0, Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'receive',
      amount: amount,
      recipient: 'Wallet Top-up',
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  Future<bool> sendMoney(String recipient, double amount) async {
    await Future.delayed(const Duration(seconds: 1));
    if (_balance >= amount) {
      _balance -= amount;
      _transactions.insert(
        0,
        Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'send',
          amount: amount,
          recipient: recipient,
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> purchaseAirtime(String provider, String phoneNumber, double amount) async {
    await Future.delayed(const Duration(seconds: 1));
    if (_balance >= amount) {
      _balance -= amount;
      _transactions.insert(
        0,
        Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'airtime',
          amount: amount,
          recipient: '$provider - $phoneNumber',
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> contributeToAjo(String groupName, double amount) async {
    await Future.delayed(const Duration(seconds: 1));
    if (_balance >= amount) {
      _balance -= amount;
      _transactions.insert(
        0,
        Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'ajo',
          amount: amount,
          recipient: groupName,
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
      return true;
    }
    return false;
  }
}
