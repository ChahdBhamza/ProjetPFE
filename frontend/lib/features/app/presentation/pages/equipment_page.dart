import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:equipment_detection_app/core/design_system/cybersight_theme.dart';
import 'package:equipment_detection_app/core/widgets/hud_widgets.dart';
import 'package:equipment_detection_app/features/app/presentation/providers/detection_provider.dart';
import 'package:equipment_detection_app/features/auth/presentation/providers/auth_provider.dart';
import 'script_lab_page.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 32,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Neural Input Source', style: GoogleFonts.plusJakartaSans(color: CybersightTheme.accent, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
            const SizedBox(height: 24),
            _ActionTile(
              icon: Icons.movie_filter_rounded,
              title: 'Neural Script Lab',
              subtitle: 'Advanced frame selection & analysis',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScriptLabPage()),
                );
              },
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detectionProvider = context.watch<DetectionProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isProcessing = detectionProvider.isLoading;
    final hasUpload = detectionProvider.capturedFile != null;
    final String operatorName = authProvider.fullName ?? "Operator";

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(
              title: 'Identify',
              subtitle: 'WELCOME, ${operatorName.toUpperCase()}',
              trailing: _StatusPill(
                label: isProcessing ? 'SCANNING' : 'SYSTEM READY',
                color: isProcessing ? CybersightTheme.warning : CybersightTheme.ok,
              ),
            ),
            const SizedBox(height: 32),
            
            // MAIN SCANNER AREA
            GestureDetector(
              onTap: isProcessing ? null : _showPickOptions,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return _ScannerHub(
                    isProcessing: isProcessing,
                    hasUpload: hasUpload,
                    capturedFile: detectionProvider.capturedFile,
                    pulseValue: isProcessing ? _pulseController.value : 0.0,
                  );
                },
              ),
            ),

            const SizedBox(height: 32),
            Text('Analysis Output', style: GoogleFonts.plusJakartaSans(color: Colors.white24, letterSpacing: 1.5, fontSize: 9, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            if (isProcessing) ...[
              const _AnalysisProgress(label: 'Neural Handshake', progress: 0.4),
              const SizedBox(height: 16),
              const _AnalysisProgress(label: 'VLM Extraction', progress: 0.7),
            ] else if (detectionProvider.status == DetectionStatus.success && detectionProvider.result != null) ...[
              _IdentityCard(result: detectionProvider.result!),
              const SizedBox(height: 24),
              GlowingButton(
                label: 'Save to Inventory',
                onTap: () async {
                  final success = await detectionProvider.saveCurrentToInventory();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Sync Successful' : 'Sync Failed', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                        backgroundColor: (success ? CybersightTheme.ok : CybersightTheme.warning).withOpacity(0.9),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => detectionProvider.reset(),
                  child: Text('Reset Scanner', style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                ),
              ),
            ] else if (detectionProvider.status == DetectionStatus.error) ...[
              _ErrorCard(message: detectionProvider.errorMessage ?? "Link Error", onRetry: () => detectionProvider.reset()),
            ] else ...[
              const _ActionTile(
                icon: Icons.auto_awesome_rounded,
                title: 'Start Analysis',
                subtitle: 'Tap the hub to begin equipment scan',
                onTap: null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- INTERNAL COMPONENTS ---

class _ScannerHub extends StatelessWidget {
  final bool isProcessing;
  final bool hasUpload;
  final File? capturedFile;
  final double pulseValue;

  const _ScannerHub({
    required this.isProcessing, 
    required this.hasUpload, 
    this.capturedFile,
    this.pulseValue = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
      ),
      child: GlassContainer(
        height: 220,
        opacity: 0.04,
        blur: 24,
        borderRadius: 32,
        child: Stack(
          children: [
            if (hasUpload)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.file(capturedFile!, fit: BoxFit.cover),
                  ),
                ),
              ),
            if (isProcessing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        CybersightTheme.accent.withOpacity(0.0),
                        CybersightTheme.accent.withOpacity(0.2 * pulseValue),
                        CybersightTheme.accent.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: isProcessing ? 1.0 + (0.05 * pulseValue) : 1.0,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CybersightTheme.accent.withOpacity(0.1),
                        border: Border.all(color: CybersightTheme.accent.withOpacity(0.4), width: 1.5),
                      ),
                      child: Icon(
                        isProcessing ? Icons.radar_rounded : (hasUpload ? Icons.check_rounded : Icons.filter_center_focus_rounded),
                        color: CybersightTheme.accent,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isProcessing ? 'Processing...' : (hasUpload ? 'Scan Complete' : 'Tap to scan equipment'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500, 
                      letterSpacing: 0.5,
                      color: isProcessing ? CybersightTheme.accent : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final dynamic result;
  const _IdentityCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final brand = (result.vectorMatch?.item.brand as String? ?? 'UNKNOWN').toUpperCase();
    final modelName = result.vectorMatch?.item.modelName as String? ?? 'No model data';
    final confidence = (result.vectorMatch?.confidence as double? ?? 0.0);
    final details = result.verifiedDetails as Map<String, dynamic>?;
    final equipmentType = details?['equipment_type'] as String?;
    final candidates = details?['model_candidates'] as List<dynamic>?;
    final visualCues = details?['visual_cues'] as List<dynamic>?;

    return CybersightCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Identified Unit', style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontWeight: FontWeight.w600, fontSize: 9, letterSpacing: 1.2)),
              if (equipmentType != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: CybersightTheme.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CybersightTheme.accent.withOpacity(0.2)),
                  ),
                  child: Text(
                    equipmentType.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(color: CybersightTheme.accent, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.0),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Brand + Model
          Text(brand, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.1)),
          const SizedBox(height: 4),
          Text(modelName, style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),

          // Confidence badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CybersightTheme.accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CybersightTheme.accent.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, color: CybersightTheme.accent, size: 14),
                const SizedBox(width: 8),
                Text(
                  '${(confidence * 100).toStringAsFixed(0)}% Confidence',
                  style: GoogleFonts.plusJakartaSans(color: CybersightTheme.accent, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
              ],
            ),
          ),

          // Alternative candidates
          if (candidates != null && candidates.length > 1) ...[
            const SizedBox(height: 24),
            Text('Alternatives', style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            ...candidates.skip(1).take(2).map((c) {
              final m = c as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(m['model']?.toString() ?? '', style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500))),
                    Text('${m['confidence']}%', style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],

          // Visual cues
          if (visualCues != null && visualCues.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Visual Evidence', style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            ...visualCues.take(2).map((cue) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('· ', style: TextStyle(color: CybersightTheme.accent, fontSize: 16, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(cue.toString(), style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12, height: 1.5))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  const _TopBar({required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  fontSize: 42,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: GoogleFonts.plusJakartaSans(color: Colors.white24, letterSpacing: 2.0, fontSize: 9, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.04),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.plusJakartaSans(color: color.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 0.98 : 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: _isHovered ? [
              BoxShadow(
                color: CybersightTheme.accent.withOpacity(0.15),
                blurRadius: 15,
                spreadRadius: 1,
              )
            ] : [],
          ),
          child: GlassContainer(
            opacity: _isHovered ? 0.08 : 0.04,
            blur: 18,
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CybersightTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CybersightTheme.accent.withOpacity(0.2)),
                  ),
                  child: Icon(widget.icon, color: CybersightTheme.accent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(widget.subtitle, style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.15), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalysisProgress extends StatelessWidget {
  final String label;
  final double progress;
  const _AnalysisProgress({required this.label, required this.progress});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white.withOpacity(0.05), color: CybersightTheme.accent, minHeight: 3),
        )
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return CybersightCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(shape: BoxShape.circle, color: CybersightTheme.warning.withOpacity(0.1)),
            child: const Icon(Icons.warning_amber_rounded, color: CybersightTheme.warning, size: 32),
          ),
          const SizedBox(height: 16),
          Text('Analysis Failed', style: GoogleFonts.plusJakartaSans(color: CybersightTheme.warning, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 20),
          GlowingButton(label: 'RETRY', onTap: onRetry, isFullWidth: true),
        ],
      ),
    );
  }
}
