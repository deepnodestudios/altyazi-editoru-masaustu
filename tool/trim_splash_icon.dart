import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Trims transparent padding from a PNG and writes a square output PNG.
///
/// This is used to create a larger-looking splash logo without manually editing
/// assets.
void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('Usage:');
    stdout.writeln(
      '  dart run tool/trim_splash_icon.dart [inputPath] [outputPath] [outputAndroid12Path] '
      '[--target-size=1024] [--padding-regular=0.06] [--padding-android12=0.22]'
      ' [--alpha-threshold=8]',
    );
    return;
  }

  // Keep backward-compatible positional args, but also support simple
  // --key=value options.
  final options = <String, String>{};
  final positionals = <String>[];
  for (final arg in args) {
    if (arg.startsWith('--')) {
      final eq = arg.indexOf('=');
      if (eq > 2) {
        final key = arg.substring(2, eq).trim();
        final value = arg.substring(eq + 1).trim();
        if (key.isNotEmpty) options[key] = value;
      }
    } else {
      positionals.add(arg);
    }
  }

  final inputPath =
      positionals.isNotEmpty ? positionals[0] : 'assets/icon/app_icon.png';
  final outputPath =
      positionals.length > 1 ? positionals[1] : 'assets/icon/splash_icon.png';
  final outputAndroid12Path = positionals.length > 2
      ? positionals[2]
      : 'assets/icon/splash_android12_icon.png';

  final targetSize = int.tryParse(options['target-size'] ?? '') ?? 1024;
  final paddingRegular =
      double.tryParse(options['padding-regular'] ?? '') ?? 0.06;
  final paddingAndroid12 =
      double.tryParse(options['padding-android12'] ?? '') ?? 0.22;
  final alphaThreshold = int.tryParse(options['alpha-threshold'] ?? '') ?? 8;

    final bool removeSolidBg = (options['remove-solid-bg'] ?? 'true') != 'false';
    final int bgTolerance = int.tryParse(options['bg-tolerance'] ?? '') ?? 26;
    final String? sampleBgColorPath = options['sample-bg-color'];
    final String? sampleEdgeColorPath = options['sample-edge-color'];

  if (targetSize <= 0) {
    stderr.writeln('Invalid --target-size: $targetSize');
    exitCode = 2;
    return;
  }

  if (paddingRegular < 0 || paddingRegular >= 0.5) {
    stderr.writeln('Invalid --padding-regular: $paddingRegular');
    exitCode = 2;
    return;
  }
  if (paddingAndroid12 < 0 || paddingAndroid12 >= 0.5) {
    stderr.writeln('Invalid --padding-android12: $paddingAndroid12');
    exitCode = 2;
    return;
  }

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: $inputPath');
    exitCode = 2;
    return;
  }

  final bytes = inputFile.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    stderr.writeln('Failed to decode image: $inputPath');
    exitCode = 3;
    return;
  }

  String toHexRgb(int r, int g, int b) {
    String h(int v) => v.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${h(r)}${h(g)}${h(b)}';
  }

  img.Image? tryDecode(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    return img.decodeImage(f.readAsBytesSync());
  }

  if (sampleBgColorPath != null && sampleBgColorPath.trim().isNotEmpty) {
    final bgImg = tryDecode(sampleBgColorPath.trim());
    if (bgImg == null) {
      stderr.writeln('Failed to decode --sample-bg-color image: $sampleBgColorPath');
      exitCode = 5;
      return;
    }

    // Sample a small patch from each corner to estimate the dominant background.
    final patch = 32;
    final w = bgImg.width;
    final h = bgImg.height;
    final corners = <(int, int)>[
      (0, 0),
      (w - patch, 0),
      (0, h - patch),
      (w - patch, h - patch),
    ];

    int sumR = 0, sumG = 0, sumB = 0, count = 0;
    for (final (cx, cy) in corners) {
      for (var y = cy; y < cy + patch; y++) {
        for (var x = cx; x < cx + patch; x++) {
          final p = bgImg.getPixel(x.clamp(0, w - 1), y.clamp(0, h - 1));
          if (p.a < 10) continue;
          sumR += p.r.toInt();
          sumG += p.g.toInt();
          sumB += p.b.toInt();
          count++;
        }
      }
    }

    if (count == 0) {
      stderr.writeln('Could not sample background color (all transparent?): $sampleBgColorPath');
      exitCode = 6;
      return;
    }

    final r = (sumR / count).round();
    final g = (sumG / count).round();
    final b = (sumB / count).round();
    stdout.writeln('Sampled background color: ${toHexRgb(r, g, b)}');
    return;
  }

  if (sampleEdgeColorPath != null && sampleEdgeColorPath.trim().isNotEmpty) {
    final edgeImg = tryDecode(sampleEdgeColorPath.trim());
    if (edgeImg == null) {
      stderr.writeln('Failed to decode --sample-edge-color image: $sampleEdgeColorPath');
      exitCode = 7;
      return;
    }

    final w = edgeImg.width;
    final h = edgeImg.height;
    final cx = (w - 1) / 2.0;
    final cy = (h - 1) / 2.0;
    final radius = (w < h ? w : h) / 2.0;
    final rMin = radius * 0.40;
    final rMax = radius * 0.49;

    double luminance(int r, int g, int b) {
      // sRGB relative luminance approximation.
      return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
    }

    int sumR = 0, sumG = 0, sumB = 0, count = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = edgeImg.getPixel(x, y);
        if (p.a.toInt() <= 10) continue;
        final dx = x - cx;
        final dy = y - cy;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < rMin || d > rMax) continue;

        final pr = p.r.toInt();
        final pg = p.g.toInt();
        final pb = p.b.toInt();
        final l = luminance(pr, pg, pb);

        // Exclude very bright pixels (like white glyphs) so we sample mostly
        // from the ring/edge colors.
        if (l > 0.70) continue;

        sumR += pr;
        sumG += pg;
        sumB += pb;
        count++;
      }
    }

    if (count == 0) {
      stderr.writeln('Could not sample edge color (no eligible pixels): $sampleEdgeColorPath');
      exitCode = 8;
      return;
    }

    final r = (sumR / count).round();
    final g = (sumG / count).round();
    final b = (sumB / count).round();
    stdout.writeln('Sampled edge color: ${toHexRgb(r, g, b)}');
    return;
  }

  // Optionally remove a near-solid background color from the input (useful
  // when the icon has a rounded-square background that looks octagonal on splash).
  img.Image working = image;
  if (removeSolidBg) {
    final w = working.width;
    final h = working.height;
    final cornerPixels = <img.Pixel>[
      working.getPixel(0, 0),
      working.getPixel(w - 1, 0),
      working.getPixel(0, h - 1),
      working.getPixel(w - 1, h - 1),
    ];
    final avgR = cornerPixels.map((p) => p.r.toInt()).reduce((a, b) => a + b) ~/ cornerPixels.length;
    final avgG = cornerPixels.map((p) => p.g.toInt()).reduce((a, b) => a + b) ~/ cornerPixels.length;
    final avgB = cornerPixels.map((p) => p.b.toInt()).reduce((a, b) => a + b) ~/ cornerPixels.length;

    int dist(int r, int g, int b) {
      final dr = (r - avgR).abs();
      final dg = (g - avgG).abs();
      final db = (b - avgB).abs();
      return dr + dg + db;
    }

    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = working.getPixel(x, y);
        final a = p.a.toInt();
        if (a <= alphaThreshold) {
          out.setPixelRgba(x, y, 0, 0, 0, 0);
          continue;
        }
        final d = dist(p.r.toInt(), p.g.toInt(), p.b.toInt());
        if (d <= bgTolerance) {
          out.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), a);
        }
      }
    }
    working = out;
  }

  // Find bounding box of non-transparent pixels.
  final width = working.width;
  final height = working.height;
  int left = width;
  int right = -1;
  int top = height;
  int bottom = -1;

  // treat near-transparent as transparent

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = working.getPixel(x, y);
      final a = p.a;
      if (a > alphaThreshold) {
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }

  if (right < left || bottom < top) {
    stderr.writeln('Image appears fully transparent: $inputPath');
    exitCode = 4;
    return;
  }

  // Crop to content.
  var cropped = img.copyCrop(
    working,
    x: left,
    y: top,
    width: (right - left + 1),
    height: (bottom - top + 1),
  );

  // Create a square canvas and scale cropped content to fill it with padding.
  // Target size: keep high-res for iOS/Android splash generation.
  img.Image renderWithPadding(double paddingFraction) {
    final innerSize = (targetSize * (1.0 - 2 * paddingFraction)).round();
    final scaled = img.copyResize(
      cropped,
      width: innerSize,
      height: innerSize,
      interpolation: img.Interpolation.cubic,
    );

    final out = img.Image(width: targetSize, height: targetSize);
    img.fill(out, color: img.ColorRgba8(0, 0, 0, 0));

    final offset = ((targetSize - innerSize) / 2).round();
    img.compositeImage(out, scaled, dstX: offset, dstY: offset);
    return out;
  }

  // Regular splash: keep the logo big but leave enough breathing room so the
  // circular edges don't look clipped.
  final outRegular = renderWithPadding(paddingRegular);
  final outFile = File(outputPath);
  outFile.createSync(recursive: true);
  outFile.writeAsBytesSync(img.encodePng(outRegular, level: 6));
  stdout.writeln('Wrote trimmed splash icon: $outputPath');

  // Android 12+: system masks the splash icon to a circle, so we need extra
  // padding to avoid cutting off the logo edges.
  final outAndroid12 = renderWithPadding(paddingAndroid12);
  final outAndroid12File = File(outputAndroid12Path);
  outAndroid12File.createSync(recursive: true);
  outAndroid12File.writeAsBytesSync(img.encodePng(outAndroid12, level: 6));
  stdout.writeln('Wrote Android 12 splash icon: $outputAndroid12Path');
}