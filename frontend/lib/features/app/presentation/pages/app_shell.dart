import 'package:flutter/material.dart';
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
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CybersightAtmosphere(
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
    );
  }
}

class _DashboardWavePainter extends CustomPainter {
  final double t;
  _DashboardWavePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * (0.08 + 0.02 * math.sin(t * math.pi * 2)), size.height * 0.60);
    final maxR = size.longestSide * 0.88;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double r = 120; r < maxR; r += 42) {
      final mix = (r / maxR).clamp(0.0, 1.0);
      p.color = Color.lerp(
            CybersightTheme.accent.withOpacity(0.10),
            CybersightTheme.accent2.withOpacity(0.04),
            mix,
          ) ??
          CybersightTheme.accent.withOpacity(0.08);
      final start = -1.05 + 0.09 * math.sin((t * math.pi * 2) + mix * 5);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, 2.3, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardWavePainter oldDelegate) => oldDelegate.t != t;
}

