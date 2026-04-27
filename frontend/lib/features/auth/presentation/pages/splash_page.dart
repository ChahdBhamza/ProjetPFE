import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dart:math' as math;
import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/design_system/cybersight_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _scanningController;
  late AnimationController _auroraController;
  
  @override
  void initState() {
    super.initState();
    _scanningController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _auroraController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    
    // Auto-navigate after splash delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isAuthenticated) {
          print("[Splash] Session detected. Bypassing login...");
          Navigator.pushReplacementNamed(context, '/app');
        } else {
          print("[Splash] No session. Waiting for user input.");
        }
      }
    });
  }

  @override
  void dispose() {
    _scanningController.dispose();
    _auroraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CybersightAtmosphere(
      child: SafeArea(
        child: Stack(
          children: [
            // Dynamic aurora layer
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _auroraController,
                builder: (context, child) => CustomPaint(
                  painter: _AuroraPainter(t: _auroraController.value),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _auroraController,
                builder: (context, child) => CustomPaint(
                  painter: _DotWavePainter(t: _auroraController.value),
                ),
              ),
            ),

            // Foreground content
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // 1) HERO CORE
                    Center(
                      child: AnimatedBuilder(
                        animation: _auroraController,
                        builder: (context, child) {
                          final floatY = math.sin(_auroraController.value * math.pi * 2) * 6;
                          return Transform.translate(
                            offset: Offset(0, floatY),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                // Soft glow halo
                                Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        CybersightTheme.accent.withOpacity(0.18),
                                        CybersightTheme.accent2.withOpacity(0.10),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.45, 1.0],
                                    ),
                                  ),
                                ),

                                // Glass Backdrop
                                GlassContainer(
                                  width: 170,
                                  height: 170,
                                  opacity: 0.03,
                                  blur: 18,
                                  borderRadius: 36,
                                  child: const SizedBox.shrink(),
                                ),

                                // Viewfinder HUD
                                SizedBox(
                                  width: 108,
                                  height: 108,
                                  child: Stack(
                                    children: [
                                      _HUDCorner(Alignment.topLeft, CybersightTheme.accent),
                                      _HUDCorner(Alignment.topRight, CybersightTheme.accent),
                                      _HUDCorner(Alignment.bottomLeft, CybersightTheme.accent),
                                      _HUDCorner(Alignment.bottomRight, CybersightTheme.accent),

                                      // Scanning Line
                                      AnimatedBuilder(
                                        animation: _scanningController,
                                        builder: (context, child) {
                                          return Positioned(
                                            top: _scanningController.value * 108,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 2,
                                              decoration: BoxDecoration(
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: CybersightTheme.accent.withOpacity(0.35),
                                                    blurRadius: 12,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                                gradient: LinearGradient(
                                                  colors: [
                                                    CybersightTheme.accent.withOpacity(0),
                                                    CybersightTheme.accent,
                                                    CybersightTheme.accent2.withOpacity(0.6),
                                                    CybersightTheme.accent.withOpacity(0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      Center(
                                        child: Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(colors: [CybersightTheme.accent, CybersightTheme.accent2]),
                                            boxShadow: [
                                              BoxShadow(color: CybersightTheme.accent.withOpacity(0.35), blurRadius: 18),
                                              BoxShadow(color: CybersightTheme.accent2.withOpacity(0.18), blurRadius: 24),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Accent badge
                                Positioned(
                                  top: -12,
                                  right: -12,
                                  child: GlassContainer(
                                    width: 42,
                                    height: 42,
                                    opacity: 0.05,
                                    blur: 16,
                                    borderRadius: 999,
                                    child: const Icon(Icons.bolt_rounded, color: CybersightTheme.accent, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 26),

                    // 2) BRANDING
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [CybersightTheme.accent, Colors.white, CybersightTheme.accent2],
                        stops: [0.0, 0.45, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        'CYBERSIGHT',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(letterSpacing: 3.0),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'EQUIPMENT DETECTION • INVENTORY • INSIGHTS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white24,
                        letterSpacing: 4.2,
                      ),
                    ),

                    const SizedBox(height: 34),

                    // 3) STATUS + CTA
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: GlassContainer(
                        opacity: 0.05,
                        blur: 18,
                        borderRadius: 24,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _PulseDot(),
                                const SizedBox(width: 10),
                                Text(
                                  'SYSTEM ONLINE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white30,
                                    letterSpacing: 3.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Upload photos to detect equipment\nand keep inventory synced.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60, height: 1.35),
                            ),
                            const SizedBox(height: 16),
                            GlowingButton(
                              label: 'Enter',
                              onTap: () => Navigator.pushReplacementNamed(context, '/signin'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text(
                      '© 2026 • CYBERSIGHT',
                      style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white12, letterSpacing: 2.0),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  _AuroraPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        colors: [
          CybersightTheme.obsidian,
          CybersightTheme.navy2.withOpacity(0.98),
          CybersightTheme.navy1.withOpacity(0.98),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => oldDelegate.t != t;
}

class _DotWavePainter extends CustomPainter {
  final double t;
  _DotWavePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;

    // Circular dotted waves that start at top and travel around.
    final center = Offset(size.width * 0.03, size.height * 0.55);
    final maxR = size.longestSide * 0.95;
    final baseTopAngle = -math.pi / 2; // top origin

    for (double radius = 140; radius < maxR; radius += 42) {
      final ringShift = (radius / 42) * 0.22;
      final head = baseTopAngle + (t * math.pi * 2 * 0.65) + ringShift;
      const trailSweep = math.pi * 1.65; // moving train length
      const spacing = 0.125;

      // Draw moving dotted trail around each ring.
      for (double d = 0; d < trailSweep; d += spacing) {
        final angle = head - d;
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);

        final tangent = angle + math.pi / 2;
        final dashLen = 4.0 + (radius / maxR) * 2.2;
        final dx = math.cos(tangent) * dashLen * 0.45;
        final dy = math.sin(tangent) * dashLen * 0.45;

        final mix = (d / trailSweep).clamp(0.0, 1.0);
        final color = Color.lerp(
              CybersightTheme.accent.withOpacity(0.46),
              CybersightTheme.accent2.withOpacity(0.60),
              mix,
            ) ??
            CybersightTheme.accent2.withOpacity(0.60);

        paint
          ..color = color.withOpacity(0.46 * (1 - mix * 0.72))
          ..strokeWidth = 2.0;
        canvas.drawLine(Offset(x - dx, y - dy), Offset(x + dx, y + dy), paint);
      }

      // Very subtle guide ring (no fill circles).
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(0.012);
      canvas.drawCircle(center, radius, paint);
      paint.style = PaintingStyle.fill;
    }
  }

  @override
  bool shouldRepaint(covariant _DotWavePainter oldDelegate) => oldDelegate.t != t;
}

class _HUDCorner extends StatelessWidget {
  final Alignment align; final Color color;
  const _HUDCorner(this.align, this.color);
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: align,
      child: Container(
        width: 18, height: 18,
        decoration: BoxDecoration(
          border: Border(
            top: align.y == -1 ? BorderSide(color: color, width: 2.5) : BorderSide.none,
            bottom: align.y == 1 ? BorderSide(color: color, width: 2.5) : BorderSide.none,
            left: align.x == -1 ? BorderSide(color: color, width: 2.5) : BorderSide.none,
            right: align.x == 1 ? BorderSide(color: color, width: 2.5) : BorderSide.none,
          ),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ring
              Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CybersightTheme.ok,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              // Solid core dot
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: CybersightTheme.ok,
                  boxShadow: [
                    BoxShadow(
                      color: CybersightTheme.ok,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// _GlowButton and _StatusIndicator removed in favor of GlowingButton from hud_widgets.dart
