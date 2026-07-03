import 'package:flutter/material.dart';

/// Retro CRT/LCD theme foundation for the whole app.
///
/// One [buildRetroTheme] factory restyles every Material widget at once: the
/// bundled VT323 pixel font, a small dark limited palette, flat hard-edged
/// (zero-radius, zero-elevation, thick-bordered) components, and larger
/// controls. `AppWidget` hands it to `MaterialApp.router`, so all six chrome
/// surfaces inherit it with no per-file edits.

/// The shared dark "screen" colour the creature sprite renders on.
///
/// CLIENT↔SERVER COUPLING — SOURCE OF TRUTH. Phase 5's Gemini birth-prompt in
/// `tamagotchi_server/lib/src/llm/critter_image_prompt.dart` must request this
/// EXACT hex (`#0E1712`) so a freshly-hatched sprite's flat JPEG background
/// matches the panel behind it and blends into the chrome. Server and client
/// share no code, so the value is duplicated by hand: change it here and you
/// MUST change it there too, or new sprites show a mismatched halo.
const Color retroScreenColor = Color(0xFF0E1712);

// --- Limited CRT palette -----------------------------------------------------
const Color _screen = retroScreenColor; // base "screen" / scaffold
const Color _panel = Color(0xFF17241C); // raised panels / cards
const Color _phosphor = Color(0xFF6FE79F); // primary phosphor-green accent
const Color _amber = Color(0xFFE8C15A); // secondary amber accent
const Color _ink = Color(0xFFCDEBD6); // body text — soft green-white
const Color _outline = Color(0xFF3E5B49); // borders / dividers
const Color _danger = Color(0xFFF2647B); // error red
const Color _onAccent = Color(0xFF04140A); // ink on the phosphor accent

// Container ("bubble"/chip) grounds. These are DARK on purpose: the app renders
// the creature talk bubble, the journal "Day one" origin card, and the chips
// with light VT323 ink, so a bright container would be illegible. Setting them
// explicitly also stops ColorScheme.dark() from falling `primaryContainer` back
// to the bright `primary` (which is exactly what made the bubbles unreadable).
const Color _greenBubble = Color(0xFF10331E); // primaryContainer — talk/origin
const Color _amberBubble = Color(0xFF33290F); // secondaryContainer
const Color _cyan = Color(0xFF6FD3E7); // tertiary accent
const Color _cyanBubble = Color(0xFF123037); // tertiaryContainer — "exhausted"
const Color _cyanInk = Color(0xFFBFE9F2); // onTertiaryContainer
const Color _panelHigh = Color(0xFF20302A); // surfaceContainerHighest — chips
const Color _mutedInk = Color(0xFF9DBBA6); // onSurfaceVariant — muted labels

/// The retro look is hard-edged: every corner in the app is square.
const BorderRadius _squareRadius = BorderRadius.zero;

/// Shared thick border for the flat panels/controls.
const BorderSide _border = BorderSide(color: _outline, width: 2);

/// Larger tap targets than Material's defaults (48 / 36).
const double _controlHeight = 52;

/// The one square, thick-bordered shape shared by cards, dialogs, and buttons.
const RoundedRectangleBorder _squareShape = RoundedRectangleBorder(
  borderRadius: _squareRadius,
  side: _border,
);

/// Builds the app-wide retro [ThemeData]. Pure and cheap; safe to call in tests.
ThemeData buildRetroTheme() {
  final colorScheme =
      const ColorScheme.dark(
        primary: _phosphor,
        onPrimary: _onAccent,
        secondary: _amber,
        onSecondary: Color(0xFF1B1405),
        surface: _panel,
        onSurface: _ink,
        error: _danger,
        onError: Color(0xFF1B0509),
        outline: _outline,
      ).copyWith(
        surfaceTint: Colors.transparent,
        // Dark bubble/chip grounds with light on-colours (see the const notes).
        primaryContainer: _greenBubble,
        onPrimaryContainer: _ink,
        secondaryContainer: _amberBubble,
        onSecondaryContainer: _amber,
        tertiary: _cyan,
        onTertiary: _onAccent,
        tertiaryContainer: _cyanBubble,
        onTertiaryContainer: _cyanInk,
        surfaceContainerHighest: _panelHigh,
        onSurfaceVariant: _mutedInk,
      );

  // Bitmap font reads small — bump the body slots so journal prose stays
  // legible in VT323. (A blanket fontSizeFactor can't be used: some
  // whiteMountainView slots have a null fontSize, which trips TextStyle.apply.)
  final baseTextTheme = Typography.whiteMountainView.apply(
    fontFamily: 'VT323',
    bodyColor: _ink,
    displayColor: _ink,
  );
  final textTheme = baseTextTheme.copyWith(
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 20),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 18),
    bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: 16),
  );

  final buttonStyle = ButtonStyle(
    elevation: const WidgetStatePropertyAll<double>(0),
    shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    minimumSize: const WidgetStatePropertyAll<Size>(Size(96, _controlHeight)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(_squareShape),
    textStyle: const WidgetStatePropertyAll<TextStyle>(
      TextStyle(fontFamily: 'VT323', fontSize: 24, letterSpacing: 1),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    fontFamily: 'VT323',
    scaffoldBackgroundColor: _screen,
    canvasColor: _screen,
    dividerColor: _outline,
    splashFactory: NoSplash.splashFactory, // flat — no Material ripple
    textTheme: textTheme,
    dividerTheme: const DividerThemeData(
      color: _outline,
      thickness: 2,
      space: 2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: buttonStyle.copyWith(
        backgroundColor: const WidgetStatePropertyAll<Color>(_phosphor),
        foregroundColor: const WidgetStatePropertyAll<Color>(_onAccent),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: buttonStyle.copyWith(
        foregroundColor: const WidgetStatePropertyAll<Color>(_phosphor),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buttonStyle.copyWith(
        foregroundColor: const WidgetStatePropertyAll<Color>(_phosphor),
        side: const WidgetStatePropertyAll<BorderSide>(_border),
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: _panel,
      surfaceTintColor: Colors.transparent,
      shape: _squareShape,
      margin: EdgeInsets.all(8),
    ),
    dialogTheme: const DialogThemeData(
      elevation: 0,
      backgroundColor: _panel,
      surfaceTintColor: Colors.transparent,
      shape: _squareShape,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: _screen,
      border: OutlineInputBorder(
        borderRadius: _squareRadius,
        borderSide: _border,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _squareRadius,
        borderSide: _border,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _squareRadius,
        borderSide: BorderSide(color: _phosphor, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _screen,
      foregroundColor: _phosphor,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    snackBarTheme: const SnackBarThemeData(
      elevation: 0,
      backgroundColor: _panel,
      contentTextStyle: TextStyle(
        fontFamily: 'VT323',
        fontSize: 20,
        color: _ink,
      ),
      shape: _squareShape,
      behavior: SnackBarBehavior.floating,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: _phosphor,
      unselectedLabelColor: _ink,
      indicatorColor: _phosphor,
      dividerColor: _outline,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _phosphor),
    // Not const: SliderComponentShape.noOverlay is a static-final, not a
    // compile-time constant.
    sliderTheme: SliderThemeData(
      trackHeight: 6,
      trackShape: const RectangularSliderTrackShape(),
      thumbShape: const _RetroSliderThumbShape(),
      overlayShape: SliderComponentShape.noOverlay, // no round halo
      tickMarkShape: SliderTickMarkShape.noTickMark,
      valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
      activeTrackColor: _phosphor,
      inactiveTrackColor: _outline,
      thumbColor: _phosphor,
      valueIndicatorColor: _panel,
      valueIndicatorTextStyle: const TextStyle(
        fontFamily: 'VT323',
        fontSize: 18,
        color: _ink,
      ),
    ),
  );
}

/// A flat, hard-edged square slider thumb — the default [RoundSliderThumbShape]
/// is a circle, which reads as modern Material against the retro chrome. Drawn
/// as a filled square with a dark outline (mirrors the button/panel borders).
class _RetroSliderThumbShape extends SliderComponentShape {
  const _RetroSliderThumbShape();

  static const Size _size = Size(16, 22);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => _size;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final rect = Rect.fromCenter(
      center: center,
      width: _size.width,
      height: _size.height,
    );
    final fill = Paint()..color = sliderTheme.thumbColor ?? _phosphor;
    final border = Paint()
      ..color = _onAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas
      ..drawRect(rect, fill)
      ..drawRect(rect, border);
  }
}
