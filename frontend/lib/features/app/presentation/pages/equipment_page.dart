import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:equipment_detection_app/core/design_system/cybersight_theme.dart';
import 'package:equipment_detection_app/core/widgets/hud_widgets.dart';
import 'package:equipment_detection_app/features/app/presentation/providers/detection_provider.dart';
import 'package:equipment_detection_app/features/auth/presentation/providers/auth_provider.dart';

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
  final ImagePicker _picker = ImagePicker();

  Future<void> _showPickOptions() async {
    final provider = context.read<DetectionProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SectionTitle('Neural Input Source'),
            const SizedBox(height: 24),
            _ActionTile(
              icon: Icons.camera_alt_outlined, 
              title: 'Camera Scan', 
              subtitle: 'Capture live equipment', 
              onTap: () => _handlePick(ImageSource.camera, provider)
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.photo_library_outlined, 
              title: 'Gallery Scan', 
              subtitle: 'Select from media library', 
              onTap: () => _handlePick(ImageSource.gallery, provider)
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.video_collection_outlined, 
              title: 'Video Neural Scan', 
              subtitle: 'Extract frames from video', 
              onTap: () => _handleVideoPick(provider)
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePick(ImageSource source, DetectionProvider provider) async {
    Navigator.pop(context);
    final XFile? file = await _picker.pickImage(source: source);
    if (file == null) return;
    provider.detectEquipment(File(file.path));
  }

  Future<void> _handleVideoPick(DetectionProvider provider) async {
    Navigator.pop(context);
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    provider.detectFromVideo(File(file.path));
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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
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
            const SizedBox(height: 26),
            
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

            const SizedBox(height: 26),
            const _SectionTitle('Analysis Output'),
            const SizedBox(height: 10),

            if (isProcessing) ...[
              const _AnalysisProgress(label: 'Neural Handshake', progress: 0.4),
              const SizedBox(height: 10),
              const _AnalysisProgress(label: 'VLM Extraction', progress: 0.7),
            ] else if (detectionProvider.status == DetectionStatus.success && detectionProvider.result != null) ...[
              _IdentityCard(result: detectionProvider.result!),
              const SizedBox(height: 16),
              GlowingButton(
                label: 'SAVE TO INVENTORY',
                onTap: () async {
                  final success = await detectionProvider.saveCurrentToInventory();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(success ? 'SYNC SUCCESSFUL' : 'SYNC FAILED')),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => detectionProvider.reset(),
                  child: const Text('RESET SCANNER', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
                ),
              ),
            ] else if (detectionProvider.status == DetectionStatus.error) ...[
              _ErrorCard(message: detectionProvider.errorMessage ?? "Link Error", onRetry: () => detectionProvider.reset()),
            ] else ...[
              const _ActionTile(
                icon: Icons.auto_awesome_outlined,
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
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: isProcessing ? [
          BoxShadow(
            color: CybersightTheme.accent.withOpacity(0.2 * pulseValue),
            blurRadius: 40 * pulseValue,
            spreadRadius: 5 * pulseValue,
          )
        ] : [],
      ),
      child: GlassContainer(
        height: 200,
        opacity: 0.05,
        blur: 22,
        borderRadius: 24,
        child: Stack(
          children: [
            if (hasUpload)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(capturedFile!, fit: BoxFit.cover),
                  ),
                ),
              ),
            if (isProcessing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        CybersightTheme.accent.withOpacity(0.0),
                        CybersightTheme.accent.withOpacity(0.15 * pulseValue),
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
                    scale: isProcessing ? 1.0 + (0.1 * pulseValue) : 1.0,
                    child: GlassContainer(
                      width: 56,
                      height: 56,
                      opacity: 0.05,
                      blur: 22,
                      borderRadius: 999,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [CybersightTheme.accent, CybersightTheme.accent2]),
                          boxShadow: [
                            BoxShadow(
                              color: CybersightTheme.accent.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Icon(
                          isProcessing ? Icons.autorenew_rounded : (hasUpload ? Icons.check_rounded : Icons.cloud_upload_outlined),
                          color: Colors.black,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isProcessing ? 'PROCESSING...' : (hasUpload ? 'SCAN COMPLETE' : 'INITIATE NEURAL SCAN'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 1.2,
                      color: isProcessing ? CybersightTheme.accent : Colors.white,
                      shadows: isProcessing ? [
                        Shadow(color: CybersightTheme.accent, blurRadius: 10 * pulseValue)
                      ] : [],
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
    return CybersightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('IDENTIFIED UNIT', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text(result.vectorMatch?.item.brand.toUpperCase() ?? 'UNKNOWN', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          Text(result.vectorMatch?.item.modelName ?? 'No model data', style: const TextStyle(color: Colors.white60)),
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
              Text(title, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, fontSize: 42, height: 1.0)),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white24, letterSpacing: 3.0, fontSize: 9)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.8)),
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
            borderRadius: BorderRadius.circular(18),
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
            borderRadius: 18,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CybersightTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: CybersightTheme.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(widget.subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.1), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: const TextStyle(color: Colors.white24, letterSpacing: 3, fontSize: 9));
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
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.white24, fontSize: 8, letterSpacing: 2)),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progress, backgroundColor: Colors.white10, color: CybersightTheme.accent, minHeight: 2),
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
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: CybersightTheme.warning),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Colors.white70)),
          TextButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}
