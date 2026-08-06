import 'package:path/path.dart' show basename;

class BatchFileItem {
  final String name;
  final String path;
  final String source;
  final String? hash;

  const BatchFileItem({
    required this.name,
    required this.path,
    this.source = 'device',
    this.hash,
  });

  factory BatchFileItem.fromJson(Map<String, dynamic> json) {
    final rawPath = (json['path'] ?? '').toString();
    final rawName = (json['name'] ?? '').toString();

    final computedName = rawName.isNotEmpty
        ? rawName
        : (rawPath.isNotEmpty ? basename(rawPath) : 'Unknown');

    return BatchFileItem(
      name: computedName,
      path: rawPath,
      source: (json['source'] ?? 'device').toString(),
      hash: json['hash']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'source': source,
      'hash': hash,
    };
  }

  BatchFileItem copyWith({
    String? name,
    String? path,
    String? source,
    String? hash,
  }) {
    return BatchFileItem(
      name: name ?? this.name,
      path: path ?? this.path,
      source: source ?? this.source,
      hash: hash ?? this.hash,
    );
  }
}
