class LogEntry {
  final String time;
  final String key;
  final String? param;
  LogEntry(this.time, this.key, [this.param]);
}

class GDriveFileInfo {
  final String id;
  final String name;
  final DateTime? modifiedTime;
  final int? sizeBytes;
  final bool isFolder;

  const GDriveFileInfo({
    required this.id,
    required this.name,
    this.modifiedTime,
    this.sizeBytes,
    this.isFolder = false,
  });
}

class DropboxFileInfo {
  final String id;
  final String name;
  final String path;
  final DateTime? modifiedTime;
  final int? sizeBytes;
  final bool isFolder;

  const DropboxFileInfo({
    required this.id,
    required this.name,
    required this.path,
    this.modifiedTime,
    this.sizeBytes,
    this.isFolder = false,
  });
}

class YandexDiskFileInfo {
  final String path;
  final String name;
  final DateTime? modifiedTime;
  final int? sizeBytes;
  final bool isFolder;

  const YandexDiskFileInfo({
    required this.path,
    required this.name,
    this.modifiedTime,
    this.sizeBytes,
    this.isFolder = false,
  });
}
