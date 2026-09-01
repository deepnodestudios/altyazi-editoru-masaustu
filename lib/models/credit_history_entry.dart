import 'package:cloud_firestore/cloud_firestore.dart';

enum CreditHistoryEntryType { add, spend }

class CreditHistoryEntry {
  final String id;
  final CreditHistoryEntryType type;
  final int amount;
  final DateTime? timestamp;
  final String? source;
  final String? reason;
  final String? fileName;
  final String? targetLanguage;
  final String? platform;
  final String? productId;
  final String? purchaseId;
  final String? chargeKey;
  final Map<String, dynamic> raw;

  const CreditHistoryEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.timestamp,
    this.source,
    this.reason,
    this.fileName,
    this.targetLanguage,
    this.platform,
    this.productId,
    this.purchaseId,
    this.chargeKey,
    this.raw = const {},
  });

  bool get isSpend => type == CreditHistoryEntryType.spend;

  bool get isAdd => type == CreditHistoryEntryType.add;

  bool get isTokenLedger {
    final unit = _normalizeString(raw['unit'])?.toLowerCase();
    if (unit == 'token') return true;
    final chargeMode = _normalizeString(raw['chargeMode'])?.toLowerCase();
    if (chargeMode == 'tokens') return true;
    final creditType = _normalizeString(raw['creditType'])?.toLowerCase() ?? '';
    if (creditType.startsWith('token')) return true;
    final fromPaidTokens = _parseAmount(raw['fromPaidTokens']);
    final fromGrantTokens = _parseAmount(raw['fromGrantTokens']);
    if (fromPaidTokens + fromGrantTokens > 0) return true;
    final product = productId?.toLowerCase() ?? '';
    return product.startsWith('tokens_');
  }

  bool get isLemonWebsitePack {
    final src = source?.trim().toLowerCase() ?? '';
    if (src == 'website_purchase') return true;
    final pid = productId?.trim() ?? '';
    return const {
      '2048626',
      '2048645',
      '2048653',
      '1456186',
      '1456188',
      '1456194',
    }.contains(pid);
  }

  bool get isHiddenLemonExtraRow {
    if (!isAdd || !isLemonWebsitePack) return false;
    final why = reason?.trim().toLowerCase() ?? '';
    if (why == 'token_pack_extra' || why == 'purchase_bonus') return true;
    return id.endsWith('_purchase_bonus');
  }

  int get displayAmount {
    if (isLemonWebsitePack && isAdd) {
      final base = _parseAmount(raw['tokenBase']);
      final bonus = _parseAmount(raw['tokenBonus']);
      final combined = base + bonus;
      if (combined > 0) return combined;
    }
    if (!isTokenLedger) return amount.abs();
    if (amount.abs() > 1) return amount.abs();
    final tokenSum =
        _parseAmount(raw['fromPaidTokens']) + _parseAmount(raw['fromGrantTokens']);
    if (tokenSum > 0) return tokenSum;
    final estimated = _parseAmount(raw['estimatedTokens']);
    if (estimated > 0) return estimated;
    return amount.abs();
  }

  String? get displayFileName {
    final original = fileName?.trim();
    if (original == null || original.isEmpty) {
      return null;
    }

    final dotIndex = original.lastIndexOf('.');
    if (dotIndex <= 0) {
      return _stripHashSuffix(original);
    }

    final name = original.substring(0, dotIndex);
    final ext = original.substring(dotIndex);
    final cleanedName = _stripHashSuffix(name);
    return '$cleanedName$ext';
  }

  static String _stripHashSuffix(String input) {
    return input.replaceFirst(
      RegExp(
        r'([_-])[a-fA-F0-9]{32}$|([_-])[a-fA-F0-9]{40}$|([_-])[a-fA-F0-9]{64}$',
      ),
      '',
    );
  }

  static CreditHistoryEntry fromCreditTransactionsDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final typeValue = _normalizeString(data['type']);
    final type = (typeValue == 'spend' || typeValue == 'revoke')
        ? CreditHistoryEntryType.spend
        : CreditHistoryEntryType.add;

    return CreditHistoryEntry(
      id: doc.id,
      type: type,
      amount: _parseAmount(data['amount']),
      timestamp: _parseTimestamp(data['timestamp'] ?? data['createdAt']),
      source: _normalizeString(data['source']),
      reason: _normalizeString(data['reason']),
      fileName: _normalizeString(data['fileName']),
      targetLanguage: _normalizeString(data['targetLanguage']),
      platform: _normalizeString(data['platform']),
      productId: _normalizeString(data['productId']),
      purchaseId: _normalizeString(data['purchaseId']),
      chargeKey: _normalizeString(data['chargeKey']),
      raw: data,
    );
  }

  static CreditHistoryEntry fromPurchaseHistoryDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return CreditHistoryEntry(
      id: doc.id,
      type: CreditHistoryEntryType.add,
      amount: _parseAmount(
        data['amount'] ??
            data['credits'] ??
            data['creditAmount'] ??
            data['value'],
      ),
      timestamp: _parseTimestamp(
        data['timestamp'] ??
            data['createdAt'] ??
            data['purchasedAt'] ??
            data['date'],
      ),
      source: _normalizeString(data['source']),
      reason: _normalizeString(data['reason']),
      fileName: _normalizeString(data['fileName']),
      targetLanguage: _normalizeString(data['targetLanguage']),
      platform: _normalizeString(data['platform']),
      productId: _normalizeString(data['productId']),
      purchaseId: _normalizeString(data['purchaseId']),
      chargeKey: _normalizeString(data['chargeKey']),
      raw: data,
    );
  }

  static CreditHistoryEntry fromCreditUsageDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return CreditHistoryEntry(
      id: doc.id,
      type: CreditHistoryEntryType.spend,
      amount: _parseAmount(
        data['amount'] ??
            data['credits'] ??
            data['creditAmount'] ??
            data['usedCredits'] ??
            data['value'] ??
            1,
      ),
      timestamp: _parseTimestamp(
        data['timestamp'] ??
            data['createdAt'] ??
            data['usedAt'] ??
            data['date'],
      ),
      source: _normalizeString(data['source']),
      reason: _normalizeString(data['reason']),
      fileName: _normalizeString(data['fileName']),
      targetLanguage: _normalizeString(data['targetLanguage']),
      platform: _normalizeString(data['platform']),
      productId: _normalizeString(data['productId']),
      purchaseId: _normalizeString(data['purchaseId']),
      chargeKey: _normalizeString(data['chargeKey']),
      raw: data,
    );
  }

  static int _parseAmount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) {
        return parsed.round();
      }
    }
    return 0;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      if (value <= 0) return null;
      final millis = value > 1000000000000 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    if (value is num) {
      return _parseTimestamp(value.toInt());
    }
    if (value is String) {
      final parsedInt = int.tryParse(value);
      if (parsedInt != null) {
        return _parseTimestamp(parsedInt);
      }
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _normalizeString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }
}
