import 'package:flutter/material.dart';

/// Colors that describe how close an item is to its best-before date.
@immutable
class FreshnessColors extends ThemeExtension<FreshnessColors> {
  const FreshnessColors({
    required this.fresh,
    required this.useSoon,
    required this.expired,
  });

  final Color fresh;
  final Color useSoon;
  final Color expired;

  @override
  FreshnessColors copyWith({Color? fresh, Color? useSoon, Color? expired}) {
    return FreshnessColors(
      fresh: fresh ?? this.fresh,
      useSoon: useSoon ?? this.useSoon,
      expired: expired ?? this.expired,
    );
  }

  @override
  FreshnessColors lerp(FreshnessColors? other, double t) {
    if (other == null) return this;
    return FreshnessColors(
      fresh: Color.lerp(fresh, other.fresh, t)!,
      useSoon: Color.lerp(useSoon, other.useSoon, t)!,
      expired: Color.lerp(expired, other.expired, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  /// Launcher icon background.
  static const Color forest = Color(0xFF143F35);

  /// Launcher icon leaf.
  static const Color leaf = Color(0xFFBBDC74);
  static const Color moss = Color(0xFF34745B);
  static const Color paper = Color(0xFFF5F7F3);
  static const Color canopy = Color(0xFF0D1A15);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: moss);
    return _build(
      colorScheme,
      scaffold: paper,
      freshness: FreshnessColors(
        fresh: colorScheme.primary,
        useSoon: const Color(0xFF8A5A00),
        expired: colorScheme.error,
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: moss,
      brightness: Brightness.dark,
    ).copyWith(
      primary: leaf,
      onPrimary: forest,
      primaryContainer: const Color(0xFF2C5236),
      onPrimaryContainer: const Color(0xFFD7F0A6),
      secondaryContainer: const Color(0xFF22443A),
      onSecondaryContainer: const Color(0xFFCBE9DA),
      surface: const Color(0xFF13231D),
      surfaceContainerLowest: const Color(0xFF09140F),
      surfaceContainerLow: const Color(0xFF101E18),
      surfaceContainer: const Color(0xFF15261F),
      surfaceContainerHigh: const Color(0xFF1B2E26),
      surfaceContainerHighest: const Color(0xFF22362D),
      outlineVariant: const Color(0xFF2B4138),
    );
    return _build(
      colorScheme,
      scaffold: canopy,
      freshness: FreshnessColors(
        fresh: leaf,
        useSoon: const Color(0xFFF2C66D),
        expired: colorScheme.error,
      ),
    );
  }

  static ThemeData _build(
    ColorScheme colorScheme, {
    required Color scaffold,
    required FreshnessColors freshness,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      extensions: [freshness],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        // Explicit size: the theme text styles only gain sizes once localized.
        titleTextStyle: TextStyle(
          fontSize: 22,
          height: 28 / 22,
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
      ),
    );
  }
}

extension FreshnessTheme on ThemeData {
  FreshnessColors get freshness => extension<FreshnessColors>()!;
}
