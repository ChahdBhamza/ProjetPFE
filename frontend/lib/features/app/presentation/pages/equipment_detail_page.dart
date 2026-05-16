import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';

class EquipmentDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const EquipmentDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final String brand = (item['brand'] ?? 'UNKNOWN').toString().toUpperCase();
    final String model = (item['model'] ?? 'N/A').toString();
    final String btu = (item['btu'] ?? 'N/A').toString();
    final Map<String, dynamic> metadata = item['metadata'] ?? {};
    final String category = (metadata['category'] ?? 'CLIMATISEUR').toString().toUpperCase();
    final String timestamp = item['added_at'] != null 
        ? item['added_at'].toString().split('T')[0] 
        : 'NEURAL LINK ACTIVE';

    return Container(
      decoration: const BoxDecoration(
        color: CybersightTheme.obsidian,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
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
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  brand,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusBadge(label: 'VERIFIED'),
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
                            Icons.ac_unit_rounded,
                            size: 80,
                            color: CybersightTheme.accent.withOpacity(0.1),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      _SectionLabel(text: 'Neural Identification'),
                      const SizedBox(height: 16),
                      
                      _InfoRow(label: 'MODEL REFERENCE', value: model),
                      _InfoRow(label: 'COOLING CAPACITY', value: '$btu BTU'),
                      _InfoRow(label: 'DETECTION DATE', value: timestamp),
                      
                      const SizedBox(height: 32),
                      
                      _SectionLabel(text: 'Technical Specifications'),
                      const SizedBox(height: 16),
                      
                      // Technical Grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.2,
                        children: [
                          _SpecCard(label: 'ENERGY CLASS', value: metadata['energy_class'] ?? 'A++', icon: Icons.bolt_rounded),
                          _SpecCard(label: 'REFRIGERANT', value: metadata['gas'] ?? 'R32', icon: Icons.opacity_rounded),
                          _SpecCard(label: 'INVERTER', value: metadata['inverter'] == true ? 'YES' : 'NO', icon: Icons.settings_input_component_rounded),
                          _SpecCard(label: 'WIFI LINK', value: 'ESTABLISHED', icon: Icons.wifi_rounded),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white24,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
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
          Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
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
                Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
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
        color: CybersightTheme.ok.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CybersightTheme.ok.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: CybersightTheme.ok,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
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
