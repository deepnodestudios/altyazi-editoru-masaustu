import 'package:cloud_firestore/cloud_firestore.dart';

enum CreditHistoryEntryType {
  add,
  spend,
}

class CreditHistoryEntry {
  final String id;
  final CreditHistoryEntryType type;
  final int amount;
  final DateTime? timestamp;

  // Common optional metadata
  final String? source;
  final String? reason;
  final String? fileName;
  final String? targetLanguage;
  final String? platform;
  final String? productId;
  final String? purchaseId;
  final String? chargeKey;

  // Raw data for additional fields (remaining credits, splits, etc.)
  final Map<String, dynamic> raw;

  const CreditHistoryEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.timestamp,
    required this.raw,
    this.source,
    this.reason,
    this.fileName,
    this.targetLanguage,
    this.platform,
    this.productId,
    this.purchaseId,
    this.chargeKey,
  });

  bool get isSpend => type == CreditHistoryEntryType.spend;

  bool get isAdd => type == CreditHistoryEntryType.add;

  bool get isTokenLedger {
    final unit = _asStringOrNull(raw['unit'])?.toLowerCase();
    if (unit == 'token' || unit == 'tokens') return true;
    final chargeMode = _asStringOrNull(raw['chargeMode'])?.toLowerCase();
    if (chargeMode == 'tokens') return true;
    final creditType = _asStringOrNull(raw['creditType'])?.toLowerCase() ?? '';
    if (creditType.startsWith('token')) return true;
    if (_asInt(raw['fromPaidTokens']) + _asInt(raw['fromGrantTokens']) > 0) {
      return true;
    }
    final product = productId?.toLowerCase() ?? '';
    if (product.startsWith('tokens_') || product.contains('token')) return true;
    // Wallet token amounts are thousands+; leftover file credits are 1 each.
    return amount.abs() >= 1000;
  }

  int get displayAmount {
    if (!isTokenLedger) return amount.abs();
    if (amount.abs() > 1) return amount.abs();
    final tokenSum =
        _asInt(raw['fromPaidTokens']) + _asInt(raw['fromGrantTokens']);
    if (tokenSum > 0) return tokenSum;
    final estimated = _asInt(raw['estimatedTokens']);
    if (estimated > 0) return estimated;
    return amount.abs();
  }

  /// A UI-friendly filename that strips common hash suffixes like
  /// `_<md5>.ext` / `-<sha1>.ext` / `_<sha256>.ext`.
  String? get displayFileName {
    final name = fileName;
    if (name == null) return null;
    return stripHashSuffix(name);
  }

  static final RegExp _hashSuffix = RegExp(
    r'([_-])([0-9a-fA-F]{32}|[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$',
  );

  static String stripHashSuffix(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return name;

    final dot = trimmed.lastIndexOf('.');
    final base = dot > 0 ? trimmed.substring(0, dot) : trimmed;
    final ext = dot > 0 ? trimmed.substring(dot) : '';

    final match = _hashSuffix.firstMatch(base);
    if (match == null) return trimmed;

    final cleanedBase = base.substring(0, match.start);
    if (cleanedBase.isEmpty) return trimmed;
    return '$cleanedBase$ext';
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String? _asStringOrNull(dynamic value) {
    final str = value?.toString();
    if (str == null) return null;
    final trimmed = str.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory CreditHistoryEntry.fromCreditTransactionsDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final typeStr = (data['type'] ?? '').toString().trim().toLowerCase();
    final type = typeStr == 'add'
        ? CreditHistoryEntryType.add
        : CreditHistoryEntryType.spend;

    return CreditHistoryEntry(
      id: doc.id,
      type: type,
      amount: _asInt(data['amount']),
      timestamp: _asDateTime(data['timestamp']),
      source: _asStringOrNull(data['source']),
      reason: _asStringOrNull(data['reason']),
      fileName: _asStringOrNull(data['fileName']),
      targetLanguage: _asStringOrNull(data['targetLanguage']),
      platform: _asStringOrNull(data['platform']),
      productId: _asStringOrNull(data['productId']),
      purchaseId: _asStringOrNull(data['purchaseId']),
      chargeKey: _asStringOrNull(data['chargeKey']),
      raw: data,
    );
  }

  factory CreditHistoryEntry.fromPurchaseHistoryDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CreditHistoryEntry(
      id: doc.id,
      type: CreditHistoryEntryType.add,
      amount: _asInt(data['amount']),
      timestamp: _asDateTime(data['timestamp']),
      source: 'purchase_history',
      productId: _asStringOrNull(data['productId']),
      purchaseId: doc.id,
      raw: data,
    );
  }

  factory CreditHistoryEntry.fromCreditUsageDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return CreditHistoryEntry(
      id: doc.id,
      type: CreditHistoryEntryType.spend,
      amount: _asInt(data['amount']),
      timestamp: _asDateTime(data['timestamp']),
      source: 'credit_usage',
      reason: _asStringOrNull(data['reason']),
      fileName: _asStringOrNull(data['fileName']),
      targetLanguage: _asStringOrNull(data['targetLanguage']),
      platform: _asStringOrNull(data['platform']),
      chargeKey: _asStringOrNull(data['chargeKey']),
      raw: data,
    );
  }
}
