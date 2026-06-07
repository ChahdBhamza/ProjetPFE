import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dart:math' as math;
import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/design_system/cybersight_theme.dart';

const Color _splashBlue = Color(0xFF5B7CFF);
const Color _splashPurple = Color(0xFF9D4DFF);
const Color _splashCyan = Color(0xFF60E4FF);
const Color _splashViolet = Color(0xFFBB64FF);

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _auroraController;
  
  @override
  void initState() {
    super.initState();
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

                    // 1) HERO CORE — stacked lockup logo
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
                                // Outer purple glow behind logo
                                Container(
                                  width: 320,
                                  height: 320,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        _splashPurple.withOpacity(0.30),
                                        _splashViolet.withOpacity(0.15),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.45, 1.0],
                                    ),
                                  ),
                                ),
                                // Secondary cyan shimmer
                                Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        _splashCyan.withOpacity(0.08),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                // The actual transparent logo
                                Image.asset(
                                  'assets/logo.png',
                                  width: 280,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

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
                      '© 2026 • SfmDetect',
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
          Color(0xFF0A0B36).withOpacity(0.96),
          Color(0xFF2A1D8E).withOpacity(0.94),
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
              _splashCyan.withOpacity(0.46),
              _splashViolet.withOpacity(0.60),
              mix,
            ) ??
            _splashViolet.withOpacity(0.60);

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
                        color: _splashCyan,
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
                  color: _splashCyan,
                  boxShadow: [
                    BoxShadow(
                      color: _splashCyan,
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
