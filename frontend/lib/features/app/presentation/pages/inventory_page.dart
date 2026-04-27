import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. NEURAL HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [CybersightTheme.accent, Colors.white, CybersightTheme.accent2],
                      ).createShader(rect),
                      child: Text(
                        'INVENTORY',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          fontSize: 26,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NEURAL DATABASE • CLIMATISEURS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: Colors.white24,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
                GlassContainer(
                  width: 42,
                  height: 42,
                  opacity: 0.05,
                  blur: 20,
                  borderRadius: 12,
                  child: const Icon(Icons.qr_code_scanner_rounded, color: CybersightTheme.accent, size: 20),
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            // 2. SEARCH HUD
            Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    height: 48,
                    opacity: 0.05,
                    blur: 15,
                    borderRadius: 14,
                    child: TextField(
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'FILTER DATABASE...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white10, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white24, size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(colors: [CybersightTheme.accent, CybersightTheme.accent2]),
                    boxShadow: [BoxShadow(color: CybersightTheme.accent.withOpacity(0.15), blurRadius: 12)],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.black, size: 24),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // 3. DATABASE LIST
            _InventoryCard(
              title: 'BIOLUX 12K SHARP',
              category: 'CLIMATISEUR',
              serial: 'BLX-2024-X99',
              status: 'VERIFIED',
              statusColor: CybersightTheme.ok,
              btu: '12000',
            ),
            const SizedBox(height: 14),
            _InventoryCard(
              title: 'SAMSUNG WIND-FREE',
              category: 'CLIMATISEUR',
              serial: 'SAM-WF-2024',
              status: 'SYNCING',
              statusColor: CybersightTheme.warning,
              btu: '18000',
            ),
            const SizedBox(height: 14),
            _InventoryCard(
              title: 'AUX PREMIUM ECO',
              category: 'CLIMATISEUR',
              serial: 'AUX-ECO-12',
              status: 'LOCAL',
              statusColor: CybersightTheme.accent2,
              btu: '12000',
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final String title;
  final String category;
  final String serial;
  final String status;
  final Color statusColor;
  final String btu;

  const _InventoryCard({
    required this.title,
    required this.category,
    required this.serial,
    required this.status,
    required this.statusColor,
    required this.btu,
  });

  @override
  Widget build(BuildContext context) {
    return CybersightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withOpacity(0.02),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Center(
                  child: Icon(Icons.ac_unit_rounded, color: statusColor.withOpacity(0.4), size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      '$category • $serial',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
              _StatusIndicator(label: status, color: statusColor),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _MetaTag(label: 'CAPACITY', value: '$btu BTU'),
              const SizedBox(width: 12),
              _MetaTag(label: 'LAST SCAN', value: '24H AGO'),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.07), size: 12),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusIndicator({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4, height: 4,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 4)]),
          ),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 7, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String label;
  final String value;
  const _MetaTag({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 6.5, fontWeight: FontWeight.w900, color: Colors.white24, letterSpacing: 1.2)),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white60)),
      ],
    );
  }
}
