import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'dart:math' as math;

import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import 'equipment_page.dart';
import 'inventory_page.dart';
import 'profile_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  late AnimationController _bgController;
  Timer? _inactivityTimer;

  // Set to 15 minutes for standard operation
  static const int _inactivityTimeoutMinutes = 15;

  static const _pages = <Widget>[
    EquipmentPage(),
    InventoryPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: _inactivityTimeoutMinutes), _handleInactivity);
  }

  void _handleInactivity() {
    _inactivityTimer?.cancel();
    
    // 1. Log the user out
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();
    
    // 2. Show a small notification box (SnackBar) that persists across screens
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Neural link severed due to inactivity.',
          style: TextStyle(color: CybersightTheme.accent, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          textAlign: TextAlign.center,
        ),
        backgroundColor: CybersightTheme.navy2.withOpacity(0.9),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: CybersightTheme.accent.withOpacity(0.3)),
        ),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        duration: const Duration(seconds: 4),
      ),
    );

    // 3. Redirect instantly to Sign In page
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      child: CybersightAtmosphere(
        child: SafeArea(
          child: Scaffold(
            backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _bgController,
                  builder: (context, child) => CustomPaint(
                    painter: _DashboardWavePainter(t: _bgController.value),
                  ),
                ),
              ),
              Positioned.fill(
                child: IndexedStack(index: _index, children: _pages),
              ),
            ],
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GlassContainer(
              opacity: 0.07,
              blur: 18,
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: BottomNavigationBar(
                currentIndex: _index,
                onTap: (v) => setState(() => _index = v),
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                backgroundColor: Colors.transparent,
                selectedItemColor: CybersightTheme.accent,
                unselectedItemColor: Colors.white54,
                showUnselectedLabels: true,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.upload_rounded),
                    label: 'Detect',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.inventory_2_outlined),
                    label: 'Inventory',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardWavePainter extends CustomPainter {
  final double t;
  _DashboardWavePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    // The CybersightAtmosphere already provides the base gradient, but we'll add the 
    // animated wave lines and moving dots exactly like the sign-in page to ensure parity.
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final driftX = 0.08 + 0.02 * math.sin(t * math.pi * 2);
    final driftY = 0.56 + 0.015 * math.cos(t * math.pi * 2);
    final center = Offset(size.width * driftX, size.height * driftY);
    final maxR = size.longestSide * 0.80;
    
    for (double r = 120; r < maxR; r += 36) {
      final mix = (r / maxR).clamp(0.0, 1.0);
      paint.color = Color.lerp(
            CybersightTheme.accent.withOpacity(0.10),
            CybersightTheme.accent2.withOpacity(0.045),
            mix,
          ) ??
          CybersightTheme.accent.withOpacity(0.08);
      final start = -1.10 + 0.08 * math.sin((this.t * math.pi * 2) + mix * 5);
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
        final dotMix = (d / trail).clamp(0.0, 1.0);
        dotPaint.color = Color.lerp(
              CybersightTheme.accent.withOpacity(0.42),
              CybersightTheme.accent2.withOpacity(0.42),
              dotMix,
            ) ??
            CybersightTheme.accent.withOpacity(0.42);
        canvas.drawLine(Offset(x - dx, y - dy), Offset(x + dx, y + dy), dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardWavePainter oldDelegate) => oldDelegate.t != t;
}

