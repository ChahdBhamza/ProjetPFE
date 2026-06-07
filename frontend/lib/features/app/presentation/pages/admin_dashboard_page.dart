import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/network/api_service.dart';

const _kPalette = [
  Color(0xFF5B9BD5),
  Color(0xFF8B7FD4),
  Color(0xFF4DBCAA),
  Color(0xFFE0885A),
  Color(0xFF6DBF8D),
];

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late TabController _tab;
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _fetchStats();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stats = await ApiService().fetchAdminStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
        if (stats == null) _error = 'No data returned';
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
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildTabBar(),
            const SizedBox(height: 4),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overview',
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
                  'ADMIN CONSOLE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: Colors.white24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _fetchStats,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: Colors.white38, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Dashboard'), Tab(text: 'Analytics')],
          labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: FontWeight.w400),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: Colors.white.withValues(alpha: 0.10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          overlayColor:
              const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white24),
                  minHeight: 2,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Loading',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null || _stats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white24, size: 36),
            const SizedBox(height: 12),
            Text(
              'Could not load data',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _fetchStats,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tab,
      children: [
        _DashboardTab(stats: _stats!, onRefresh: _fetchStats),
        _AnalyticsTab(stats: _stats!),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// DASHBOARD TAB
// ══════════════════════════════════════════════════════════════════════

class _DashboardTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final VoidCallback onRefresh;
  const _DashboardTab({required this.stats, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: Colors.white38,
      backgroundColor: const Color(0xFF0E1E3A),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: _KpiCard(
                  label: 'Detections',
                  value: stats['total_detections'] as int? ?? 0,
                  icon: Icons.radar_rounded,
                  color: _kPalette[0],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  label: 'Saved',
                  value: stats['total_assets'] as int? ?? 0,
                  icon: Icons.inventory_2_outlined,
                  color: _kPalette[1],
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _KpiCard(
                  label: 'Active Operators',
                  value: stats['active_operators'] as int? ?? 0,
                  icon: Icons.people_outline_rounded,
                  color: _kPalette[2],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  label: 'ID Success',
                  value: (stats['id_success_rate'] as num?)?.toInt() ?? 0,
                  icon: Icons.verified_outlined,
                  color: _kPalette[4],
                  suffix: '%',
                ),
              ),
            ]),
            const SizedBox(height: 24),
            const _Label(
                title: 'Detection activity',
                sub: 'AI detections per day — last 7 days'),
            const SizedBox(height: 10),
            _ActivityChart(
              data: List<Map<String, dynamic>>.from(
                  stats['activity_over_time'] ?? []),
            ),
            const SizedBox(height: 24),
            const _Label(
                title: 'Operators', sub: 'Ranked by assets saved'),
            const SizedBox(height: 10),
            _OperatorList(
              operators: List<Map<String, dynamic>>.from(
                  stats['operator_performance'] ?? []),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ANALYTICS TAB
// ══════════════════════════════════════════════════════════════════════

class _AnalyticsTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _AnalyticsTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final detectionsToday = stats['detections_today'] as int? ?? 0;
    final totalDetections = stats['total_detections'] as int? ?? 0;
    final idSuccessRate = (stats['id_success_rate'] as num?)?.toInt() ?? 0;
    final totalAssets = stats['total_assets'] as int? ?? 0;
    final brands = Map<String, dynamic>.from(stats['brands'] ?? {})
      ..removeWhere((k, _) => k.toLowerCase() == 'unknown');
    final categories = Map<String, dynamic>.from(stats['categories'] ?? {})
      ..removeWhere((k, _) => k.toLowerCase() == 'unknown');
    final activity = List<Map<String, dynamic>>.from(
        stats['activity_over_time'] ?? []);
    final scanValues = activity
        .map((e) => e['scans'] as int? ?? 0)
        .toList();

    final catTotal = categories.values.whereType<int>().fold<int>(0, (s, v) => s + v);
    final topEntry = categories.entries.isNotEmpty
        ? categories.entries.reduce((a, b) => (a.value as int) >= (b.value as int) ? a : b)
        : null;
    final topTypeLabel = topEntry != null
        ? topEntry.key.replaceAll('_', ' ')
        : 'N/A';
    final topTypePct = (topEntry != null && catTotal > 0)
        ? ((topEntry.value as int) / catTotal * 100).round()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TodayHero(today: detectionsToday, total: totalDetections),
          const SizedBox(height: 12),
          Row(children: [
            _Chip(label: 'Saved', value: totalAssets),
            const SizedBox(width: 8),
            _Chip(label: 'ID Rate', value: idSuccessRate, suffix: '%'),
            const SizedBox(width: 8),
            _Chip(label: topTypeLabel, value: topTypePct, suffix: '%'),
          ]),
          const SizedBox(height: 24),

          // 7-day sparkline
          if (scanValues.isNotEmpty) ...[
            const _Label(title: '7-day detections', sub: 'AI detections per day'),
            const SizedBox(height: 10),
            _SparklineCard(values: scanValues),
            const SizedBox(height: 24),
          ],

          // Top brands — interactive
          const _Label(title: 'Top brands', sub: 'Most detected manufacturers'),
          const SizedBox(height: 10),
          _InteractiveBars(data: brands),
          const SizedBox(height: 24),

          const _Label(title: 'Category split', sub: 'Detected equipment by type'),
          const SizedBox(height: 10),
          _DonutChart(data: categories),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════

class _Label extends StatelessWidget {
  final String title;
  final String sub;
  const _Label({required this.title, required this.sub});

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
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: GoogleFonts.plusJakartaSans(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

// ── Animated KPI card ──────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String suffix;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.05,
      blur: 14,
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white30,
                      fontSize: 10,
                      fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 3),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.toDouble()),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    '${v.toInt()}$suffix',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
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

// ── Activity bar chart ─────────────────────────────────────────────────────

class _ActivityChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  const _ActivityChart({required this.data});

  @override
  State<_ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<_ActivityChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const _EmptyCard(label: 'No activity data');
    final max = widget.data
        .map((e) => e['scans'] as int? ?? 0)
        .fold<int>(1, (m, v) => v > m ? v : m);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return GlassContainer(
      opacity: 0.04,
      blur: 14,
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: widget.data.asMap().entries.map((entry) {
            final idx = entry.key;
            final scans = entry.value['scans'] as int? ?? 0;
            final dateStr = entry.value['date'] as String? ?? '';
            final ratio = scans / max;
            final isSelected = _selected == idx;
            final baseColor = _kPalette[idx % _kPalette.length];
            String day = '—';
            if (dateStr.isNotEmpty) {
              try {
                day = days[DateTime.parse(dateStr).weekday - 1];
              } catch (_) {}
            }

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(
                    () => _selected = _selected == idx ? null : idx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: isSelected ? 1.0 : 0.0,
                        child: Text(
                          '$scans',
                          style: GoogleFonts.plusJakartaSans(
                              color: baseColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: ratio.clamp(0.05, 1.0)),
                            duration: Duration(milliseconds: 500 + idx * 80),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => FractionallySizedBox(
                              heightFactor: v,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(5)),
                                  gradient: LinearGradient(
                                    colors: [
                                      baseColor.withValues(alpha: isSelected ? 0.45 : 0.28),
                                      baseColor.withValues(alpha: isSelected ? 1.0 : 0.80),
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(
                                          color: baseColor.withValues(alpha: 0.45),
                                          blurRadius: 10,
                                          spreadRadius: -2,
                                        )]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        day,
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected ? baseColor.withValues(alpha: 0.9) : Colors.white24,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Today hero ─────────────────────────────────────────────────────────────

class _TodayHero extends StatelessWidget {
  final int today;
  final int total;
  const _TodayHero({required this.today, required this.total});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.05,
      blur: 14,
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detections today',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white30,
                      fontSize: 11,
                      fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: today.toDouble()),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    '${v.toInt()}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'assets',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white24,
                      fontSize: 12,
                      fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.04),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: total.toDouble()),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(
                'Total: ${v.toInt()}',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w400),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final int value;
  final String suffix;
  const _Chip(
      {required this.label, required this.value, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.03),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(
                '${v.toInt()}$suffix',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Operator list ──────────────────────────────────────────────────────────

class _OperatorList extends StatelessWidget {
  final List<Map<String, dynamic>> operators;
  const _OperatorList({required this.operators});

  @override
  Widget build(BuildContext context) {
    if (operators.isEmpty) {
      return const _EmptyCard(label: 'No operator data');
    }
    return GlassContainer(
      opacity: 0.04,
      blur: 14,
      borderRadius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: operators.asMap().entries.map((entry) {
          final idx = entry.key;
          final op = entry.value;
          final name = op['name'] as String? ?? 'Operator';
          final email = op['email'] as String? ?? '';
          final saved = op['items_saved'] as int? ?? 0;
          final color = _kPalette[idx % _kPalette.length];

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.02),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color.withValues(alpha: 0.30)),
                ),
                child: Center(
                  child: Text(
                    '${idx + 1}',
                    style: GoogleFonts.plusJakartaSans(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text(email.split('@').first,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white30,
                            fontSize: 9,
                            fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${op['items_detected'] ?? saved} detected',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Text('$saved saved',
                      style: GoogleFonts.plusJakartaSans(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Sparkline card ─────────────────────────────────────────────────────────

class _SparklineCard extends StatelessWidget {
  final List<int> values;
  const _SparklineCard({required this.values});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.04,
      blur: 14,
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, progress, __) => ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: SizedBox(
                  height: 80,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _SparklinePainter(values: values),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(values.length, (i) {
              const abbr = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              return Text(
                abbr[i % abbr.length],
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white24, fontSize: 9),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  const _SparklinePainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final max = values.fold<int>(1, (m, v) => v > m ? v : m);
    final pts = values.asMap().entries.map((e) {
      final x = e.key / (values.length - 1) * size.width;
      final y = size.height - (e.value / max) * size.height * 0.85;
      return Offset(x, y);
    }).toList();

    // Filled area
    final area = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) { area.lineTo(p.dx, p.dy); }
    area.lineTo(pts.last.dx, size.height);
    area.close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _kPalette[2].withValues(alpha: 0.28),
            _kPalette[2].withValues(alpha: 0.03),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Line
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) { line.lineTo(pts[i].dx, pts[i].dy); }
    canvas.drawPath(
      line,
      Paint()
        ..color = _kPalette[2]
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots at each point
    for (final p in pts) {
      canvas.drawCircle(p, 3, Paint()..color = _kPalette[2]);
      canvas.drawCircle(
          p,
          3,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.values != values;
}

// ── Interactive brand bars ─────────────────────────────────────────────────

class _InteractiveBars extends StatefulWidget {
  final Map<String, dynamic> data;
  const _InteractiveBars({required this.data});
  @override
  State<_InteractiveBars> createState() => _InteractiveBarsState();
}

class _InteractiveBarsState extends State<_InteractiveBars> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final filtered = Map<String, dynamic>.from(widget.data)
      ..removeWhere((k, _) => k.toLowerCase() == 'unknown');
    if (filtered.isEmpty) return const _EmptyCard(label: 'No brand data');
    final total = filtered.values.whereType<int>().fold<int>(0, (s, v) => s + v);
    final max = filtered.values.whereType<int>().fold<int>(1, (m, v) => v > m ? v : m);

    return GlassContainer(
      opacity: 0.04,
      blur: 14,
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: filtered.entries.toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final key = entry.value.key;
          final count = entry.value.value as int? ?? 0;
          final ratio = count / max;
          final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
          final color = _kPalette[idx % _kPalette.length];
          final isSelected = _selected == idx;

          return GestureDetector(
            onTap: () => setState(() => _selected = _selected == idx ? null : idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected
                    ? color.withValues(alpha: 0.10)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.30)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? color : color.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(key,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            )),
                      ]),
                      Row(children: [
                        Text('$count',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white38, fontSize: 11)),
                        const SizedBox(width: 6),
                        Text('$pct%',
                            style: GoogleFonts.plusJakartaSans(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (_, constraints) => Stack(children: [
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio),
                      duration: Duration(milliseconds: 700 + idx * 100),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Container(
                        height: 5,
                        width: constraints.maxWidth * v,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(colors: [
                            color.withValues(alpha: 0.5),
                            color,
                          ]),
                        ),
                      ),
                    ),
                  ])),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Donut chart — category split ───────────────────────────────────────────

class _DonutChart extends StatefulWidget {
  final Map<String, dynamic> data;
  const _DonutChart({required this.data});
  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  int? _selected;

  static final _catColors = <String, Color>{
    'laptop': _kPalette[1],
    'monitor': _kPalette[3],
    'air_conditioner': _kPalette[0],
    'refrigerator': _kPalette[2],
    'microwave': _kPalette[4],
  };

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _colorFor(String key, int idx) =>
      _catColors[key.toLowerCase()] ?? _kPalette[idx % _kPalette.length];

  @override
  Widget build(BuildContext context) {
    final filtered = Map<String, dynamic>.from(widget.data)
      ..removeWhere((k, _) => k.toLowerCase() == 'unknown');
    if (filtered.isEmpty) return const _EmptyCard(label: 'No category data');

    final total =
        filtered.values.whereType<int>().fold<int>(0, (s, v) => s + v);
    final entries = filtered.entries.toList();
    final colors =
        List.generate(entries.length, (i) => _colorFor(entries[i].key, i));

    return GlassContainer(
      opacity: 0.04,
      blur: 14,
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 210,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final chartSize = constraints.biggest;
                return AnimatedBuilder(
                  animation: _anim,
                  builder: (_, __) => Stack(
                    children: [
                      GestureDetector(
                        onTapDown: (d) =>
                            _onTap(d.localPosition, chartSize, entries, total),
                        child: CustomPaint(
                          size: chartSize,
                          painter: _DonutPainter(
                            entries: entries,
                            total: total,
                            progress: _anim.value,
                            selected: _selected,
                            colors: colors,
                          ),
                        ),
                      ),
                      Center(
                          child: _centerLabel(entries, total, colors)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: entries.asMap().entries.map((e) {
              final idx = e.key;
              final key = e.value.key;
              final count = e.value.value as int? ?? 0;
              final pct =
                  total > 0 ? (count / total * 100).round() : 0;
              final color = colors[idx];
              final isSel = _selected == idx;
              return GestureDetector(
                onTap: () => setState(
                    () => _selected = _selected == idx ? null : idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isSel
                        ? color.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.03),
                    border: Border.all(
                      color: isSel
                          ? color.withValues(alpha: 0.36)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel
                              ? color
                              : color.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        key.replaceAll('_', ' '),
                        style: GoogleFonts.plusJakartaSans(
                          color: isSel ? Colors.white : Colors.white54,
                          fontSize: 11,
                          fontWeight: isSel
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$pct%',
                        style: GoogleFonts.plusJakartaSans(
                          color: isSel
                              ? color
                              : color.withValues(alpha: 0.70),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _centerLabel(
      List<MapEntry<String, dynamic>> entries, int total, List<Color> colors) {
    if (_selected != null && _selected! < entries.length) {
      final key = entries[_selected!].key;
      final count = entries[_selected!].value as int? ?? 0;
      final pct = total > 0 ? (count / total * 100).round() : 0;
      final color = colors[_selected!];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            key.replaceAll('_', '\n'),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
          Text(
            '$pct%',
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$total',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w700,
            letterSpacing: -2,
            height: 1.0,
          ),
        ),
        Text(
          'total',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white24,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  void _onTap(Offset pos, Size chartSize,
      List<MapEntry<String, dynamic>> entries, int total) {
    if (total == 0) return;
    final center = Offset(chartSize.width / 2, chartSize.height / 2);
    final outerR = math.min(chartSize.width, chartSize.height) / 2 - 8;
    final strokeW = outerR * 0.28;
    final innerR = outerR - strokeW;
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < innerR - 6 || dist > outerR + 8) {
      setState(() => _selected = null);
      return;
    }

    // Normalize angle to [0, 2π) from top
    double angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    const gap = 0.04;
    final available = 2 * math.pi - gap * entries.length;
    double cursor = 0;
    for (int i = 0; i < entries.length; i++) {
      final count = entries[i].value as int? ?? 0;
      final sweep = (count / total) * available;
      if (angle >= cursor && angle < cursor + sweep) {
        setState(() => _selected = _selected == i ? null : i);
        return;
      }
      cursor += sweep + gap;
    }
    setState(() => _selected = null);
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, dynamic>> entries;
  final int total;
  final double progress;
  final int? selected;
  final List<Color> colors;

  const _DonutPainter({
    required this.entries,
    required this.total,
    required this.progress,
    required this.selected,
    required this.colors,
  });

  static const double _gap = 0.04;

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0 || entries.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2 - 8;
    final strokeW = outerR * 0.28;
    final drawR = outerR - strokeW / 2;
    final available = 2 * math.pi - _gap * entries.length;

    double cursor = -math.pi / 2; // start from top

    // Background ring
    canvas.drawCircle(
      center,
      drawR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..color = Colors.white.withValues(alpha: 0.04),
    );

    for (int i = 0; i < entries.length; i++) {
      final count = entries[i].value as int? ?? 0;
      final ratio = count / total;
      final sweep = ratio * available * progress;
      final color = colors[i];
      final isSel = selected == i;

      final midAngle = cursor + sweep / 2;
      final pop = isSel ? 9.0 : 0.0;
      final popCenter =
          center + Offset(math.cos(midAngle) * pop, math.sin(midAngle) * pop);
      final rect = Rect.fromCircle(center: popCenter, radius: drawR);

      // Outer glow for selected segment
      if (isSel) {
        canvas.drawArc(
          rect,
          cursor,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW + 14
            ..strokeCap = StrokeCap.butt
            ..color = color.withValues(alpha: 0.18)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }

      // Segment arc
      canvas.drawArc(
        rect,
        cursor,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.butt
          ..color =
              isSel ? color : color.withValues(alpha: 0.68),
      );

      cursor += sweep + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.selected != selected;
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
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.02),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
              color: Colors.white24, fontSize: 12),
        ),
      ),
    );
  }
}
