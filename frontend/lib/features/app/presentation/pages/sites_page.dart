import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class _SiteData {
  final String id;
  final String name;
  final String country;
  final String city;
  final List<String> floors;

  const _SiteData({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.floors,
  });
}

const List<_SiteData> _kSites = [
  _SiteData(
    id: 's1',
    name: 'Bâtiment Alpha',
    country: 'Morocco',
    city: 'Casablanca',
    floors: ['Ground Floor', '1st Floor', '2nd Floor', '3rd Floor'],
  ),
  _SiteData(
    id: 's2',
    name: 'Campus Technopolis',
    country: 'Morocco',
    city: 'Rabat',
    floors: ['Ground Floor', '1st Floor', '2nd Floor'],
  ),
  _SiteData(
    id: 's3',
    name: 'Centre Numérique',
    country: 'France',
    city: 'Paris',
    floors: ['Ground Floor', '1st Floor', '2nd Floor', '3rd Floor', '4th Floor'],
  ),
  _SiteData(
    id: 's4',
    name: 'Hub Innovation',
    country: 'Belgium',
    city: 'Brussels',
    floors: ['Ground Floor', '1st Floor'],
  ),
];

class SitesPage extends StatefulWidget {
  const SitesPage({super.key});

  @override
  State<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends State<SitesPage> with SingleTickerProviderStateMixin {
  late AnimationController _bgController;
  String _selectedCountry = 'All';
  String? _expandedSiteId;

  List<String> get _countries {
    final c = _kSites.map((s) => s.country).toSet().toList()..sort();
    return ['All', ...c];
  }

  List<_SiteData> get _filteredSites => _selectedCountry == 'All'
      ? _kSites
      : _kSites.where((s) => s.country == _selectedCountry).toList();

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _startDetection(String siteName, String floor) {
    Navigator.pushNamed(
      context,
      '/app',
      arguments: {'site': siteName, 'floor': floor},
    );
  }

  @override
  Widget build(BuildContext context) {
    final operatorName = context.watch<AuthProvider>().fullName ?? 'Operator';
    final filtered = _filteredSites;

    return CybersightAtmosphere(
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (_, __) => CustomPaint(
                  painter: _SitesBgPainter(t: _bgController.value),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sites',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 42,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'WELCOME, ${operatorName.toUpperCase()}',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white24,
                                letterSpacing: 2.0,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: CybersightTheme.ok.withOpacity(0.06),
                          border: Border.all(color: CybersightTheme.ok.withOpacity(0.25)),
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
                              'ONLINE',
                              style: GoogleFonts.plusJakartaSans(
                                color: CybersightTheme.ok.withOpacity(0.9),
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
                ),

                const SizedBox(height: 28),

                // ── Country filter ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 10),
                  child: Text(
                    'FILTER BY COUNTRY',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white24,
                      letterSpacing: 1.8,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: _countries.map((country) {
                      final selected = _selectedCountry == country;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedCountry = country;
                            _expandedSiteId = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: selected
                                  ? CybersightTheme.accent.withOpacity(0.12)
                                  : Colors.white.withOpacity(0.04),
                              border: Border.all(
                                color: selected
                                    ? CybersightTheme.accent.withOpacity(0.45)
                                    : Colors.white.withOpacity(0.07),
                                width: selected ? 1.2 : 1,
                              ),
                            ),
                            child: Text(
                              country,
                              style: GoogleFonts.plusJakartaSans(
                                color: selected
                                    ? CybersightTheme.accent
                                    : Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Count label ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${filtered.length} SITE${filtered.length != 1 ? 'S' : ''} AVAILABLE',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white24,
                      letterSpacing: 1.8,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Sites list ───────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                color: Colors.white24,
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No sites found',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white38,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final site = filtered[i];
                            return _SiteCard(
                              site: site,
                              isExpanded: _expandedSiteId == site.id,
                              onToggle: () => setState(() {
                                _expandedSiteId =
                                    _expandedSiteId == site.id ? null : site.id;
                              }),
                              onStartDetection: (floor) =>
                                  _startDetection(site.name, floor),
                            );
                          },
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Background painter ─────────────────────────────────────────────────────

class _SitesBgPainter extends CustomPainter {
  final double t;
  const _SitesBgPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final center = Offset(size.width * 0.88, size.height * 0.12);
    final maxR = size.longestSide * 0.65;

    for (double r = 60; r < maxR; r += 38) {
      final mix = (r / maxR).clamp(0.0, 1.0);
      paint.color = Color.lerp(
            CybersightTheme.accent2.withOpacity(0.09),
            CybersightTheme.accent.withOpacity(0.02),
            mix,
          ) ??
          CybersightTheme.accent2.withOpacity(0.05);
      final start = -0.6 + 0.05 * math.sin((t * math.pi * 2) + mix * 5);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        1.6,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SitesBgPainter old) => old.t != t;
}

// ── Site card ──────────────────────────────────────────────────────────────

class _SiteCard extends StatelessWidget {
  final _SiteData site;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(String) onStartDetection;

  const _SiteCard({
    required this.site,
    required this.isExpanded,
    required this.onToggle,
    required this.onStartDetection,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: CybersightTheme.accent.withOpacity(0.08),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: GlassContainer(
        opacity: isExpanded ? 0.07 : 0.04,
        blur: 18,
        borderRadius: 20,
        border: Border.all(
          color: isExpanded
              ? CybersightTheme.accent.withOpacity(0.25)
              : Colors.white.withOpacity(0.07),
          width: isExpanded ? 1.2 : 1,
        ),
        child: Column(
          children: [
            // Card header
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: (isExpanded
                                ? CybersightTheme.accent
                                : CybersightTheme.accent2)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: (isExpanded
                                  ? CybersightTheme.accent
                                  : CybersightTheme.accent2)
                              .withOpacity(0.22),
                        ),
                      ),
                      child: Icon(
                        Icons.location_city_rounded,
                        color: isExpanded
                            ? CybersightTheme.accent
                            : CybersightTheme.accent2,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            site.name,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                color: Colors.white38,
                                size: 11,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${site.city}, ${site.country}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isExpanded
                                ? CybersightTheme.accent
                                : Colors.white38,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${site.floors.length} FLOORS',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white24,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Expandable floors
            AnimatedCrossFade(
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 280),
              sizeCurve: Curves.easeOutCubic,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: Colors.white.withOpacity(0.06)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                    child: Text(
                      'SELECT FLOOR',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white24,
                        letterSpacing: 2.0,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ...site.floors.map(
                    (floor) => Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      child: _FloorRow(
                        floor: floor,
                        onStart: () => onStartDetection(floor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Floor row ──────────────────────────────────────────────────────────────

class _FloorRow extends StatefulWidget {
  final String floor;
  final VoidCallback onStart;

  const _FloorRow({required this.floor, required this.onStart});

  @override
  State<_FloorRow> createState() => _FloorRowState();
}

class _FloorRowState extends State<_FloorRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onStart,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        transform: Matrix4.identity()..scale(_pressed ? 0.985 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _pressed
              ? CybersightTheme.accent.withOpacity(0.06)
              : Colors.white.withOpacity(0.03),
          border: Border.all(
            color: _pressed
                ? CybersightTheme.accent.withOpacity(0.18)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CybersightTheme.accent2.withOpacity(0.08),
                border: Border.all(
                  color: CybersightTheme.accent2.withOpacity(0.18),
                ),
              ),
              child: const Icon(
                Icons.layers_rounded,
                color: CybersightTheme.accent2,
                size: 14,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.floor,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            // Gradient "Start Detection" pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [CybersightTheme.accent, CybersightTheme.accent2],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: _pressed
                    ? []
                    : [
                        BoxShadow(
                          color: CybersightTheme.accent.withOpacity(0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Text(
                'Start Detection',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
