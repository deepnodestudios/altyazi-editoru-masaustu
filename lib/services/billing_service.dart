import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

class CreditPackage {
  final String id;
  final String productId;
  final String title;
  final String description;
  final int credits;
  String? localizedTitle;
  String? localizedDescription;
  String? price;
  double? rawPrice;
  String? currencySymbol;

  CreditPackage({
    required this.id,
    required this.productId,
    required this.title,
    required this.description,
    required this.credits,
    this.price,
    this.rawPrice,
    this.currencySymbol,
  });

  factory CreditPackage.fromJson(Map<String, dynamic> json) {
    return CreditPackage(
      id: json['id'],
      productId: json['productId'],
      title: json['title'] ?? json['name'] ?? 'Paket',
      description: json['description'] ?? '',
      credits: json['credits'],
    );
  }

  String get name =>
      (localizedTitle != null && localizedTitle!.trim().isNotEmpty)
          ? localizedTitle!
          : title;
}

class BillingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  int _userCredits = 0;
  int get userCredits => _userCredits;

  int _purchasedCredits = 0;
  int get purchasedCredits =>
      usesTokenWallet ? _legacyFlatRateRemaining : _purchasedCredits;

  int _tokenBalance = 0;
  int get tokenBalance => _tokenBalance;

  int _legacyFlatRateRemaining = 0;
  int get legacyFlatRateRemaining => _legacyFlatRateRemaining;

  String _creditPolicy = '';
  bool get usesTokenWallet => _creditPolicy == 'token_v1';
  bool get offerTokenPacks => usesTokenWallet;
  int get displayFileCredits =>
      usesTokenWallet ? _legacyFlatRateRemaining : _purchasedCredits;
  int get displayTokenBalance => _tokenBalance;
  /// Desktop has no bonus/ad grants; purchased wallet tokens are the balance.
  int get displayPaidTokenBalance => _tokenBalance;
  bool get showTokenWalletUi => usesTokenWallet || _tokenBalance > 0;
  bool get isDesktopClient => true;
  int get tokenGrantBalance => 0;
  int get freeCredits => 0;
  bool get preferFreeCreditsFirst => false;
  bool get hasPaidAccess =>
      _purchasedCredits > 0 || _legacyFlatRateRemaining > 0;
  bool get hasSpendableBalance {
    if (usesTokenWallet) {
      return _legacyFlatRateRemaining > 0 || _tokenBalance > 0;
    }
    return _userCredits > 0;
  }
  
  bool _initialCreditsLoaded = false;

  int _deviceCredits = 0;
  int get deviceCredits => _deviceCredits;

  String? _deviceId;
  String? get deviceId => _deviceId;

  Timer? _deviceIdRetryTimer;
  int _deviceIdRetryCount = 0;
  static const int _maxDeviceIdRetries = 6;

  List<CreditPackage> _packages = [];
  List<CreditPackage> get packages => _packages;

  List<ProductDetails> _products = [];
  bool _isStoreLoading = true;
  bool get isStoreLoading => _isStoreLoading;

  bool _isPurchasing = false;
  bool get isPurchasing => _isPurchasing;

  String? _storeError;
  String? get storeError => _storeError;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  StreamSubscription<DocumentSnapshot>? _creditsSubscription;
  StreamSubscription<User?>? _authSubscription;
  Timer? _creditsPollTimer;
  Timer? _authPollTimer;
  String? _lastObservedUserUid;

  bool _starterCreditsCheckTriggered = false;
  Timer? _starterCreditsRetryTimer;
  int _starterCreditsRetryCount = 0;
  static const int _maxStarterCreditsRetries = 6;

  bool _purchaseCleanupStarted = false;

  CreditPackage? _activePurchasePackage;
  bool _alreadyOwnedRecoveryInProgress = false;
  bool _alreadyOwnedRetried = false;

  final _purchaseSuccessController = StreamController<void>.broadcast();
  Stream<void> get purchaseSuccessStream => _purchaseSuccessController.stream;

  Function(String key, [String? param])? onLog;

  // Used internally to decide whether a purchase can be safely finalized.
  // - success: credits were granted now
  // - alreadyProcessed: server says this purchase was already applied earlier
  // - failed: server could not grant credits (do NOT consume/complete)
  static const int _addCreditsOutcomeSuccess = 1;
  static const int _addCreditsOutcomeAlreadyProcessed = 2;
  static const int _addCreditsOutcomeFailed = 3;

  bool get _isIapSupportedPlatform => Platform.isAndroid || Platform.isIOS;
  bool get _isWindowsDesktop => !kIsWeb && Platform.isWindows;
  bool get _isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  BillingService() {
    _initDeviceId();
    if (_isIapSupportedPlatform) {
      _subscription = _iap.purchaseStream.listen(_listenToPurchaseUpdated);
    }
    if (_isWindowsDesktop) {
      _lastObservedUserUid = _auth.currentUser?.uid;
      _listenToUserCredits();
      _authPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        final currentUid = _auth.currentUser?.uid;
        if (currentUid != _lastObservedUserUid) {
          _lastObservedUserUid = currentUid;
          _listenToUserCredits();
          unawaited(_maybeCheckStarterCredits());
        }
      });
    } else {
      _authSubscription = _auth.authStateChanges().listen((_) {
        _listenToUserCredits();
        unawaited(_maybeCheckStarterCredits());
      });
    }

    // NOTE: We intentionally do NOT run restorePurchases on app startup.
    // Doing so can replay old/stuck purchases and surface verification errors
    // (storeError) before the user even opens the purchase UI.
    // Cleanup is triggered when the user starts a purchase (buyCredit) and
    // when handling already-owned errors.
  }

  void _scheduleDeviceIdRetry() {
    if (_deviceId != null && _deviceId!.trim().isNotEmpty) return;
    if (_deviceIdRetryCount >= _maxDeviceIdRetries) return;
    if (_deviceIdRetryTimer?.isActive ?? false) return;

    final seconds = min(120, 2 * (1 << _deviceIdRetryCount));
    _deviceIdRetryCount++;
    _deviceIdRetryTimer = Timer(Duration(seconds: seconds), () {
      unawaited(_initDeviceId());
    });
  }

  Future<void> _maybeCheckStarterCredits({bool silent = true}) async {
    if (_starterCreditsCheckTriggered) return;
    if (_deviceId == null) return;
    // Starter credits are granted server-side; require Firebase Auth (anonymous is OK).
    if (_auth.currentUser == null) return;

    _starterCreditsCheckTriggered = true;
    await checkAndGiveStarterCredits(silent: silent);
  }
  static String _generateInstallId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    // URL-safe, compact.
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<String?> _loadOrCreateIosKeychainId() async {
    try {
      const storage = FlutterSecureStorage();
      final existing = await storage.read(key: 'keychain_install_id');
      if (existing != null && existing.trim().isNotEmpty) {
        return existing.trim();
      }
      final created = _generateInstallId();
      await storage.write(key: 'keychain_install_id', value: created);
      return created;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _loadOrCreateInstallId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('install_id');
      if (existing != null && existing.trim().isNotEmpty) {
        return existing.trim();
      }
      final created = _generateInstallId();
      await prefs.setString('install_id', created);
      return created;
    } catch (_) {
      // If prefs fail, fall back to device_info values.
      return null;
    }
  }

  String _sanitizeProductTitle(String title) {
    // Play/App Store titles often include app name in parentheses.
    final idx = title.indexOf('(');
    if (idx > 0) return title.substring(0, idx).trim();
    return title.trim();
  }

  Future<ProductDetails?> _getProductDetails(String productId) async {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      final response = await _iap.queryProductDetails({productId});
      if (response.error != null) {
        onLog?.call(
          'log_iap_single_query_error',
          jsonEncode({'error': response.error?.message ?? ''}),
        );
      }
      if (response.productDetails.isNotEmpty) {
        return response.productDetails.first;
      }
      return null;
    }
  }

  Future<void> _maybeCleanupStuckAndroidPurchases() async {
    if (!Platform.isAndroid) return;
    if (_purchaseCleanupStarted) return;
    _purchaseCleanupStarted = true;

    try {
      onLog?.call('log_iap_restore_cleanup_start');
      // This does not require user interaction on Android; it just replays existing
      // unconsumed purchases through the purchaseStream as "restored".
      await _iap.restorePurchases();
      onLog?.call('log_iap_restore_cleanup_done');
    } catch (e) {
      onLog?.call(
          'log_iap_cleanup_failed', jsonEncode({'error': e.toString()}));
    }
  }

  Future<void> _consumeAndroidPurchaseIfPossible(
      PurchaseDetails purchaseDetails) async {
    if (!Platform.isAndroid) return;

    // Without platform-specific Android billing APIs, rely on completePurchase
    // and restore flow; this is a no-op best-effort hook.
    onLog?.call(
      'log_iap_consume_skipped',
      jsonEncode({'productId': purchaseDetails.productID}),
    );
  }

  Future<bool> _recoverAndroidAlreadyOwnedConsumable(
      CreditPackage package) async {
    if (!Platform.isAndroid) return false;

    try {
      onLog?.call(
        'log_iap_already_owned_recovery_start',
        jsonEncode({'productId': package.productId}),
      );
      await _iap.restorePurchases();
      onLog?.call('log_iap_already_owned_recovery_done');
      return true;
    } catch (e) {
      onLog?.call('log_iap_already_owned_cleanup_failed',
          jsonEncode({'error': e.toString()}));
      return false;
    }
  }

  Future<void> _initDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final androidId = androidInfo.id;
        _deviceId = (androidId.trim().isNotEmpty)
            ? androidId.trim()
            : await _loadOrCreateInstallId();
      } else if (Platform.isIOS) {
        // Prefer Keychain-backed ID: survives reinstalls.
        final keychainId = await _loadOrCreateIosKeychainId();
        if (keychainId != null && keychainId.trim().isNotEmpty) {
          _deviceId = keychainId.trim();
        } else {
          final iosInfo = await deviceInfo.iosInfo;
          _deviceId = iosInfo.identifierForVendor;
        }
      } else {
        // Desktop/web: per-install is acceptable.
        _deviceId = await _loadOrCreateInstallId();
      }

      if (_deviceId == null || _deviceId!.trim().isEmpty) {
        _scheduleDeviceIdRetry();
        return;
      }

      // Success: stop retrying.
      _deviceIdRetryTimer?.cancel();
      _deviceIdRetryTimer = null;
      _deviceIdRetryCount = 0;

      _listenToUserCredits();
      unawaited(_maybeCheckStarterCredits());
    } catch (e) {
      onLog?.call('log_device_id_failed', jsonEncode({'error': e.toString()}));
      _scheduleDeviceIdRetry();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _creditsSubscription?.cancel();
    _authSubscription?.cancel();
    _creditsPollTimer?.cancel();
    _authPollTimer?.cancel();
    _starterCreditsRetryTimer?.cancel();
    _deviceIdRetryTimer?.cancel();
    _purchaseSuccessController.close();
    super.dispose();
  }

  void _scheduleStarterCreditsRetry({required bool silent}) {
    if (_starterCreditsRetryCount >= _maxStarterCreditsRetries) return;
    if (_starterCreditsRetryTimer?.isActive ?? false) return;

    // Exponential backoff with a reasonable cap.
    final seconds = min(120, 5 * (1 << _starterCreditsRetryCount));
    _starterCreditsRetryCount++;
    _starterCreditsRetryTimer = Timer(Duration(seconds: seconds), () {
      // Allow a future attempt.
      _starterCreditsCheckTriggered = false;
      unawaited(_maybeCheckStarterCredits(silent: silent));
    });
  }

  void _listenToUserCredits() {
    _creditsSubscription?.cancel();
    _creditsPollTimer?.cancel();
    _initialCreditsLoaded = false;

    final user = _auth.currentUser;
    if (user != null) {
      final listenedUid = user.uid;

      // Windows'da bazı cloud_firestore sürümlerinde realtime stream callback'leri
      // platform thread dışında gelebiliyor (engine warning + olası crash riski).
      // Bu yüzden Windows desktop'ta kredi takibini polling ile sürdürüyoruz.
      if (!kIsWeb && Platform.isWindows) {
        _startCreditsPollingForUser(listenedUid);
        unawaited(_refreshUserCreditsOnce(listenedUid));
        return;
      }

      _creditsSubscription = _firestore
          .collection('users')
          .doc(listenedUid)
          .snapshots()
          .listen((snapshot) {
        _applyCreditsFromUserSnapshot(snapshot.data());
      }, onError: (e) {
        final currentUid = _auth.currentUser?.uid;
        final isPermissionDenied =
            e.toString().toLowerCase().contains('permission-denied');

        // During anonymous->Google transitions, old listener can briefly throw
        // permission-denied for the previous UID. Rebind instead of noisy logs.
        if (isPermissionDenied &&
            currentUid != null &&
            currentUid != listenedUid) {
          _listenToUserCredits();
          return;
        }

        onLog?.call(
            'log_credit_listen_error', jsonEncode({'error': e.toString()}));
        _startCreditsPollingForUser(currentUid ?? listenedUid);
        notifyListeners();
      });

      // Immediate load for first paint before the first stream event arrives.
      unawaited(_refreshUserCreditsOnce(listenedUid));
    } else {
      _purchasedCredits = 0;
      _legacyFlatRateRemaining = 0;
      _tokenBalance = 0;
      _creditPolicy = '';
      // Keep device credits (starter bonus) even if auth is not ready.
      // Bonus is device-scoped and should be visible on first open.
      _recomputeTotalCredits();
      notifyListeners();
    }
  }

  void _startCreditsPollingForUser(String uid) {
    _creditsPollTimer?.cancel();
    _creditsPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refreshUserCreditsOnce(uid));
    });
  }

  void _applyCreditsFromUserSnapshot(Map<String, dynamic>? data) {
    final purchasedA = _asInt(data?['purchasedCredits']);
    final purchasedB = _asInt(data?['credits']);
    final newPurchasedCredits = max(purchasedA, purchasedB);

    if (_initialCreditsLoaded) {
      if (newPurchasedCredits > _purchasedCredits) {
        _purchaseSuccessController.add(null);
      }
    } else {
      _initialCreditsLoaded = true;
    }

    _purchasedCredits = newPurchasedCredits;
    _legacyFlatRateRemaining = max(_asInt(data?['legacyFlatRateRemaining']), 0);
    _tokenBalance = max(_asInt(data?['tokenBalance']), 0);
    _creditPolicy = (data?['creditPolicy'] as String?)?.trim() ?? '';
    if (!usesTokenWallet) {
      _legacyFlatRateRemaining = _purchasedCredits;
    }
    _recomputeTotalCredits();
    notifyListeners();
  }

  Future<void> _refreshUserCreditsOnce(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();

      if (_auth.currentUser?.uid != uid) {
        return;
      }

      if (snapshot.exists) {
        _applyCreditsFromUserSnapshot(snapshot.data());
      } else {
        _purchasedCredits = 0;
        _legacyFlatRateRemaining = 0;
        _tokenBalance = 0;
        _creditPolicy = '';
        _legacyFlatRateRemaining = 0;
        _tokenBalance = 0;
        _creditPolicy = '';
        _recomputeTotalCredits();
        notifyListeners();
      }
    } catch (e) {
      final isPermissionDenied =
          e.toString().toLowerCase().contains('permission-denied');
      if (isPermissionDenied && _auth.currentUser?.uid != uid) {
        return;
      }
      onLog?.call(
          'log_credit_listen_error', jsonEncode({'error': e.toString()}));
    }
  }

  void _recomputeTotalCredits() {
    final paidDisplay = usesTokenWallet ? _legacyFlatRateRemaining : _purchasedCredits;
    _userCredits = paidDisplay;
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<String> _currentAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.trim();
    } catch (_) {
      return '';
    }
  }

  bool get _supportsFunctionsPlugin =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _callCloudFunction(
    String name,
    Map<String, dynamic> payload,
  ) async {
    if (_supportsFunctionsPlugin) {
      final callable = _functions.httpsCallable(name);
      final result = await callable.call(payload);
      return _asMap(result.data);
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('unauthenticated');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('auth-token-unavailable');
    }

    final projectId = _functions.app.options.projectId;
    final uri =
        Uri.parse('https://us-central1-$projectId.cloudfunctions.net/$name');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'data': payload}),
    );

    Map<String, dynamic> decoded;
    try {
      decoded = _asMap(jsonDecode(response.body));
    } catch (_) {
      throw Exception(
          'functions-http-${response.statusCode}: ${response.body}');
    }

    if (decoded.containsKey('error') && decoded['error'] != null) {
      final errorMap = _asMap(decoded['error']);
      final status = errorMap['status']?.toString() ?? 'unknown';
      final message = errorMap['message']?.toString() ?? response.body;
      throw Exception('$status: $message');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'functions-http-${response.statusCode}: ${response.body}');
    }

    return _asMap(decoded['result']);
  }

  /// Cloud Function üzerinden kredi düşme
  Future<void> consumeCredit(
    int amount, {
    String? reason,
    String? chargeKey,
    String? fileName,
    String? targetLanguage,
    String? platform,
  }) async {
    try {
      if (_deviceId == null || _deviceId!.trim().isEmpty) return;

      String resolvePlatform() {
        final override = platform?.trim();
        if (override != null && override.isNotEmpty) return override.toLowerCase();
        if (kIsWeb) return 'web';
        if (Platform.isAndroid) return 'android';
        if (Platform.isIOS) return 'ios';
        if (Platform.isWindows) return 'windows';
        if (Platform.isMacOS) return 'macos';
        if (Platform.isLinux) return 'linux';
        return Platform.operatingSystem.toLowerCase();
      }

      final beforePurchased = _purchasedCredits;
      final beforeDevice = _deviceCredits;
      final beforeTotal = _userCredits;
      final appVersion = await _currentAppVersion();

      final data = await _callCloudFunction('consumeCredit', {
        'amount': amount,
        'deviceId': _deviceId,
        'reason': reason ?? 'usage',
        'platform': resolvePlatform(),
        if (appVersion.isNotEmpty) 'appVersion': appVersion,
        if (chargeKey != null && chargeKey.trim().isNotEmpty) 'chargeKey': chargeKey.trim(),
        if (fileName != null && fileName.trim().isNotEmpty) 'fileName': fileName.trim(),
        if (targetLanguage != null && targetLanguage.trim().isNotEmpty) 'targetLanguage': targetLanguage.trim(),
      });

      if (data['success'] == true) {
        if (data.containsKey('remainingPurchasedCredits')) {
          _purchasedCredits = _asInt(data['remainingPurchasedCredits']);
        }
        if (data.containsKey('remainingLegacyFlatRateRemaining')) {
          _legacyFlatRateRemaining =
              _asInt(data['remainingLegacyFlatRateRemaining']);
        }
        if (data.containsKey('remainingTokenBalance')) {
          _tokenBalance = _asInt(data['remainingTokenBalance']);
        }
        if (data.containsKey('remainingDeviceCredits')) {
          _deviceCredits = _asInt(data['remainingDeviceCredits']);
        }
        _recomputeTotalCredits();

        final afterTotal = _userCredits;
        final consumed = max(0, beforeTotal - afterTotal);
        // Log exactly when credit is actually deducted.
        if (consumed > 0) {
          onLog?.call(
            'log_credit_consumed',
            jsonEncode({
              // Keep key name as {amount} for existing template; value is the actual deducted amount.
              'amount': consumed,
              'requested': amount,
              'remaining': afterTotal,
              'reason': reason ?? 'usage',
              'before': {
                'purchased': beforePurchased,
                'device': beforeDevice,
                'total': beforeTotal,
              },
              'after': {
                'purchased': _purchasedCredits,
                'device': _deviceCredits,
                'total': afterTotal,
              },
            }),
          );
        }

        notifyListeners();
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        final message = (e.message ?? '').toLowerCase();
        if (message.contains('first chunk')) {
          onLog?.call('log_first_chunk_not_approved');
          throw Exception('İlk chunk onayı bekleniyor');
        }
        onLog?.call('log_insufficient_credit');
        // Keep wording consistent with other credit checks in the app.
        throw Exception('Yetersiz Bakiye');
      } else {
        onLog?.call(
          'log_credit_consume_failed',
          jsonEncode({'error': e.message ?? ''}),
        );
        rethrow;
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('first chunk')) {
        onLog?.call('log_first_chunk_not_approved');
        throw Exception('İlk chunk onayı bekleniyor');
      }
      if (msg.contains('failed_precondition') ||
          msg.contains('failed-precondition') ||
          msg.contains('insufficient')) {
        onLog?.call('log_insufficient_credit');
        throw Exception('Yetersiz Bakiye');
      }
      onLog?.call('log_unexpected_error', jsonEncode({'error': e.toString()}));
      rethrow;
    }
  }

  Future<void> fetchPackages({bool silent = false}) async {
    try {
      _isStoreLoading = true;
      _storeError = null;
      notifyListeners();

      if (!silent) {
        onLog?.call('log_iap_packages_loading');
      }

      if (!_isIapSupportedPlatform) {
        if (!silent) {
          onLog?.call('log_iap_platform_unsupported');
        }
        _isStoreLoading = false;
        notifyListeners();
        return;
      }

      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate();

      String jsonString = remoteConfig.getString('credit_packages');
      if (jsonString.isNotEmpty) {
        List<dynamic> jsonList = jsonDecode(jsonString);
        _packages = jsonList.map((e) => CreditPackage.fromJson(e)).toList();

        if (!silent) {
          onLog?.call(
            'log_iap_packages_loaded',
            jsonEncode({'count': _packages.length}),
          );
        }

        if (await _iap.isAvailable()) {
          if (!silent) {
            onLog?.call('log_iap_store_available');
          }
          final Set<String> ids = _packages.map((e) => e.productId).toSet();
          if (ids.isNotEmpty) {
            final ProductDetailsResponse response =
                await _iap.queryProductDetails(ids);
            _products = response.productDetails;

            if (response.error != null) {
              onLog?.call(
                'log_iap_query_product_error',
                jsonEncode({'error': response.error?.message ?? ''}),
              );
            }

            if (!silent) {
              onLog?.call(
                'log_iap_product_details_loaded',
                jsonEncode({
                  'count': _products.length,
                  'notFound': response.notFoundIDs.length,
                }),
              );
            }
            for (var product in _products) {
              for (var pkg in _packages) {
                if (pkg.productId == product.id) {
                  pkg.price = product.price;
                  pkg.rawPrice = product.rawPrice;
                  pkg.currencySymbol = product.currencySymbol;
                  pkg.localizedTitle = _sanitizeProductTitle(product.title);
                  pkg.localizedDescription = product.description;
                }
              }
            }
          }
        } else {
          onLog?.call('log_iap_store_unavailable');
        }
      } else {
        onLog?.call('log_iap_remote_config_empty');
      }
    } catch (e, stackTrace) {
      _storeError = "Mağaza bağlantısı kurulamadı.";
      onLog?.call(
        'log_iap_store_data_failed',
        jsonEncode({'error': e.toString(), 'stack': stackTrace.toString()}),
      );
    } finally {
      _isStoreLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkAndGiveStarterCredits({bool silent = false}) async {
    // The server expects Firebase Auth.
    if (_auth.currentUser == null) return;

    if (_isDesktopPlatform) {
      // Desktop does not spend bonus buckets, but login/purchase bonuses may still be granted server-side.
      try {
        final data = await _callCloudFunction('giveStarterCredits', {
          'deviceId': _deviceId ?? 'desktop_client',
          'platform': Platform.isWindows
              ? 'windows'
              : (Platform.isMacOS
                  ? 'macos'
                  : (Platform.isLinux ? 'linux' : 'windows')),
          'appVersion': await _currentAppVersion(),
        });

        if (data.containsKey('purchasedCredits')) {
          _purchasedCredits = _asInt(data['purchasedCredits']);
        }
        _recomputeTotalCredits();

        final bonusAmount = _asInt(data['bonusAmount'] ?? 0);
        if (bonusAmount > 0 && !silent) {
          onLog?.call(
            'log_iap_starter_bonus_given',
            jsonEncode({'amount': bonusAmount}),
          );
        }
      } catch (e) {
        debugPrint('Desktop starter credit check failed: $e');
      }

      _starterCreditsRetryTimer?.cancel();
      _starterCreditsRetryTimer = null;
      _starterCreditsRetryCount = 0;
      _starterCreditsCheckTriggered = true;
      return;
    }

    if (_deviceId == null) return;
    // The server expects Firebase Auth (anonymous is OK).
    if (_auth.currentUser == null) return;

    try {
      final data = await _callCloudFunction('giveStarterCredits', {
        'deviceId': _deviceId,
        'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : Platform.operatingSystem.toLowerCase()),
        'appVersion': await _currentAppVersion(),
      });

      if (data.containsKey('deviceCredits')) {
        _deviceCredits = _asInt(data['deviceCredits']);
      }
      _recomputeTotalCredits();

      final bonusAmount = _asInt(data['bonusAmount'] ?? 0);
      if (bonusAmount > 0 && !silent) {
        onLog?.call(
            'log_starter_credits_added', jsonEncode({'amount': bonusAmount}));
      }

      // Success: stop retrying.
      _starterCreditsRetryTimer?.cancel();
      _starterCreditsRetryTimer = null;
      _starterCreditsRetryCount = 0;
      notifyListeners();
    } on FirebaseFunctionsException catch (e) {
      // Don't permanently give up on first launch; network/auth/App Check transitions
      // can cause one-off failures.
      onLog?.call(
        'log_starter_credits_failed',
        jsonEncode({
          'error': '${e.code}: ${e.message ?? 'unknown'}',
          'code': e.code,
          'message': e.message ?? '',
        }),
      );
      _starterCreditsCheckTriggered = false;
      _scheduleStarterCreditsRetry(silent: silent);
    } catch (e) {
      onLog?.call(
          'log_starter_credits_failed', jsonEncode({'error': e.toString()}));
      _starterCreditsCheckTriggered = false;
      _scheduleStarterCreditsRetry(silent: silent);
    }
  }

  /// Cloud Function üzerinden kredi ekleme
  /// Returns an internal outcome code:
  ///  - [_addCreditsOutcomeSuccess]
  ///  - [_addCreditsOutcomeAlreadyProcessed]
  ///  - [_addCreditsOutcomeFailed]
  Future<int> addCredits(int amount,
      {String? purchaseId, String? productId, String? purchaseToken}) async {
    try {
      final data = await _callCloudFunction('addCredits', {
        'amount': amount,
        'purchaseId': purchaseId,
        'productId': productId,
        'purchaseToken': purchaseToken,
        'trackAsPurchased': true,
      });

      if (data['success'] == true) {
        if (data.containsKey('newCredits')) {
          _purchasedCredits = _asInt(data['newCredits']);
          _recomputeTotalCredits();
        }

        onLog?.call('log_payment_success', jsonEncode({'amount': amount}));
        _purchaseSuccessController.add(null);
        notifyListeners();
        return _addCreditsOutcomeSuccess;
      }
      return _addCreditsOutcomeFailed;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        onLog?.call('log_purchase_already_processed');
        _storeError =
            'Bu satın alma daha önce işlendi. Lütfen farklı bir paket seçin veya daha sonra tekrar deneyin.';
        notifyListeners();
        return _addCreditsOutcomeAlreadyProcessed;
      } else {
        onLog?.call(
            'log_credit_add_failed', jsonEncode({'error': e.message ?? ''}));
        _storeError = 'Kredi yüklenemedi: ${e.message}';
      }
      notifyListeners();
      return _addCreditsOutcomeFailed;
    } catch (e, stackTrace) {
      onLog?.call(
        'log_unexpected_error_with_stack',
        jsonEncode({'error': e.toString(), 'stack': stackTrace.toString()}),
      );
      _storeError = 'Satın alma sırasında bir hata oluştu.';
      notifyListeners();
      return _addCreditsOutcomeFailed;
    }
  }

  Future<void> transferDeviceCreditsToGoogleAccount(String googleUserId) async {
    if (_deviceId == null) return;
    try {
      // Do not trust client-side transactions for credit movement.
      // This operation is performed on the server to prevent tampering.
      final data =
          await _callCloudFunction('transferDeviceCreditsToGoogleAccount', {
        'deviceId': _deviceId,
        // googleUserId is ignored server-side; server uses request.auth.uid.
      });
      if (data['success'] == true) {
        final transferred = data['transferred'] ?? 0;
        onLog?.call('log_credit_transfer_complete',
            jsonEncode({'amount': transferred}));
      } else {
        final msg = data['message']?.toString() ?? 'Transfer yapılmadı.';
        onLog?.call(
            'log_credit_transfer_message', jsonEncode({'message': msg}));
      }

      _listenToUserCredits();
    } catch (e, stackTrace) {
      onLog?.call(
        'log_credit_transfer_failed',
        jsonEncode({'error': e.toString(), 'stack': stackTrace.toString()}),
      );
    }
  }

  Future<List<Map<String, dynamic>>> getPurchaseHistory() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('purchase_history')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e, stackTrace) {
      onLog?.call(
        'log_purchase_history_failed',
        jsonEncode({'error': e.toString(), 'stack': stackTrace.toString()}),
      );
      return [];
    }
  }

  Future<void> buyCredit(CreditPackage package) async {
    if (!_isIapSupportedPlatform) {
      _storeError =
          'Kredi satın alma bu platformda kapalı. Krediyi mobil uygulamadan yükleyip bu uygulamada harcayabilirsiniz.';
      notifyListeners();
      return;
    }

    final user = _auth.currentUser;
    final isGoogleUser = user != null && !user.isAnonymous;

    if (!isGoogleUser) {
      _storeError = "Kredi satın almak için Google ile giriş yapmalısınız.";
      onLog?.call('log_purchase_google_required');
      notifyListeners();
      return;
    }

    try {
      _isPurchasing = true;
      _activePurchasePackage = package;
      _alreadyOwnedRetried = false;
      notifyListeners();

      // onLog?.call(
      //   'log_info',
      //   '[IAP] Satın alma başlatılıyor (productId=${package.productId}, credits=${package.credits}).',
      // );

      // Best-effort cleanup before starting a new purchase so users can repurchase
      // without ever seeing "already owned".
      await _maybeCleanupStuckAndroidPurchases();
      final productDetails = await _getProductDetails(package.productId);

      if (productDetails != null) {
        // onLog?.call(
        //   'log_info',
        //   '[IAP] ProductDetails bulundu (title=${productDetails.title}, price=${productDetails.price}).',
        // );
        final PurchaseParam purchaseParam =
            PurchaseParam(productDetails: productDetails);
        try {
          final started = await _iap.buyConsumable(
            purchaseParam: purchaseParam,
            // Consumable credit packs: allow repeated purchases.
            // Using autoConsume avoids Google Play keeping the item as "owned"
            // when our manual consume/cleanup misses edge cases.
            autoConsume: true,
          );
          // onLog?.call('log_info', '[IAP] buyConsumable çağrıldı (started=$started).');
          if (!started) {
            _storeError = 'Satın alma başlatılamadı. Lütfen tekrar deneyin.';
            _isPurchasing = false;
            notifyListeners();
          }
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('already owned') ||
              msg.contains('item_already_owned') ||
              msg.contains('itemalreadyowned') ||
              msg.contains('item already owned')) {
            // Bu hata genelde tüketilmemiş (consume edilmemiş) önceki satın alma yüzünden olur.
            // Otomatik temizle + aynı paketi tekrar satın almayı dene.
            onLog?.call('log_iap_already_owned_detected');
            _storeError = 'Önceki satın alma temizleniyor. Lütfen bekleyin...';
            notifyListeners();

            final recovered =
                await _recoverAndroidAlreadyOwnedConsumable(package);
            if (recovered) {
              onLog?.call('log_iap_cleanup_done_retry');
              try {
                final startedRetry = await _iap.buyConsumable(
                  purchaseParam: purchaseParam,
                  autoConsume: true,
                );
                // onLog?.call('log_info', '[IAP] buyConsumable retry çağrıldı (started=$startedRetry).');
                if (!startedRetry) {
                  _storeError =
                      'Satın alma başlatılamadı. Lütfen tekrar deneyin.';
                } else {
                  _storeError = null;
                }
              } catch (e2) {
                _storeError = 'Satın alma yeniden başlatılamadı: $e2';
                onLog?.call('log_iap_retry_failed',
                    jsonEncode({'error': e2.toString()}));
              }
            } else {
              _storeError =
                  'Önceki satın alma temizlenemedi. Biraz sonra tekrar deneyin.';
              onLog?.call('log_iap_cleanup_failed_wait');
            }

            _isPurchasing = false;
            notifyListeners();
            return;
          }
          onLog?.call('log_iap_buy_consumable_error',
              jsonEncode({'error': e.toString()}));
          rethrow;
        }
      } else {
        onLog?.call(
          'log_iap_product_not_found',
          jsonEncode({'productId': package.productId}),
        );
        _isPurchasing = false;
        _activePurchasePackage = null;
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _storeError = "Satın alma başlatılamadı: $e";
      onLog?.call(
        'log_iap_purchase_start_failed',
        jsonEncode({'error': e.toString(), 'stack': stackTrace.toString()}),
      );
      _isPurchasing = false;
      _activePurchasePackage = null;
      notifyListeners();
    }
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      // onLog?.call(
      //   'log_info',
      //   '[IAP] purchaseStream event (status=${purchaseDetails.status}, productId=${purchaseDetails.productID}, purchaseId~=$purchaseIdShort, pendingComplete=${purchaseDetails.pendingCompletePurchase}).',
      // );

      if (purchaseDetails.status == PurchaseStatus.pending) {
        // onLog?.call('log_info', 'İşlem bekleniyor...');
        _isPurchasing = true;
        notifyListeners();
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _storeError = "Hata: ${purchaseDetails.error?.message}";
        onLog?.call(
          'log_iap_purchase_error',
          jsonEncode({'error': purchaseDetails.error?.message ?? ''}),
        );

        final errMsg = (purchaseDetails.error?.message ?? '').toLowerCase();
        if (errMsg.contains('already owned') ||
            errMsg.contains('item_already_owned') ||
            errMsg.contains('itemalreadyowned') ||
            errMsg.contains('item already owned')) {
          // Android: This error often comes via purchaseStream (not thrown by buyConsumable).
          // Try to recover by consuming the previous purchase and retrying ONCE.
          await _maybeCleanupStuckAndroidPurchases();

          if (Platform.isAndroid &&
              _activePurchasePackage != null &&
              !_alreadyOwnedRecoveryInProgress &&
              !_alreadyOwnedRetried) {
            _alreadyOwnedRecoveryInProgress = true;
            _alreadyOwnedRetried = true;

            try {
              onLog?.call(
                'log_iap_stream_already_owned_recovery_start',
              );
              _storeError =
                  'Önceki satın alma temizleniyor. Lütfen bekleyin...';
              _isPurchasing = true;
              notifyListeners();

              final pkg = _activePurchasePackage!;
              final recovered =
                  await _recoverAndroidAlreadyOwnedConsumable(pkg);
              if (recovered) {
                final productDetails = await _getProductDetails(pkg.productId);
                if (productDetails != null) {
                  final PurchaseParam purchaseParam =
                      PurchaseParam(productDetails: productDetails);
                  final startedRetry = await _iap.buyConsumable(
                    purchaseParam: purchaseParam,
                    autoConsume: true,
                  );
                  // onLog?.call(
                  //   'log_info',
                  //   '[IAP] buyConsumable retry (purchaseStream) çağrıldı (started=$startedRetry).',
                  // );
                  if (!startedRetry) {
                    _storeError =
                        'Satın alma başlatılamadı. Lütfen tekrar deneyin.';
                    _isPurchasing = false;
                  } else {
                    _storeError = null;
                    _isPurchasing = true;
                  }
                } else {
                  _storeError =
                      'Ürün bilgisi bulunamadı. Lütfen tekrar deneyin.';
                  _isPurchasing = false;
                }
              } else {
                _storeError =
                    'Önceki satın alma temizlenemedi. Biraz sonra tekrar deneyin.';
                _isPurchasing = false;
              }
            } catch (e) {
              _storeError = 'Önceki satın alma temizlenemedi: $e';
              _isPurchasing = false;
              onLog?.call(
                'log_iap_stream_already_owned_recovery_failed',
                jsonEncode({'error': e.toString()}),
              );
            } finally {
              _alreadyOwnedRecoveryInProgress = false;
              notifyListeners();
            }

            return;
          }
        }

        _isPurchasing = false;
        _activePurchasePackage = null;
        notifyListeners();
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        _isPurchasing = false;
        _activePurchasePackage = null;
        notifyListeners();
      } else if (purchaseDetails.status == PurchaseStatus.restored) {
        // Android: restorePurchases replays unconsumed purchases.
        // We should attempt to grant credits (idempotent server-side) and only
        // then complete/consume. Do NOT affect active purchase UI state here.

        if (_packages.isEmpty) {
          await fetchPackages(silent: true);
        }

        int outcome = _addCreditsOutcomeFailed;
        for (var pkg in _packages) {
          if (pkg.productId == purchaseDetails.productID) {
            // onLog?.call(
            //   'log_info',
            //   '[IAP] (restored) Ürün paketi eşleşti (credits=${pkg.credits}). addCredits çağrılıyor...',
            // );
            outcome = await addCredits(
              pkg.credits,
              purchaseId: purchaseDetails.purchaseID,
              productId: pkg.productId,
              purchaseToken:
                  purchaseDetails.verificationData.serverVerificationData,
            );
            break;
          }
        }

        final handled = outcome == _addCreditsOutcomeSuccess ||
            outcome == _addCreditsOutcomeAlreadyProcessed;

        if (!handled) {
          onLog?.call(
            'log_iap_restored_server_unhandled',
            jsonEncode({'outcome': outcome.toString()}),
          );
          continue;
        }

        if (purchaseDetails.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchaseDetails);
            // onLog?.call('log_info', '[IAP] completePurchase ok (restored).');
          } catch (e) {
            onLog?.call(
              'log_iap_complete_failed_restored',
              jsonEncode({'error': e.toString()}),
            );
          }
        }

        await _consumeAndroidPurchaseIfPossible(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.purchased) {
        if (_packages.isEmpty) {
          await fetchPackages();
        }

        int outcome = _addCreditsOutcomeFailed;
        for (var pkg in _packages) {
          if (pkg.productId == purchaseDetails.productID) {
            // onLog?.call('log_info', '[IAP] Ürün paketi eşleşti (credits=${pkg.credits}). addCredits çağrılıyor...');
            outcome = await addCredits(
              pkg.credits,
              purchaseId: purchaseDetails.purchaseID,
              productId: pkg.productId,
              purchaseToken:
                  purchaseDetails.verificationData.serverVerificationData,
            );
            break;
          }
        }

        final handled = outcome == _addCreditsOutcomeSuccess ||
            outcome == _addCreditsOutcomeAlreadyProcessed;

        if (outcome == _addCreditsOutcomeSuccess) {
          // onLog?.call('log_info', 'Kredi başarıyla eklendi.');
        }

        if (outcome == _addCreditsOutcomeAlreadyProcessed) {
          onLog?.call('log_iap_server_already_processed');
        }

        if (handled) {
          if (purchaseDetails.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchaseDetails);
              // onLog?.call('log_info', '[IAP] completePurchase ok.');
            } catch (e) {
              onLog?.call(
                'log_iap_complete_failed',
                jsonEncode({
                  'productId': purchaseDetails.productID,
                  'error': e.toString()
                }),
              );
            }
          } else {
            // onLog?.call('log_info', '[IAP] pendingCompletePurchase=false, completePurchase atlandı.');
          }

          // IMPORTANT (Android): This is a consumable. If it is not consumed,
          // Google Play may keep it as "owned" and future purchases fail with
          // BillingResponse.itemAlreadyOwned.
          // With buyConsumable(autoConsume: true) most purchases will be auto-consumed
          // as part of the platform flow, but we still do a best-effort manual consume
          // to clean up restored/stuck purchases and edge cases.
          await _consumeAndroidPurchaseIfPossible(purchaseDetails);
        } else {
          onLog?.call(
            'log_iap_credit_add_failed',
            jsonEncode({'outcome': outcome.toString()}),
          );
        }

        _isPurchasing = false;
        _activePurchasePackage = null;
        notifyListeners();
      }
    }
  }
}
