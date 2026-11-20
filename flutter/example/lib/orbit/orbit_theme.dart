import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// NexVora ORBIT design tokens (from the reference sheets).
class OrbitColors {
  static const Color bg = Color(0xFF080A14);
  static const Color primary = Color(0xFF792EFF);
  static const Color secondary = Color(0xFF00D5FF);
  static const Color surface = Color(0xFF111426);
  static const Color surfaceHi = Color(0xFF1A1E38);
  static const Color border = Color(0x33792EFF);
  static const Color text = Color(0xFFF2F3FA);
  static const Color textDim = Color(0xFF9AA0C0);
  static const Color ok = Color(0xFF2EE59D);
  static const Color warn = Color(0xFFFFB020);
  static const Color error = Color(0xFFFF5470);

  static const LinearGradient brand = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

ThemeData orbitTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: OrbitColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: OrbitColors.primary,
    secondary: OrbitColors.secondary,
    surface: OrbitColors.surface,
    onSurface: OrbitColors.text,
    error: OrbitColors.error,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: OrbitColors.bg,
    canvasColor: OrbitColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: OrbitColors.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: OrbitColors.text,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: OrbitColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: OrbitColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OrbitColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: OrbitColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: OrbitColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: OrbitColors.secondary),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: OrbitColors.surface,
      selectedColor: OrbitColors.primary,
      side: const BorderSide(color: OrbitColors.border),
      labelStyle: const TextStyle(color: OrbitColors.text),
      shape: const StadiumBorder(),
    ),
    dividerColor: OrbitColors.border,
    textTheme: Typography.whiteMountainView.apply(
      bodyColor: OrbitColors.text,
      displayColor: OrbitColors.text,
    ),
  );
}

/// Dark glass panel: translucent fill, hairline violet border, optional blur.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.onTap,
    this.glow = false,
    this.blur = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  final bool glow;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: OrbitColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: OrbitColors.border),
        boxShadow: glow
            ? [BoxShadow(color: OrbitColors.primary.withValues(alpha: 0.25), blurRadius: 18)]
            : null,
      ),
      child: child,
    );
    if (blur) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: body),
      );
    }
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: body),
    );
  }
}

enum OrbMode { idle, listening, thinking }

/// Animated AI orb: glowing sphere, tilted cyan ring, white sparkle. One
/// AnimationController + one CustomPainter (wrapped in a RepaintBoundary) keeps
/// it cheap; the loop pauses when the widget is off-screen (TickerMode).
class OrbitOrb extends StatefulWidget {
  const OrbitOrb({super.key, this.size = 200, this.mode = OrbMode.idle});
  final double size;
  final OrbMode mode;

  @override
  State<OrbitOrb> createState() => _OrbitOrbState();
}

class _OrbitOrbState extends State<OrbitOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(painter: _OrbPainter(_c.value, widget.mode)),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t, this.mode);
  final double t;
  final OrbMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final speed = switch (mode) { OrbMode.idle => 1.0, OrbMode.listening => 3.0, OrbMode.thinking => 2.0 };
    final pulse = 1 + 0.035 * math.sin(t * 2 * math.pi * speed);
    final r = size.width * 0.27 * pulse;

    // Outer glow.
    canvas.drawCircle(
      c,
      r * 1.9,
      Paint()
        ..shader = RadialGradient(colors: [
          OrbitColors.primary.withValues(alpha: mode == OrbMode.listening ? 0.55 : 0.38),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: c, radius: r * 1.9)),
    );

    void ring(bool front) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.38);
      final rect = Rect.fromCenter(center: Offset.zero, width: r * 3.1, height: r * 1.1);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.018
        ..shader = const SweepGradient(
          colors: [OrbitColors.secondary, OrbitColors.primary, OrbitColors.secondary],
        ).createShader(rect);
      // Front arc = lower half; back arc = upper half (hidden behind sphere).
      canvas.drawArc(rect, front ? 0 : math.pi, math.pi, false, p);
      canvas.restore();
    }

    ring(false);

    // Sphere.
    final hi = Offset(c.dx - r * 0.35, c.dy - r * 0.4);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: Alignment((hi.dx - c.dx) / r, (hi.dy - c.dy) / r),
          radius: 1.15,
          colors: const [Color(0xFFB892FF), OrbitColors.primary, Color(0xFF1B0F55)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    ring(true);

    // Sparkle.
    final s = r * 0.42 * (0.9 + 0.1 * math.sin(t * 2 * math.pi * 2));
    final star = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s);
    canvas.drawPath(star, Paint()..color = Colors.white.withValues(alpha: 0.95));

    // Listening waveform bars under the orb.
    if (mode != OrbMode.idle) {
      final base = c.dy + r * 1.9;
      for (var i = -12; i <= 12; i++) {
        final h = (6 + 16 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * speed + i * 0.7))) *
            (1 - i.abs() / 14);
        final x = c.dx + i * size.width * 0.028;
        canvas.drawLine(
          Offset(x, base - h),
          Offset(x, base + h),
          Paint()
            ..color = (i.isEven ? OrbitColors.secondary : OrbitColors.primary)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t || old.mode != mode;
}

class OrbitBottomNav extends StatelessWidget {
  const OrbitBottomNav({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, String)>[
    (Icons.home_rounded, 'Home'),
    (Icons.search_rounded, 'Explore'),
    (Icons.chat_bubble_rounded, 'Assistant'),
    (Icons.bolt_rounded, 'Automations'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: OrbitColors.surface,
        border: Border(top: BorderSide(color: OrbitColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_items[i].$1,
                            size: 24,
                            color: i == index ? OrbitColors.secondary : OrbitColors.textDim),
                        const SizedBox(height: 2),
                        Text(_items[i].$2,
                            style: TextStyle(
                                fontSize: 10.5,
                                color: i == index ? OrbitColors.secondary : OrbitColors.textDim,
                                fontWeight: i == index ? FontWeight.w600 : FontWeight.w400)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient filled button used for primary actions ("Create workflow").
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Ink(
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [OrbitColors.primary, Color(0xFF4F46FF)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: OrbitColors.primary.withValues(alpha: 0.4), blurRadius: 16)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 20, color: Colors.white), const SizedBox(width: 8)],
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
