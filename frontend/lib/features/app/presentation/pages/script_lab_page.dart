import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:equipment_detection_app/core/network/api_service.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
      final result = await _apiService.processSelectedFrames(
        _sessionId!, 
        _selectedFilenames.toList()
      );

      if (result != null && result['success']) {
        // Update local frames with AI results
        final List<dynamic> processedFrames = result['frames'];
        setState(() {
          for (var pf in processedFrames) {
            int idx = _frames.indexWhere((f) => f['filename'] == pf['filename']);
            if (idx != -1) {
              _frames[idx] = pf;
            }
          }
          _selectedFilenames.clear();
        });
      }
    } finally {
      setState(() => _isProcessingAI = false);
    }
  }

  void _showFrameDetails(Map<String, dynamic> frame) {
    final initialForensic = frame['forensic_data'] ?? {};
    final brand = initialForensic['brand']?.toString() ?? 'Unknown';
    final candidates = initialForensic['model_candidates'] as List? ?? [];
    final type = initialForensic['equipment_type'] ?? 'Equipment';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _SpecDetailsSheet(
        brand: brand, 
        modelCandidates: candidates, 
        type: type
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                      child: const Text('DETECTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
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
