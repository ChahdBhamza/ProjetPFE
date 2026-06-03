import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/network/api_service.dart';
import '../../data/models/detection_result_model.dart';

class EquipmentDetailPage extends StatelessWidget {
  final EquipmentResult result;
  const EquipmentDetailPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final String rawBrand = result.identity.brand;
    final String brand = (rawBrand.isEmpty || rawBrand.toLowerCase() == 'unknown')
        ? 'UNIDENTIFIED'
        : rawBrand.toUpperCase();

    final String rawModel = result.identity.topModel;
    final String model =
        (rawModel.isEmpty || rawModel.toLowerCase() == 'unknown model' || rawModel.toLowerCase() == 'unknown')
            ? '—'
            : rawModel;

    final String rawCategory = result.identity.equipmentCategory;
    final String categoryLabel = _cleanCategoryLabel(rawCategory);
    final IconData categoryIcon = _getCategoryIcon(categoryLabel.toUpperCase());

    final int confidence = result.identity.confidence;

    // Always render the FULL schema for this category. Start from the complete
    // field template (all empty) then overlay whatever real values we have, so
    // every field is shown — filled values in white, missing ones as "—".
    final Map<String, dynamic> displaySpecs = {
      ..._schemaForCategory(rawCategory),
      ...result.specs,
    };

    return GlassContainer(
      opacity: 0.15,
      blur: 30,
      borderRadius: 32,
      child: Stack(
        children: [
          // Background grid atmosphere
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // ── 1. HERO IMAGE ───────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: result.meta.aiImage != null && result.meta.aiImage!.isNotEmpty
                            ? Container(
                                height: 240,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: CybersightTheme.accent.withOpacity(0.25)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Stack(children: [
                                    Positioned.fill(
                                      child: Image.memory(
                                        base64Decode(result.meta.aiImage!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _FallbackHero(
                                            icon: categoryIcon, label: categoryLabel),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _ViewfinderOverlayPainter(
                                            color: CybersightTheme.accent),
                                      ),
                                    ),
                                    Positioned.fill(child: _ScanLineEffect()),
                                  ]),
                                ),
                              )
                            : _FallbackHero(icon: categoryIcon, label: categoryLabel),
                      ),

                      const SizedBox(height: 22),

                      // ── 2. IDENTITY HEADER ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _CategoryChip(label: categoryLabel, icon: categoryIcon),
                                _StatusBadge(
                                    label: result.meta.verified ? 'VERIFIED' : 'UNVERIFIED'),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              brand,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              model,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── 3. STAT CHIPS ROW ───────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(children: [
                          _StatChip(
                            label: 'EQUIPMENT',
                            value: categoryLabel,
                            icon: categoryIcon,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'CONFIDENCE',
                            value: confidence > 0 ? '$confidence%' : 'N/A',
                            icon: Icons.psychology_outlined,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'SOURCE',
                            value: _resolveSourceQuality(
                                result.meta.sourceQuality, result.meta.sourceUrls),
                            icon: Icons.verified_outlined,
                          ),
                        ]),
                      ),

                      const SizedBox(height: 28),

                      // ── 4. TECHNICAL SPECIFICATIONS ─────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionLabel(text: 'Technical Specifications'),
                            const SizedBox(height: 14),
                            _SpecGrid(specs: displaySpecs),
                          ],
                        ),
                      ),

                      // ── 5. NEURAL SUMMARY ───────────────────────────────────
                      if (result.meta.summary != null &&
                          result.meta.summary!.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel(text: 'Neural Summary'),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.07)),
                                ),
                                child: Text(
                                  result.meta.summary!,
                                  style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white70, fontSize: 13, height: 1.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── 6. SOURCES (Hidden per user request) ────────────────
                      /*
                      if (result.meta.sourceUrls.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel(text: 'Sources'),
                              const SizedBox(height: 8),
                              ...result.meta.sourceUrls.map((url) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: InkWell(
                                      onTap: () => launchUrlString(url),
                                      child: Row(children: [
                                        const Icon(Icons.link,
                                            color: CybersightTheme.accent, size: 14),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            url,
                                            style: GoogleFonts.plusJakartaSans(
                                              color: CybersightTheme.accent.withOpacity(0.8),
                                              fontSize: 11,
                                              decoration: TextDecoration.underline,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ]),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                      */

                      // ── 7. ACTION BUTTONS ───────────────────────────────────
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(children: [
                          if (result.meta.sourceQuality != 'inventory') ...[
                            GlowingButton(
                              label: 'SAVE TO NEURAL INVENTORY',
                              onTap: () => _handleSave(context),
                            ),
                          ],
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Close button
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    final brand = result.identity.brand.trim().toLowerCase();
    final isUnknownBrand = brand.isEmpty || brand == 'unknown';

    // Warn before saving an item whose brand the AI could not identify
    if (isUnknownBrand) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: CybersightTheme.navy2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: CybersightTheme.warning, size: 22),
            const SizedBox(width: 10),
            Text('Unidentified Brand',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          content: Text(
            'The AI could not identify this item\'s brand. Saving it will create an incomplete '
            'inventory entry.\n\nConsider re-scanning with the brand logo or label clearly visible.',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Re-scan',
                  style: GoogleFonts.plusJakartaSans(
                      color: CybersightTheme.accent, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Save anyway',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final apiService = ApiService();
    final success = await apiService.saveEquipmentToInventory(result);
    if (!context.mounted) return;

    if (success) {
      // Show the success page, then it auto-redirects home. Clears the whole
      // stack so the modal sheets and script-lab page are dismissed cleanly.
      Navigator.pushNamedAndRemoveUntil(context, '/save-success', (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'SYNC FAILED',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        backgroundColor: CybersightTheme.warning.withOpacity(0.9),
      ));
    }
  }

  String _cleanCategoryLabel(String raw) {
    const map = {
      'laptop': 'Laptop',
      'notebook': 'Laptop',
      'computer': 'Laptop',
      'monitor': 'Monitor',
      'screen': 'Monitor',
      'tv': 'Monitor',
      'tv_monitor': 'Monitor',
      'air_conditioner': 'Air Conditioner',
      'airconditioner': 'Air Conditioner',
      'refrigerator': 'Refrigerator',
      'fridge': 'Refrigerator',
      'microwave': 'Microwave',
    };
    final key = raw.toLowerCase().replaceAll(' ', '_');
    return map[key] ??
        raw
            .split(' ')
            .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
            .join(' ');
  }

  String _resolveSourceQuality(String? raw, List<String> urls) {
    if (raw == null || raw.isEmpty) return urls.isNotEmpty ? 'WEB' : 'AI';
    switch (raw.toLowerCase()) {
      case 'inventory': return 'SAVED';
      case 'web':       return 'WEB';
      case 'cache':     return 'CACHE';
      case 'ai':        return 'AI';
      default:          return raw.toUpperCase();
    }
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('AIR')) return Icons.ac_unit_rounded;
    if (category.contains('REF') || category.contains('FRIDGE')) return Icons.kitchen_rounded;
    if (category.contains('MICRO')) return Icons.microwave_rounded;
    if (category.contains('LAP') || category.contains('COMP') || category.contains('NOTEBOOK')) return Icons.laptop_rounded;
    if (category.contains('MONITOR') || category.contains('SCREEN') || category.contains('TV')) return Icons.monitor_rounded;
    return Icons.memory_rounded;
  }

  /// Canonical field list per equipment type — mirrors the backend schema.
  /// All values empty; real specs are overlaid on top so every field renders
  /// (filled in white, missing as "—").
  Map<String, dynamic> _schemaForCategory(String rawCategory) {
    final cat = rawCategory.toLowerCase();
    List<String> keys;
    if (cat.contains('air') || cat.contains('conditioner') || cat.contains('climat')) {
      keys = [
        'capacity_btu', 'technology', 'mode', 'energy_class', 'refrigerant',
        'smart_wifi', 'noise_level_db', 'power_consumption_w',
        'annual_energy_consumption_kwh', 'dimensions', 'warranty_years',
      ];
    } else if (cat.contains('refriger') || cat.contains('fridge')) {
      keys = [
        'capacity_liters', 'energy_class', 'refrigerant', 'no_frost', 'inverter',
        'dimensions', 'weight_kg', 'noise_level_db', 'power_consumption_w',
        'annual_energy_consumption_kwh', 'warranty_years',
      ];
    } else if (cat.contains('micro')) {
      keys = [
        'power_watts', 'annual_energy_consumption_kwh', 'capacity_liters',
        'functions', 'turntable_diameter_cm', 'control_type', 'dimensions',
        'weight_kg', 'warranty_years',
      ];
    } else if (cat.contains('laptop') || cat.contains('notebook') || cat.contains('computer')) {
      keys = [
        'cpu', 'ram_gb', 'storage', 'display_inches', 'display_resolution',
        'gpu', 'battery_wh', 'power_supply_w', 'os', 'weight_kg', 'warranty_years',
      ];
    } else if (cat.contains('monitor') || cat.contains('screen') || cat.contains('display') || cat.contains('tv')) {
      keys = [
        'screen_size_inches', 'resolution', 'panel_type', 'refresh_rate_hz',
        'response_time_ms', 'aspect_ratio', 'brightness_cdm2', 'contrast_ratio',
        'ports', 'power_consumption_w', 'warranty_years',
      ];
    } else {
      keys = [];
    }
    return {for (final k in keys) k: null};
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _FallbackHero extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FallbackHero({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: CybersightTheme.accent.withOpacity(0.04),
        border: Border.all(color: CybersightTheme.accent.withOpacity(0.18)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 84, color: CybersightTheme.accent.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: CybersightTheme.accent.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _CategoryChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: CybersightTheme.accent.withOpacity(0.10),
        border: Border.all(color: CybersightTheme.accent.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: CybersightTheme.accent, size: 13),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: CybersightTheme.accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white24,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 5),
            Row(children: [
              Icon(icon, color: CybersightTheme.accent, size: 12),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SpecGrid extends StatelessWidget {
  final Map<String, dynamic> specs;
  const _SpecGrid({required this.specs});

  static bool _isEmpty(dynamic v) {
    if (v == null) return true;
    final s = v.toString().toLowerCase().trim();
    return s.isEmpty || s == 'null' || s == 'unknown' || s == 'unknown model' || s == 'n/a';
  }

  static String _formatValue(dynamic v) {
    if (_isEmpty(v)) return '—';
    if (v is List) return v.join(', ');
    return v.toString();
  }

  static bool _shouldHide(String key) {
    final k = key.toLowerCase();
    return k.contains('price') ||
        k.contains('status') ||
        k.contains('source') ||
        k.contains('color');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = specs.entries
        .where((e) => !_shouldHide(e.key))
        .toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.02),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Center(
          child: Text(
            'No specification data available.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 12),
          ),
        ),
      );
    }

    final rows = <List<MapEntry<String, dynamic>>>[];
    for (int i = 0; i < filtered.length; i += 2) {
      if (i + 1 < filtered.length) {
        rows.add([filtered[i], filtered[i + 1]]);
      } else {
        rows.add([filtered[i]]);
      }
    }

    return Column(
      children: rows.asMap().entries.map((rowEntry) {
        final baseIdx = rowEntry.key * 2;
        final pair = rowEntry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SpecCard(
                  label: pair[0].key,
                  value: _formatValue(pair[0].value),
                  isEmpty: _isEmpty(pair[0].value),
                  delayIndex: baseIdx,
                ),
              ),
              const SizedBox(width: 8),
              pair.length > 1
                  ? Expanded(
                      child: _SpecCard(
                        label: pair[1].key,
                        value: _formatValue(pair[1].value),
                        isEmpty: _isEmpty(pair[1].value),
                        delayIndex: baseIdx + 1,
                      ),
                    )
                  : const Expanded(child: SizedBox()),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SpecCard extends StatelessWidget {
  final String label;
  final String value;
  final int delayIndex;
  final bool isEmpty;
  const _SpecCard({required this.label, required this.value, required this.delayIndex, this.isEmpty = false});

  IconData _icon() {
    final k = label.toLowerCase();
    if (k.contains('power') || k.contains('watt')) return Icons.bolt_rounded;
    if (k.contains('cooling') || k.contains('btu') || k.contains('capacity') || k.contains('freezer')) return Icons.thermostat_rounded;
    if (k.contains('energy') || k.contains('class') || k.contains('rating')) return Icons.eco_rounded;
    if (k.contains('noise')) return Icons.volume_up_rounded;
    if (k.contains('refrigerant') || k.contains('gas') || k.contains('coverage')) return Icons.opacity_rounded;
    if (k.contains('processor') || k.contains('cpu') || k.contains('ram') || k.contains('os') || k.contains('storage')) return Icons.memory_rounded;
    if (k.contains('display') || k.contains('screen') || k.contains('resolution') || k.contains('refresh') || k.contains('panel')) return Icons.monitor_rounded;
    if (k.contains('battery')) return Icons.battery_charging_full_rounded;
    if (k.contains('dimension') || k.contains('weight') || k.contains('size') || k.contains('turntable')) return Icons.straighten_rounded;
    if (k.contains('port') || k.contains('wifi') || k.contains('smart')) return Icons.wifi_rounded;
    if (k.contains('defrost') || k.contains('program')) return Icons.settings_rounded;
    return Icons.info_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delayIndex * 70),
      curve: Curves.easeOutCubic,
      builder: (_, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(offset: Offset(0, 12 * (1 - val)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.02),
          border: Border.all(color: CybersightTheme.accent.withOpacity(0.12)),
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.04), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CybersightTheme.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon(), color: CybersightTheme.accent, size: 14),
            ),
            const SizedBox(height: 10),
            Text(
              label.replaceAll('_', ' ').toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white30,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: isEmpty ? Colors.white24 : Colors.white,
                fontSize: 13,
                fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white24,
        fontSize: 9,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CybersightTheme.ok.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CybersightTheme.ok.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: CybersightTheme.ok,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ViewfinderOverlayPainter extends CustomPainter {
  final Color color;
  _ViewfinderOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const double len = 12.0;
    const double pad = 10.0;

    canvas.drawPath(
        Path()
          ..moveTo(pad + len, pad)
          ..lineTo(pad, pad)
          ..lineTo(pad, pad + len),
        paint);
    canvas.drawPath(
        Path()
          ..moveTo(size.width - pad - len, pad)
          ..lineTo(size.width - pad, pad)
          ..lineTo(size.width - pad, pad + len),
        paint);
    canvas.drawPath(
        Path()
          ..moveTo(pad + len, size.height - pad)
          ..lineTo(pad, size.height - pad)
          ..lineTo(pad, size.height - pad - len),
        paint);
    canvas.drawPath(
        Path()
          ..moveTo(size.width - pad - len, size.height - pad)
          ..lineTo(size.width - pad, size.height - pad)
          ..lineTo(size.width - pad, size.height - pad - len),
        paint);

    final crossPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(size.width / 2 - 8, size.height / 2),
        Offset(size.width / 2 + 8, size.height / 2), crossPaint);
    canvas.drawLine(Offset(size.width / 2, size.height / 2 - 8),
        Offset(size.width / 2, size.height / 2 + 8), crossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLineEffect extends StatefulWidget {
  @override
  State<_ScanLineEffect> createState() => _ScanLineEffectState();
}

class _ScanLineEffectState extends State<_ScanLineEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              CybersightTheme.accent.withOpacity(0.04),
              CybersightTheme.accent.withOpacity(0.12),
              CybersightTheme.accent.withOpacity(0.04),
              Colors.transparent,
            ],
            stops: [
              (_controller.value - 0.15).clamp(0.0, 1.0),
              (_controller.value - 0.05).clamp(0.0, 1.0),
              _controller.value,
              (_controller.value + 0.05).clamp(0.0, 1.0),
              (_controller.value + 0.15).clamp(0.0, 1.0),
            ],
          ),
        ),
      ),
    );
  }
}
