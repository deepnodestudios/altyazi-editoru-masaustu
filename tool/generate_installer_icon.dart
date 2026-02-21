import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  final sourcePath = args.isNotEmpty ? args[0] : 'assets/icon/app_icon.png';
  final outputPath = args.length >= 2 ? args[1] : 'tool/installer_icon.ico';

  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source image not found: $sourcePath');
    exitCode = 2;
    return;
  }

  final bytes = sourceFile.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln('Could not decode image: $sourcePath');
    exitCode = 3;
    return;
  }

  // Include small sizes so Windows can render the icon in titlebars/taskbar/UI.
  const sizes = <int>[16, 24, 32, 48, 64, 128, 256];
  final frames = <img.Image>[];

  for (final size in sizes) {
    final resized = img.copyResize(
      decoded,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    );
    frames.add(resized);
  }

  final icoBytes = img.IcoEncoder().encodeImages(frames);
  final outFile = File(outputPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsBytesSync(icoBytes);

  stdout.writeln('Wrote ICO: $outputPath (${outFile.lengthSync()} bytes)');
}
