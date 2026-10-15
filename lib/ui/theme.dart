import 'package:flutter/material.dart';

/// Resonance's look: big bold titles, generous spacing, rounded artwork,
/// and one warm accent colour.
class AppTheme {
  static const accent = Color(0xFFFF6A3D);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? const Color(0xFF0B0B0D) : const Color(0xFFFFFFFF);
    final surface = dark ? const Color(0xFF1A1A1E) : const Color(0xFFF2F2F5);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: b,
      primary: accent,
      surface: bg,
    ).copyWith(surfaceContainerHighest: surface, surfaceContainer: surface);

    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(
        color: dark ? Colors.white12 : Colors.black12,
        thickness: 0.5,
        space: 0.5,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: dark ? Colors.white : Colors.black,
        ),
        iconTheme: const IconThemeData(color: accent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xF0141416) : const Color(0xF5F9F9FB),
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: s.contains(WidgetState.selected)
                  ? accent
                  : (dark ? Colors.white54 : Colors.black45),
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 26,
              color: s.contains(WidgetState.selected)
                  ? accent
                  : (dark ? Colors.white54 : Colors.black45),
            )),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: dark ? Colors.white : Colors.black87,
        inactiveTrackColor: dark ? Colors.white24 : Colors.black12,
        thumbColor: dark ? Colors.white : Colors.black87,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: dark ? Colors.white : Colors.black,
        displayColor: dark ? Colors.white : Colors.black,
      ),
    );
  }

  static TextStyle largeTitle(BuildContext c) => TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: Theme.of(c).colorScheme.onSurface,
      );

  static TextStyle sectionTitle(BuildContext c) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: Theme.of(c).colorScheme.onSurface,
      );

  static Color secondaryText(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? Colors.white60 : Colors.black54;
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

String formatLongDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '$m minute${m == 1 ? '' : 's'}';
  return '$h hour${h == 1 ? '' : 's'}, $m minute${m == 1 ? '' : 's'}';
}
