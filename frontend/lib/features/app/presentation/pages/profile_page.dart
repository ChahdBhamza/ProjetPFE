import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/network/api_service.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onGoToInventory;
  const ProfilePage({super.key, this.onGoToInventory});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _stats;
  List<dynamic> _recentScans = [];
  bool _loadingStats = true;
  bool _loadingScans = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Auto-refresh every 30s — only rebuilds if values changed
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshStats());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadStats(), _loadScans()]);
  }

  Future<void> _loadStats() async {
    final data = await _api.fetchMyStats();
    if (mounted) setState(() { _stats = data; _loadingStats = false; });
  }

  Future<void> _loadScans() async {
    final data = await _api.fetchScanHistory();
    if (mounted) setState(() { _recentScans = data.take(5).toList(); _loadingScans = false; });
  }

  Future<void> _refreshStats() async {
    final fresh = await _api.fetchMyStats();
    if (!mounted) return;
    final changed = fresh['scans'] != _stats?['scans'] ||
        fresh['detected'] != _stats?['detected'] ||
        fresh['saved'] != _stats?['saved'];
    if (changed) setState(() => _stats = fresh);
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return '—'; }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final name = auth.fullName ?? 'Cyber Operator';
    final email = auth.userEmail ?? 'Access Denied';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadAll,
        color: CybersightTheme.accent,
        backgroundColor: CybersightTheme.navy2,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900, fontSize: 42, height: 1.0)),
                      const SizedBox(height: 4),
                      Text('OPERATOR · ACCESS · PREFERENCES',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white24, letterSpacing: 3, fontSize: 9)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Identity card ────────────────────────────────────────
              GlassContainer(
                opacity: 0.06,
                blur: 18,
                borderRadius: 26,
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  Row(children: [
                    // Initials avatar
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: [CybersightTheme.accent, CybersightTheme.accent2]),
                        boxShadow: [BoxShadow(
                            color: CybersightTheme.accent.withOpacity(0.35),
                            blurRadius: 22,
                            spreadRadius: -12)],
                      ),
                      child: Center(
                        child: Text(
                          _initials(name),
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    _Badge(
                      label: auth.isAdmin ? 'ADMIN' : 'OPERATOR',
                      color: auth.isAdmin ? CybersightTheme.accent2 : CybersightTheme.ok,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Container(height: 1, color: Colors.white.withOpacity(0.05)),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(children: [
                    Expanded(child: _Stat(label: 'Scans',
                        value: _loadingStats ? '–' : '${_stats?['scans'] ?? 0}',
                        loading: _loadingStats)),
                    const SizedBox(width: 12),
                    Expanded(child: _Stat(label: 'Detected',
                        value: _loadingStats ? '–' : '${_stats?['detected'] ?? 0}',
                        loading: _loadingStats)),
                    const SizedBox(width: 12),
                    Expanded(child: _Stat(label: 'Saved',
                        value: _loadingStats ? '–' : '${_stats?['saved'] ?? 0}',
                        loading: _loadingStats)),
                  ]),
                ]),
              ),

              const SizedBox(height: 24),

              // ── Recent scans ─────────────────────────────────────────
              _SectionTitle('Recent scans'),
              const SizedBox(height: 10),
              if (_loadingScans)
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.02),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: const Center(child: CircularProgressIndicator(
                      color: CybersightTheme.accent, strokeWidth: 2)),
                )
              else if (_recentScans.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.02),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Center(child: Text('No scans yet',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white24, fontSize: 12))),
                )
              else
                GlassContainer(
                  opacity: 0.04,
                  blur: 14,
                  borderRadius: 20,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: _recentScans.asMap().entries.map((e) {
                      final scan = e.value as Map<String, dynamic>;
                      final status = scan['status'] as String? ?? 'unknown';
                      final isOk = status == 'completed';
                      final color = isOk ? CybersightTheme.ok : CybersightTheme.warning;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withOpacity(0.02),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              scan['session_id'] as String? ?? '—',
                              style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white60, fontSize: 11,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(scan['start_time'] as String?),
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white30, fontSize: 10),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: color.withOpacity(0.10),
                              border: Border.all(color: color.withOpacity(0.30)),
                            ),
                            child: Text(status.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                    color: color, fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8)),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 24),

              // ── Quick actions ────────────────────────────────────────
              _SectionTitle('Quick actions'),
              const SizedBox(height: 10),
              _RowAction(
                icon: Icons.inventory_2_outlined,
                title: 'My Inventory',
                subtitle: 'Browse saved equipment',
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                onTap: () => widget.onGoToInventory?.call(),
              ),
              const SizedBox(height: 10),
              _RowAction(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                subtitle: 'Return to login',
                trailing: const Icon(Icons.arrow_forward_rounded, color: Colors.white24),
                onTap: () {
                  auth.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/signin', (_) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
            color: Colors.white24, letterSpacing: 3, fontSize: 9,
            fontWeight: FontWeight.w600),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label,
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white60, fontSize: 10, letterSpacing: 1.8)),
      );
}

class _Stat extends StatefulWidget {
  final String label;
  final String value;
  final bool loading;
  const _Stat({required this.label, required this.value, this.loading = false});
  @override
  State<_Stat> createState() => _StatState();
}

class _StatState extends State<_Stat> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.identity()..scale(_pressed ? 0.95 : 1.0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _pressed
              ? CybersightTheme.accent.withOpacity(0.05)
              : Colors.white.withOpacity(0.02),
          border: Border.all(
              color: _pressed
                  ? CybersightTheme.accent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                  color: _pressed ? CybersightTheme.accent : Colors.white24,
                  fontSize: 9, letterSpacing: 2.2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          widget.loading
              ? Container(
                  height: 22, width: 36,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white.withOpacity(0.06)))
              : Text(widget.value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _RowAction extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  const _RowAction({
    required this.icon, required this.title, required this.subtitle,
    required this.trailing, required this.onTap,
  });
  @override
  State<_RowAction> createState() => _RowActionState();
}

class _RowActionState extends State<_RowAction> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.identity()..scale(_pressed ? 0.98 : 1.0),
        child: GlassContainer(
          opacity: _pressed ? 0.08 : 0.05,
          blur: 18,
          borderRadius: 20,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: [
                  CybersightTheme.accent.withOpacity(0.18),
                  CybersightTheme.accent2.withOpacity(0.10),
                ]),
                border: Border.all(
                    color: Colors.white.withOpacity(_pressed ? 0.15 : 0.08)),
              ),
              child: Icon(widget.icon,
                  color: _pressed ? CybersightTheme.accent : Colors.white70,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(widget.subtitle,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white38, fontSize: 11)),
              ]),
            ),
            widget.trailing,
          ]),
        ),
      ),
    );
  }
}
