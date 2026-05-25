import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:equipment_detection_app/core/network/api_service.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../widgets/model_selection_sheet.dart';
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
      // We'll use the same endpoint as the web Script Lab
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
        // Auto‑open hero preview if any hero frames exist
        if (_selectedFilenames.isNotEmpty) {
          // Delay to ensure UI is built, then show carousel
          Future.microtask(() async {
            await _showHeroFrames();
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
                style: const TextStyle(fontSize: 13),
              ),
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extraction error: $e')),
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
      // Process frames sequentially to provide incremental feedback
      final total = _selectedFilenames.length;
      int processedCount = 0;
      Map<String, dynamic>? firstDetected;

      for (final filename in List<String>.from(_selectedFilenames)) {
        // Show a progress snackbar for the current frame
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Processing $filename (${processedCount + 1}/$total)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // Show modal progress dialog for this frame
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
        }
        final result = await _apiService.processSelectedFrames(
          _sessionId!,
          [filename],
        );
        // Dismiss progress dialog
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (result != null && result['success'] == true) {
          final List<dynamic> processedFrames = result['frames'];
          bool brandFound = false;
          setState(() {
            for (var pf in processedFrames) {
              final idx = _frames.indexWhere((f) => f['filename'] == pf['filename']);
              if (idx != -1) {
                _frames[idx] = pf;
                if (pf['has_ai'] == true && pf['forensic_data'] != null) {
                  final brand = pf['forensic_data']['brand']?.toString();
                  if (brand != null && brand.toLowerCase() != 'unknown') {
                    brandFound = true;
                    Future.microtask(() => _showModelSuggestions(pf));
                  }
                }
              }
            }
            // Remove the processed filename from the selection set
            _selectedFilenames.remove(filename);
            if (brandFound) {
              _selectedFilenames.clear();
            }
          });
          processedCount++;
          if (brandFound) break;
        } else {
          // If a frame fails, stop further processing and inform the user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to process a frame, stopping.')),
            );
          }
          break;
        }
      }

      // Notify completion of batch processing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI analysis completed.')),
        );
      }
    } finally {
      setState(() => _isProcessingAI = false);
    }
  }

  // Show a simple dialog with brand and model suggestions

  Future<void> _showFrameDetails(Map<String, dynamic> frame) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Frame Details'),
        content: Text("Details for frame: ${frame['filename'] ?? 'unknown'}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF161B22),
      child: ElevatedButton(
        onPressed: _isProcessingAI ? null : _runAIOnSelected,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF58A6FF),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isProcessingAI
            ? const CircularProgressIndicator(color: Colors.white)
            : Text('Analyze ${_selectedFilenames.length} Selected Frames'),
      ),
    );
  }
  Future<void> _showModelSuggestions(Map<String, dynamic> frame) async {
    final initialForensic = frame['forensic_data'] ?? {};
    final brand = initialForensic['brand']?.toString() ?? 'Unknown';
    final candidates = initialForensic['model_candidates'] as List? ?? [];
    final type = initialForensic['equipment_category'] ?? initialForensic['equipment_type'] ?? 'Equipment';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0C10),
        title: Text('Brand: $brand', style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (cctx, idx) {
              final cand = candidates[idx] as Map? ?? {};
              final modelName = cand['model']?.toString() ?? 'Unknown';
              final confidence = cand['confidence']?.toString() ?? '';
              return ListTile(
                title: Text(modelName, style: const TextStyle(color: Colors.white)),
                subtitle: confidence.isNotEmpty ? Text('$confidence% match', style: const TextStyle(color: Colors.grey)) : null,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  // Show loading then fetch specs similar to original flow
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.blue)),
                  );
                  try {
                    final res = await _apiService.getSpecs(brand, modelName, type);
                    Navigator.of(context).pop(); // close loading
                    if (res != null && res['equipment_result'] != null) {
                      final equipmentResult = EquipmentResult.fromJson(res['equipment_result']);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => Scaffold(body: EquipmentDetailPage(result: equipmentResult))),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to extract specs')));
                    }
                  } catch (e) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      appBar: AppBar(
        title: const Text('🎞️ Neural Script Lab'),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _frames.isEmpty 
              ? _buildEmptyState()
              : _buildFrameGrid(),
          ),
          if (_selectedFilenames.isNotEmpty) _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF161B22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Video Forensics',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _isExtracting ? 'Analyzing motion vectors...' : 'Select a video to begin frame extraction',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!_isExtracting)
            ElevatedButton.icon(
              onPressed: _pickAndProcessVideo,
              icon: const Icon(Icons.video_call),
              label: const Text('Upload'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            )
          else
            const CircularProgressIndicator(color: Color(0xFF58A6FF)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_filter_outlined, size: 80, color: Colors.grey[800]),
          const SizedBox(height: 16),
          const Text('No frames extracted yet', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // Helper to preview hero frames in a fullscreen carousel
  Future<void> _showHeroFrames() async {
    final heroFrames = _frames.where((f) => _selectedFilenames.contains(f['filename'])).toList();
    if (heroFrames.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.95,
        child: Scaffold(
          backgroundColor: const Color(0xFF0A0C10),
          appBar: AppBar(
            backgroundColor: const Color(0xFF161B22),
            title: const Text('Hero Frames'),
            leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ),
          body: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  itemCount: heroFrames.length,
                  itemBuilder: (context, index) {
                    final frame = heroFrames[index];
                    return Center(
                      child: Image.memory(
                        base64Decode(frame['image']),
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF58A6FF)),
                  child: const Text('PROCEED'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() async {
      // After the carousel is dismissed, automatically trigger AI analysis if still mounted
      if (mounted) await _runAIOnSelected();
    });
  }

  Widget _buildFrameGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
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
            // Prevent interactions while AI is processing
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
              // Auto‑run AI analysis after any selection change
              Future.microtask(() async {
                if (mounted && _selectedFilenames.isNotEmpty) {
                  await _runAIOnSelected();
                }
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF58A6FF) : Colors.transparent,
                width: 3,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Use AI image if available, otherwise raw
                Image.memory(
                  base64Decode(aiImage ?? frame['image']),
                  fit: BoxFit.cover,
                ),
                if (frame['is_hero'] == true)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                      child: const Text('HERO', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (hasAi)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F5A0),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF00F5A0).withOpacity(0.4), blurRadius: 8),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('DETECTED', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          Text('TAP → SELECT', style: TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                  ),
                if (isSelected)
                  Container(color: Colors.blue.withOpacity(0.2)),
              ],
            ),
          ),
        );
      },
    );
  }

  

}

class _SpecDetailsSheet extends StatefulWidget {
  final String brand;
  final List modelCandidates;
  final String type;

  const _SpecDetailsSheet({required this.brand, required this.modelCandidates, required this.type});

  @override
  State<_SpecDetailsSheet> createState() => _SpecDetailsSheetState();
}

class _SpecDetailsSheetState extends State<_SpecDetailsSheet> {
  bool _isLoading = false;
  String? _selectedModel;
  Map<String, dynamic>? _specs;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Don't fetch immediately - wait for user to pick a candidate
  }

  Future<void> _fetchData(String model) async {
    setState(() {
      _isLoading = true;
      _selectedModel = model;
      _specs = null;
      _error = null;
    });
    
    try {
      final data = await ApiService().getSpecs(widget.brand, model, widget.type);
      setState(() {
        _specs = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Could not fetch web specs for this model.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Merge all data categories into one for the UI
    final Map<String, dynamic> allDetails = {};
    if (_specs != null) {
      if (_specs!['specs'] is Map) allDetails.addAll(Map<String, dynamic>.from(_specs!['specs']));
      if (_specs!['energy_info'] is Map) allDetails.addAll(Map<String, dynamic>.from(_specs!['energy_info']));
      if (_specs!['consumables'] is Map) allDetails.addAll(Map<String, dynamic>.from(_specs!['consumables']));
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.brand.toUpperCase(),
                    style: const TextStyle(color: Colors.blue, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.type.toUpperCase(),
                    style: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 2),
                  ),
                ],
              ),
              const Icon(Icons.psychology, color: Colors.blue, size: 40),
            ],
          ),
          const Divider(color: Colors.white10, height: 40),
          
          // 1. Model Suggestions
          const Text('MODEL SUGGESTIONS (CHOOSE ONE)', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.modelCandidates.map<Widget>((c) {
              final mName = c['model'] ?? 'Unknown';
              final isSelected = _selectedModel == mName;
              return InkWell(
                onTap: () => _fetchData(mName),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? Colors.blue : Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mName, style: TextStyle(color: isSelected ? Colors.blue : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${c['confidence']}% Match', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          
          const Divider(color: Colors.white10, height: 40),

          if (_isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                    Text('Searching technical databases...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else if (_specs == null)
            const Expanded(child: Center(child: Text('Select a model above to view specifications', style: TextStyle(color: Colors.grey))))
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Technical Specs
                    const Text('TECHNICAL SPECIFICATIONS', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    
                    if (allDetails.isEmpty)
                      const Text('No structured technical data found yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    
                    ...allDetails.entries.map((entry) {
                      // Clean up key names (e.g., energy_class -> Energy Class)
                      final label = entry.key.split('_').map((word) {
                        if (word.isEmpty) return '';
                        return word[0].toUpperCase() + word.substring(1);
                      }).join(' ');
                      
                      return _buildSpecRow(label, entry.value?.toString() ?? 'N/A');
                    }).toList(),
                    
                    const SizedBox(height: 32),
                    
                    // 2. Neural Summary (The Web Search Result)
                    const Text('NEURAL SUMMARY', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                      child: Text(
                        _specs?['summary'] ?? 'Spec extraction complete based on visual matches.',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 3. Primary Source
                    if (_specs?['primary_source'] != null) ...[
                      const Text('PRIMARY SOURCE', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => launchUrlString(_specs!['primary_source']),
                        child: Text(
                          _specs!['primary_source'],
                          style: const TextStyle(color: Colors.blueAccent, fontSize: 12, decoration: TextDecoration.underline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 4. Documentation Links
                    if (_specs?['manual_url'] != null || _specs?['official_url'] != null) ...[
                      const Text('DOCUMENTATION', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (_specs?['manual_url'] != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => launchUrlString(_specs!['manual_url']),
                                icon: const Icon(Icons.picture_as_pdf, size: 18),
                                label: const Text('MANUAL', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2), foregroundColor: Colors.redAccent),
                              ),
                            ),
                          if (_specs?['manual_url'] != null && _specs?['official_url'] != null) const SizedBox(width: 12),
                          if (_specs?['official_url'] != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => launchUrlString(_specs!['official_url']),
                                icon: const Icon(Icons.language, size: 18),
                                label: const Text('OFFICIAL', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.withOpacity(0.2), foregroundColor: Colors.blueAccent),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],

                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('CONFIRM & CLOSE', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
