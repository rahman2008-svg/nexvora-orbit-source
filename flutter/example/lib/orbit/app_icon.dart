import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'orbit_native.dart';
import 'orbit_theme.dart';

/// Lazy-loaded app icon (PNG from PackageManager) with a letter fallback.
class AppIconView extends StatelessWidget {
  const AppIconView({super.key, required this.native, required this.app, this.size = 44});
  final NativeBridge native;
  final InstalledApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: native.iconFor(app.package, size: (size * 2).round()),
      builder: (_, snap) {
        final bytes = snap.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.24),
          child: SizedBox(
            width: size,
            height: size,
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
                : Container(
                    color: OrbitColors.surfaceHi,
                    alignment: Alignment.center,
                    child: Text(
                      app.label.isEmpty ? '?' : app.label.characters.first.toUpperCase(),
                      style: TextStyle(fontSize: size * 0.45, color: OrbitColors.secondary),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
