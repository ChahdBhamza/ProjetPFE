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
    final String brand = result.identity.brand.toUpperCase();
    final String model = result.identity.topModel;
    final String category = result.identity.equipmentCategory.toUpperCase();
    
    // Attempt to extract some common high-level fields for the top info row
    final String capacityOrBtu = result.specs['capacity_btu']?.toString() ?? 
                                 result.specs['capacity_liters']?.toString() ?? 
                                 'N/A';

    final String timestamp = 'NEURAL LINK ACTIVE';

    return GlassContainer(
      opacity: 0.15,
      blur: 30,
      borderRadius: 32,
      child: Stack(
        children: [
          // Background Atmosphere
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: CybersightTheme.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  brand,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusBadge(label: result.meta.verified ? 'VERIFIED' : 'UNVERIFIED'),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Hero Image Placeholder (Futuristic Icon)
                      GlassContainer(
                        height: 180,
                        width: double.infinity,
                        borderRadius: 24,
                        opacity: 0.03,
                        blur: 20,
                        child: Center(
                          child: Icon(
                            _getCategoryIcon(category),
                            size: 80,
                            color: CybersightTheme.accent.withOpacity(0.1),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      _SectionLabel(text: 'Neural Identification'),
                      const SizedBox(height: 16),
                      
                      _InfoRow(label: 'MODEL REFERENCE', value: model),
                      if (capacityOrBtu != 'N/A')
                        _InfoRow(label: 'MAIN CAPACITY', value: capacityOrBtu),
                      _InfoRow(label: 'SOURCE QUALITY', value: (result.meta.sourceQuality ?? 'UNKNOWN').toUpperCase()),
                      
                      const SizedBox(height: 32),
                      
                      _SectionLabel(text: 'Technical Specifications'),
                      const SizedBox(height: 16),
                      
                      if (result.specs.isEmpty)
                        Text(
                          'No structured technical data found.',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13),
                        )
                      else
                        // Technical Grid dynamic builder
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.2,
                          children: result.specs.entries
                              .where((e) => e.value != null && e.value.toString().isNotEmpty)
                              .map((entry) {
                                final label = entry.key.replaceAll('_', ' ').toUpperCase();
                                return _SpecCard(
                                  label: label, 
                                  value: entry.value.toString().toUpperCase(), 
                                  icon: _getIconForSpec(entry.key)
                                );
                              }).toList(),
                        ),
                      
                      const SizedBox(height: 32),
                      
                      _SectionLabel(text: 'Neural Summary'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          result.meta.summary ?? 'Spec extraction complete based on visual matches.',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, height: 1.6),
                        ),
                      ),

                      if (result.meta.sourceUrls.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SectionLabel(text: 'Sources'),
                        const SizedBox(height: 8),
                        ...result.meta.sourceUrls.map((url) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            onTap: () => launchUrlString(url),
                            child: Row(
                              children: [
                                const Icon(Icons.link, color: CybersightTheme.accent, size: 14),
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
                              ],
                            ),
                          ),
                        )),
                      ],
                      
                      const SizedBox(height: 40),
                      
                      if (result.meta.sourceQuality != 'inventory') ...[
                        GlowingButton(
                          label: 'SAVE TO NEURAL INVENTORY',
                          onTap: () async {
                            final apiService = ApiService();
                            final success = await apiService.saveEquipmentToInventory(result);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success ? 'SYNC SUCCESSFUL • ADDED TO INVENTORY' : 'SYNC FAILED',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                                  ),
                                  backgroundColor: (success ? CybersightTheme.ok : CybersightTheme.warning).withOpacity(0.9),
                                ),
                              );
                              if (success) {
                                Navigator.pop(context);
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      GlowingButton(
                        label: 'EXPORT TECHNICAL DATA',
                        onTap: () => Navigator.pop(context),
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

  IconData _getCategoryIcon(String category) {
    if (category.contains('AIR')) return Icons.ac_unit_rounded;
    if (category.contains('REF')) return Icons.kitchen_rounded;
    if (category.contains('MICRO')) return Icons.microwave_rounded;
    if (category.contains('LAP')) return Icons.laptop_rounded;
    if (category.contains('MONITOR') || category.contains('SCREEN') || category.contains('DISP')) return Icons.monitor_rounded;
    return Icons.memory_rounded;
  }

  IconData _getIconForSpec(String key) {
    key = key.toLowerCase();
    if (key.contains('power') || key.contains('energy') || key.contains('watt')) return Icons.bolt_rounded;
    if (key.contains('wifi') || key.contains('smart')) return Icons.wifi_rounded;
    if (key.contains('price')) return Icons.payments_rounded;
    if (key.contains('warranty')) return Icons.verified_user_rounded;
    if (key.contains('noise')) return Icons.volume_up_rounded;
    if (key.contains('dimension') || key.contains('weight')) return Icons.straighten_rounded;
    if (key.contains('refrigerant') || key.contains('gas')) return Icons.opacity_rounded;
    if (key.contains('color')) return Icons.palette_rounded;
    if (key.contains('cpu') || key.contains('gpu') || key.contains('ram')) return Icons.memory_rounded;
    return Icons.info_outline_rounded;
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SpecCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SpecCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.04,
      borderRadius: 16,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: CybersightTheme.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
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
