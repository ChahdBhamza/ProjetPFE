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

class _EquipmentPageState extends State<EquipmentPage> {
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
              child: _ScannerHub(
                isProcessing: isProcessing,
                hasUpload: hasUpload,
                capturedFile: detectionProvider.capturedFile,
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

  const _ScannerHub({required this.isProcessing, required this.hasUpload, this.capturedFile});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlassContainer(
                  width: 56,
                  height: 56,
                  opacity: 0.05,
                  blur: 22,
                  borderRadius: 999,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [CybersightTheme.accent, CybersightTheme.accent2]),
                    ),
                    child: Icon(
                      isProcessing ? Icons.autorenew_rounded : (hasUpload ? Icons.check_rounded : Icons.cloud_upload_outlined),
                      color: Colors.black,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isProcessing ? 'PROCESSING...' : (hasUpload ? 'SCAN COMPLETE' : 'INITIATE NEURAL SCAN'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ],
            ),
          ),
        ],
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        opacity: 0.04,
        borderRadius: 18,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: CybersightTheme.accent, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
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
