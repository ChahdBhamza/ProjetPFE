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
      // Collect ALL detections from ALL hero frames
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
            builder: (_) => const Center(child: CircularProgressIndicator(color: CybersightTheme.accent)),
          );
        }

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
              if (pf['has_ai'] == true && pf['forensic_data'] != null) {
                final brand = pf['forensic_data']['brand']?.toString();
                if (brand != null && brand.toLowerCase() != 'unknown') {
                  allDetections.add(pf);
                }
              }
            }
          }
        }

        // Dismiss the loading dialog for this frame
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }

      setState(() {
        _selectedFilenames.clear();
      });

      // Show the verification carousel sheet with ALL detected equipment
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
              'AI ANALYSIS COMPLETED — ${allDetections.length} equipment detected.',
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
                // Camera viewfinder corner brackets
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ViewfinderCornersPainter(
                      color: isSelected ? CybersightTheme.accent : Colors.white.withValues(alpha: 0.15),
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
                        color: CybersightTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: CybersightTheme.warning, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: CybersightTheme.warning.withValues(alpha: 0.3),
                            blurRadius: 6,
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4, height: 4,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: CybersightTheme.warning),
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
                if (hasAi)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    left: 10,
                    child: GlassContainer(
                      opacity: 0.15,
                      blur: 15,
                      borderRadius: 12,
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: CybersightTheme.ok.withValues(alpha: 0.3), width: 1.0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Flashing green active indicator
                                  _BlinkingDot(color: CybersightTheme.ok),
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

class _VerificationCarouselSheet extends StatefulWidget {
  final List<Map<String, dynamic>> detections;

  const _VerificationCarouselSheet({required this.detections});

  @override
  State<_VerificationCarouselSheet> createState() => _VerificationCarouselSheetState();
}

class _VerificationCarouselSheetState extends State<_VerificationCarouselSheet> {
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentIndex = 0;

  bool _isFetchingSpecs = false;
  String _fetchingLabel = '';

  Future<void> _fetchSpecs(String brand, String modelName, String type) async {
    setState(() {
      _isFetchingSpecs = true;
      _fetchingLabel = '$brand $modelName';
    });

    try {
      final specRes = await _apiService.getSpecs(brand, modelName, type);
      if (mounted) {
        Navigator.of(context).pop();
        if (specRes['equipment_result'] != null) {
          final equipmentResult = EquipmentResult.fromJson(specRes['equipment_result']);
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
        setState(() {
          _isFetchingSpecs = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching specs: $e'), backgroundColor: CybersightTheme.warning),
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
          border: Border(top: BorderSide(color: CybersightTheme.accent.withValues(alpha: 0.2))),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: CybersightTheme.accent),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Querying global technical databases...',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 11,
                ),
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
        border: Border(top: BorderSide(color: CybersightTheme.accent.withValues(alpha: 0.2))),
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
                  child: const Icon(Icons.verified_user_rounded, color: CybersightTheme.accent, size: 24),
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
                  icon: _getEquipmentIcon(widget.detections[index]['forensic_data']?['equipment_category']?.toString() ?? ''),
                  onVerify: (brand, model, type) => _fetchSpecs(brand, model, type),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Page Indicators
          if (widget.detections.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.detections.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index ? CybersightTheme.accent : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _VerificationCard extends StatefulWidget {
  final Map<String, dynamic> detection;
  final IconData icon;
  final Function(String brand, String model, String type) onVerify;

  const _VerificationCard({required this.detection, required this.icon, required this.onVerify});

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard> {
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _typeController;

  @override
  void initState() {
    super.initState();
    final forensic = widget.detection['forensic_data'] ?? {};
    final candidates = forensic['model_candidates'] as List? ?? [];
    final topCandidate = candidates.isNotEmpty ? candidates.first : {};
    
    final detectedType = forensic['equipment_category']?.toString() ?? forensic['equipment_type']?.toString() ?? '';
    
    _typeController = TextEditingController(text: detectedType);
    _brandController = TextEditingController(text: forensic['brand']?.toString() ?? 'Unknown');
    _modelController = TextEditingController(text: topCandidate['model']?.toString() ?? '');
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
    final aiImage = widget.detection['ai_image'] ?? widget.detection['image'];
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Visual Context (Hero Crop)
              Container(
                height: 180,
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (aiImage != null)
                      Image.memory(base64Decode(aiImage as String), fit: BoxFit.cover)
                    else
                      const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.white24, size: 48)),
                    
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, CybersightTheme.navy2.withValues(alpha: 0.9)],
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
                          Icon(widget.icon, color: CybersightTheme.accent, size: 20),
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
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Editable Equipment Type Field
                    _buildInputField(
                      'EQUIPMENT TYPE',
                      _typeController,
                      hint: 'e.g. Laptop, Microwave, Refrigerator…',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Editable Brand Field
                    _buildInputField('BRAND', _brandController),
                    const SizedBox(height: 16),
                    
                    // Editable Model Field
                    _buildInputField('MODEL REFERENCE', _modelController),
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
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: Colors.white24,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CybersightTheme.accent),
            ),
            suffixIcon: const Icon(Icons.edit_rounded, color: Colors.white38, size: 16),
          ),
        ),
      ],
    );
  }
}

class _ViewfinderCornersPainter extends CustomPainter {
  final Color color;
  _ViewfinderCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double len = 10.0; // corner line length
    final double pad = 8.0; // corner padding

    // Top Left Corner
    canvas.drawPath(
        Path()
          ..moveTo(pad + len, pad)
          ..lineTo(pad, pad)
          ..lineTo(pad, pad + len),
        paint);

    // Top Right Corner
    canvas.drawPath(
        Path()
          ..moveTo(size.width - pad - len, pad)
          ..lineTo(size.width - pad, pad)
          ..lineTo(size.width - pad, pad + len),
        paint);

    // Bottom Left Corner
    canvas.drawPath(
        Path()
          ..moveTo(pad + len, size.height - pad)
          ..lineTo(pad, size.height - pad)
          ..lineTo(pad, size.height - pad - len),
        paint);

    // Bottom Right Corner
    canvas.drawPath(
        Path()
          ..moveTo(size.width - pad - len, size.height - pad)
          ..lineTo(size.width - pad, size.height - pad)
          ..lineTo(size.width - pad, size.height - pad - len),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BlinkingDot extends StatefulWidget {
  final Color color;
  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
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
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color,
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
