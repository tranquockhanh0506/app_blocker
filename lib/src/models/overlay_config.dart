import 'dart:ui';

/// Configuration for the Android overlay shown when a blocked app is opened.
///
/// This has no effect on iOS, where the system shield is used instead.
class OverlayConfig {
  /// Creates an [OverlayConfig] instance.
  const OverlayConfig({
    this.title,
    this.subtitle,
    this.message,
    this.backgroundColor,
    this.iconAssetPath,
  });

  /// The title text shown on the overlay.
  ///
  /// Defaults to "App Blocked" if not specified.
  final String? title;

  /// The subtitle text shown below the title.
  final String? subtitle;

  /// Additional message text shown on the overlay.
  final String? message;

  /// The background color of the overlay.
  ///
  /// Defaults to a dark semi-transparent color if not specified.
  final Color? backgroundColor;

  /// Path to a custom icon asset to display on the overlay.
  ///
  /// Should be a Flutter asset path (e.g., `assets/icons/lock.png`).
  final String? iconAssetPath;

  /// Converts this instance to a map.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'message': message,
      'backgroundColor': backgroundColor?.toARGB32(),
      'iconAssetPath': iconAssetPath,
    };
  }

  @override
  String toString() => 'OverlayConfig(title: $title, subtitle: $subtitle)';
}
