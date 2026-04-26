import 'package:flutter/material.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

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
                    'Inventory',
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
                  child: const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'TRACKED EQUIPMENT • TAGS • STATUS',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white24, letterSpacing: 3, fontSize: 9),
            ),
            const SizedBox(height: 16),
            GlassContainer(
              opacity: 0.05,
              blur: 18,
              borderRadius: 24,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search equipment…',
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.025),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(colors: [CybersightTheme.accent, CybersightTheme.accent2]),
                      boxShadow: [BoxShadow(color: CybersightTheme.accent.withOpacity(0.35), blurRadius: 18, spreadRadius: -10)],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _InventoryCard(
              title: 'Safety Helmet',
              subtitle: 'PPE • ID: HEL-219',
              status: 'ACTIVE',
              statusColor: CybersightTheme.ok,
              meta: const [
                _Meta(label: 'Stock', value: '12'),
                _Meta(label: 'Last scan', value: '2 days'),
                _Meta(label: 'Confidence', value: '93%'),
              ],
            ),
            const SizedBox(height: 12),
            _InventoryCard(
              title: 'Reflective Vest',
              subtitle: 'PPE • ID: VST-884',
              status: 'LOW',
              statusColor: CybersightTheme.warning,
              meta: const [
                _Meta(label: 'Stock', value: '3'),
                _Meta(label: 'Last scan', value: 'Today'),
                _Meta(label: 'Confidence', value: '88%'),
              ],
            ),
            const SizedBox(height: 12),
            _InventoryCard(
              title: 'Protective Gloves',
              subtitle: 'PPE • ID: GLV-055',
              status: 'CHECK',
              statusColor: CybersightTheme.accent2,
              meta: const [
                _Meta(label: 'Stock', value: '8'),
                _Meta(label: 'Last scan', value: '5 hrs'),
                _Meta(label: 'Confidence', value: '74%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final List<_Meta> meta;
  const _InventoryCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.05,
      blur: 18,
      borderRadius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.25),
                      Colors.white.withOpacity(0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Icon(Icons.qr_code_2_rounded, color: statusColor.withOpacity(0.9), size: 18),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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
              _StatusBadge(label: status, color: statusColor),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 14),
          Row(
            children: meta
                .map(
                  (m) => Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.label.toUpperCase(),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white24, fontSize: 9, letterSpacing: 2.2),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.10)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'View',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white60, letterSpacing: 2),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(colors: [CybersightTheme.accent, CybersightTheme.accent2]),
                  ),
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'Update',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black, letterSpacing: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 10)]),
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white60, fontSize: 10, letterSpacing: 1.8)),
        ],
      ),
    );
  }
}

class _Meta {
  final String label;
  final String value;
  const _Meta({required this.label, required this.value});
}

