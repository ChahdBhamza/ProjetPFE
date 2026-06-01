import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import 'analytics_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.fetchAdminStats();
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white24),
                        minHeight: 2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Loading stats',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _error != null || _stats == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.white24, size: 40),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load stats',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error ?? 'Unable to retrieve statistics.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white30,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: _fetchStats,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withValues(alpha: 0.04),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.09)),
                            ),
                            child: Text(
                              'Retry',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchStats,
                  color: CybersightTheme.accent,
                  backgroundColor: CybersightTheme.navy2,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Admin',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 28,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: CybersightTheme.accent,
                                          boxShadow: [
                                            BoxShadow(
                                                color: CybersightTheme.accent,
                                                blurRadius: 6)
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'System overview',
                                        style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white30,
                                            letterSpacing: 0.3,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _fetchStats,
                              child: GlassContainer(
                                width: 44,
                                height: 44,
                                opacity: 0.05,
                                blur: 18,
                                borderRadius: 14,
                                child: const Icon(Icons.refresh_rounded,
                                    color: Colors.white70, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
 
                        // Section Title: Grid KPIs
                        _SectionHeader(
                            title: 'Grid KPIs', subtitle: 'Global System Nodes'),
                        const SizedBox(height: 10),
 
                        // Top KPI Cards Row
                        Row(
                          children: [
                            Expanded(
                              child: _KpiCard(
                                label: 'Assets',
                                value: _stats!['total_assets'].toString(),
                                icon: Icons.inventory_2_outlined,
                                color: CybersightTheme.accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _KpiCard(
                                label: 'Operators',
                                value: _stats!['total_operators'].toString(),
                                icon: Icons.people_outline_rounded,
                                color: Colors.purpleAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _KpiCard(
                                label: 'Scans',
                                value: _stats!['total_scans'].toString(),
                                icon: Icons.qr_code_scanner_rounded,
                                color: CybersightTheme.accent2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _KpiCard(
                                label: 'AI Conf',
                                value: '${_stats!['avg_confidence']}%',
                                icon: Icons.psychology_outlined,
                                color: CybersightTheme.ok,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
 
                        // Scan Activity Graph
                        _SectionHeader(
                            title: 'Temporal Scan Load',
                            subtitle: 'Daily Scan Sessions (Last 7 Days)'),
                        const SizedBox(height: 12),
                        _LoadChart(
                            activity: List<Map<String, dynamic>>.from(
                                _stats!['activity_over_time'] ?? [])),
                        const SizedBox(height: 24),
 
                        // Category Distribution
                        _SectionHeader(
                            title: 'Asset Breakdown',
                            subtitle: 'Quantity Registered by Category'),
                        const SizedBox(height: 12),
                        _CategoryBreakdownList(
                            categories: Map<String, dynamic>.from(
                                _stats!['categories'] ?? {})),
                        const SizedBox(height: 24),

                        // Analytics entry
                        _AnalyticsCard(stats: _stats!),
                        const SizedBox(height: 24),

                        // Operator Performance Ranking
                        _SectionHeader(
                            title: 'Operators',
                            subtitle: 'Yield & AI validation rank'),
                        const SizedBox(height: 12),
                        _OperatorRankList(
                            operators: List<Map<String, dynamic>>.from(
                                _stats!['operator_performance'] ?? [])),
                      ],
                    ),
                  ),
                ),
    );
  }
}
 
// â”€â”€ Analytics entry card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AnalyticsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _AnalyticsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnalyticsPage(stats: stats)),
      ),
      child: GlassContainer(
        opacity: 0.05,
        blur: 16,
        borderRadius: 20,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: Colors.white54, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analytics',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Brands, categories, today\'s detections',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white30,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 13),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13,
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
 
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
 
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
 
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.05,
      blur: 15,
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white30,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 
class _CategoryBreakdownList extends StatelessWidget {
  final Map<String, dynamic> categories;
  const _CategoryBreakdownList({required this.categories});
 
  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('No categories indexed.',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ),
      );
    }
 
    final total = categories.values.fold<int>(0, (sum, val) => sum + (val as int));
 
    return GlassContainer(
      opacity: 0.04,
      blur: 18,
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: categories.entries.map((e) {
          final count = e.value as int;
          final pct = total > 0 ? count / total : 0.0;
          final categoryName = e.key;
 
          // Distinct color mapping per category
          Color barColor;
          switch (categoryName.toLowerCase()) {
            case 'refrigerator':
              barColor = CybersightTheme.accent;
              break;
            case 'air_conditioner':
              barColor = Colors.orangeAccent;
              break;
            case 'laptop':
              barColor = Colors.purpleAccent;
              break;
            case 'monitor':
              barColor = Colors.greenAccent;
              break;
            case 'microwave':
              barColor = Colors.pinkAccent;
              break;
            default:
              barColor = Colors.blueGrey;
          }
 
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      categoryName.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$count items',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: barColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (ctx, constraint) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: 6,
                          width: constraint.maxWidth * pct,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: [
                                barColor.withValues(alpha: 0.4),
                                barColor,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: barColor.withValues(alpha: 0.3),
                                blurRadius: 6,
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
 
class _LoadChart extends StatelessWidget {
  final List<Map<String, dynamic>> activity;
  const _LoadChart({required this.activity});
 
  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) return const SizedBox();
 
    // Find peak value to scale correctly
    final maxScans = activity.map((e) => e['scans'] as int).fold<int>(
        1, (peak, val) => val > peak ? val : peak);
 
    return GlassContainer(
      opacity: 0.04,
      blur: 18,
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: activity.map((e) {
                final scans = e['scans'] as int;
                final dateStr = e['date'] as String;
                final ratio = scans / maxScans;
                const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                final day = dayNames[DateTime.parse(dateStr).weekday - 1];
 
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Tooltip-like scan count
                        Text(
                          scans.toString(),
                          style: const TextStyle(
                            color: CybersightTheme.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Interactive Glowing Bar
                        Expanded(
                          child: FractionallySizedBox(
                            heightFactor: ratio.clamp(0.08, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                gradient: const LinearGradient(
                                  colors: [
                                    CybersightTheme.accent2,
                                    CybersightTheme.accent,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: CybersightTheme.accent.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    spreadRadius: -2,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Label text (day only)
                        Text(
                          day,
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
 
class _SystemAlertsFeed extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;
  const _SystemAlertsFeed({required this.alerts});
 
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.04,
      blur: 18,
      borderRadius: 22,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: alerts.map((alert) {
          final type = alert['type'] as String? ?? 'info';
          final message = alert['message'] as String? ?? 'System Normal';
          final operator = alert['operator'] as String? ?? 'system';
 
          Color indicatorColor;
          IconData alertIcon;
 
          switch (type) {
            case 'low_confidence':
              indicatorColor = CybersightTheme.warning;
              alertIcon = Icons.warning_amber_rounded;
              break;
            case 'unknown_brand':
              indicatorColor = Colors.orangeAccent;
              alertIcon = Icons.help_outline_rounded;
              break;
            case 'error':
              indicatorColor = CybersightTheme.warning;
              alertIcon = Icons.error_outline_rounded;
              break;
            default:
              indicatorColor = CybersightTheme.ok;
              alertIcon = Icons.check_circle_outline_rounded;
          }
 
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: indicatorColor.withValues(alpha: 0.03),
              border: Border.all(color: indicatorColor.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flashing custom indicator icon
                Icon(alertIcon, color: indicatorColor, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'BY: ${operator.split('@').first.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Text(
                            'REAL-TIME',
                            style: TextStyle(
                              color: Colors.white12,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OperatorRankList extends StatelessWidget {
  final List<Map<String, dynamic>> operators;
  const _OperatorRankList({required this.operators});

  @override
  Widget build(BuildContext context) {
    if (operators.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('No operators indexed.',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ),
      );
    }

    return GlassContainer(
      opacity: 0.04,
      blur: 18,
      borderRadius: 22,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: operators.asMap().entries.map((entry) {
          final index = entry.key;
          final op = entry.value;
          final name = op['name'] as String? ?? 'Operator';
          final email = op['email'] as String? ?? 'Unknown';
          final savedCount = op['items_saved'] as int? ?? 0;
          final conf = op['avg_confidence']?.toString() ?? '80.0';

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.01),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                // Rank Avatar
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == 0
                        ? CybersightTheme.accent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.03),
                    border: Border.all(
                      color: index == 0
                          ? CybersightTheme.accent
                          : Colors.white10,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: index == 0 ? CybersightTheme.accent : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Operator Ident details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                // Stats breakdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$savedCount Assets',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$conf% VLM',
                      style: const TextStyle(
                        color: CybersightTheme.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _IntelGrid extends StatelessWidget {
  final int totalAssets;
  final int totalScans;
  final int activeOperators;
  final int unknownBrandCount;

  const _IntelGrid({
    required this.totalAssets,
    required this.totalScans,
    required this.activeOperators,
    required this.unknownBrandCount,
  });

  @override
  Widget build(BuildContext context) {
    final saveRate = totalScans > 0
        ? '${(totalAssets / totalScans).toStringAsFixed(1)}/scan'
        : 'â€”';
    final idFailRate = totalAssets > 0
        ? '${(unknownBrandCount / totalAssets * 100).toStringAsFixed(0)}%'
        : 'â€”';

    return GlassContainer(
      opacity: 0.05,
      blur: 15,
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniKpi(
                  label: 'SAVE RATE',
                  value: saveRate,
                  sub: 'assets per scan',
                  color: CybersightTheme.ok,
                ),
              ),
              Container(width: 1, height: 48, color: Colors.white.withValues(alpha: 0.05)),
              Expanded(
                child: _MiniKpi(
                  label: 'AVG / SCAN',
                  value: totalScans > 0
                      ? (totalAssets / totalScans).toStringAsFixed(1)
                      : 'â€”',
                  sub: 'items identified',
                  color: CybersightTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniKpi(
                  label: 'ACTIVE OPS',
                  value: activeOperators.toString(),
                  sub: 'operators active',
                  color: Colors.purpleAccent,
                ),
              ),
              Container(width: 1, height: 48, color: Colors.white.withValues(alpha: 0.05)),
              Expanded(
                child: _MiniKpi(
                  label: 'ID FAILURES',
                  value: idFailRate,
                  sub: 'unknown brand rate',
                  color: unknownBrandCount > 0
                      ? CybersightTheme.warning
                      : CybersightTheme.ok,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _MiniKpi({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  letterSpacing: 1.5,
                  fontSize: 8,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(color: Colors.white24, fontSize: 9)),
        ],
      ),
    );
  }
}

class _TopBrandsList extends StatelessWidget {
  final Map<String, dynamic> brands;
  const _TopBrandsList({required this.brands});

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('No brand data.', style: TextStyle(color: Colors.white24, fontSize: 13)),
        ),
      );
    }

    final total = brands.values.fold<int>(0, (sum, v) => sum + (v as int));
    const brandColors = [
      CybersightTheme.accent,
      Colors.purpleAccent,
      CybersightTheme.accent2,
      CybersightTheme.ok,
      Colors.orangeAccent,
    ];

    return GlassContainer(
      opacity: 0.04,
      blur: 18,
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: brands.entries.toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final e = entry.value;
          final count = e.value as int;
          final pct = total > 0 ? count / total : 0.0;
          final color = brandColors[idx % brandColors.length];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7.0),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text('${idx + 1}',
                        style: TextStyle(
                            color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                          Text('$count  ${(pct * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Stack(
                        children: [
                          Container(
                              height: 4,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white.withValues(alpha: 0.04))),
                          LayoutBuilder(builder: (ctx, constraints) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              height: 4,
                              width: constraints.maxWidth * pct,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                    colors: [color.withValues(alpha: 0.5), color]),
                                boxShadow: [
                                  BoxShadow(
                                      color: color.withValues(alpha: 0.3), blurRadius: 6)
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
