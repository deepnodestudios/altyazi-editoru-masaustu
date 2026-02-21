import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_dartio/google_sign_in_dartio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart';

import '../cloud_oauth_config.dart';
import '../models/cloud_file_info.dart';
import '../managers/cloud_state_manager.dart';
import '../utils/file_encoding_utils.dart';

class CloudStorageService {
  final CloudStateManager _cloudStateManager;

  // Callback for logging
  Function(String key, [String? param])? onLog;

  /// Callback that returns the current UI translation map.
  Map<String, String> Function()? onGetTranslations;

  // Dependencies
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Secure storage (Keychain/Keystore/Credential Vault depending on platform)
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<void>? _secureMigrationFuture;
  late final Future<void> _preferencesLoadFuture;

  // Preferences keys
  static const String _prefsDropboxClientIdOverride =
      'oauth_override_dropbox_client_id';
  static const String _prefsGoogleOauthClientIdOverride =
      'oauth_override_google_oauth_client_id';
  static const String _prefsYandexClientIdOverride =
      'oauth_override_yandex_client_id';
  static const String _prefsYandexClientSecretOverride =
      'oauth_override_yandex_client_secret';

  static const String _prefsDropboxAccessToken = 'dropbox_access_token';
  static const String _prefsDropboxRefreshToken = 'dropbox_refresh_token';
  static const String _prefsDropboxExpiresAtMs = 'dropbox_expires_at_ms';

  static const String _prefsYandexAccessToken = 'yandex_access_token';
  static const String _prefsYandexRefreshToken = 'yandex_refresh_token';
  static const String _prefsYandexExpiresAtMs = 'yandex_expires_at_ms';

  static const String _prefsGoogleAccessToken = 'google_access_token';
  static const String _prefsGoogleRefreshToken = 'google_refresh_token';
  static const String _prefsGoogleIdToken = 'google_id_token';
  static const String _prefsGoogleExpiresAtMs = 'google_expires_at_ms';

  // Overrides
  String _overrideDropboxClientId = '';
  String _overrideGoogleOauthClientId = '';
  String _overrideYandexClientId = '';
  String _overrideYandexClientSecret = '';
  bool _remoteGoogleOauthClientResolved = false;
  DateTime? _lastRemoteGoogleOauthAttemptAt;
  bool _desktopGoogleSignInRegistered = false;

  CloudStorageService(this._cloudStateManager) {
    _preferencesLoadFuture = _loadPreferences();
  }

  void _debugCloud(String message) {
    if (!kDebugMode) return;
    debugPrint('[CloudStorageService] $message');
  }

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<String?> _promptForYandexAuthCode(
    BuildContext context, {
    required Uri authUri,
  }) async {
    final controller = TextEditingController();

    final trans = onGetTranslations?.call() ?? const <String, String>{};

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(trans['yandex_code_title'] ?? 'Yandex Disk Authorization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trans['yandex_code_help'] ??
                    'A browser window will open and show a confirmation code. Copy it and paste it here.',
              ),
              const SizedBox(height: 8),
              SelectableText(
                authUri.toString(),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: trans['yandex_code_label'] ?? 'Confirmation code',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(trans['btn_cancel'] ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(trans['btn_continue'] ?? 'Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _overrideDropboxClientId =
        prefs.getString(_prefsDropboxClientIdOverride) ?? '';
    _overrideGoogleOauthClientId =
        prefs.getString(_prefsGoogleOauthClientIdOverride) ?? '';
    _overrideYandexClientId =
        prefs.getString(_prefsYandexClientIdOverride) ?? '';
    _overrideYandexClientSecret =
        prefs.getString(_prefsYandexClientSecretOverride) ?? '';
  }

  Future<void> _tryLoadGoogleOauthClientIdFromRemoteConfig() async {
    if (_remoteGoogleOauthClientResolved) return;

    final now = DateTime.now();
    if (_lastRemoteGoogleOauthAttemptAt != null &&
        now.difference(_lastRemoteGoogleOauthAttemptAt!) <
            const Duration(seconds: 5)) {
      return;
    }
    _lastRemoteGoogleOauthAttemptAt = now;

    await _preferencesLoadFuture;

    try {
      final rc = FirebaseRemoteConfig.instance;

      try {
        await rc.setDefaults(<String, dynamic>{
          'google_desktop_client_id': '',
          'google_oauth_client_id': '',
          'google_client_id': '',
        });
      } catch (_) {}

      try {
        final minFetchInterval = _isDesktop
            ? const Duration(seconds: 10)
            : const Duration(hours: 1);
        await rc.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30),
          minimumFetchInterval: minFetchInterval,
        ));
      } catch (_) {}

      try {
        await rc.fetchAndActivate();
      } catch (_) {}

      String safeGetString(String key) {
        try {
          return _sanitizeOAuthValue(rc.getString(key));
        } catch (_) {
          return '';
        }
      }

        final fromDesktop = safeGetString('google_desktop_client_id');
      final fromPrimary = safeGetString('google_oauth_client_id');
      final fromLegacy = safeGetString('google_client_id');
      final fromWeb = safeGetString('google_web_client_id');
        final resolved = fromDesktop.isNotEmpty
          ? fromDesktop
          : (fromPrimary.isNotEmpty
            ? fromPrimary
            : (fromLegacy.isNotEmpty ? fromLegacy : fromWeb));

      if (resolved.isEmpty) {
        onLog?.call(
          'log_google_oauth_config_missing',
          jsonEncode({
            'checkedKeys': [
              'google_desktop_client_id',
              'google_oauth_client_id',
              'google_client_id',
              'google_web_client_id'
            ],
            'hasDesktop': fromDesktop.isNotEmpty,
            'hasPrimary': fromPrimary.isNotEmpty,
            'hasLegacy': fromLegacy.isNotEmpty,
            'hasWeb': fromWeb.isNotEmpty,
          }),
        );
        return;
      }

      _overrideGoogleOauthClientId = resolved;
      _remoteGoogleOauthClientResolved = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsGoogleOauthClientIdOverride, resolved);
    } catch (_) {
      // Best effort only; caller will show existing config-missing message.
    }
  }

  Future<void> _ensureSecureMigration() {
    return _secureMigrationFuture ??= _migrateOAuthTokensToSecureStorage();
  }

  Future<void> _ensureDesktopGoogleSignInRegistered() async {
    if (!_isDesktop || _desktopGoogleSignInRegistered) return;

    if (!hasGoogleOAuthConfig) {
      await _tryLoadGoogleOauthClientIdFromRemoteConfig();
    }

    if (!hasGoogleOAuthConfig) {
      throw Exception(
          'Google OAuth client id missing. On Windows, provide --dart-define=GOOGLE_OAUTH_CLIENT_ID=... (Remote Config is not available on this platform).');
    }

    try {
      await GoogleSignInDart.register(clientId: effectiveGoogleOauthClientId);
    } catch (e) {
      _debugCloud('GoogleSignInDart register skipped/failed: $e');
    }
    _desktopGoogleSignInRegistered = true;
  }

  Future<void> _migrateOAuthTokensToSecureStorage() async {
    // If older versions stored OAuth tokens in SharedPreferences (plaintext),
    // migrate them to secure storage once and wipe the plaintext values.
    final prefs = await SharedPreferences.getInstance();

    Future<void> migrateStringKey(String key) async {
      final v = prefs.getString(key);
      if (v == null || v.isEmpty) return;
      final existing = await _secureStorage.read(key: key);
      if (existing == null || existing.isEmpty) {
        await _secureStorage.write(key: key, value: v);
      }
      await prefs.remove(key);
    }

    Future<void> migrateIntKey(String key) async {
      final v = prefs.getInt(key);
      if (v == null) return;
      final existing = await _secureStorage.read(key: key);
      if (existing == null || existing.isEmpty) {
        await _secureStorage.write(key: key, value: v.toString());
      }
      await prefs.remove(key);
    }

    await migrateStringKey(_prefsDropboxAccessToken);
    await migrateStringKey(_prefsDropboxRefreshToken);
    await migrateIntKey(_prefsDropboxExpiresAtMs);

    await migrateStringKey(_prefsYandexAccessToken);
    await migrateStringKey(_prefsYandexRefreshToken);
    await migrateIntKey(_prefsYandexExpiresAtMs);
  }

  Future<String?> _secureRead(String key) async {
    return _secureStorage.read(key: key);
  }

  Future<int?> _secureReadInt(String key) async {
    final v = await _secureRead(key);
    if (v == null || v.isEmpty) return null;
    return int.tryParse(v);
  }

  Future<void> _secureWrite(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<void> _secureWriteInt(String key, int value) async {
    await _secureWrite(key, value.toString());
  }

  Future<void> _secureDelete(String key) async {
    await _secureStorage.delete(key: key);
  }

  // ============ GOOGLE AUTH ============

  GoogleSignInAccount? get googleUser => _googleSignIn.currentUser;

  Future<Map<String, dynamic>> _exchangeGoogleAuthCodeForTokens({
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    final tokenUri = Uri.https('oauth2.googleapis.com', '/token');
    final resp = await http.post(
      tokenUri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': code,
        'client_id': effectiveGoogleOauthClientId,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': codeVerifier,
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('Google token failed: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String?;
    final idToken = data['id_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    final expiresIn = int.tryParse('${data['expires_in'] ?? ''}') ?? 3600;

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Google token response missing access_token');
    }

    await _secureWrite(_prefsGoogleAccessToken, accessToken);
    await _secureWriteInt(
      _prefsGoogleExpiresAtMs,
      DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch,
    );

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureWrite(_prefsGoogleRefreshToken, refreshToken);
    }

    if (idToken != null && idToken.isNotEmpty) {
      await _secureWrite(_prefsGoogleIdToken, idToken);
    }

    return data;
  }

  Future<String?> _refreshGoogleAccessToken({
    required String refreshToken,
  }) async {
    final tokenUri = Uri.https('oauth2.googleapis.com', '/token');
    final resp = await http.post(
      tokenUri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': effectiveGoogleOauthClientId,
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('Google refresh failed: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String?;
    final idToken = data['id_token'] as String?;
    final expiresIn = int.tryParse('${data['expires_in'] ?? ''}') ?? 3600;

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Google refresh response missing access_token');
    }

    await _secureWrite(_prefsGoogleAccessToken, accessToken);
    await _secureWriteInt(
      _prefsGoogleExpiresAtMs,
      DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch,
    );

    if (idToken != null && idToken.isNotEmpty) {
      await _secureWrite(_prefsGoogleIdToken, idToken);
    }

    return accessToken;
  }

  Future<String?> _ensureDesktopGoogleAccessToken({
    required bool interactive,
  }) async {
    await _preferencesLoadFuture;
    await _ensureSecureMigration();

    final access = await _secureRead(_prefsGoogleAccessToken);
    final expiresAtMs = await _secureReadInt(_prefsGoogleExpiresAtMs);

    if (access != null && expiresAtMs != null) {
      final stillValid = DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
          .isAfter(DateTime.now().add(const Duration(minutes: 2)));
      if (stillValid) {
        return access;
      }
    }

    final refresh = await _secureRead(_prefsGoogleRefreshToken);
    if (refresh != null && refresh.isNotEmpty) {
      try {
        return await _refreshGoogleAccessToken(refreshToken: refresh);
      } catch (_) {}
    }

    if (!interactive) {
      return null;
    }

    if (!hasGoogleOAuthConfig) {
      await _tryLoadGoogleOauthClientIdFromRemoteConfig();
    }

    if (!hasGoogleOAuthConfig) {
      throw Exception(
          'Google OAuth client id missing. On Windows, provide --dart-define=GOOGLE_OAUTH_CLIENT_ID=... (Remote Config is not available on this platform).');
    }

    final verifier = _generateCodeVerifier();
    final challenge = _codeChallengeS256(verifier);
    const scopes = [
      'openid',
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
      'https://www.googleapis.com/auth/drive.readonly',
    ];

    final callbackServer =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final callbackUri =
        Uri.parse('http://127.0.0.1:${callbackServer.port}/oauth2redirect');

    final authUri = Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      {
        'client_id': effectiveGoogleOauthClientId,
        'redirect_uri': callbackUri.toString(),
        'response_type': 'code',
        'scope': scopes.join(' '),
        'access_type': 'offline',
        'prompt': 'consent',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );

    Uri returned;
    try {
      final opened = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('Could not open system browser for Google auth');
      }

      final req = await callbackServer.first.timeout(
        const Duration(minutes: 5),
      );
      returned = req.uri;

      const html = '''
<!doctype html>
<html><head><meta charset="utf-8"><title>Authentication Complete</title></head>
<body style="font-family:Segoe UI,Arial,sans-serif;padding:24px;">
  <h2>Google authentication completed.</h2>
  <p>You can close this tab and return to the app.</p>
</body></html>
''';
      req.response.headers.contentType = ContentType.html;
      req.response.write(html);
      await req.response.close();
    } finally {
      await callbackServer.close(force: true);
    }

    final error = returned.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      throw Exception('Google auth error: $error');
    }

    final code = returned.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('Google auth did not return code');
    }

    final tokenData = await _exchangeGoogleAuthCodeForTokens(
      code: code,
      codeVerifier: verifier,
      redirectUri: callbackUri.toString(),
    );

    return tokenData['access_token'] as String?;
  }

  Future<void> _signInWithGoogleDesktopFirebase({
    required User? currentUser,
    required Function(String uid)? onGoogleSignInSuccess,
  }) async {
    final accessToken =
        await _ensureDesktopGoogleAccessToken(interactive: true);
    final idToken = await _secureRead(_prefsGoogleIdToken);

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Google access token unavailable');
    }
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google id token unavailable');
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );

    final auth = FirebaseAuth.instance;
    late final UserCredential userCredential;
    if (currentUser != null && currentUser.isAnonymous) {
      try {
        userCredential = await currentUser.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          userCredential = await auth.signInWithCredential(credential);
        } else {
          rethrow;
        }
      }
    } else {
      userCredential = await auth.signInWithCredential(credential);
    }

    try {
      await userCredential.user?.reload();
    } catch (_) {}

    final signedInUser = userCredential.user;
    if (signedInUser == null) return;

    await _firestore.collection('users').doc(signedInUser.uid).set({
      'email': signedInUser.email,
      'displayName': signedInUser.displayName,
      'photoUrl': signedInUser.photoURL,
      'lastSignIn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (onGoogleSignInSuccess != null) {
      await onGoogleSignInSuccess(signedInUser.uid);
    }

    _cloudStateManager.setIsGDriveConnected(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_gdrive_connected', true);
    onLog?.call('log_gdrive_connected', signedInUser.email);
  }

  Future<void> _signInWithGoogleCredential({
    required User? currentUser,
    required AuthCredential credential,
    required Function(String uid)? onGoogleSignInSuccess,
    String? connectedIdentity,
  }) async {
    final auth = FirebaseAuth.instance;

    late final UserCredential userCredential;
    if (currentUser != null && currentUser.isAnonymous) {
      try {
        userCredential = await currentUser.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          userCredential = await auth.signInWithCredential(credential);
        } else {
          rethrow;
        }
      }
    } else {
      userCredential = await auth.signInWithCredential(credential);
    }

    final signedInUser = userCredential.user;
    if (signedInUser == null) return;

    await _firestore.collection('users').doc(signedInUser.uid).set({
      'email': signedInUser.email,
      'displayName': signedInUser.displayName,
      'photoUrl': signedInUser.photoURL,
      'lastSignIn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (onGoogleSignInSuccess != null) {
      await onGoogleSignInSuccess(signedInUser.uid);
    }

    _cloudStateManager.setIsGDriveConnected(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_gdrive_connected', true);
    onLog?.call('log_gdrive_connected', connectedIdentity ?? signedInUser.email);
  }

  Future<void> signInWithGoogle(
      {required Function(String uid)? onGoogleSignInSuccess}) async {
    try {
      _cloudStateManager.setLoadingAuthProvider('google_sign_in');

      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      if (_isDesktop) {
        // Desktop: PKCE akışını öncelikli kullan (refresh token saklayarak
        // sonraki açılışlarda oturumu geri yükleyebilmek için).
        try {
          await _signInWithGoogleDesktopFirebase(
            currentUser: currentUser,
            onGoogleSignInSuccess: onGoogleSignInSuccess,
          );
          return;
        } catch (e) {
          onLog?.call(
            'log_gdrive_signin_error',
            jsonEncode({'desktopPKCE': true, 'error': e.toString()}),
          );
        }

        // Fallback: GoogleSignIn eklentisi üzerinden dene
        try {
          await _ensureDesktopGoogleSignInRegistered();
          final account = await _googleSignIn.signIn();
          if (account == null) return;

          final googleAuth = await account.authentication;
          if (googleAuth.idToken != null && googleAuth.idToken!.isNotEmpty) {
            // Eklentiden gelen token'ları da secure storage'a kaydet
            // (refresh yok ama en azından kısa süreli restore için yeterli)
            if (googleAuth.accessToken != null) {
              await _secureWrite(
                  _prefsGoogleAccessToken, googleAuth.accessToken!);
              await _secureWriteInt(
                _prefsGoogleExpiresAtMs,
                DateTime.now()
                    .add(const Duration(minutes: 55))
                    .millisecondsSinceEpoch,
              );
            }
            await _secureWrite(_prefsGoogleIdToken, googleAuth.idToken!);

            final credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );

            await _signInWithGoogleCredential(
              currentUser: currentUser,
              credential: credential,
              onGoogleSignInSuccess: onGoogleSignInSuccess,
              connectedIdentity: account.email,
            );
            return;
          }
        } catch (e) {
          onLog?.call(
            'log_gdrive_signin_error',
            jsonEncode({'desktopPlugin': true, 'error': e.toString()}),
          );
        }
        return;
      }

      final account = await _googleSignIn.signIn();
      if (account == null) {
        return;
      }

      final connectedIdentity = account.email;
      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _signInWithGoogleCredential(
        currentUser: currentUser,
        credential: credential,
        onGoogleSignInSuccess: onGoogleSignInSuccess,
        connectedIdentity: connectedIdentity,
      );
    } catch (e) {
      onLog?.call(
          'log_gdrive_signin_error', jsonEncode({'error': e.toString()}));
    } finally {
      _cloudStateManager.setLoadingAuthProvider(null);
    }
  }

  Future<void> restoreGoogleSession() async {
    try {
      if (_isDesktop) {
        // 1) Eklenti üzerinden sessiz oturum açmayı dene
        try {
          await _ensureDesktopGoogleSignInRegistered();
          final account = await _googleSignIn.signInSilently();
          if (account != null) {
            final googleAuth = await account.authentication;
            final credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            await FirebaseAuth.instance.signInWithCredential(credential);
            await _persistGDriveConnected(true);
            _debugCloud('Session restored via plugin signInSilently');
            return;
          }
        } catch (e) {
          _debugCloud('Plugin signInSilently failed: $e');
          onLog?.call(
            'log_gdrive_restore_error',
            jsonEncode({'desktopPlugin': true, 'error': e.toString()}),
          );
        }

        // 2) Saklı token (refresh token dahil) ile kontrol et
        final accessToken =
            await _ensureDesktopGoogleAccessToken(interactive: false);
        if (accessToken != null && accessToken.isNotEmpty) {
          final user = FirebaseAuth.instance.currentUser;
          final isGoogleUser = user != null &&
              !user.isAnonymous &&
              user.providerData.any((p) => p.providerId == 'google.com');

          if (!isGoogleUser) {
            // Firebase oturumu kapanmış ama token kalmış → Firebase'e tekrar
            // bağlanmayı dene
            try {
              final idToken = await _secureRead(_prefsGoogleIdToken);
              if (idToken != null && idToken.isNotEmpty) {
                final credential = GoogleAuthProvider.credential(
                  accessToken: accessToken,
                  idToken: idToken,
                );
                await FirebaseAuth.instance.signInWithCredential(credential);
                _debugCloud('Session restored via stored tokens + Firebase');
              } else {
                _debugCloud('id_token missing, cannot restore Firebase session');
              }
            } catch (e) {
              _debugCloud('Firebase signInWithCredential failed: $e');
              onLog?.call(
                'log_gdrive_restore_error',
                jsonEncode({
                  'step': 'firebase_credential',
                  'error': e.toString(),
                }),
              );
            }
          } else {
            _debugCloud('Session restored: Firebase user already present');
          }
          await _persistGDriveConnected(true);
          return;
        }

        _debugCloud('No stored tokens found, session cannot be restored');
        // Token yoksa durumu değiştirme – signOut yapılmadıysa pref true kalır
        return;
      }

      // Mobil & Web
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final googleAuth = await account.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _persistGDriveConnected(true);
      }
    } catch (e) {
      onLog?.call(
          'log_gdrive_restore_error', jsonEncode({'error': e.toString()}));
    }
  }

  /// GDrive bağlantı durumunu hem bellekte hem SharedPreferences'ta günceller.
  Future<void> _persistGDriveConnected(bool connected) async {
    _cloudStateManager.setIsGDriveConnected(connected);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_gdrive_connected', connected);
  }

  Future<void> signOutGoogle() async {
    try {
      _cloudStateManager.setLoadingAuthProvider('google_sign_in');
      await FirebaseAuth.instance.signOut();
      if (_isDesktop) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        await _secureDelete(_prefsGoogleAccessToken);
        await _secureDelete(_prefsGoogleRefreshToken);
        await _secureDelete(_prefsGoogleIdToken);
        await _secureDelete(_prefsGoogleExpiresAtMs);
      } else {
        await _googleSignIn.signOut();
      }

      _cloudStateManager.setIsGDriveConnected(false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_gdrive_connected', false);
    } catch (e) {
      onLog?.call(
          'log_gdrive_signout_error', jsonEncode({'error': e.toString()}));
    } finally {
      _cloudStateManager.setLoadingAuthProvider(null);
    }
  }

  Future<GoogleSignInAccount?> ensureGDriveAccount(
      {bool interactive = true}) async {
    if (_isDesktop) {
      try {
        await _ensureDesktopGoogleSignInRegistered();
        GoogleSignInAccount? account = _googleSignIn.currentUser;
        account ??= await _googleSignIn.signInSilently();
        if (account == null && interactive) {
          account = await _googleSignIn.signIn();
        }

        if (account != null && interactive) {
          final granted = await _googleSignIn.requestScopes([
            'https://www.googleapis.com/auth/drive.file',
            'https://www.googleapis.com/auth/drive.readonly',
          ]);
          if (!granted) {
            await _googleSignIn.signOut();
            account = null;
          }
        }

        if (account != null) {
          _cloudStateManager.setIsGDriveConnected(true);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_gdrive_connected', true);
          return account;
        }

        final token =
            await _ensureDesktopGoogleAccessToken(interactive: interactive);
        final connected = token != null && token.isNotEmpty;
        _cloudStateManager.setIsGDriveConnected(connected);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_gdrive_connected', connected);
        return null;
      } catch (e) {
        onLog?.call(
            'log_gdrive_auth_error', jsonEncode({'error': e.toString()}));
        return null;
      }
    }

    GoogleSignInAccount? account;
    try {
      _debugCloud('GDrive ensure account (interactive=$interactive) start');
      account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      if (account == null && interactive) {
        account = await _googleSignIn.signIn();
      }

      if (account != null && interactive) {
        final granted = await _googleSignIn.requestScopes([
          'https://www.googleapis.com/auth/drive.file',
          'https://www.googleapis.com/auth/drive.readonly',
        ]);
        if (!granted) {
          try {
            await _googleSignIn.disconnect();
          } catch (_) {
            await _googleSignIn.signOut();
          }
          account = await _googleSignIn.signIn();
        }
      }

      _cloudStateManager.setIsGDriveConnected(account != null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_gdrive_connected', account != null);
      return account;
    } catch (e) {
      onLog?.call('log_gdrive_auth_error', jsonEncode({'error': e.toString()}));
      return null;
    }
  }

  Future<Map<String, String>?> _getGoogleAuthHeaders({
    required bool interactive,
  }) async {
    if (_isDesktop) {
      try {
        final account = await ensureGDriveAccount(interactive: interactive);
        if (account != null) {
          return account.authHeaders;
        }
      } catch (_) {}

      final token =
          await _ensureDesktopGoogleAccessToken(interactive: interactive);
      if (token == null || token.isEmpty) return null;
      return <String, String>{'Authorization': 'Bearer $token'};
    }

    final account = await ensureGDriveAccount(interactive: interactive);
    if (account == null) return null;
    return account.authHeaders;
  }

  // ============ CONFIG ============

  static String _sanitizeOAuthValue(String value) {
    final v = value.trim().replaceAll(RegExp(r'\s+'), '');
    if (v.isEmpty) return '';
    final upper = v.toUpperCase();
    if (upper == 'PASTE_HERE' || upper.contains('PASTE_HERE')) return '';
    return v;
  }

  String get effectiveDropboxClientId {
    final override = _sanitizeOAuthValue(_overrideDropboxClientId);
    if (override.isNotEmpty) return override;
    return _sanitizeOAuthValue(CloudOAuthConfig.dropboxClientId);
  }

  String get effectiveYandexClientId {
    final override = _sanitizeOAuthValue(_overrideYandexClientId);
    if (override.isNotEmpty) return override;
    return _sanitizeOAuthValue(CloudOAuthConfig.yandexClientId);
  }

  String get effectiveYandexClientSecret {
    final override = _sanitizeOAuthValue(_overrideYandexClientSecret);
    if (override.isNotEmpty) return override;
    return _sanitizeOAuthValue(CloudOAuthConfig.yandexClientSecret);
  }

  String get effectiveGoogleOauthClientId =>
      _sanitizeOAuthValue(_overrideGoogleOauthClientId).isNotEmpty
        ? _sanitizeOAuthValue(_overrideGoogleOauthClientId)
        : _sanitizeOAuthValue(CloudOAuthConfig.googleOauthClientId);

  bool get hasDropboxOAuthConfig => effectiveDropboxClientId.trim().isNotEmpty;
  bool get hasGoogleOAuthConfig =>
      effectiveGoogleOauthClientId.trim().isNotEmpty;
  bool get hasYandexOAuthConfig =>
      effectiveYandexClientId.trim().isNotEmpty &&
      effectiveYandexClientSecret.trim().isNotEmpty;

  Future<void> setOAuthOverrides({
    String? dropboxClientId,
    String? googleOauthClientId,
    String? yandexClientId,
    String? yandexClientSecret,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (dropboxClientId != null) {
      _overrideDropboxClientId = dropboxClientId.trim();
      if (_overrideDropboxClientId.isEmpty) {
        await prefs.remove(_prefsDropboxClientIdOverride);
      } else {
        await prefs.setString(
            _prefsDropboxClientIdOverride, _overrideDropboxClientId);
      }
    }

    if (googleOauthClientId != null) {
      _overrideGoogleOauthClientId = googleOauthClientId.trim();
      if (_overrideGoogleOauthClientId.isEmpty) {
        await prefs.remove(_prefsGoogleOauthClientIdOverride);
      } else {
        await prefs.setString(
            _prefsGoogleOauthClientIdOverride, _overrideGoogleOauthClientId);
      }
    }

    if (yandexClientId != null) {
      _overrideYandexClientId = yandexClientId.trim();
      if (_overrideYandexClientId.isEmpty) {
        await prefs.remove(_prefsYandexClientIdOverride);
      } else {
        await prefs.setString(
            _prefsYandexClientIdOverride, _overrideYandexClientId);
      }
    }

    if (yandexClientSecret != null) {
      _overrideYandexClientSecret = yandexClientSecret.trim();
      if (_overrideYandexClientSecret.isEmpty) {
        await prefs.remove(_prefsYandexClientSecretOverride);
      } else {
        await prefs.setString(
            _prefsYandexClientSecretOverride, _overrideYandexClientSecret);
      }
    }
  }

  // ============ DROPBOX AUTH ============

  static String _base64UrlNoPadding(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(64, (_) => random.nextInt(256));
    return _base64UrlNoPadding(bytes);
  }

  static String _codeChallengeS256(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return _base64UrlNoPadding(digest.bytes);
  }

  Future<void> connectDropbox() async {
    await _ensureSecureMigration();
    if (effectiveDropboxClientId.trim().isEmpty) {
      throw Exception('Dropbox clientId missing. Configure OAuth client id.');
    }

    onLog?.call(
      'log_dropbox_oauth_start',
      jsonEncode({'redirect': CloudOAuthConfig.redirectUri}),
    );

    final verifier = _generateCodeVerifier();
    final challenge = _codeChallengeS256(verifier);

    final authUri = Uri.https(
      'www.dropbox.com',
      '/oauth2/authorize',
      {
        'client_id': effectiveDropboxClientId,
        'response_type': 'code',
        'redirect_uri': CloudOAuthConfig.redirectUri,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'token_access_type': 'offline',
      },
    );

    Uri returned;
    if (_isDesktop) {
      final callbackUri = Uri.parse(CloudOAuthConfig.dropboxDesktopRedirectUri);
      onLog?.call(
        'log_dropbox_oauth_start',
        jsonEncode({'redirect': callbackUri.toString(), 'desktop': true}),
      );
      final callbackServer =
        await HttpServer.bind(InternetAddress.loopbackIPv4, callbackUri.port);

      final desktopAuthUri = Uri.https(
        'www.dropbox.com',
        '/oauth2/authorize',
        {
          'client_id': effectiveDropboxClientId,
          'response_type': 'code',
          'redirect_uri': callbackUri.toString(),
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          'token_access_type': 'offline',
        },
      );

      final opened = await launchUrl(
        desktopAuthUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        await callbackServer.close(force: true);
        throw Exception('Could not open system browser for Dropbox auth');
      }

      try {
        final req = await callbackServer.first.timeout(
          const Duration(seconds: 90),
        );
        returned = req.uri;

        const html = '''
<!doctype html>
<html><head><meta charset="utf-8"><title>Authentication Complete</title></head>
<body style="font-family:Segoe UI,Arial,sans-serif;padding:24px;">
  <h2>Dropbox authentication completed.</h2>
  <p>You can close this tab and return to the app.</p>
</body></html>
''';
        req.response.headers.contentType = ContentType.html;
        req.response.write(html);
        await req.response.close();
      } on TimeoutException {
        throw Exception(
            'Dropbox auth callback timeout. Add this Redirect URI in Dropbox app settings: ${callbackUri.toString()}');
      } finally {
        await callbackServer.close(force: true);
      }

      // Token exchange on desktop must use the same loopback redirect uri.
      final err = returned.queryParameters['error'];
      if (err != null && err.isNotEmpty) {
        final desc = returned.queryParameters['error_description'] ?? '';
        throw Exception(
            'Dropbox auth error: $err ${desc.isEmpty ? '' : '($desc)'}');
      }
      final code = returned.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw Exception('Dropbox auth did not return code');
      }

      final tokenUri = Uri.https('api.dropboxapi.com', '/oauth2/token');
      final resp = await http.post(
        tokenUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'grant_type': 'authorization_code',
          'client_id': effectiveDropboxClientId,
          'redirect_uri': callbackUri.toString(),
          'code_verifier': verifier,
        },
      );
      if (resp.statusCode != 200) {
        throw Exception('Dropbox token failed: ${resp.body}');
      }

      late final Map<String, dynamic> data;
      try {
        data = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Dropbox token parse failed: $e (body=${resp.body})');
      }

      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      final expiresIn = int.tryParse('${data['expires_in'] ?? ''}') ?? 14400;

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception(
            'Dropbox token response missing access_token (body=${resp.body})');
      }

      await _secureWrite(_prefsDropboxAccessToken, accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _secureWrite(_prefsDropboxRefreshToken, refreshToken);
      } else {
        await _secureDelete(_prefsDropboxRefreshToken);
      }
      await _secureWriteInt(
        _prefsDropboxExpiresAtMs,
        DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch,
      );

      _cloudStateManager.setIsDropboxConnected(true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dropbox_connected', true);

      onLog?.call('log_dropbox_oauth_complete');
      return;
    }

    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: CloudOAuthConfig.redirectScheme,
    );

    returned = Uri.parse(result);
    final err = returned.queryParameters['error'];
    if (err != null && err.isNotEmpty) {
      final desc = returned.queryParameters['error_description'] ?? '';
      throw Exception(
          'Dropbox auth error: $err ${desc.isEmpty ? '' : '($desc)'}');
    }
    final code = returned.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('Dropbox auth did not return code');
    }

    final tokenUri = Uri.https('api.dropboxapi.com', '/oauth2/token');
    final resp = await http.post(
      tokenUri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'code': code,
        'grant_type': 'authorization_code',
        'client_id': effectiveDropboxClientId,
        'redirect_uri': CloudOAuthConfig.redirectUri,
        'code_verifier': verifier,
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('Dropbox token failed: ${resp.body}');
    }

    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Dropbox token parse failed: $e (body=${resp.body})');
    }

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    final expiresIn = int.tryParse('${data['expires_in'] ?? ''}') ?? 14400;

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception(
          'Dropbox token response missing access_token (body=${resp.body})');
    }

    await _secureWrite(_prefsDropboxAccessToken, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureWrite(_prefsDropboxRefreshToken, refreshToken);
    } else {
      await _secureDelete(_prefsDropboxRefreshToken);
    }
    await _secureWriteInt(
      _prefsDropboxExpiresAtMs,
      DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch,
    );

    _cloudStateManager.setIsDropboxConnected(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dropbox_connected', true);

    onLog?.call('log_dropbox_oauth_complete');
  }

  Future<String?> ensureDropboxAccessToken({required bool interactive}) async {
    await _ensureSecureMigration();
    String? token;
    final access = await _secureRead(_prefsDropboxAccessToken);
    final expiresAtMs = await _secureReadInt(_prefsDropboxExpiresAtMs);

    // Check if valid
    if (access != null && expiresAtMs != null) {
      if (DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
          .isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
        return access;
      }
    }

    // Try refresh
    final refresh = await _secureRead(_prefsDropboxRefreshToken);
    if (refresh != null && refresh.isNotEmpty) {
      try {
        token = await _refreshDropboxToken(refreshToken: refresh);
        return token;
      } catch (_) {}
    }

    if (!interactive) return null;
    await connectDropbox();
    return _secureRead(_prefsDropboxAccessToken);
  }

  Future<String> _refreshDropboxToken({required String refreshToken}) async {
    await _ensureSecureMigration();
    final tokenUri = Uri.https('api.dropboxapi.com', '/oauth2/token');
    final resp = await http.post(
      tokenUri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': effectiveDropboxClientId,
      },
    );
    if (resp.statusCode != 200) throw Exception('Dropbox refresh failed');

    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Dropbox refresh parse failed: $e (body=${resp.body})');
    }

    final accessToken = data['access_token'] as String?;
    final expiresIn = int.tryParse('${data['expires_in'] ?? ''}') ?? 14400;

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception(
          'Dropbox refresh response missing access_token (body=${resp.body})');
    }

    await _secureWrite(_prefsDropboxAccessToken, accessToken);
    await _secureWriteInt(
      _prefsDropboxExpiresAtMs,
      DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch,
    );
    return accessToken;
  }

  Future<void> disconnectDropbox() async {
    await _ensureSecureMigration();
    final prefs = await SharedPreferences.getInstance();
    await _secureDelete(_prefsDropboxAccessToken);
    await _secureDelete(_prefsDropboxRefreshToken);
    await _secureDelete(_prefsDropboxExpiresAtMs);

    _cloudStateManager.setIsDropboxConnected(false);
    await prefs.setBool('is_dropbox_connected', false);
    onLog?.call("log_dropbox_disconnected");
  }

  // ============ YANDEX AUTH ============

  Future<void> connectYandex(BuildContext context,
      {required Future<String?> Function(Uri authUri) onCodeRequired}) async {
    await _ensureSecureMigration();
    if (effectiveYandexClientId.trim().isEmpty) {
      throw Exception('Yandex Client ID missing');
    }

    onLog?.call('log_yandex_oauth_start');

    final authUri = Uri.https(
      'oauth.yandex.com',
      '/authorize',
      {
        'response_type': 'code',
        'client_id': effectiveYandexClientId,
        'redirect_uri': CloudOAuthConfig.yandexVerificationCodeRedirectUri,
        'scope': 'cloud_api:disk.read cloud_api:disk.write',
        'force_confirm': 'yes',
      },
    );

    // Best-effort: on some devices/ROMs `externalApplication` can fail silently.
    // We still proceed to the code dialog (which provides an "Open browser" button).
    bool launched = false;
    try {
      launched = await launchUrl(authUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      onLog?.call('log_yandex_browser_open_failed');
    }

    final code = await onCodeRequired(authUri);
    if (code == null || code.isEmpty) throw Exception('Code not provided');

    final tokenUri = Uri.https('oauth.yandex.com', '/token');
    http.Response resp;
    try {
      resp = await http.post(
        tokenUri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization':
              'Basic ${base64.encode(utf8.encode('$effectiveYandexClientId:$effectiveYandexClientSecret'))}',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': CloudOAuthConfig.yandexVerificationCodeRedirectUri,
        },
      );
    } catch (_) {
      rethrow;
    }

    // Some OAuth servers require client_id/client_secret in body.
    if (resp.statusCode != 200) {
      final retry = await http.post(
        tokenUri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'client_id': effectiveYandexClientId,
          'client_secret': effectiveYandexClientSecret,
          'redirect_uri': CloudOAuthConfig.yandexVerificationCodeRedirectUri,
        },
      );
      if (retry.statusCode == 200) {
        resp = retry;
      }
    }

    if (resp.statusCode != 200) {
      throw Exception('Yandex token failed: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String?;
    final expiresIn = int.tryParse('${data['expires_in'] ?? ''}') ?? 3600;

    await _secureWrite(_prefsYandexAccessToken, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureWrite(_prefsYandexRefreshToken, refreshToken);
    } else {
      await _secureDelete(_prefsYandexRefreshToken);
    }
    await _secureWriteInt(
      _prefsYandexExpiresAtMs,
      DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch,
    );

    _cloudStateManager.setIsYandexConnected(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_yandex_connected', true);

    onLog?.call('log_yandex_oauth_complete');
  }

  Future<String?> ensureYandexAccessToken(
      {required bool interactive,
      BuildContext? context,
      Future<String?> Function(Uri)? onCodeRequired}) async {
    await _ensureSecureMigration();
    final access = await _secureRead(_prefsYandexAccessToken);
    final expiresAtMs = await _secureReadInt(_prefsYandexExpiresAtMs);

    if (access != null && expiresAtMs != null) {
      if (DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
          .isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
        return access;
      }
    }

    final refresh = await _secureRead(_prefsYandexRefreshToken);
    if (refresh != null) {
      try {
        return await _refreshYandexToken(refreshToken: refresh);
      } catch (_) {}
    }

    if (!interactive || context == null) return null;
    if (!context.mounted) return null;

    final effectiveOnCodeRequired = onCodeRequired ??
        ((Uri authUri) => _promptForYandexAuthCode(context, authUri: authUri));

    await connectYandex(context, onCodeRequired: effectiveOnCodeRequired);
    return _secureRead(_prefsYandexAccessToken);
  }

  Future<String> _refreshYandexToken({required String refreshToken}) async {
    await _ensureSecureMigration();
    final tokenUri = Uri.https('oauth.yandex.com', '/token');
    http.Response resp = await http.post(
      tokenUri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization':
            'Basic ${base64.encode(utf8.encode('$effectiveYandexClientId:$effectiveYandexClientSecret'))}',
      },
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );

    if (resp.statusCode != 200) {
      final retry = await http.post(
        tokenUri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': effectiveYandexClientId,
          'client_secret': effectiveYandexClientSecret,
        },
      );
      if (retry.statusCode == 200) {
        resp = retry;
      }
    }

    if (resp.statusCode != 200) throw Exception('Yandex refresh failed');

    final data = jsonDecode(resp.body);
    final accessToken = data['access_token'];
    final expiresIn = int.tryParse('${data['expires_in']}') ?? 3600;

    await _secureWrite(_prefsYandexAccessToken, '$accessToken');
    await _secureWriteInt(
      _prefsYandexExpiresAtMs,
      DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch,
    );
    return '$accessToken';
  }

  Future<void> disconnectYandex() async {
    await _ensureSecureMigration();
    final prefs = await SharedPreferences.getInstance();
    await _secureDelete(_prefsYandexAccessToken);
    await _secureDelete(_prefsYandexRefreshToken);
    await _secureDelete(_prefsYandexExpiresAtMs);

    _cloudStateManager.setIsYandexConnected(false);
    await prefs.setBool('is_yandex_connected', false);
    onLog?.call("log_yandex_disconnected");
  }

  // ============ API METHODS ============

  Future<List<DropboxFileInfo>> listDropboxFolderItems(
      {required String path}) async {
    final token = await ensureDropboxAccessToken(interactive: true);
    if (token == null) return [];

    final uri = Uri.https('api.dropboxapi.com', '/2/files/list_folder');
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'path': path,
        'recursive': false,
        'include_deleted': false,
        'include_media_info': false,
        'include_non_downloadable_files': false
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Dropbox list failed: ${resp.body}');
    }

    final entries =
        (jsonDecode(resp.body)['entries'] as List).cast<Map<String, dynamic>>();
    final folders = <DropboxFileInfo>[];
    final files = <DropboxFileInfo>[];

    for (final m in entries) {
      final tag = m['.tag'] as String;
      final name = m['name'] as String;
      final pathDisplay = m['path_display'] as String;

      if (tag == 'folder') {
        folders.add(DropboxFileInfo(
            id: m['id'], name: name, path: pathDisplay, isFolder: true));
      } else if (tag == 'file') {
        if (!name.toLowerCase().endsWith('.srt') &&
            !name.toLowerCase().endsWith('.vtt')) {
          continue;
        }
        files.add(DropboxFileInfo(
            id: m['id'],
            name: name,
            path: pathDisplay,
            sizeBytes: m['size'],
            modifiedTime: DateTime.tryParse(m['server_modified'] ?? '')));
      }
    }

    // Sort
    folders
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    files.sort((a, b) => (b.modifiedTime?.millisecondsSinceEpoch ?? 0)
        .compareTo(a.modifiedTime?.millisecondsSinceEpoch ?? 0));
    return [...folders, ...files];
  }

  Future<List<DropboxFileInfo>> searchDropboxSubtitleFiles(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final token = await ensureDropboxAccessToken(interactive: true);
    if (token == null) return [];

    final uri = Uri.https('api.dropboxapi.com', '/2/files/search_v2');
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'query': q,
        'options': {
          'path': '',
          'max_results': 100,
          'filename_only': false,
        }
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception(
          'Dropbox search failed (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final matches = (data['matches'] as List?) ?? const <dynamic>[];
    final out = <DropboxFileInfo>[];

    for (final match in matches) {
      final m = (match as Map).cast<String, dynamic>();
      final metadata = (m['metadata'] as Map?)?.cast<String, dynamic>();
      final meta = (metadata?['metadata'] as Map?)?.cast<String, dynamic>();
      if (meta == null) continue;
      if ((meta['.tag'] as String?) != 'file') continue;

      final name = (meta['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      final lower = name.toLowerCase();
      if (!(lower.endsWith('.srt') || lower.endsWith('.vtt'))) continue;

      final entryPath = (meta['path_lower'] as String?) ??
          (meta['path_display'] as String?) ??
          '';
      if (entryPath.isEmpty) continue;

      DateTime? modified;
      final mt = meta['server_modified'] as String?;
      if (mt != null) modified = DateTime.tryParse(mt);
      final size = int.tryParse('${meta['size'] ?? ''}');

      out.add(DropboxFileInfo(
        id: (meta['id'] as String?) ?? entryPath,
        name: name,
        path: entryPath,
        modifiedTime: modified,
        sizeBytes: size,
        isFolder: false,
      ));
    }

    return out;
  }

  Future<void> uploadTextFileToDropbox(
      {required String fileName,
      required String content,
      String? folderPath}) async {
    final token = await ensureDropboxAccessToken(interactive: true);
    if (token == null) throw Exception('Not signed in');

    String path = fileName.startsWith('/') ? fileName : '/$fileName';
    if (!fileName.startsWith('/') &&
        folderPath != null &&
        folderPath.isNotEmpty) {
      path =
          '${folderPath.endsWith('/') ? folderPath : '$folderPath/'}$fileName';
    }

    final uri = Uri.https('content.dropboxapi.com', '/2/files/upload');
    final apiArg = encodeDropboxApiArg(
        {'path': path, 'mode': 'overwrite', 'autorename': true, 'mute': false});

    await http.post(uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/octet-stream',
          'Dropbox-API-Arg': apiArg
        },
        body: utf8.encode(content));
  }

  Future<Map<String, String>> downloadDropboxFileWithEncoding(
      String path) async {
    final token = await ensureDropboxAccessToken(interactive: true);
    if (token == null) throw Exception('Dropbox not signed in');

    final uri = Uri.https('content.dropboxapi.com', '/2/files/download');
    final apiArg = encodeDropboxApiArg({'path': path});

    final resp = await http.post(uri, headers: {
      'Authorization': 'Bearer $token',
      'Dropbox-API-Arg': apiArg,
    });

    if (resp.statusCode != 200) {
      throw Exception('Dropbox download failed: ${resp.body}');
    }

    return compute(decodeFileContent, resp.bodyBytes);
  }

  // Yandex Disk Lists
  Future<List<YandexDiskFileInfo>> listYandexDiskFolderItems({
    required String path,
    BuildContext? context,
  }) async {
    final token = await ensureYandexAccessToken(
      interactive: true,
      context: context,
    );
    if (token == null) return <YandexDiskFileInfo>[];

    final uri = Uri.https('cloud-api.yandex.net', '/v1/disk/resources', {
      'path': path,
      'limit': '200',
      'sort': 'modified',
    });

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'OAuth $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) {
      throw Exception('Yandex list failed (${resp.statusCode}): ${resp.body}');
    }

    // Decode + filter + sort can be expensive; do it off the UI isolate.
    final entries = await compute(_extractYandexListFiltered, resp.bodyBytes);
    return entries
        .map((e) {
          final modifiedMs = e['modifiedMs'] as int?;
          return YandexDiskFileInfo(
            path: (e['path'] as String?) ?? '',
            name: (e['name'] as String?) ?? '',
            modifiedTime: (modifiedMs == null || modifiedMs == 0)
                ? null
                : DateTime.fromMillisecondsSinceEpoch(modifiedMs),
            sizeBytes: e['size'] is int ? (e['size'] as int) : null,
            isFolder: (e['isFolder'] as bool?) ?? false,
          );
        })
        .where((f) => f.path.isNotEmpty && f.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<YandexDiskFileInfo>> searchYandexDiskSubtitleFiles(
    String query, {
    BuildContext? context,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return <YandexDiskFileInfo>[];

    final token = await ensureYandexAccessToken(
      interactive: true,
      context: context,
    );
    if (token == null) return <YandexDiskFileInfo>[];

    final uri = Uri.https('cloud-api.yandex.net', '/v1/disk/resources/search', {
      'text': q,
      'limit': '200',
    });

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'OAuth $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) {
      throw Exception(
          'Yandex search failed (${resp.statusCode}): ${resp.body}');
    }

    final entries = await compute(_extractYandexSearchFiltered, resp.bodyBytes);
    return entries
        .map((e) {
          final modifiedMs = e['modifiedMs'] as int?;
          return YandexDiskFileInfo(
            path: (e['path'] as String?) ?? '',
            name: (e['name'] as String?) ?? '',
            modifiedTime: (modifiedMs == null || modifiedMs == 0)
                ? null
                : DateTime.fromMillisecondsSinceEpoch(modifiedMs),
            sizeBytes: e['size'] is int ? (e['size'] as int) : null,
            isFolder: false,
          );
        })
        .where((f) => f.path.isNotEmpty && f.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, String>> downloadYandexDiskFileWithEncoding(
      String path) async {
    final token = await ensureYandexAccessToken(interactive: true);
    if (token == null) {
      throw Exception('Yandex Disk not authenticated');
    }

    final uri =
        Uri.https('cloud-api.yandex.net', '/v1/disk/resources/download', {
      'path': path,
    });
    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'OAuth $token',
        'Accept': 'application/json',
      },
    );
    if (resp.statusCode != 200) {
      throw Exception(
          'Yandex download link failed (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final href = data['href'] as String?;
    if (href == null || href.isEmpty) {
      throw Exception('Yandex download response missing href');
    }

    final fileResp = await http.get(Uri.parse(href));
    if (fileResp.statusCode != 200) {
      throw Exception('Yandex download failed (${fileResp.statusCode})');
    }
    return compute(decodeFileContent, fileResp.bodyBytes);
  }

  Future<void> uploadTextFileToYandexDisk({
    required String fileName,
    required String content,
    String? folderPath,
  }) async {
    final token = await ensureYandexAccessToken(interactive: true);
    if (token == null) {
      throw Exception('Yandex Disk not authenticated');
    }

    final String fullPath;
    if (fileName.startsWith('disk:')) {
      fullPath = fileName;
    } else {
      final String folder =
          (folderPath == null || folderPath.isEmpty) ? 'disk:/' : folderPath;
      final String base = folder.endsWith('/')
          ? folder.substring(0, folder.length - 1)
          : folder;
      fullPath = '$base/$fileName';
    }

    final linkUri =
        Uri.https('cloud-api.yandex.net', '/v1/disk/resources/upload', {
      'path': fullPath,
      'overwrite': 'true',
    });
    final linkResp = await http.get(
      linkUri,
      headers: {
        'Authorization': 'OAuth $token',
        'Accept': 'application/json',
      },
    );
    if (linkResp.statusCode != 200) {
      throw Exception(
          'Yandex upload link failed (${linkResp.statusCode}): ${linkResp.body}');
    }

    final linkData = jsonDecode(linkResp.body) as Map<String, dynamic>;
    final href = linkData['href'] as String?;
    if (href == null || href.isEmpty) {
      throw Exception('Yandex upload response missing href');
    }

    final putResp = await http.put(
      Uri.parse(href),
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
      },
      body: utf8.encode(content),
    );
    if (putResp.statusCode != 200 && putResp.statusCode != 201) {
      throw Exception(
          'Yandex upload failed (${putResp.statusCode}): ${putResp.body}');
    }
  }

  // Google Drive helpers
  String _escapeGDriveQueryValue(String s) {
    return s.replaceAll("'", "\\'");
  }

  Future<void> disconnectGDrive() async {
    if (_isDesktop) {
      await _secureDelete(_prefsGoogleAccessToken);
      await _secureDelete(_prefsGoogleRefreshToken);
      await _secureDelete(_prefsGoogleIdToken);
      await _secureDelete(_prefsGoogleExpiresAtMs);
    } else {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      await _googleSignIn.signOut();
    }

    _cloudStateManager.setIsGDriveConnected(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_gdrive_connected', false);
  }

  Future<List<GDriveFileInfo>> listGDriveFolderItems({
    String? folderId,
    List<String> allowedExtensions = const ['.srt', '.vtt'],
    bool includeFolders = true,
    bool interactive = true,
  }) async {
    final headers = await _getGoogleAuthHeaders(interactive: interactive);
    if (headers == null) return <GDriveFileInfo>[];

    final parent = folderId ?? 'root';
    final normalizedExtensions = allowedExtensions
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    final extensionQuery = normalizedExtensions
        .map((ext) => "name contains '${_escapeGDriveQueryValue(ext)}'")
        .join(' or ');

    final typeClauses = <String>[];
    if (includeFolders) {
      typeClauses.add("mimeType='application/vnd.google-apps.folder'");
    }
    if (extensionQuery.isNotEmpty) {
      typeClauses.add(extensionQuery);
    }

    final q = typeClauses.isEmpty
        ? "'$parent' in parents and trashed=false"
        : "'$parent' in parents and trashed=false and (${typeClauses.join(' or ')})";

    String? pageToken;
    final folders = <GDriveFileInfo>[];
    final filesOut = <GDriveFileInfo>[];

    for (var page = 0; page < 10; page++) {
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q': q,
        'orderBy': 'modifiedTime desc',
        'pageSize': '200',
        'fields': 'nextPageToken,files(id,name,modifiedTime,size,mimeType)',
        'spaces': 'drive',
        if (pageToken != null) 'pageToken': pageToken,
      });

      final resp = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 25));
      if (resp.statusCode != 200) {
        throw Exception('Drive list failed (${resp.statusCode}): ${resp.body}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final items = (data['files'] as List?) ?? const <dynamic>[];
      for (final e in items) {
        final m = (e as Map).cast<String, dynamic>();
        final id = (m['id'] as String?) ?? '';
        if (id.isEmpty) continue;
        final name = (m['name'] as String?) ?? 'unknown';
        final mimeType = (m['mimeType'] as String?) ?? '';
        final isFolder = mimeType == 'application/vnd.google-apps.folder';

        DateTime? modified;
        final mt = m['modifiedTime'] as String?;
        if (mt != null) modified = DateTime.tryParse(mt);
        final size = int.tryParse('${m['size'] ?? ''}');

        final info = GDriveFileInfo(
          id: id,
          name: name,
          modifiedTime: modified,
          sizeBytes: size,
          isFolder: isFolder,
        );

        if (isFolder) {
          if (includeFolders) {
            folders.add(info);
          }
        } else {
          final lower = name.toLowerCase();
          if (normalizedExtensions.isNotEmpty &&
              !normalizedExtensions.any((ext) => lower.endsWith(ext))) {
            continue;
          }
          filesOut.add(info);
        }
      }

      pageToken = data['nextPageToken'] as String?;
      if (pageToken == null || pageToken.isEmpty) break;
    }

    folders
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    filesOut.sort((a, b) =>
        b.modifiedTime?.compareTo(
            a.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0)) ??
        0);
    return <GDriveFileInfo>[...folders, ...filesOut];
  }

  Future<List<GDriveFileInfo>> searchGDriveSubtitleFiles(String query) async {
    final q0 = query.trim();
    if (q0.isEmpty) return <GDriveFileInfo>[];

    final headers = await _getGoogleAuthHeaders(interactive: true);
    if (headers == null) return <GDriveFileInfo>[];

    final q =
        "(name contains '.srt' or name contains '.vtt') and name contains '${_escapeGDriveQueryValue(q0)}' and trashed=false";

    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': q,
      'orderBy': 'modifiedTime desc',
      'pageSize': '200',
      'fields': 'files(id,name,modifiedTime,size,mimeType)',
      'spaces': 'drive',
    });

    final resp = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) {
      throw Exception('Drive search failed (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final files = (data['files'] as List?) ?? const <dynamic>[];
    return files
        .map((e) {
          final m = (e as Map).cast<String, dynamic>();
          DateTime? modified;
          final mt = m['modifiedTime'] as String?;
          if (mt != null) {
            modified = DateTime.tryParse(mt);
          }
          return GDriveFileInfo(
            id: (m['id'] as String?) ?? '',
            name: (m['name'] as String?) ?? 'unknown',
            modifiedTime: modified,
            sizeBytes: int.tryParse('${m['size'] ?? ''}'),
            isFolder: (m['mimeType'] as String?) ==
                'application/vnd.google-apps.folder',
          );
        })
        .where((f) => f.id.isNotEmpty && !f.isFolder)
        .toList(growable: false);
  }

  Future<List<GDriveFileInfo>> listGDriveSubtitleFiles() async {
    final headers = await _getGoogleAuthHeaders(interactive: true);
    if (headers == null) return <GDriveFileInfo>[];

    const q =
        "(name contains '.srt' or name contains '.vtt') and trashed=false";

    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': q,
      'orderBy': 'modifiedTime desc',
      'pageSize': '100',
      'fields': 'files(id,name,modifiedTime,size,mimeType)',
      'spaces': 'drive',
    });

    final resp = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) {
      throw Exception('Drive list failed (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final files = (data['files'] as List?) ?? const <dynamic>[];
    return files
        .map((e) {
          final m = (e as Map).cast<String, dynamic>();
          DateTime? modified;
          final mt = m['modifiedTime'] as String?;
          if (mt != null) {
            modified = DateTime.tryParse(mt);
          }
          return GDriveFileInfo(
            id: (m['id'] as String?) ?? '',
            name: (m['name'] as String?) ?? 'unknown',
            modifiedTime: modified,
            sizeBytes: int.tryParse('${m['size'] ?? ''}'),
            isFolder: (m['mimeType'] as String?) ==
                'application/vnd.google-apps.folder',
          );
        })
        .where((f) => f.id.isNotEmpty && !f.isFolder)
        .toList(growable: false);
  }

  Future<Map<String, String>> downloadGDriveFileWithEncoding(
      String fileId) async {
    final headers = await _getGoogleAuthHeaders(interactive: true);
    if (headers == null) {
      throw Exception('Google Drive not signed in');
    }

    final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
      'alt': 'media',
    });

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw Exception(
          'Drive download failed (${resp.statusCode}): ${resp.body}');
    }
    return compute(decodeFileContent, resp.bodyBytes);
  }

  Future<void> uploadTextFileToGDrive({
    required String fileName,
    required String content,
    String? folderId,
  }) async {
    final headers = await _getGoogleAuthHeaders(interactive: true);
    if (headers == null) {
      throw Exception('Google Drive not signed in');
    }

    final boundary =
        '----altyazi_editoru_${DateTime.now().millisecondsSinceEpoch}';

    final String? parentId =
        (folderId == null || folderId.isEmpty) ? null : folderId;
    final metaMap = <String, dynamic>{
      'name': fileName,
      if (parentId != null) 'parents': <String>[parentId],
    };
    final metadata = jsonEncode(metaMap);

    final bytes = utf8.encode(content);
    const mimeType = 'text/plain';

    final bodyBytes = BytesBuilder(copy: false)
      ..add(utf8.encode('--$boundary\r\n'))
      ..add(
          utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'))
      ..add(utf8.encode(metadata))
      ..add(utf8.encode('\r\n'))
      ..add(utf8.encode('--$boundary\r\n'))
      ..add(utf8.encode('Content-Type: $mimeType\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));

    final uri = Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
      'uploadType': 'multipart',
    });

    final resp = await http.post(
      uri,
      headers: {
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: bodyBytes.takeBytes(),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Drive upload failed (${resp.statusCode}): ${resp.body}');
    }
  }
}

// Top-level helper functions for Yandex (used with compute())
List<Map<String, dynamic>> _extractYandexListItems(Uint8List bodyBytes) {
  final body = utf8.decode(bodyBytes);
  final data = jsonDecode(body) as Map<String, dynamic>;
  final embedded = (data['_embedded'] as Map?)?.cast<String, dynamic>();
  final items = (embedded?['items'] as List?) ?? const <dynamic>[];
  return items
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList(growable: false);
}

List<Map<String, dynamic>> _extractYandexListFiltered(Uint8List bodyBytes) {
  final items = _extractYandexListItems(bodyBytes);

  final folders = <Map<String, dynamic>>[];
  final files = <Map<String, dynamic>>[];

  for (final m in items) {
    final type = (m['type'] as String?) ?? '';
    final name = (m['name'] as String?) ?? '';
    final itemPath = (m['path'] as String?) ?? '';
    if (name.isEmpty || itemPath.isEmpty) continue;

    final mt = m['modified'] as String?;
    final modifiedMs =
        mt == null ? 0 : (DateTime.tryParse(mt)?.millisecondsSinceEpoch ?? 0);

    if (type == 'dir') {
      folders.add({
        'path': itemPath,
        'name': name,
        'modifiedMs': modifiedMs,
        'size': null,
        'isFolder': true,
      });
      continue;
    }

    if (type != 'file') continue;
    final lower = name.toLowerCase();
    if (!(lower.endsWith('.srt') || lower.endsWith('.vtt'))) continue;
    final size = int.tryParse('${m['size'] ?? ''}');
    files.add({
      'path': itemPath,
      'name': name,
      'modifiedMs': modifiedMs,
      'size': size,
      'isFolder': false,
    });
  }

  folders.sort((a, b) => ('${a['name'] ?? ''}')
      .toLowerCase()
      .compareTo(('${b['name'] ?? ''}').toLowerCase()));
  files.sort((a, b) =>
      (b['modifiedMs'] as int? ?? 0).compareTo(a['modifiedMs'] as int? ?? 0));

  return <Map<String, dynamic>>[...folders, ...files];
}

List<Map<String, dynamic>> _extractYandexSearchItems(Uint8List bodyBytes) {
  final body = utf8.decode(bodyBytes);
  final data = jsonDecode(body) as Map<String, dynamic>;
  final items = (data['items'] as List?) ?? const <dynamic>[];
  return items
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList(growable: false);
}

List<Map<String, dynamic>> _extractYandexSearchFiltered(Uint8List bodyBytes) {
  final items = _extractYandexSearchItems(bodyBytes);
  final out = <Map<String, dynamic>>[];

  for (final m in items) {
    final type = (m['type'] as String?) ?? '';
    if (type != 'file') continue;

    final name = (m['name'] as String?) ?? '';
    final itemPath = (m['path'] as String?) ?? '';
    if (name.isEmpty || itemPath.isEmpty) continue;

    final lower = name.toLowerCase();
    if (!(lower.endsWith('.srt') || lower.endsWith('.vtt'))) continue;

    final mt = m['modified'] as String?;
    final modifiedMs =
        mt == null ? 0 : (DateTime.tryParse(mt)?.millisecondsSinceEpoch ?? 0);
    final size = int.tryParse('${m['size'] ?? ''}');

    out.add({
      'path': itemPath,
      'name': name,
      'modifiedMs': modifiedMs,
      'size': size,
      'isFolder': false,
    });
  }

  out.sort((a, b) =>
      (b['modifiedMs'] as int? ?? 0).compareTo(a['modifiedMs'] as int? ?? 0));
  return out;
}
