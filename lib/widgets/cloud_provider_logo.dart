import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

class CloudProviderAssets {
  static const String googleDrive = 'assets/icon/cloud/google_drive.svg';
  static const String dropbox = 'assets/icon/cloud/dropbox.svg';
  static const String yandexDisk = 'assets/icon/cloud/yandex_disk.svg';
}

class CloudProviderLogo extends StatelessWidget {
  const CloudProviderLogo({
    super.key,
    required this.asset,
    this.size = 24,
    this.monochrome = false,
    this.semanticLabel,
  });

  final String asset;
  final double size;
  final bool monochrome;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;

    // `flutter_svg` will throw if the asset is missing/empty. If that error
    // bubbles up to PlatformDispatcher.onError with `return false`, the app may
    // terminate. Preload bytes and provide a safe fallback.
    return FutureBuilder<ByteData>(
      future: DefaultAssetBundle.of(context).load(asset),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(width: size, height: size);
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Icon(Icons.cloud_off, size: size, color: iconColor);
        }

        final bytes = snapshot.data!.buffer.asUint8List();
        if (bytes.isEmpty) {
          return Icon(Icons.cloud_off, size: size, color: iconColor);
        }

        return SvgPicture.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: monochrome
              ? ColorFilter.mode(iconColor, BlendMode.srcIn)
              : null,
          semanticsLabel: semanticLabel,
        );
      },
    );
  }
}
