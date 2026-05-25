import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';

class ModelSelectionSheet extends StatelessWidget {
  final String brand;
  final String category;
  final List<dynamic> modelCandidates;
  final Function(String) onModelSelected;

  const ModelSelectionSheet({
    super.key,
    required this.brand,
    required this.category,
    required this.modelCandidates,
    required this.onModelSelected,
  });

  static void show(
    BuildContext context, {
    required String brand,
    required String category,
    required List<dynamic> modelCandidates,
    required Function(String) onModelSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModelSelectionSheet(
        brand: brand,
        category: category,
        modelCandidates: modelCandidates,
        onModelSelected: onModelSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: CybersightTheme.obsidian,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: CybersightTheme.accent, blurRadius: 100, spreadRadius: -50)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: CybersightTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    brand.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Icon(Icons.radar_rounded, color: CybersightTheme.accent.withOpacity(0.5), size: 40),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'NEURAL IDENTIFICATION COMPLETE',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white24,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the exact model reference from the candidates below:',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          ...modelCandidates.map((c) {
            final String modelName = c['model']?.toString() ?? 'UNKNOWN';
            final int confidence = (c['confidence'] as num?)?.toInt() ?? 0;
            final String reasoning = c['reasoning']?.toString() ?? 'Matched via visual neural net';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Close the sheet
                  onModelSelected(modelName);
                },
                child: GlassContainer(
                  opacity: 0.05,
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 46,
                            height: 46,
                            child: CircularProgressIndicator(
                              value: confidence / 100.0,
                              strokeWidth: 3,
                              color: confidence >= 90 ? CybersightTheme.ok : (confidence >= 70 ? CybersightTheme.accent : CybersightTheme.warning),
                              backgroundColor: Colors.white10,
                            ),
                          ),
                          Text(
                            '$confidence%',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              modelName,
                              style: GoogleFonts.plusJakartaSans(
                                color: CybersightTheme.accent,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reasoning,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
