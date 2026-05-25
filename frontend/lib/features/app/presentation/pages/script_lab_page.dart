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

class ScriptLabPage extends StatefulWidget {
  const ScriptLabPage({super.key});

  @override
  State<ScriptLabPage> createState() => _ScriptLabPageState();
}

class _ScriptLabPageState extends State<ScriptLabPage> {
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
          // AUTO-SELECT HERO FRAMES
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
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white),
              ),
              backgroundColor: CybersightTheme.warning.withValues(alpha: 0.9),
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
      Map<String, dynamic>? firstDetected;

      for (final filename in List<String>.from(_selectedFilenames)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PROCESSING $filename (${processedCount + 1}/$total)',
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
            builder: (_) => const Center(child: CircularProgressIndicator(color: CybersightTheme.accent)),
          );
        }

        final result = await _apiService.processSelectedFrames(
          _sessionId!,
          [filename],
        );

        bool brandFound = false;

        if (result != null && result['success'] == true) {
          final List<dynamic> processedFrames = result['frames'];
          for (var pf in processedFrames) {
            final idx = _frames.indexWhere((f) => f['filename'] == pf['filename']);
            if (idx != -1) {
              setState(() => _frames[idx] = pf);
              if (pf['has_ai'] == true && pf['forensic_data'] != null) {
                final brand = pf['forensic_data']['brand']?.toString();
                if (brand != null && brand.toLowerCase() != 'unknown') {
                  brandFound = true;
                  firstDetected = pf;
                }
              }
            }
          }
        }

        if (brandFound && firstDetected != null) {
          final initialForensic = firstDetected['forensic_data'] ?? {};
          final brand = initialForensic['brand']?.toString() ?? 'Unknown';
          final candidates = initialForensic['model_candidates'] as List? ?? [];
          final topCand = candidates.isNotEmpty ? candidates.first as Map? ?? {} : {};
          final topModelName = topCand['model']?.toString() ?? 'Unknown';
          final type = initialForensic['equipment_category'] ?? initialForensic['equipment_type'] ?? 'Equipment';

          try {
            final specRes = await _apiService.getSpecs(brand, topModelName, type);
            if (mounted) Navigator.of(context, rootNavigator: true).pop();

            setState(() {
              _selectedFilenames.clear();
            });

            if (specRes['equipment_result'] != null) {
              final equipmentResult = EquipmentResult.fromJson(specRes['equipment_result']);
              if (mounted) {
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
            if (mounted) Navigator.of(context, rootNavigator: true).pop();
          }
          break;
        } else {
          if (mounted) Navigator.of(context, rootNavigator: true).pop();
          setState(() {
            _selectedFilenames.remove(filename);
          });
          processedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI ANALYSIS COMPLETED.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
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
                "ID: ${frame['filename'] ?? 'unknown'}",
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
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

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CybersightTheme.navy2.withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: CybersightTheme.accent.withValues(alpha: 0.2))),
      ),
      child: GlowingButton(
        label: _isProcessingAI ? 'Processing...' : 'Analyze ${_selectedFilenames.length} Selected',
        onTap: _isProcessingAI ? () {} : _runAIOnSelected,
        isFullWidth: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CybersightAtmosphere(
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildHeader(),
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

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Neural Script Lab',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Video Forensics',
                  style: GoogleFonts.plusJakartaSans(
                    color: CybersightTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isExtracting ? 'Analyzing motion vectors...' : 'Select video to begin',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!_isExtracting)
            GestureDetector(
              onTap: _pickAndProcessVideo,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: CybersightTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.video_call_rounded, color: Colors.black, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Upload',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const CircularProgressIndicator(color: CybersightTheme.accent),
        ],
      ),
    );
  }

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
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    color: CybersightTheme.accent.withValues(alpha: 0.1),
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    color: CybersightTheme.accent.withValues(alpha: 0.4),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: CybersightTheme.accent,
                    strokeWidth: 4,
                  ),
                ),
                const Icon(Icons.memory_rounded, size: 24, color: CybersightTheme.accent),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              'Neural Engine Active',
              style: GoogleFonts.plusJakartaSans(
                color: CybersightTheme.accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Decompiling video stream into vector frames...',
              style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 11, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            Text(
              'Isolating equipment hardware signatures...',
              style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11, letterSpacing: 0.5),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.02),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Icon(
              Icons.movie_filter_rounded,
              size: 36,
              color: CybersightTheme.accent.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Frames Extracted',
            style: GoogleFonts.plusJakartaSans(
              color: CybersightTheme.accent.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a video to isolate key signatures.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
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
                if (mounted && _selectedFilenames.isNotEmpty) await _runAIOnSelected();
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? CybersightTheme.accent : Colors.white.withValues(alpha: 0.05),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: CybersightTheme.accent.withValues(alpha: 0.2), blurRadius: 15)]
                  : [],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Builder(builder: (_) {
                  final rawImg = aiImage ?? frame['image'];
                  if (rawImg == null) {
                    return Container(
                      color: CybersightTheme.navy2,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_rounded, color: Colors.white24, size: 32),
                      ),
                    );
                  }
                  return Image.memory(base64Decode(rawImg as String), fit: BoxFit.cover);
                }),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                if (frame['is_hero'] == true)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: CybersightTheme.warning,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'HERO',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                if (hasAi)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: CybersightTheme.ok.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: CybersightTheme.ok.withValues(alpha: 0.4), blurRadius: 10),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'DETECTED',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'TAP FOR DETAILS',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black54,
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                      child: const Icon(Icons.check_rounded, color: Colors.black, size: 14),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
