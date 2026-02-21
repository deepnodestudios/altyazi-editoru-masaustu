import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

class FileService {
  Future<File?> pickSrtFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
    );

    if (result != null && result.files.single.path != null) {
      final name = result.files.single.name.toLowerCase();
      if (!(name.endsWith('.srt') || name.endsWith('.vtt'))) {
        throw Exception('Sadece .srt / .vtt dosyaları destekleniyor.');
      }
      final file = File(result.files.single.path!);
      
      // 500KB kontrolü (500 * 1024 bytes)
      final size = await file.length();
      if (size > 500 * 1024) {
        throw Exception('Dosya boyutu 500KB sınırını aşıyor.');
      }

      return file;
    }
    return null;
  }

  Future<String> calculateMd5(File file) async {
    final bytes = await file.readAsBytes();
    return md5.convert(bytes).toString();
  }

  /// String içeriğinden MD5 hash hesapla (resume consistency için)
  String calculateMd5FromString(String content) {
    final bytes = utf8.encode(content);
    return md5.convert(bytes).toString();
  }
}