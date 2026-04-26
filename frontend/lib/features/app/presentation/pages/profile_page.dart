import 'package:flutter/material.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white24, letterSpacing: 3, fontSize: 9),
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
                          gradient: const LinearGradient(colors: [CybersightTheme.accent, CybersightTheme.accent2]),
                          boxShadow: [BoxShadow(color: CybersightTheme.accent.withOpacity(0.35), blurRadius: 22, spreadRadius: -12)],
                        ),
                        child: const Icon(Icons.person_rounded, color: Colors.black, size: 34),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Chahd Operator', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              'ID: OP-7742 • Role: Supervisor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      _Badge(label: 'SECURE', color: CybersightTheme.ok),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: Colors.white.withOpacity(0.05)),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Expanded(child: _Stat(label: 'Uploads', value: '28')),
                      SizedBox(width: 12),
                      Expanded(child: _Stat(label: 'Detected', value: '84')),
                      SizedBox(width: 12),
                      Expanded(child: _Stat(label: 'Saved', value: '41')),
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
              icon: Icons.cloud_outlined,
              title: 'Backend',
              subtitle: 'Python API connection',
              trailing: const _Badge(label: 'MOCK', color: CybersightTheme.warning),
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _RowAction(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              subtitle: 'Return to login',
              trailing: const Icon(Icons.arrow_forward_rounded, color: Colors.white24),
              onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/signin', (_) => false),
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
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white24, letterSpacing: 3, fontSize: 9),
    );
  }
}

class _RowAction extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        opacity: 0.05,
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
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Icon(icon, color: Colors.white70, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            trailing,
          ],
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
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white60, fontSize: 10, letterSpacing: 1.8),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white24, fontSize: 9, letterSpacing: 2.2)),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

