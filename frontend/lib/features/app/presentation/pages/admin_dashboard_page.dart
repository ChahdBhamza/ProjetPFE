import 'package:flutter/material.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';

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
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: CybersightTheme.accent),
                  SizedBox(height: 16),
                  Text(
                    'SYNCING WITH NEURAL GRID...',
                    style: TextStyle(
                      color: Colors.white30,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
                            color: CybersightTheme.warning, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'CONNECTION SEVERED',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: CybersightTheme.warning,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error ?? 'Unable to retrieve statistics payload.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchStats,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('RETRY SYNC'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CybersightTheme.warning.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: CybersightTheme.warning),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                                    'Admin Console',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 36,
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
                                        'SYSTEM OVERVIEW • GLOBAL INTEL',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                                color: Colors.white30,
                                                letterSpacing: 2,
                                                fontSize: 9),
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
 
                        // Top Brands & System Anomaly alerts side-by-side or stacked
                        _SectionHeader(
                            title: 'System Health Alerts',
                            subtitle: 'Real-time VLM & Grounding Anomalies'),
                        const SizedBox(height: 12),
                        _SystemAlertsFeed(
                            alerts: List<Map<String, dynamic>>.from(
                                _stats!['alerts'] ?? [])),
                        const SizedBox(height: 24),
 
                        // Operator Performance Ranking
                        _SectionHeader(
                            title: 'Operator Registry',
                            subtitle: 'Operational Yield & AI Validation Rank'),
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
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 12,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle.toUpperCase(),
          style: const TextStyle(
            color: Colors.white24,
            letterSpacing: 1.5,
            fontSize: 9,
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
                  color.withOpacity(0.18),
                  color.withOpacity(0.04),
                ],
              ),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white30,
                    letterSpacing: 1.5,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
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
                        color: Colors.white.withOpacity(0.04),
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
                                barColor.withOpacity(0.4),
                                barColor,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: barColor.withOpacity(0.3),
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
                final day = dateStr.split('-').last;
 
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
                                    color: CybersightTheme.accent.withOpacity(0.25),
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
              color: indicatorColor.withOpacity(0.03),
              border: Border.all(color: indicatorColor.withOpacity(0.12)),
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
              color: Colors.white.withOpacity(0.01),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
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
                        ? CybersightTheme.accent.withOpacity(0.2)
                        : Colors.white.withOpacity(0.03),
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
                        color: Colors.white.withOpacity(0.8),
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
