import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:equipment_detection_app/core/design_system/cybersight_theme.dart';
import 'package:equipment_detection_app/core/widgets/hud_widgets.dart';
import 'package:equipment_detection_app/features/app/presentation/providers/detection_provider.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

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
            Text('NEURAL INPUT SOURCE', style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
            const SizedBox(height: 24),
            _PickOption(icon: Icons.camera_alt_outlined, label: 'SCAN VIA CAMERA', onTap: () => _handlePick(ImageSource.camera, provider)),
            const SizedBox(height: 12),
            _PickOption(icon: Icons.photo_library_outlined, label: 'SCAN VIA GALLERY', onTap: () => _handlePick(ImageSource.gallery, provider)),
            const SizedBox(height: 12),
            _PickOption(icon: Icons.videocam_outlined, label: 'RECORD VIDEO SCAN', onTap: () => _handlePick(ImageSource.camera, provider, isVideo: true)),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePick(ImageSource source, DetectionProvider provider, {bool isVideo = false}) async {
    Navigator.pop(context); 
    
    XFile? file;
    if (isVideo) {
      file = await _picker.pickVideo(source: source);
    } else {
      file = await _picker.pickImage(source: source);
    }

    if (file == null) return;
    provider.detectEquipment(File(file.path));
  }

  @override
  Widget build(BuildContext context) {
    final detectionProvider = context.watch<DetectionProvider>();
    final isProcessing = detectionProvider.isLoading;
    final hasUpload = detectionProvider.capturedFile != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER
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
                        'EQUIPMENT',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          fontSize: 42,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NEURAL RECOGNITION SYSTEM • V3.1',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white24,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
                GlassContainer(
                  width: 48,
                  height: 48,
                  opacity: 0.05,
                  blur: 15,
                  borderRadius: 14,
                  child: const Icon(Icons.hub_outlined, color: CybersightTheme.accent, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // 2. CIRCULAR SCANNER HUB
            Center(
              child: GestureDetector(
                onTap: isProcessing ? null : _showPickOptions,
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rotating Outer Ring
                      RotationTransition(
                        turns: _rotationController,
                        child: CustomPaint(
                          size: const Size(280, 280),
                          painter: _HUDRingPainter(color: CybersightTheme.accent.withOpacity(0.2)),
                        ),
                      ),
                      // Static Inner HUD
                      CustomPaint(
                        size: const Size(220, 220),
                        painter: _HUDRingPainter(color: Colors.white10, dashCount: 40, strokeWidth: 1),
                      ),
                      // Viewfinder Corners
                      const _HUDViewfinder(size: 200),
                      
                      // Central Sphere
                      ScaleTransition(
                        scale: Tween<double>(begin: 1.0, end: 1.05).animate(_pulseController),
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: CybersightTheme.accent.withOpacity(0.3), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: CybersightTheme.accent.withOpacity(isProcessing ? 0.3 : 0.1),
                                blurRadius: isProcessing ? 30 : 15,
                                spreadRadius: isProcessing ? 5 : 0,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Center(
                              child: hasUpload
                                  ? ClipOval(
                                      child: Image.file(
                                        detectionProvider.capturedFile!,
                                        fit: BoxFit.cover,
                                        width: 170,
                                        height: 170,
                                      ),
                                    )
                                  : Container(
                                      width: 170,
                                      height: 170,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            CybersightTheme.accent.withOpacity(0.1),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo_outlined,
                                            color: CybersightTheme.accent.withOpacity(0.5),
                                            size: 40,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'INITIATE SCAN',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: CybersightTheme.accent.withOpacity(0.7),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 3. NEURAL DATA OUTPUT
            if (isProcessing) ...[
              _MetricRow(label: 'ENCRYPTION', value: 'ECC-256V3', progress: 0.9),
              const SizedBox(height: 12),
              _MetricRow(label: 'NEURAL SYNC', value: 'SYNCING...', progress: _pulseController.value),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Text(
                      'DECODING UNIT SIGNATURE...',
                      style: GoogleFonts.plusJakartaSans(
                        color: CybersightTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RAG PIPELINE ACTIVE',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white24,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (detectionProvider.status == DetectionStatus.success && detectionProvider.result != null) ...[
              // REAL AI RESULTS PANEL
              CybersightCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('IDENTIFIED UNIT', style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 2)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: CybersightTheme.ok.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: CybersightTheme.ok.withOpacity(0.3)),
                          ),
                          child: Text(
                            '${((detectionProvider.result!.vectorMatch?.confidence ?? 0) * 100).toInt()}% CONFIDENCE',
                            style: GoogleFonts.plusJakartaSans(color: CybersightTheme.ok, fontSize: 8, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      detectionProvider.result!.vectorMatch?.item.brand.toUpperCase() ?? 'UNKNOWN BRAND',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      detectionProvider.result!.vectorMatch?.item.modelName ?? 'Model: Not Identified',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _ResultMeta(label: 'CAPACITY', value: '${detectionProvider.result!.vectorMatch?.item.btu ?? "???"} BTU'),
                        const SizedBox(width: 24),
                        _ResultMeta(label: 'SERIAL', value: detectionProvider.result!.vectorMatch?.item.normalizedReference ?? 'GENERIC'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GlowingButton(
                label: 'SAVE TO INVENTORY',
                onTap: () async {
                  final success = await detectionProvider.saveCurrentToInventory();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: success ? CybersightTheme.ok : CybersightTheme.warning,
                        content: Text(
                          success ? 'DATABASE SYNC SUCCESSFUL' : 'SYNC FAILED - CHECK LINK',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2),
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => detectionProvider.reset(),
                child: Center(
                  child: Text(
                    'RESET SCANNER',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
              ),
            ] else if (detectionProvider.status == DetectionStatus.error) ...[
              // ERROR PANEL
              CybersightCard(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: CybersightTheme.warning, size: 32),
                    const SizedBox(height: 16),
                    Text(
                      'NEURAL LINK INTERRUPTED',
                      style: GoogleFonts.plusJakartaSans(color: CybersightTheme.warning, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      detectionProvider.errorMessage ?? 'Unexpected server error.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => detectionProvider.reset(),
                      child: Text('TRY AGAIN', style: GoogleFonts.plusJakartaSans(color: CybersightTheme.accent, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // IDLE PANEL
              const _MetricRow(label: 'ENCRYPTION', value: 'WAITING...', progress: 0),
              const SizedBox(height: 12),
              const _MetricRow(label: 'NEURAL SYNC', value: 'DISCONNECTED', progress: 0),
            ],
          ],
        ),
      ),
    );
  }
}

// UI HELPERS (KEEPING EXISTING STYLES)

class _PickOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          opacity: 0.05,
          child: Row(
            children: [
              Icon(icon, color: CybersightTheme.accent, size: 24),
              const SizedBox(width: 20),
              Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultMeta extends StatelessWidget {
  final String label;
  final String value;
  const _ResultMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 7, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  const _MetricRow({required this.label, required this.value, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 2)),
            Text(value, style: GoogleFonts.plusJakartaSans(color: CybersightTheme.accent.withOpacity(0.8), fontWeight: FontWeight.w900, fontSize: 9)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(height: 2, width: double.infinity, color: Colors.white.withOpacity(0.05)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 2,
              width: MediaQuery.of(context).size.width * 0.9 * progress,
              decoration: BoxDecoration(
                color: CybersightTheme.accent,
                boxShadow: [BoxShadow(color: CybersightTheme.accent.withOpacity(0.5), blurRadius: 4)],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HUDRingPainter extends CustomPainter {
  final Color color;
  final int dashCount;
  final double strokeWidth;
  _HUDRingPainter({required this.color, this.dashCount = 60, this.strokeWidth = 2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const dashWidth = 2 * 3.14159 / 100;
    for (int i = 0; i < dashCount; i++) {
      if (i % 5 == 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * (2 * 3.14159 / dashCount),
        dashWidth,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HUDViewfinder extends StatelessWidget {
  final double size;
  const _HUDViewfinder({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(top: 0, left: 0, child: _HUDCorner(angle: 0)),
          Positioned(top: 0, right: 0, child: _HUDCorner(angle: 1.5708)),
          Positioned(bottom: 0, left: 0, child: _HUDCorner(angle: 4.7124)),
          Positioned(bottom: 0, right: 0, child: _HUDCorner(angle: 3.14159)),
        ],
      ),
    );
  }
}

class _HUDCorner extends StatelessWidget {
  final double angle;
  const _HUDCorner({required this.angle});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: CybersightTheme.accent.withOpacity(0.5), width: 3),
            left: BorderSide(color: CybersightTheme.accent.withOpacity(0.5), width: 3),
          ),
        ),
      ),
    );
  }
}
