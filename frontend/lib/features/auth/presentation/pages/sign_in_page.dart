import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> with SingleTickerProviderStateMixin {
  late AnimationController _bgController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6B), size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ]),
        backgroundColor: const Color(0xFF151B2A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0x33FF6B6B)),
        ),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ));
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(email, password);

    if (!mounted) return;
    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, '/auth-success', (_) => false);
    } else {
      _showError(authProvider.errorMessage ?? 'Sign in failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return CybersightAtmosphere(
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, child) => CustomPaint(
                  painter: _SignInWavePainter(t: _bgController.value),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: AnimatedBuilder(
                            animation: _bgController,
                            builder: (context, child) {
                              final lift = math.sin(_bgController.value * math.pi * 2) * 4;
                              return Transform.translate(
                                offset: Offset(0, lift),
                                child: GlassContainer(
                                  width: 64,
                                  height: 64,
                                  borderRadius: 18,
                                  opacity: 0.05,
                                  child: const Center(
                                    child: Icon(Icons.wifi_tethering_rounded, color: CybersightTheme.accent, size: 28),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28, letterSpacing: 0.1, height: 1.05),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in with your email or continue with Google.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white54, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        GlassContainer(
                          opacity: 0.05,
                          blur: 16,
                          borderRadius: 24,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CybersightInput(
                                controller: _emailController,
                                label: 'Email',
                                hint: 'you@example.com',
                                icon: Icons.alternate_email_rounded,
                              ),
                              const SizedBox(height: 10),
                              CybersightInput(
                                controller: _passwordController,
                                label: 'Password',
                                hint: '••••••••••',
                                icon: Icons.lock_outline_rounded,
                                isPass: true,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot password?',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white.withOpacity(0.45), letterSpacing: 0.2),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),
                              GlowingButton(
                                label: authProvider.isLoading ? 'VERIFYING...' : 'Sign in',
                                textSize: 12,
                                darkOverlayOpacity: 0.22,
                                onTap: authProvider.isLoading ? () {} : () => _handleSignIn(),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'or',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white.withOpacity(0.35), letterSpacing: 0.2),
                              ),
                              const SizedBox(height: 8),
                              _GoogleButton(
                                onTap: authProvider.isLoading 
                                  ? () {} 
                                  : () async {
                                      final success = await authProvider.signInWithGoogle();
                                      if (success && mounted) {
                                        Navigator.pushNamedAndRemoveUntil(context, '/auth-success', (_) => false);
                                      }
                                    },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const ProgressSegments(activeIndex: 1),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/signup'),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              text: 'New here? ',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white38, letterSpacing: 0.2),
                              children: const [
                                TextSpan(
                                  text: 'Register now',
                                  style: TextStyle(color: CybersightTheme.accent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInWavePainter extends CustomPainter {
  final double t;
  _SignInWavePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          CybersightTheme.obsidian,
          CybersightTheme.navy2.withOpacity(0.98),
          CybersightTheme.navy1.withOpacity(0.98),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final driftX = 0.08 + 0.02 * math.sin(t * math.pi * 2);
    final driftY = 0.56 + 0.015 * math.cos(t * math.pi * 2);
    final center = Offset(size.width * driftX, size.height * driftY);
    final maxR = size.longestSide * 0.80;
    for (double r = 120; r < maxR; r += 36) {
      final t = (r / maxR).clamp(0.0, 1.0);
      paint.color = Color.lerp(
            CybersightTheme.accent.withOpacity(0.10),
            CybersightTheme.accent2.withOpacity(0.045),
            t,
          ) ??
          CybersightTheme.accent.withOpacity(0.08);
      final start = -1.10 + 0.08 * math.sin((this.t * math.pi * 2) + t * 5);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, 2.35, false, paint);

      // Splash-like moving dotted highlights along each arc
      final dotPaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.9;
      final head = start + (this.t * math.pi * 2 * 0.58);
      const trail = math.pi * 1.0;
      for (double d = 0; d < trail; d += 0.16) {
        final a = head - d;
        final inArc = a >= start && a <= start + 2.35;
        if (!inArc) continue;
        final x = center.dx + r * math.cos(a);
        final y = center.dy + r * math.sin(a);
        final tangent = a + math.pi / 2;
        final len = 3.8;
        final dx = math.cos(tangent) * len * 0.45;
        final dy = math.sin(tangent) * len * 0.45;
        final mix = (d / trail).clamp(0.0, 1.0);
        dotPaint.color = Color.lerp(
              CybersightTheme.accent.withOpacity(0.42),
              CybersightTheme.accent2.withOpacity(0.42),
              mix,
            ) ??
            CybersightTheme.accent.withOpacity(0.42);
        canvas.drawLine(Offset(x - dx, y - dy), Offset(x + dx, y + dy), dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignInWavePainter oldDelegate) => oldDelegate.t != t;
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.92),
              ),
              child: Text(
                'G',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.black87,
                      fontSize: 12,
                      letterSpacing: 0,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withOpacity(0.80),
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
