import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../../core/network/api_service.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  bool _hasUpload = false;
  bool _isProcessing = false;

  Future<void> _mockUploadAndDetect() async {
    setState(() {
      _hasUpload = true;
      _isProcessing = true;
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(
              title: 'Equipment\nDetection',
              subtitle: 'UPLOAD • ANALYZE • SAVE',
              trailing: _StatusPill(
                label: _isProcessing ? 'ANALYZING' : 'READY',
                color: _isProcessing ? CybersightTheme.warning : CybersightTheme.accent,
              ),
            ),
            const SizedBox(height: 18),
            GlassContainer(
              opacity: 0.05,
              blur: 18,
              borderRadius: 24,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload a photo (not realtime)',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We’ll send it to the Python backend for detection and return labels + confidence.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60),
                  ),
                  const SizedBox(height: 18),
                  _DropZone(
                    hasUpload: _hasUpload,
                    isProcessing: _isProcessing,
                    onTap: _mockUploadAndDetect,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.photo_library_outlined,
                          title: 'Gallery',
                          subtitle: 'Pick image',
                          onTap: _mockUploadAndDetect,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.camera_alt_outlined,
                          title: 'Camera',
                          subtitle: 'Take photo',
                          onTap: _mockUploadAndDetect,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ResultPanel(isProcessing: _isProcessing, hasUpload: _hasUpload),
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final bool isProcessing;
  final bool hasUpload;
  const _ResultPanel({required this.isProcessing, required this.hasUpload});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.045,
      blur: 18,
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: CybersightTheme.accent, size: 18),
              const SizedBox(width: 10),
              Text(
                'Detection result',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (isProcessing)
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasUpload) ...[
            Text(
              'No image yet. Upload to start.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white54),
            ),
          ] else if (isProcessing) ...[
            Text(
              'Analyzing…',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60),
            ),
            const SizedBox(height: 10),
            _ConfidenceRow(label: 'Preprocessing', value: 0.85),
            _ConfidenceRow(label: 'Feature extract', value: 0.60),
            _ConfidenceRow(label: 'Inference', value: 0.25),
          ] else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _Chip(label: 'Helmet', score: 0.93),
                _Chip(label: 'Safety Vest', score: 0.88),
                _Chip(label: 'Gloves', score: 0.74),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GlowingButton(
                    label: 'Save to Inventory',
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  final String label;
  final double value;
  const _ConfidenceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white24, fontSize: 9),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: const AlwaysStoppedAnimation(CybersightTheme.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('${(value * 100).round()}%', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white38)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final double score;
  const _Chip({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [CybersightTheme.accent, CybersightTheme.accent2]),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Text(
            '${(score * 100).round()}%',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final bool hasUpload;
  final bool isProcessing;
  final VoidCallback onTap;
  const _DropZone({required this.hasUpload, required this.isProcessing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = !hasUpload
        ? 'Tap to upload'
        : (isProcessing ? 'Uploading…' : 'Image staged');
    final subtitle = !hasUpload
        ? 'PNG/JPG • up to 10MB'
        : (isProcessing ? 'Sending to backend' : 'Ready for detection');

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        height: 170,
        opacity: 0.055,
        blur: 20,
        borderRadius: 22,
        border: Border.all(color: Colors.white.withOpacity(0.09)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: (hasUpload ? CybersightTheme.accent2 : CybersightTheme.accent).withOpacity(isProcessing ? 0.12 : 0.18),
                blurRadius: 26,
                spreadRadius: -16,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle tint (keeps the glass feeling, without heavy patterns)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        CybersightTheme.navy1.withOpacity(0.20),
                        Colors.white.withOpacity(0.02),
                        CybersightTheme.navy2.withOpacity(0.18),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Accent rim
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: (hasUpload ? CybersightTheme.accent2 : CybersightTheme.accent).withOpacity(0.16),
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
              ),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassContainer(
                      width: 56,
                      height: 56,
                      opacity: 0.05,
                      blur: 22,
                      borderRadius: 999,
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
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
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white38, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        opacity: 0.04,
        blur: 18,
        borderRadius: 18,
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    colors: [
                      CybersightTheme.accent.withOpacity(0.24),
                      CybersightTheme.accent2.withOpacity(0.14),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Icon(icon, color: Colors.white70, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white38,
                            fontSize: 11,
                            letterSpacing: 0.1,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
            ],
          ),
        ),
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
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: 0.5,
                      fontSize: 42,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white24,
                      letterSpacing: 3.0,
                      fontSize: 9,
                    ),
              ),
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
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 10)],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white60,
                  fontSize: 10,
                  letterSpacing: 1.8,
                ),
          ),
        ],
      ),
    );
  }
}

