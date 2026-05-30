import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_service.dart';
import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';

import 'equipment_detail_page.dart';
import '../../data/models/detection_result_model.dart';

class ScanLabPage extends StatefulWidget {
  const ScanLabPage({super.key});

  @override
  State<ScanLabPage> createState() => _ScanLabPageState();
}

class _ScanLabPageState extends State<ScanLabPage> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _isExtracting = false;
  bool _isProcessingAI = false;
  String? _sessionId;
  List<Map<String, dynamic>> _frames = [];
  Set<String> _selectedFilenames = {};

  Future<void> _pickAndProcessVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    setState(() {
      _isExtracting = true;
      _frames = [];
      _selectedFilenames = {};
    });

    try {
      final res = await _apiService.processVideoScript(File(video.path));
      if (res['success'] == true && res['frames'] != null) {
        setState(() {
          _frames = List<Map<String, dynamic>>.from(res['frames']);
          _sessionId = res['session_id'];
          _selectedFilenames = _frames
              .where((f) => f['is_hero'] == true)
              .map((f) => f['filename'] as String)
              .toSet();
          _isExtracting = false;
        });
        if (_selectedFilenames.isNotEmpty) {
          Future.microtask(() async {
            await _runAIOnSelected();
          });
        }
      } else {
        final err = res['error']?.toString() ?? 'Unknown error';
        final hint = res['hint']?.toString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hint != null ? '$err\n$hint' : err,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: Colors.white),
              ),
              backgroundColor:
                  CybersightTheme.warning.withValues(alpha: 0.9),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extraction error: $e'),
            backgroundColor: CybersightTheme.warning,
          ),
        );
      }
    } finally {
      setState(() => _isExtracting = false);
    }
  }

  Future<void> _runAIOnSelected() async {
    if (_selectedFilenames.isEmpty || _sessionId == null) return;

    setState(() => _isProcessingAI = true);
    try {
      final total = _selectedFilenames.length;
      int processedCount = 0;
      final List<Map<String, dynamic>> allDetections = [];

      for (final filename in List<String>.from(_selectedFilenames)) {
        processedCount++;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PROCESSING $filename ($processedCount/$total)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: CybersightTheme.accent,
                ),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: CybersightTheme.navy2.withValues(alpha: 0.9),
            ),
          );
        }
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black54,
            builder: (_) => const Center(
              child: CircularProgressIndicator(
                  color: CybersightTheme.accent),
            ),
          );
        }

        final result = await _apiService.processSelectedFrames(
          _sessionId!,
          [filename],
        );

        if (result != null && result['success'] == true) {
          final List<dynamic> processedFrames = result['frames'];
          for (var pf in processedFrames) {
            final idx =
                _frames.indexWhere((f) => f['filename'] == pf['filename']);
            if (idx != -1) {
              setState(() => _frames[idx] = pf);
              if (pf['has_ai'] == true && pf['forensic_data'] != null) {
                final brand =
                    pf['forensic_data']['brand']?.toString();
                if (brand != null && brand.toLowerCase() != 'unknown') {
                  allDetections.add(pf);
                }
              }
            }
          }
        }

        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }

      setState(() => _selectedFilenames.clear());

      if (allDetections.isNotEmpty && mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => FractionallySizedBox(
            heightFactor: 0.85,
            child: _VerificationCarouselSheet(detections: allDetections),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ANALYSIS COMPLETE — ${allDetections.length} equipment detected.',
              style:
                  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            ),
            backgroundColor: CybersightTheme.ok.withValues(alpha: 0.9),
          ),
        );
      }
    } finally {
      setState(() => _isProcessingAI = false);
    }
  }

  Future<void> _showFrameDetails(Map<String, dynamic> frame) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Frame Details',
                style: GoogleFonts.plusJakartaSans(
                  color: CybersightTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ID: ${frame['filename'] ?? 'unknown'}',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 24),
              GlowingButton(
                label: 'Close',
                onTap: () => Navigator.of(ctx).pop(),
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CybersightAtmosphere(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(),
            Expanded(
              child: _frames.isEmpty
                  ? _buildEmptyState()
                  : _buildFrameGrid(),
            ),
            if (_selectedFilenames.isNotEmpty) _buildActionBar(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final frameCount = _frames.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white70,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan Lab',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  frameCount > 0
                      ? '$frameCount FRAMES EXTRACTED'
                      : 'UPLOAD · EXTRACT · IDENTIFY',
                  style: GoogleFonts.plusJakartaSans(
                    color: frameCount > 0
                        ? CybersightTheme.accent.withValues(alpha: 0.7)
                        : Colors.white24,
                    letterSpacing: 1.8,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Upload button (visible when frames exist, for re-upload)
          if (_frames.isNotEmpty && !_isExtracting)
            GestureDetector(
              onTap: _pickAndProcessVideo,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: CybersightTheme.accent.withValues(alpha: 0.1),
                  border: Border.all(
                    color: CybersightTheme.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.video_library_rounded,
                        color: CybersightTheme.accent, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'Reupload',
                      style: GoogleFonts.plusJakartaSans(
                        color: CybersightTheme.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_isExtracting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: CybersightTheme.accent,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    if (_isExtracting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    color: CybersightTheme.accent.withValues(alpha: 0.08),
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    color: CybersightTheme.accent.withValues(alpha: 0.35),
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    color: CybersightTheme.accent,
                    strokeWidth: 3,
                  ),
                ),
                const Icon(Icons.memory_rounded,
                    size: 22, color: CybersightTheme.accent),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              'Extracting Frames',
              style: GoogleFonts.plusJakartaSans(
                color: CybersightTheme.accent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Deconstructing video into key signatures...',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Isolating equipment hardware frames...',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
      );
    }

    // Upload zone
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        children: [
          // Main upload card
          Expanded(
            child: _UploadZoneCard(onTap: _pickAndProcessVideo),
          ),
          const SizedBox(height: 20),

          // Info chips row
          Row(
            children: [
              _InfoChip(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Auto hero frame selection'),
              const SizedBox(width: 10),
              _InfoChip(
                  icon: Icons.verified_rounded,
                  label: 'AI equipment detection'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Frame grid ───────────────────────────────────────────────────────────

  Widget _buildFrameGrid() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemCount: _frames.length,
            itemBuilder: (context, index) {
              final frame = _frames[index];
              final filename = frame['filename'];
              final isSelected = _selectedFilenames.contains(filename);
              final hasAi = frame['has_ai'] == true;
              final aiImage = frame['ai_image'];

              return GestureDetector(
                onTap: () {
                  if (_isProcessingAI) return;
                  if (hasAi && frame['forensic_data'] != null) {
                    _showFrameDetails(frame);
                  } else {
                    setState(() {
                      if (isSelected) {
                        _selectedFilenames.remove(filename);
                      } else {
                        _selectedFilenames.add(filename);
                      }
                    });
                    Future.microtask(() async {
                      if (mounted && _selectedFilenames.isNotEmpty) {
                        await _runAIOnSelected();
                      }
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? CybersightTheme.accent
                          : Colors.white.withValues(alpha: 0.06),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: CybersightTheme.accent
                                  .withValues(alpha: 0.22),
                              blurRadius: 16,
                            )
                          ]
                        : [],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Frame image
                      Builder(builder: (_) {
                        final rawImg = aiImage ?? frame['image'];
                        if (rawImg == null) {
                          return Container(
                            color: CybersightTheme.navy2,
                            child: const Center(
                              child: Icon(
                                  Icons.image_not_supported_rounded,
                                  color: Colors.white24,
                                  size: 30),
                            ),
                          );
                        }
                        return Image.memory(
                          base64Decode(rawImg as String),
                          fit: BoxFit.cover,
                        );
                      }),

                      // Top/bottom gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),

                      // Viewfinder corners
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ViewfinderCornersPainter(
                            color: isSelected
                                ? CybersightTheme.accent
                                : Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),

                      // Hero badge
                      if (frame['is_hero'] == true)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: CybersightTheme.warning
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: CybersightTheme.warning,
                                  width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: CybersightTheme.warning
                                      .withValues(alpha: 0.3),
                                  blurRadius: 6,
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: CybersightTheme.warning),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'HERO',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // AI decrypted overlay
                      if (hasAi)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          left: 10,
                          child: GlassContainer(
                            opacity: 0.15,
                            blur: 14,
                            borderRadius: 12,
                            padding: const EdgeInsets.all(6),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: CybersightTheme.ok
                                        .withValues(alpha: 0.3),
                                    width: 1.0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      _BlinkingDot(
                                          color: CybersightTheme.ok),
                                      const SizedBox(width: 6),
                                      Text(
                                        'DECRYPTED',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: CybersightTheme.ok,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'TAP FOR INFO',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white38,
                                      fontSize: 7,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Selected checkmark
                      if (isSelected && !hasAi)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: CybersightTheme.accent,
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.black, size: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Action bar ───────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: CybersightTheme.navy2.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
              color: CybersightTheme.accent.withValues(alpha: 0.15)),
        ),
      ),
      child: GlowingButton(
        label: _isProcessingAI
            ? 'Processing...'
            : 'Analyze ${_selectedFilenames.length} Frame${_selectedFilenames.length != 1 ? 's' : ''}',
        onTap: _isProcessingAI ? () {} : _runAIOnSelected,
        isFullWidth: true,
      ),
    );
  }
}

// ── Upload zone card ───────────────────────────────────────────────────────

class _UploadZoneCard extends StatefulWidget {
  final VoidCallback onTap;
  const _UploadZoneCard({required this.onTap});

  @override
  State<_UploadZoneCard> createState() => _UploadZoneCardState();
}

class _UploadZoneCardState extends State<_UploadZoneCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        // Gradient border wrapper
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              CybersightTheme.accent.withValues(alpha: 0.5),
              CybersightTheme.accent2.withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: GlassContainer(
          borderRadius: 27,
          opacity: 0.04,
          blur: 20,
          border: Border.all(color: Colors.transparent),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
            ),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing icon
                  Transform.scale(
                    scale: _pressed ? 0.92 : _pulse.value,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CybersightTheme.accent
                            .withValues(alpha: 0.08),
                        border: Border.all(
                          color: CybersightTheme.accent.withValues(
                              alpha: 0.3 + 0.2 * _pulse.value),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CybersightTheme.accent.withValues(
                                alpha: 0.15 * _pulse.value),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.video_library_rounded,
                        color: CybersightTheme.accent,
                        size: 36,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'Upload a Video',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pick a saved video from your gallery.\nKey frames are extracted automatically.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.55,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Tap indicator pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [
                          CybersightTheme.accent,
                          CybersightTheme.accent2
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CybersightTheme.accent.withValues(
                              alpha: 0.35 * _pulse.value),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Choose from Gallery',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.black, size: 17),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

// ── Info chip ──────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.03),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: CybersightTheme.accent.withValues(alpha: 0.7),
                size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Verification carousel sheet ────────────────────────────────────────────

class _VerificationCarouselSheet extends StatefulWidget {
  final List<Map<String, dynamic>> detections;
  const _VerificationCarouselSheet({required this.detections});

  @override
  State<_VerificationCarouselSheet> createState() =>
      _VerificationCarouselSheetState();
}

class _VerificationCarouselSheetState
    extends State<_VerificationCarouselSheet> {
  final ApiService _apiService = ApiService();
  final PageController _pageController =
      PageController(viewportFraction: 0.9);
  int _currentIndex = 0;
  bool _isFetchingSpecs = false;
  String _fetchingLabel = '';

  Future<void> _fetchSpecs(
      String brand, String modelName, String type) async {
    setState(() {
      _isFetchingSpecs = true;
      _fetchingLabel = '$brand $modelName';
    });

    try {
      final specRes = await _apiService.getSpecs(brand, modelName, type);
      if (mounted) {
        Navigator.of(context).pop();
        if (specRes['equipment_result'] != null) {
          final equipmentResult =
              EquipmentResult.fromJson(specRes['equipment_result']);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => FractionallySizedBox(
              heightFactor: 0.85,
              child: EquipmentDetailPage(result: equipmentResult),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingSpecs = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error fetching specs: $e'),
              backgroundColor: CybersightTheme.warning),
        );
      }
    }
  }

  IconData _getEquipmentIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('air') || t.contains('climat')) return Icons.ac_unit_rounded;
    if (t.contains('ref') || t.contains('fridge')) return Icons.kitchen_rounded;
    if (t.contains('micro')) return Icons.microwave_rounded;
    if (t.contains('laptop') || t.contains('computer')) return Icons.laptop_rounded;
    if (t.contains('monitor') || t.contains('tv') || t.contains('screen')) return Icons.monitor_rounded;
    return Icons.memory_rounded;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingSpecs) {
      return Container(
        decoration: BoxDecoration(
          color: CybersightTheme.navy2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
              top: BorderSide(
                  color: CybersightTheme.accent.withValues(alpha: 0.2))),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: CybersightTheme.accent),
              const SizedBox(height: 24),
              Text(
                'EXTRACTING TELEMETRY',
                style: GoogleFonts.plusJakartaSans(
                  color: CybersightTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _fetchingLabel,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Querying global technical databases...',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: CybersightTheme.navy2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
            top: BorderSide(
                color: CybersightTheme.accent.withValues(alpha: 0.2))),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CybersightTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.verified_user_rounded,
                      color: CybersightTheme.accent, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VERIFICATION REQUIRED',
                      style: GoogleFonts.plusJakartaSans(
                        color: CybersightTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${widget.detections.length} Device${widget.detections.length > 1 ? "s" : ""} Pending',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemCount: widget.detections.length,
              itemBuilder: (context, index) {
                return _VerificationCard(
                  detection: widget.detections[index],
                  icon: _getEquipmentIcon(
                    widget.detections[index]['forensic_data']
                            ?['equipment_category']
                            ?.toString() ??
                        '',
                  ),
                  onVerify: (brand, model, type) =>
                      _fetchSpecs(brand, model, type),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (widget.detections.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.detections.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? CybersightTheme.accent
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Verification card ──────────────────────────────────────────────────────

class _VerificationCard extends StatefulWidget {
  final Map<String, dynamic> detection;
  final IconData icon;
  final Function(String brand, String model, String type) onVerify;

  const _VerificationCard(
      {required this.detection,
      required this.icon,
      required this.onVerify});

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard> {
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _typeController;
  late TextEditingController _colorController;

  // Common color keywords to scan in visual_cues
  static const _colorWords = [
    'white', 'black', 'silver', 'grey', 'gray', 'red', 'blue', 'green',
    'yellow', 'orange', 'brown', 'beige', 'cream', 'gold', 'rose gold',
    'graphite', 'platinum', 'charcoal', 'navy', 'teal', 'purple', 'pink',
    'metallic', 'stainless', 'space gray', 'dark', 'light',
  ];

  String _extractColor(Map<dynamic, dynamic> forensic) {
    // 1. Direct fields
    final direct = forensic['color'] ??
        forensic['dominant_color'] ??
        forensic['primary_color'] ??
        forensic['colour'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    // 2. Mine from visual_cues
    final cues = (forensic['visual_cues'] as List? ?? []);
    for (final cue in cues) {
      final lower = cue.toString().toLowerCase();
      for (final kw in _colorWords) {
        if (lower.contains(kw)) {
          return kw[0].toUpperCase() + kw.substring(1);
        }
      }
    }
    return '';
  }

  String _extractType(Map<dynamic, dynamic> forensic) {
    // Try every known field name the backend might use
    final raw = forensic['equipment_category'] ??
        forensic['equipment_type'] ??
        forensic['category'] ??
        forensic['type'] ??
        forensic['device_type'];
    if (raw != null && raw.toString().trim().isNotEmpty) {
      // Capitalise first letter, lowercase rest (e.g. "laptop", "MICROWAVE" → "Laptop", "Microwave")
      final s = raw.toString().trim();
      return s[0].toUpperCase() + s.substring(1).toLowerCase();
    }
    // Last resort: scan visual_cues for equipment-type keywords
    const typeWords = [
      'laptop', 'computer', 'microwave', 'refrigerator', 'fridge',
      'air conditioner', 'monitor', 'screen', 'tv', 'television',
      'printer', 'scanner', 'tablet', 'phone', 'oven', 'dishwasher',
      'washing machine', 'dryer', 'fan', 'heater', 'router',
    ];
    final cues = (forensic['visual_cues'] as List? ?? []);
    for (final cue in cues) {
      final lower = cue.toString().toLowerCase();
      for (final kw in typeWords) {
        if (lower.contains(kw)) {
          return kw[0].toUpperCase() + kw.substring(1);
        }
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    final forensic =
        Map<dynamic, dynamic>.from(widget.detection['forensic_data'] ?? {});
    final candidates = forensic['model_candidates'] as List? ?? [];
    final topCandidate =
        candidates.isNotEmpty ? candidates.first as Map : <dynamic, dynamic>{};

    _typeController = TextEditingController(text: _extractType(forensic));
    _brandController = TextEditingController(
        text: forensic['brand']?.toString().trim() ?? '');
    _modelController = TextEditingController(
        text: topCandidate['model']?.toString().trim() ?? '');
    _colorController = TextEditingController(text: _extractColor(forensic));
  }

  @override
  void dispose() {
    _typeController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiImage =
        widget.detection['ai_image'] ?? widget.detection['image'];
    final displayType = _typeController.text.trim().isNotEmpty
        ? _typeController.text.trim().toUpperCase()
        : 'EQUIPMENT';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 180,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (aiImage != null)
                    Image.memory(
                        base64Decode(aiImage as String),
                        fit: BoxFit.cover)
                  else
                    const Center(
                        child: Icon(Icons.image_not_supported_rounded,
                            color: Colors.white24, size: 48)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          CybersightTheme.navy2.withValues(alpha: 0.9)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Row(
                      children: [
                        Icon(widget.icon,
                            color: CybersightTheme.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          displayType,
                          style: GoogleFonts.plusJakartaSans(
                            color: CybersightTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Extracted Data',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    'EQUIPMENT TYPE',
                    _typeController,
                    hint: 'e.g. Laptop, Microwave, Refrigerator…',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _buildInputField(
                    'BRAND',
                    _brandController,
                    hint: 'e.g. Samsung, LG, Dell…',
                  ),
                  const SizedBox(height: 14),
                  _buildInputField(
                    'MODEL REFERENCE',
                    _modelController,
                    hint: 'e.g. Galaxy Book Pro 360…',
                  ),
                  const SizedBox(height: 14),
                  _buildInputField(
                    'COLOR',
                    _colorController,
                    hint: 'e.g. White, Black, Silver…',
                  ),
                  const SizedBox(height: 24),
                  GlowingButton(
                    label: 'Verify & Fetch Specs',
                    isFullWidth: true,
                    onTap: () {
                      widget.onVerify(
                        _brandController.text.trim(),
                        _modelController.text.trim(),
                        _typeController.text.trim(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    String? hint,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: CybersightTheme.accent,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.3),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: Colors.white24,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: CybersightTheme.accent),
            ),
            suffixIcon: const Icon(Icons.edit_rounded,
                color: Colors.white30, size: 15),
          ),
        ),
      ],
    );
  }
}

// ── Viewfinder corners painter ─────────────────────────────────────────────

class _ViewfinderCornersPainter extends CustomPainter {
  final Color color;
  _ViewfinderCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double len = 10.0;
    const double pad = 8.0;

    canvas.drawPath(
      Path()
        ..moveTo(pad + len, pad)
        ..lineTo(pad, pad)
        ..lineTo(pad, pad + len),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad - len, pad)
        ..lineTo(size.width - pad, pad)
        ..lineTo(size.width - pad, pad + len),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(pad + len, size.height - pad)
        ..lineTo(pad, size.height - pad)
        ..lineTo(pad, size.height - pad - len),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad - len, size.height - pad)
        ..lineTo(size.width - pad, size.height - pad)
        ..lineTo(size.width - pad, size.height - pad - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Blinking dot ───────────────────────────────────────────────────────────

class _BlinkingDot extends StatefulWidget {
  final Color color;
  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Opacity(
        opacity: _controller.value,
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                  color: widget.color, blurRadius: 4, spreadRadius: 1)
            ],
          ),
        ),
      ),
    );
  }
}
