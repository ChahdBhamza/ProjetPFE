import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
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
  int _aiProgress = 0;
  int _aiTotal = 0;
  String _aiLabel = '';
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
          // Show frames for 2 seconds before analyzing
          Future.delayed(const Duration(seconds: 2), () async {
            if (mounted) {
              await _runAIOnSelected();
            }
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

    final queue = List<String>.from(_selectedFilenames);
    setState(() {
      _isProcessingAI = true;
      _aiTotal = queue.length;
      _aiProgress = 0;
      _aiLabel = 'Detecting brand & model...';
    });

    try {
      final List<Map<String, dynamic>> detectedFrames = [];

      // STEP 1: Detect brand + model for all frames
      for (final filename in queue) {
        final frameMeta = _frames.firstWhere(
          (f) => f['filename'] == filename,
          orElse: () => <String, dynamic>{},
        );
        setState(() {
          _aiProgress += 1;
          _aiLabel = 'Detecting: ${(frameMeta['detected_class'] as String?)?.trim() ?? 'Equipment'}';
        });

        final result = await _apiService.processSelectedFrames(
          _sessionId!,
          [filename],
        );

        if (result != null && result['success'] == true) {
          final List<dynamic> processedFrames = result['frames'];
          for (var pf in processedFrames) {
            final idx = _frames.indexWhere((f) => f['filename'] == pf['filename']);
            if (idx != -1) {
              setState(() => _frames[idx] = pf);
            }
            if (pf['has_ai'] == true && pf['forensic_data'] != null) {
              detectedFrames.add(pf);
            }
          }
        }
      }

      if (mounted) setState(() => _isProcessingAI = false);

      // STEP 2: Show verification dialog
      if (detectedFrames.isNotEmpty && mounted) {
        await _showVerificationDialog(detectedFrames);
      }
    } finally {
      if (mounted) setState(() => _isProcessingAI = false);
    }
  }

  Future<void> _showVerificationDialog(List<Map<String, dynamic>> detectedFrames) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 24,
          opacity: 0.15,
          blur: 30,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '✓ Detection Complete',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...detectedFrames.asMap().entries.map<Widget>((entry) {
                final frame = entry.value;
                final brand = frame['equipment_result']?['identity']?['brand'] ?? 'Unknown';
                final model = frame['equipment_result']?['identity']?['top_model'] ?? 'Unknown';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: CybersightTheme.accent.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                brand,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                model,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GlowingButton(
                      label: 'Verify & Get Specs',
                      onTap: () {
                        Navigator.pop(ctx);
                        _fetchSpecsForFrames(detectedFrames);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchSpecsForFrames(List<Map<String, dynamic>> detectedFrames) async {
    setState(() {
      _isProcessingAI = true;
      _aiLabel = 'Fetching specifications...';
    });

    try {
      // STEP 3: Fetch specs for verified frames
      for (var frame in detectedFrames) {
        final equipResult = frame['equipment_result'];
        if (equipResult != null) {
          final brand = equipResult['identity']?['brand'] ?? 'Unknown';
          final model = equipResult['identity']?['top_model'] ?? 'Unknown';
          final category = equipResult['identity']?['equipment_category'] ?? 'unknown';

          // Call spec service
          final specsResult = await _apiService.getSpecs(
            brand,
            model,
            category,
          );

          if (specsResult['success'] == true) {
            // Update frame with full specs
            final frameIdx = _frames.indexWhere((f) => f['filename'] == frame['filename']);
            if (frameIdx != -1) {
              setState(() {
                _frames[frameIdx]['specs'] = specsResult;
                _frames[frameIdx]['equipment_result'] = specsResult['equipment_result'];
              });
            }
          }
        }
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/detection-success', (_) => false);
      }
    } finally {
      if (mounted) setState(() => _isProcessingAI = false);
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
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  height: 44,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Close',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
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
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                Expanded(
                  child: _frames.isEmpty
                      ? _buildEmptyState()
                      : _buildFrameGrid(),
                ),
                if (_selectedFilenames.isNotEmpty && !_isProcessingAI)
                  _buildActionBar(),
              ],
            ),
            if (_isProcessingAI)
              _AiAnalysisOverlay(
                progress: _aiProgress,
                total: _aiTotal,
                label: _aiLabel,
              ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final frameCount = _frames.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white54, size: 14),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan Lab',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  frameCount > 0
                      ? '$frameCount frames extracted'
                      : 'Upload · Extract · Identify',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (_frames.isNotEmpty && !_isExtracting)
            GestureDetector(
              onTap: _pickAndProcessVideo,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, color: Colors.white30, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      'New video',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white30,
                        fontWeight: FontWeight.w400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: GlassContainer(
            opacity: 0.08,
            blur: 20,
            borderRadius: 28,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: CybersightTheme.accent.withValues(alpha: 0.14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: CybersightTheme.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LIVE PROCESSING',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Processing your video',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Uploading, extracting key frames and scanning for equipment.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                const _ProcessingStages(
                  stages: [
                    _Stage('Uploading video', 'Securing your footage', 2800),
                    _Stage('Extracting key frames', 'Sampling the timeline', 7000),
                    _Stage('Scanning with AI vision', 'Detecting equipment', 16000),
                    _Stage('Selecting best shots', 'Ranking sharpest frames', 0),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.cloud_upload_rounded,
                          color: CybersightTheme.accent, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your video is being analyzed securely in the background.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
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
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.50),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.40, 1.0],
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
                                        'Identified',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: CybersightTheme.ok,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Tap to view',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white38,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w400,
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: CybersightTheme.navy2.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: GestureDetector(
        onTap: _isProcessingAI ? null : _runAIOnSelected,
        child: Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF0E1E3A),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Center(
            child: _isProcessingAI
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white30,
                          strokeWidth: 1.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Processing...',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Analyze ${_selectedFilenames.length} Frame${_selectedFilenames.length != 1 ? 's' : ''}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white38, size: 15),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Upload zone card ───────────────────────────────────────────────────────

class _UploadZoneCard extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadZoneCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F2A52),
              const Color(0xFF0A1535),
              const Color(0xFF06101F),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.45, 1.0],
          ),
          border: Border.all(
            color: CybersightTheme.accent.withValues(alpha: 0.20),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CybersightTheme.accent.withValues(alpha: 0.07),
                    border: Border.all(
                      color: CybersightTheme.accent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Icon(Icons.video_library_rounded,
                      color: CybersightTheme.accent, size: 30),
                ),
                const SizedBox(height: 24),
                Text(
                  'Upload a Video',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Pick any saved video from your gallery.\nKey frames are extracted automatically.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white38,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: CybersightTheme.accent.withValues(alpha: 0.09),
                    border: Border.all(
                      color: CybersightTheme.accent.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Choose from Gallery',
                        style: GoogleFonts.plusJakartaSans(
                          color: CybersightTheme.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: CybersightTheme.accent, size: 16),
                    ],
                  ),
                ),
              ],
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
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withValues(alpha: 0.02),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white24, size: 13),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
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
  late List<Map<String, String>> _cardValues;

  @override
  void initState() {
    super.initState();
    _cardValues = widget.detections.map(_defaultValues).toList();
  }

  Map<String, String> _defaultValues(Map<String, dynamic> detection) {
    final f = Map<dynamic, dynamic>.from(detection['forensic_data'] ?? {});
    final candidates = f['model_candidates'] as List? ?? [];
    final top = candidates.isNotEmpty ? candidates.first as Map : <dynamic, dynamic>{};
    final rawType = f['equipment_category'] ?? f['equipment_type'] ?? f['category'] ?? '';
    final type = rawType.toString().trim().isNotEmpty
        ? rawType.toString().trim().replaceAll('_', ' ')
        : '';
    return {
      'brand': f['brand']?.toString().trim() ?? '',
      'model': top['model']?.toString().trim() ?? '',
      'type': type.isNotEmpty ? type[0].toUpperCase() + type.substring(1).toLowerCase() : '',
    };
  }

  Future<void> _verifyAll() async {
    for (int i = 0; i < widget.detections.length; i++) {
      final vals = _cardValues[i];
      final detection = widget.detections[i];
      final frameImage = (detection['ai_image'] ?? detection['raw_image'] ?? detection['image'])?.toString();
      final fd = (detection['forensic_data'] as Map?)?.cast<String, dynamic>() ?? {};
      final candidates = fd['model_candidates'] as List? ?? [];
      final top = candidates.isNotEmpty ? (candidates.first as Map).cast<String, dynamic>() : <String, dynamic>{};
      final conf = (top['confidence'] as num?)?.toInt() ?? 0;
      await _fetchSpecs(vals['brand']!, vals['model']!, vals['type']!, frameImage, confidence: conf);
    }
  }

  Future<void> _fetchSpecs(
      String brand, String modelName, String type, String? frameImage, {int confidence = 0}) async {
    setState(() {
      _isFetchingSpecs = true;
      _fetchingLabel = '$brand $modelName';
    });

    try {
      final specRes = await _apiService.getSpecs(brand, modelName, type);
      if (mounted) {
        // Re-show carousel before opening detail — carousel stays alive underneath
        setState(() => _isFetchingSpecs = false);

        if (specRes['equipment_result'] != null) {
          final equipResult = Map<String, dynamic>.from(
              specRes['equipment_result'] as Map);

          if (frameImage != null) {
            final meta = Map<String, dynamic>.from(
                (equipResult['meta'] as Map?) ?? {});
            meta['ai_image'] = frameImage;
            equipResult['meta'] = meta;
          }

          if (confidence > 0) {
            final identity = Map<String, dynamic>.from(
                (equipResult['identity'] as Map?) ?? {});
            identity['confidence'] = confidence;
            equipResult['identity'] = identity;
          }

          final equipmentResult = EquipmentResult.fromJson(equipResult);
          // Push detail ON TOP of carousel — user can dismiss it and come back
          // to verify the remaining cards without restarting the flow.
          await showModalBottomSheet(
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
                final detection = widget.detections[index];
                return _VerificationCard(
                  detection: detection,
                  icon: _getEquipmentIcon(
                    detection['forensic_data']
                            ?['equipment_category']
                            ?.toString() ??
                        '',
                  ),
                  onChanged: (brand, model, type) {
                    _cardValues[index] = {'brand': brand, 'model': model, 'type': type};
                  },
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlowingButton(
              label: widget.detections.length > 1
                  ? 'Verify & Search All (${widget.detections.length})'
                  : 'Verify & Search',
              isFullWidth: true,
              onTap: _verifyAll,
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
  final Function(String brand, String model, String type) onChanged;

  const _VerificationCard(
      {required this.detection,
      required this.icon,
      required this.onChanged});

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard> {
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _typeController;



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
  }

  @override
  void dispose() {
    _typeController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiImage =
        widget.detection['ai_image'] ?? widget.detection['raw_image'] ?? widget.detection['image'];
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
                    onChanged: (_) {
                      setState(() {});
                      widget.onChanged(_brandController.text.trim(), _modelController.text.trim(), _typeController.text.trim());
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildInputField(
                    'BRAND',
                    _brandController,
                    hint: 'e.g. Samsung, LG, Dell…',
                    onChanged: (_) => widget.onChanged(_brandController.text.trim(), _modelController.text.trim(), _typeController.text.trim()),
                  ),
                  const SizedBox(height: 14),
                  _buildInputField(
                    'MODEL REFERENCE',
                    _modelController,
                    hint: 'e.g. Galaxy Book Pro 360…',
                    onChanged: (_) => widget.onChanged(_brandController.text.trim(), _modelController.text.trim(), _typeController.text.trim()),
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

// ── AI analysis overlay ────────────────────────────────────────────────────
// A single persistent full-screen overlay shown while frames are sent to the
// AI. Replaces the old flickery per-frame spinner dialog + snackbars.

class _AiAnalysisOverlay extends StatefulWidget {
  final int progress;
  final int total;
  final String label;
  const _AiAnalysisOverlay({
    required this.progress,
    required this.total,
    required this.label,
  });

  @override
  State<_AiAnalysisOverlay> createState() => _AiAnalysisOverlayState();
}

class _AiAnalysisOverlayState extends State<_AiAnalysisOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.total <= 0 ? 1 : widget.total;
    final ratio = (widget.progress / total).clamp(0.0, 1.0);

    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: CybersightTheme.navy2.withValues(alpha: 0.82),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsing radar / scanning core
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) {
                        return SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Expanding pulse ring
                              Container(
                                width: 60 + 60 * _pulse.value,
                                height: 60 + 60 * _pulse.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: CybersightTheme.accent.withValues(
                                        alpha: (1 - _pulse.value) * 0.5),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 96,
                                height: 96,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      CybersightTheme.accent),
                                ),
                              ),
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      CybersightTheme.accent.withValues(alpha: 0.10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: CybersightTheme.accent
                                          .withValues(alpha: 0.4),
                                      blurRadius: 30,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.auto_awesome_rounded,
                                    color: CybersightTheme.accent, size: 28),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'ANALYZING EQUIPMENT',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.label.isEmpty
                          ? 'Reading brand & specifications'
                          : 'Identifying ${widget.label}',
                      style: GoogleFonts.plusJakartaSans(
                        color: CybersightTheme.accent.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Progress bar + counter
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: ratio),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, __) => LinearProgressIndicator(
                                value: v,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.07),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    CybersightTheme.accent),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${widget.progress}/${widget.total}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

// ── Multi-stage processing loader ──────────────────────────────────────────
// Auto-advances through a list of stages on a timer to give a sense of forward
// motion during the (single) backend call. The final stage lingers (duration 0)
// until the parent removes the widget when the real work finishes.

class _Stage {
  final String title;
  final String subtitle;
  final int durationMs; // 0 = linger here until dismissed
  const _Stage(this.title, this.subtitle, this.durationMs);
}

class _ProcessingStages extends StatefulWidget {
  final List<_Stage> stages;
  const _ProcessingStages({required this.stages});

  @override
  State<_ProcessingStages> createState() => _ProcessingStagesState();
}

class _ProcessingStagesState extends State<_ProcessingStages> {
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_current >= widget.stages.length - 1) return; // last stage lingers
    final ms = widget.stages[_current].durationMs;
    if (ms <= 0) return;
    _timer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _current++);
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.stages.length;
    final progress = (_current + 1) / total;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thin overall progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  CybersightTheme.accent),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Stage checklist
        ...List.generate(total, (i) {
          final stage = widget.stages[i];
          final isDone = i < _current;
          final isActive = i == _current;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: (isDone || isActive) ? 1.0 : 0.35,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  _StageIcon(isDone: isDone, isActive: isActive),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stage.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: isActive
                                ? Colors.white
                                : isDone
                                    ? Colors.white60
                                    : Colors.white38,
                            fontSize: 13.5,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 2),
                          Text(
                            stage.subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              color: CybersightTheme.accent
                                  .withValues(alpha: 0.7),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StageIcon extends StatelessWidget {
  final bool isDone;
  final bool isActive;
  const _StageIcon({required this.isDone, required this.isActive});

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CybersightTheme.accent.withValues(alpha: 0.15),
          border: Border.all(color: CybersightTheme.accent.withValues(alpha: 0.5)),
        ),
        child: const Icon(Icons.check_rounded,
            color: CybersightTheme.accent, size: 14),
      );
    }
    if (isActive) {
      return SizedBox(
        width: 22,
        height: 22,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(CybersightTheme.accent),
              ),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: CybersightTheme.accent,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
    );
  }
}
