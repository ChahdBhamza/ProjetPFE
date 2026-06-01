import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:equipment_detection_app/core/design_system/cybersight_theme.dart';
import 'package:equipment_detection_app/core/widgets/hud_widgets.dart';
import 'package:equipment_detection_app/features/auth/presentation/providers/auth_provider.dart';
import 'script_lab_page.dart';

class EquipmentPage extends StatelessWidget {
  const EquipmentPage({super.key});

  void _launchScanLab(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const ScanLabPage(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubicEmphasized,
          );
          return FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final operatorName =
        context.watch<AuthProvider>().fullName ?? 'Operator';
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final siteName = args?['site'] as String?;
    final floorName = args?['floor'] as String?;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detect',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (siteName != null && floorName != null)
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: Colors.white30, size: 11),
                            const SizedBox(width: 4),
                            Text(
                              '$siteName · $floorName'.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white30,
                                letterSpacing: 1.4,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Welcome, $operatorName',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            letterSpacing: 0.2,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: CybersightTheme.ok.withOpacity(0.05),
                    border: Border.all(
                        color: CybersightTheme.ok.withOpacity(0.22)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CybersightTheme.ok,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'READY',
                        style: GoogleFonts.plusJakartaSans(
                          color: CybersightTheme.ok.withOpacity(0.85),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // ── Launch card ──────────────────────────────────────────────
            _LaunchCard(onTap: () => _launchScanLab(context)),

            const SizedBox(height: 32),

            // ── How it works ─────────────────────────────────────────────
            Text(
              'HOW IT WORKS',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white24,
                letterSpacing: 1.8,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            GlassContainer(
              opacity: 0.04,
              blur: 16,
              borderRadius: 20,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Column(
                children: [
                  _StepRow(
                    number: '01',
                    icon: Icons.video_library_rounded,
                    title: 'Upload a Video',
                    subtitle:
                        'Pick any saved video from your gallery.',
                  ),
                  _Divider(),
                  _StepRow(
                    number: '02',
                    icon: Icons.grid_view_rounded,
                    title: 'Review Key Frames',
                    subtitle:
                        'Browse AI-extracted frames and confirm hero shots.',
                  ),
                  _Divider(),
                  _StepRow(
                    number: '03',
                    icon: Icons.verified_rounded,
                    title: 'Identify Equipment',
                    subtitle:
                        'Brand, model, and full specs detected automatically.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Launch card ────────────────────────────────────────────────────────────

class _LaunchCard extends StatefulWidget {
  final VoidCallback onTap;
  const _LaunchCard({required this.onTap});

  @override
  State<_LaunchCard> createState() => _LaunchCardState();
}

class _LaunchCardState extends State<_LaunchCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 0.975)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 0.08, end: 0.22)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _ctrl.forward().then((_) => _ctrl.reverse());
        widget.onTap();
      },
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: CybersightTheme.accent.withOpacity(_glow.value),
                  blurRadius: 36,
                  spreadRadius: -4,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: [
                    CybersightTheme.accent.withValues(alpha: 0.35),
                    CybersightTheme.accent2.withValues(alpha: 0.18),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: GlassContainer(
                borderRadius: 27,
                opacity: 0.06,
                blur: 20,
                border: Border.all(color: Colors.transparent),
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon badge
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: CybersightTheme.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: CybersightTheme.accent.withValues(alpha: 0.20),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.video_library_rounded,
                        color: CybersightTheme.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Title
                    Text(
                      'Scan Lab',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload a video, review extracted key frames,\nand let the AI identify your equipment.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 26),

                    // CTA pill
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: CybersightTheme.accent.withValues(alpha: 0.12),
                            border: Border.all(
                              color: CybersightTheme.accent.withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Launch Scan Lab',
                                style: GoogleFonts.plusJakartaSans(
                                  color: CybersightTheme.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: CybersightTheme.accent, size: 16),
                            ],
                          ),
                        ),
                      ],
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

// ── Step row ───────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String subtitle;

  const _StepRow({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CybersightTheme.accent.withOpacity(0.07),
            border: Border.all(
                color: CybersightTheme.accent.withOpacity(0.18)),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.plusJakartaSans(
                color: CybersightTheme.accent,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
        height: 1,
        color: Colors.white.withOpacity(0.05),
      ),
    );
  }
}
