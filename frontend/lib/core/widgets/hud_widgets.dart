import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/cybersight_theme.dart';

class CybersightAtmosphere extends StatefulWidget {
  final Widget child;
  const CybersightAtmosphere({super.key, required this.child});

  @override
  State<CybersightAtmosphere> createState() => _CybersightAtmosphereState();
}

class _CybersightAtmosphereState extends State<CybersightAtmosphere> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CybersightTheme.obsidian,
      body: Stack(
        children: [
          // 1. Animated Grid
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _CybersightGridPainter(offset: _controller.value),
              );
            },
          ),
          
          // 2. HUD Vignette & Ambient Glow
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      CybersightTheme.obsidian.withOpacity(0.4),
                      CybersightTheme.obsidian,
                    ],
                    stops: const [0.4, 0.8, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Content
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _CybersightGridPainter extends CustomPainter {
  final double offset;
  _CybersightGridPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.50, size.height * 0.50);
    final maxRadius = size.longestSide * 0.82;

    // Animated phase for slight breathing movement
    final phase = offset * 2 * 3.141592653589793;

    // Concentric circles: small at center, growing outward
    for (double r = 24; r <= maxRadius; r += 32) {
      final normalized = (r / maxRadius).clamp(0.0, 1.0);
      final wobble = 2.0 * (0.5 - normalized) * (0.5 + 0.5 * offset);
      final animatedRadius = r + wobble;

      final color = Color.lerp(
            CybersightTheme.accent.withOpacity(0.11),
            CybersightTheme.accent2.withOpacity(0.03),
            normalized,
          ) ??
          CybersightTheme.accent.withOpacity(0.08);

      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = normalized < 0.2 ? 1.2 : 0.85
        ..color = color;

      canvas.drawCircle(center, animatedRadius, p);
    }

    // Core glow ring in the middle
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = CybersightTheme.accent.withOpacity(0.12 + (0.04 * (0.5 + 0.5 * offset)));
    canvas.drawCircle(center, 18 + 2 * (0.5 + 0.5 * offset), corePaint);

    // Subtle rotating arc to keep scene dynamic
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = CybersightTheme.accent2.withOpacity(0.14);
    final rect = Rect.fromCircle(center: center, radius: maxRadius * 0.42);
    canvas.drawArc(rect, phase, 0.95, false, arcPaint);
  }
  @override
  bool shouldRepaint(covariant _CybersightGridPainter oldDelegate) => oldDelegate.offset != offset;
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final double? width;
  final double? height;
  final Border? border;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.05,
    this.borderRadius = 16.0,
    this.width,
    this.height,
    this.border,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlowingButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isFullWidth;
  final double textSize;
  final double darkOverlayOpacity;
  
  const GlowingButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isFullWidth = true,
    this.textSize = 14,
    this.darkOverlayOpacity = 0.0,
  });

  @override
  State<GlowingButton> createState() => _GlowingButtonState();
}

class _GlowingButtonState extends State<GlowingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _glowAnimation = Tween<double>(begin: 0.4, end: 0.7).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 58,
              width: widget.isFullWidth ? double.infinity : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: CybersightTheme.accent.withOpacity(_glowAnimation.value),
                    blurRadius: 18,
                    spreadRadius: -4,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [CybersightTheme.accent, CybersightTheme.accent2],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                    if (widget.darkOverlayOpacity > 0)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(widget.darkOverlayOpacity * 0.9),
                                Colors.transparent,
                                Colors.black.withOpacity(widget.darkOverlayOpacity),
                              ],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.22)),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              widget.label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: widget.textSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                                letterSpacing: 0.5,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CybersightCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const CybersightCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding ?? const EdgeInsets.all(20),
      borderRadius: 24,
      opacity: 0.05,
      blur: 15,
      border: Border.all(color: Colors.white.withOpacity(0.05)),
      child: child,
    );
  }
}
