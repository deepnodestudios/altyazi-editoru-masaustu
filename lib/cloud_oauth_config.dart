class CloudOAuthConfig {
  /// OAuth redirect URI used for Dropbox flows.
  ///
  /// Must be registered in the provider console AND in AndroidManifest intent-filters.
  /// Example redirect URI: com.deepnode.altyaziceviri://oauth2redirect
  static const String redirectScheme = 'com.deepnode.altyaziceviri';
  static const String redirectHost = 'oauth2redirect';

  static String get redirectUri => '$redirectScheme://$redirectHost';

  /// Desktop Dropbox OAuth loopback redirect.
  /// Add this exact URI in Dropbox app settings -> Redirect URIs.
  static const String dropboxDesktopRedirectUri =
      'http://127.0.0.1:53682/oauth2redirect';

  /// Yandex OAuth redirect URI used for the "show confirmation code" flow.
  ///
  /// Yandex requires an HTTPS Redirect URI for web services. For mobile apps,
  /// we use their built-in page that displays a confirmation code to the user.
  static const String yandexVerificationCodeRedirectUri =
      'https://oauth.yandex.com/verification_code';

  /// Dropbox app client id.
  /// Create an app at https://www.dropbox.com/developers/apps
  /// Provide at runtime using: --dart-define=DROPBOX_CLIENT_ID=...
    static const String _defaultDropboxClientId = 'dvngybwvqxiwuq7';
  static const String _envDropboxClientId =
            String.fromEnvironment(
                'DROPBOX_CLIENT_ID',
                defaultValue: _defaultDropboxClientId,
            );
  static String get dropboxClientId =>
      _envDropboxClientId.trim().isNotEmpty
          ? _envDropboxClientId
          : _defaultDropboxClientId;

  /// Google OAuth client id for desktop PKCE login.
  /// Provide at runtime using: --dart-define=GOOGLE_OAUTH_CLIENT_ID=...
    ///
    /// Defaults to the desktop OAuth client ID so Windows login works out of the
    /// box without additional runtime flags.
    static const String _defaultGoogleOauthClientId =
      '203321032277-47m517a2dd5k6f4u5jdjbrhfp0vcm2ce.apps.googleusercontent.com';
  static const String _envGoogleOauthClientId =
      String.fromEnvironment(
        'GOOGLE_OAUTH_CLIENT_ID',
        defaultValue: _defaultGoogleOauthClientId,
      );
  static String get googleOauthClientId =>
      _envGoogleOauthClientId.trim().isNotEmpty
          ? _envGoogleOauthClientId
          : _defaultGoogleOauthClientId;

  static const String _defaultGoogleOauthClientSecret =
      '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';
  static const String _envGoogleOauthClientSecret =
      String.fromEnvironment(
        'GOOGLE_OAUTH_CLIENT_SECRET',
        defaultValue: _defaultGoogleOauthClientSecret,
      );
  static String get googleOauthClientSecret =>
      _envGoogleOauthClientSecret.trim().isNotEmpty
          ? _envGoogleOauthClientSecret
          : _defaultGoogleOauthClientSecret;

  /// Yandex OAuth app id (ClientID) for Yandex Disk.
  /// Create an app at https://oauth.yandex.com/client/new/
  /// Provide at runtime using: --dart-define=YANDEX_CLIENT_ID=...
    static const String _defaultYandexClientId =
            'b747781e7bc64456b4a9f7e980b4d009';
  static const String _envYandexClientId =
            String.fromEnvironment(
                'YANDEX_CLIENT_ID',
                defaultValue: _defaultYandexClientId,
            );
  static String get yandexClientId =>
      _envYandexClientId.trim().isNotEmpty
          ? _envYandexClientId
          : _defaultYandexClientId;

  /// Yandex OAuth app secret key.
  /// Required to exchange authorization_code and refresh_token.
  ///
  /// IMPORTANT: A client secret cannot be kept truly secret in a mobile/desktop app.
  /// If you need real secrecy, move the token exchange to a backend (Cloud Functions)
  /// or switch to an OAuth flow that doesn't require a client secret (e.g. PKCE) if supported.
  /// Provide at runtime using: --dart-define=YANDEX_CLIENT_SECRET=...
    static const String _defaultYandexClientSecret =
            '45e36fb0484b4cdeb48161813751b67a';
  static const String _envYandexClientSecret =
            String.fromEnvironment(
                'YANDEX_CLIENT_SECRET',
                defaultValue: _defaultYandexClientSecret,
            );
  static String get yandexClientSecret =>
      _envYandexClientSecret.trim().isNotEmpty
          ? _envYandexClientSecret
          : _defaultYandexClientSecret;

  static bool get hasDropboxConfig => dropboxClientId.trim().isNotEmpty;
  static bool get hasGoogleOauthConfig => googleOauthClientId.trim().isNotEmpty;
  static bool get hasYandexConfig =>
      yandexClientId.trim().isNotEmpty && yandexClientSecret.trim().isNotEmpty;

  /// Google Drive folder id that stores desktop installer files.
  /// Provide at runtime using: --dart-define=GDRIVE_UPDATE_FOLDER_ID=...
  static const String googleDriveUpdateFolderId =
      String.fromEnvironment('GDRIVE_UPDATE_FOLDER_ID', defaultValue: '1MLlLkBXpFHwYsebpf3_GGEiPm-IkohaP');

  /// Optional public Google Drive folder URL for manual navigation fallback.
  /// Provide at runtime using: --dart-define=GDRIVE_UPDATE_FOLDER_URL=...
  static const String googleDriveUpdateFolderUrl =
      String.fromEnvironment(
        'GDRIVE_UPDATE_FOLDER_URL',
        defaultValue:
            'https://drive.google.com/drive/folders/1MLlLkBXpFHwYsebpf3_GGEiPm-IkohaP?usp=sharing',
      );
}
