import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/hud_widgets.dart';

class AnalyticsPage extends StatelessWidget {
  final Map<String, dynamic> stats;
  const AnalyticsPage({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final assetsToday = stats['assets_today'] as int? ?? 0;
    final totalAssets = stats['total_assets'] as int? ?? 0;
    final totalScans = stats['total_scans'] as int? ?? 0;
    final avgConf = stats['avg_confidence'] ?? 0;
    final brands = Map<String, dynamic>.from(stats['brands'] ?? {});
    final categories = Map<String, dynamic>.from(stats['categories'] ?? {});

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Today hero
                    _TodayCard(count: assetsToday, total: totalAssets),
                    const SizedBox(height: 14),

                    // Summary row
                    Row(
                      children: [
                        _StatChip(label: 'All assets', value: totalAssets.toString()),
                        const SizedBox(width: 8),
                        _StatChip(label: 'Avg confidence', value: '$avgConf%'),
                        const SizedBox(width: 8),
                        _StatChip(label: 'Sessions', value: totalScans.toString()),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Top brands
                    const _SectionLabel(title: 'Top brands', subtitle: 'Most detected manufacturers'),
                    const SizedBox(height: 10),
                    _BrandsChart(brands: brands),
                    const SizedBox(height: 28),

                    // Category breakdown
                    const _SectionLabel(title: 'By category', subtitle: 'Equipment type distribution'),
                    const SizedBox(height: 10),
                    _CategoryChart(categories: categories),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white54, size: 14),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analytics',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Asset detection insights',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white30,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Today hero card ────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  final int count;
  final int total;
  const _TodayCard({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.05,
      blur: 16,
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detected today',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  count.toString(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'assets',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white24,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                ),
                child: Text(
                  'All time: $total',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
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

// ── Stat chip ──────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Brands chart ───────────────────────────────────────────────────────────

class _BrandsChart extends StatelessWidget {
  final Map<String, dynamic> brands;
  const _BrandsChart({required this.brands});

  static const _barColors = [
    Color(0xFF4A9FD4),
    Color(0xFF7E6FD8),
    Color(0xFF4ABCA8),
    Color(0xFFD4884A),
    Color(0xFF8ED484),
    Color(0xFFD4A84A),
  ];

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) {
      return const _EmptyCard(label: 'No brand data yet');
    }

    final maxCount = brands.values
        .whereType<int>()
        .fold<int>(1, (m, v) => v > m ? v : m);

    return GlassContainer(
      opacity: 0.04,
      blur: 16,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: brands.entries.toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final brand = entry.value.key;
          final count = entry.value.value as int? ?? 0;
          final ratio = count / maxCount;
          final color = _barColors[idx % _barColors.length];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      brand,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      count.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(builder: (ctx, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        height: 5,
                        width: constraints.maxWidth * ratio,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: color,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Category chart ─────────────────────────────────────────────────────────

class _CategoryChart extends StatelessWidget {
  final Map<String, dynamic> categories;
  const _CategoryChart({required this.categories});

  static const _catColors = {
    'air_conditioner': Color(0xFF4A9FD4),
    'refrigerator': Color(0xFF4ABCA8),
    'laptop': Color(0xFF7E6FD8),
    'monitor': Color(0xFFD4884A),
    'microwave': Color(0xFFD4A84A),
  };

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _EmptyCard(label: 'No category data yet');
    }

    final total = categories.values
        .whereType<int>()
        .fold<int>(0, (s, v) => s + v);

    return GlassContainer(
      opacity: 0.04,
      blur: 16,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: categories.entries.map((e) {
          final name = e.key;
          final count = e.value as int? ?? 0;
          final pct = total > 0 ? count / total : 0.0;
          final color = _catColors[name.toLowerCase()] ?? const Color(0xFF7A8BA0);
          final label = name.replaceAll('_', ' ');

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$count',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.plusJakartaSans(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(builder: (ctx, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        height: 5,
                        width: constraints.maxWidth * pct,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: color,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Empty placeholder ──────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String label;
  const _EmptyCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white24,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
