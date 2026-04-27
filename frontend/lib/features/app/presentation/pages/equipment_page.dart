import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:image_picker/image_picker.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> with TickerProviderStateMixin {
  bool _hasUpload = false;
  bool _isProcessing = false;
  File? _selectedFile;
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
            _PickOption(icon: Icons.camera_alt_outlined, label: 'SCAN VIA CAMERA', onTap: () => _handlePick(ImageSource.camera)),
            const SizedBox(height: 12),
            _PickOption(icon: Icons.photo_library_outlined, label: 'SCAN VIA GALLERY', onTap: () => _handlePick(ImageSource.gallery)),
            const SizedBox(height: 12),
            _PickOption(icon: Icons.videocam_outlined, label: 'RECORD VIDEO SCAN', onTap: () => _handlePick(ImageSource.camera, isVideo: true)),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePick(ImageSource source, {bool isVideo = false}) async {
    Navigator.pop(context); // Close bottom sheet
    
    XFile? file;
    if (isVideo) {
      file = await _picker.pickVideo(source: source);
    } else {
      file = await _picker.pickImage(source: source);
    }

    if (file == null) return;

    setState(() {
      _selectedFile = File(file!.path);
      _hasUpload = true;
      _isProcessing = true;
    });

    // Mock processing for now as requested
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => _isProcessing = false);
  }

  Future<void> _mockUploadAndDetect() async {
    _showPickOptions();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. DYNAMIC CYBER HEADER
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
                          fontSize: 32,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NEURAL DETECTION CORE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white24,
                        letterSpacing: 2.8,
                      ),
                    ),
                  ],
                ),
                _StatusPill(
                  label: _isProcessing ? 'SCANNING' : 'ONLINE',
                  color: _isProcessing ? CybersightTheme.warning : CybersightTheme.ok,
                ),
              ],
            ),
            
            const SizedBox(height: 32),

            // 2. HOLOGRAPHIC SCANNER ZONE
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating HUD Rings
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationController.value * 2 * math.pi,
                        child: CustomPaint(
                          size: const Size(260, 260),
                          painter: _ScannerRingsPainter(
                            color: _isProcessing ? CybersightTheme.warning : CybersightTheme.accent,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Central Interaction Sphere
                  GestureDetector(
                    onTap: _mockUploadAndDetect,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final glow = _pulseController.value * 15.0;
                        return Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                            boxShadow: [
                              BoxShadow(
                                color: (_isProcessing ? CybersightTheme.warning : CybersightTheme.accent).withOpacity(0.15),
                                blurRadius: 20 + glow,
                                spreadRadius: -2,
                              ),
                            ],
                            border: Border.all(
                              color: (_isProcessing ? CybersightTheme.warning : CybersightTheme.accent).withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_selectedFile != null)
                                  Positioned.fill(
                                    child: Image.file(
                                      _selectedFile!,
                                      fit: BoxFit.cover,
                                      color: _isProcessing ? Colors.black.withOpacity(0.5) : null,
                                      colorBlendMode: BlendMode.darken,
                                    ),
                                  ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isProcessing ? Icons.radar_rounded : Icons.camera_rounded,
                                      color: _isProcessing ? CybersightTheme.warning : CybersightTheme.accent,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _isProcessing ? 'DECODING' : 'INITIATE',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white70,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 3. ACTION CONTROLS
            Row(
              children: [
                Expanded(
                  child: _NeuralActionBtn(
                    icon: Icons.photo_library_outlined,
                    label: 'SOURCE LIBRARY',
                    onTap: _mockUploadAndDetect,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _NeuralActionBtn(
                    icon: Icons.videocam_outlined,
                    label: 'LIVE UPLINK',
                    onTap: _mockUploadAndDetect,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 4. ANALYTICS CARD
            _AnalyticsPanel(isProcessing: _isProcessing, hasUpload: _hasUpload),
          ],
        ),
      ),
    );
  }
}

class _ScannerRingsPainter extends CustomPainter {
  final Color color;
  _ScannerRingsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withOpacity(0.2);

    // Outer faint ring
    canvas.drawCircle(center, size.width / 2, paint);
    
    // Segmented ring
    paint.color = color.withOpacity(0.5);
    paint.strokeWidth = 2.5;
    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: size.width / 2 - 10),
        (i * math.pi / 2) + 0.2,
        0.8,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _NeuralActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NeuralActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        height: 60,
        opacity: 0.05,
        blur: 15,
        borderRadius: 14,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: CybersightTheme.accent, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white38,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  final bool isProcessing;
  final bool hasUpload;
  const _AnalyticsPanel({required this.isProcessing, required this.hasUpload});

  @override
  Widget build(BuildContext context) {
    return CybersightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: CybersightTheme.accent, size: 14),
              const SizedBox(width: 10),
              Text(
                'NEURAL ANALYTICS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white38,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!hasUpload)
            Text(
              'WAITING FOR DATA...',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white12, fontWeight: FontWeight.bold, letterSpacing: 2),
            )
          else if (isProcessing)
            const Column(
              children: [
                _MiniMetric(label: 'SCANNING FREQUENCY', value: 0.7),
                _MiniMetric(label: 'NEURAL MAPPING', value: 0.4),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'BIOLUX 12000 BTU',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18),
                ),
                Text('MODEL: BLX-SHARP-X1', style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                GlowingButton(
                  label: 'Commit Data',
                  onTap: () {},
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final double value;
  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white24, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value,
            minHeight: 2,
            backgroundColor: Colors.white.withOpacity(0.03),
            valueColor: const AlwaysStoppedAnimation(CybersightTheme.accent),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.2)),
        color: color.withOpacity(0.05),
      ),
      child: Row(
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 4)]),
          ),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

class _PickOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: CybersightTheme.accent, size: 22),
            const SizedBox(width: 16),
            Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}
