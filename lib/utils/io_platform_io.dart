import 'dart:io' show Platform;

bool get isWindows => Platform.isWindows;
bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
String get operatingSystem => Platform.operatingSystem;
