import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class CryptoAsset {
  final String symbol;
  final String name;
  final String logoUrl;
  double balance;

  CryptoAsset({
    required this.symbol,
    required this.name,
    required this.logoUrl,
    required this.balance,
  });
}

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  String _walletAddress = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e";
  
  final List<CryptoAsset> _assets = [
    CryptoAsset(
      symbol: 'USDT',
      name: 'Tether USD',
      logoUrl: 'https://cryptologos.cc/logos/tether-usdt-logo.png',
      balance: 1250.0,
    ),
    CryptoAsset(
      symbol: 'ETH',
      name: 'Ethereum',
      logoUrl: 'https://cryptologos.cc/logos/ethereum-eth-logo.png',
      balance: 1.45,
    ),
    CryptoAsset(
      symbol: 'BTC',
      name: 'Bitcoin',
      logoUrl: 'https://cryptologos.cc/logos/bitcoin-btc-logo.png',
      balance: 0.042,
    ),
  ];

  String get walletAddress => _walletAddress;
  List<CryptoAsset> get assets => _assets;

  Future<void> sendCrypto(String symbol, String address, double amount) async {
    // Mock sending logic
    final asset = _assets.firstWhere((a) => a.symbol == symbol);
    if (asset.balance >= amount) {
      asset.balance -= amount;
      print("💸 Sent $amount $symbol to $address");
    } else {
      throw Exception("Insufficient balance");
    }
  }

  void generateNewAddress() {
    final random = Random();
    const chars = '0123456789abcdef';
    String newAddr = "0x";
    for (int i = 0; i < 40; i++) {
      newAddr += chars[random.nextInt(chars.length)];
    }
    _walletAddress = newAddr;
  }
}
