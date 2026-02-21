import 'package:flutter/foundation.dart';

class CloudStateManager extends ChangeNotifier {
  bool _isGoogleSignedIn = false;
  bool _isGDriveConnected = false;
  bool _isDropboxConnected = false;
  bool _isYandexConnected = false;
  bool _isOffline = false;
  String? _loadingAuthProvider;

  // Getters
  bool get isGoogleSignedIn => _isGoogleSignedIn;
  bool get isGDriveConnected => _isGDriveConnected;
  bool get isDropboxConnected => _isDropboxConnected;
  bool get isYandexConnected => _isYandexConnected;
  bool get isOffline => _isOffline;
  String? get loadingAuthProvider => _loadingAuthProvider;

  bool get isAuthLoading => _loadingAuthProvider != null;

  bool isProviderLoading(String provider) => _loadingAuthProvider == provider;

  bool get isAnyCloudConnected =>
      _isGDriveConnected || _isDropboxConnected || _isYandexConnected;

  // Setters
  void setIsGoogleSignedIn(bool value) {
    if (_isGoogleSignedIn != value) {
      _isGoogleSignedIn = value;
      notifyListeners();
    }
  }

  void setIsGDriveConnected(bool value) {
    if (_isGDriveConnected != value) {
      _isGDriveConnected = value;
      notifyListeners();
    }
  }

  void setIsDropboxConnected(bool value) {
    if (_isDropboxConnected != value) {
      _isDropboxConnected = value;
      notifyListeners();
    }
  }

  void setIsYandexConnected(bool value) {
    if (_isYandexConnected != value) {
      _isYandexConnected = value;
      notifyListeners();
    }
  }

  void setIsOffline(bool value) {
    if (_isOffline != value) {
      _isOffline = value;
      notifyListeners();
    }
  }

  void setLoadingAuthProvider(String? provider) {
    if (_loadingAuthProvider != provider) {
      _loadingAuthProvider = provider;
      notifyListeners();
    }
  }

  // Disconnect specific cloud service
  void disconnectGDrive() {
    setIsGDriveConnected(false);
  }

  void disconnectDropbox() {
    setIsDropboxConnected(false);
  }

  void disconnectYandex() {
    setIsYandexConnected(false);
  }

  // Disconnect all cloud services
  void disconnectAllCloudServices() {
    _isGDriveConnected = false;
    _isDropboxConnected = false;
    _isYandexConnected = false;
    notifyListeners();
  }

  // Reset Google sign-in
  void resetGoogleSignIn() {
    _isGoogleSignedIn = false;
    _loadingAuthProvider = null;
    notifyListeners();
  }

  // Initialize from saved state
  Future<void> loadCloudStateFromPrefs() async {
    // Cloud connection states are determined dynamically from tokens,
    // not persisted in SharedPreferences
    _isGoogleSignedIn = false;
    _isGDriveConnected = false;
    _isDropboxConnected = false;
    _isYandexConnected = false;
    _isOffline = false;
    _loadingAuthProvider = null;
    
    notifyListeners();
  }
}
