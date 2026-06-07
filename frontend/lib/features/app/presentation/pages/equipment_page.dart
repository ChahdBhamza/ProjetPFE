import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:equipment_detection_app/core/design_system/cybersight_theme.dart';
import 'package:equipment_detection_app/core/network/api_service.dart';
import 'package:equipment_detection_app/core/widgets/hud_widgets.dart';
import 'package:equipment_detection_app/features/auth/presentation/providers/auth_provider.dart';
import 'script_lab_page.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _recentSessions = [];
  bool _loadingSessions = true;

  @override
  void initState() {
    super.initState();
    _fetchRecentSessions();
  }

  Future<void> _fetchRecentSessions() async {
    final sessions = await _apiService.fetchScanHistory();
    if (mounted) {
      setState(() {
        _recentSessions = sessions.take(3).toList();
        _loadingSessions = false;
      });
    }
  }

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
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Must call build from AutomaticKeepAliveClientMixin
    final operatorName =
        context.watch<AuthProvider>().fullName ?? 'Operator';

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
                letterSpacing: 1.5,
                fontSize: 10,
                fontWeight: FontWeight.w600,
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
                    title: 'Detect Key Frames',
                    subtitle:
                        'Browse the extracted  Hero Frames.',
                  ),
                  _Divider(),
                  _StepRow(
                    number: '03',
                    icon: Icons.verified_rounded,
                    title: 'Identify Equipment',
                    subtitle:
                        'Brand, model, and full specs detected Ready to export.',
                  ),
                ],
              ),
            ),

            // ── Recent activity ───────────────────────────────────────
            if (!_loadingSessions && _recentSessions.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'RECENT ACTIVITY',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white24,
                  letterSpacing: 1.5,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              GlassContainer(
                opacity: 0.04,
                blur: 16,
                borderRadius: 20,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  children: [
                    for (int i = 0; i < _recentSessions.length; i++) ...[
                      if (i > 0) _Divider(),
                      _SessionRow(session: _recentSessions[i]),
                    ],
                  ],
                ),
              ),
            ],
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

// ── Session row (recent activity) ─────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final dynamic session;
  const _SessionRow({required this.session});

  String _formatTime(String? raw) {
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (session['status'] ?? 'completed').toString().toLowerCase();
    final isCompleted = status == 'completed';
    final color = isCompleted ? CybersightTheme.ok : CybersightTheme.accent;
    final timeStr = _formatTime(session['start_time'] as String?);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.07),
            border: Border.all(color: color.withOpacity(0.20)),
          ),
          child: Icon(
            isCompleted ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan Session',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeStr,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: color.withOpacity(0.07),
            border: Border.all(color: color.withOpacity(0.20)),
          ),
          child: Text(
            status.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
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
