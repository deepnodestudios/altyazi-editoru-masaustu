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
