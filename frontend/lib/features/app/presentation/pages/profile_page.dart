import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/network/api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final data = await _apiService.fetchMyStats();
    if (mounted) setState(() { _stats = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final String name = authProvider.fullName ?? "Cyber Operator";
    final String email = authProvider.userEmail ?? "Access Denied";

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profile',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 42,
                          height: 1.0,
                        ),
                  ),
                ),
                GlassContainer(
                  width: 44,
                  height: 44,
                  opacity: 0.05,
                  blur: 18,
                  borderRadius: 14,
                  child: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'OPERATOR • ACCESS • PREFERENCES',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white24, letterSpacing: 3, fontSize: 9),
            ),
            const SizedBox(height: 16),
            GlassContainer(
              opacity: 0.06,
              blur: 18,
              borderRadius: 26,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                              colors: [CybersightTheme.accent, CybersightTheme.accent2]),
                          boxShadow: [
                            BoxShadow(
                                color: CybersightTheme.accent.withOpacity(0.35),
                                blurRadius: 22,
                                spreadRadius: -12)
                          ],
                        ),
                        child: const Icon(Icons.person_rounded, color: Colors.black, size: 34),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      _Badge(
                        label: authProvider.isAdmin ? 'ADMIN' : 'OPERATOR',
                        color: authProvider.isAdmin
                            ? CybersightTheme.accent2
                            : CybersightTheme.ok,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: Colors.white.withOpacity(0.05)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'Scans',
                          value: _loading ? '–' : (_stats?['scans'] ?? 0).toString(),
                          loading: _loading,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat(
                          label: 'Detected',
                          value: _loading ? '–' : (_stats?['detected'] ?? 0).toString(),
                          loading: _loading,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat(
                          label: 'Saved',
                          value: _loading ? '–' : (_stats?['saved'] ?? 0).toString(),
                          loading: _loading,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle('Quick actions'),
            const SizedBox(height: 10),
            _RowAction(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              subtitle: 'Data & permissions',
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _RowAction(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              subtitle: 'Return to login',
              trailing: const Icon(Icons.arrow_forward_rounded, color: Colors.white24),
              onTap: () {
                authProvider.logout();
                Navigator.pushNamedAndRemoveUntil(context, '/signin', (_) => false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: Colors.white24, letterSpacing: 3, fontSize: 9),
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
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  State<_RowAction> createState() => _RowActionState();
}

class _RowActionState extends State<_RowAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 0.98 : 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: CybersightTheme.accent.withOpacity(0.15),
                      blurRadius: 15,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: GlassContainer(
            opacity: _isHovered ? 0.08 : 0.05,
            blur: 18,
            borderRadius: 20,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        CybersightTheme.accent.withOpacity(0.18),
                        CybersightTheme.accent2.withOpacity(0.10),
                      ],
                    ),
                    border: Border.all(
                        color: Colors.white.withOpacity(_isHovered ? 0.15 : 0.08)),
                  ),
                  child: Icon(widget.icon,
                      color: _isHovered ? CybersightTheme.accent : Colors.white70,
                      size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                widget.trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Colors.white60, fontSize: 10, letterSpacing: 1.8),
      ),
    );
  }
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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 0.95 : 1.0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: _isHovered
                ? CybersightTheme.accent.withOpacity(0.05)
                : Colors.white.withOpacity(0.02),
            border: Border.all(
                color: _isHovered
                    ? CybersightTheme.accent.withOpacity(0.2)
                    : Colors.white.withOpacity(0.06)),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: CybersightTheme.accent.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 0,
                    )
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _isHovered ? CybersightTheme.accent : Colors.white24,
                      fontSize: 9,
                      letterSpacing: 2.2)),
              const SizedBox(height: 8),
              widget.loading
                  ? Container(
                      height: 22,
                      width: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white.withOpacity(0.06),
                      ),
                    )
                  : Text(widget.value,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}
