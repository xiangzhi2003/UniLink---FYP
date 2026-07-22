// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : wallet.dart
// Description     : Data models for WalletEntry (a ledger row) and WalletSummary (balance + history).
// First Written on: Tuesday,14-Jul-2026
// Edited on       : Thursday,16-Jul-2026

class WalletEntry {
  final String id;
  final String? transactionId;
  final double amount;
  final String type; // credit | withdrawal | deposit
  final DateTime createdAt;
  final String? listingTitle;
  final String? dealType;

  const WalletEntry({
    required this.id,
    this.transactionId,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.listingTitle,
    this.dealType,
  });

  factory WalletEntry.fromJson(Map<String, dynamic> json) {
    return WalletEntry(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      listingTitle: json['listing_title'] as String?,
      dealType: json['deal_type'] as String?,
    );
  }
}

class WalletSummary {
  final double balance;
  final List<WalletEntry> history;
  final double outstandingDebt;

  const WalletSummary({
    required this.balance,
    required this.history,
    this.outstandingDebt = 0,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      balance: (json['balance'] as num).toDouble(),
      history: (json['history'] as List<dynamic>)
          .map((e) => WalletEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      outstandingDebt: (json['outstanding_debt'] as num?)?.toDouble() ?? 0,
    );
  }
}
