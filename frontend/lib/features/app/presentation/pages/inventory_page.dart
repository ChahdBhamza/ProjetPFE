import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';

import '../../../../core/network/api_service.dart';
import '../../data/models/detection_result_model.dart';
import 'equipment_detail_page.dart';

class InventoryPage extends StatefulWidget {
  final bool isActive;
  const InventoryPage({super.key, this.isActive = false});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic>? _allInventoryItems;
  List<dynamic>? _filteredItems;
  bool _isLoading = true;
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void didUpdateWidget(InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadInventory();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    final items = await _apiService.fetchInventory();
    if (mounted) {
      setState(() {
        _allInventoryItems = items;
        _isLoading = false;
      });
      _filterInventory(_searchController.text);
    }
  }

  void _filterInventory(String query) {
    if (_allInventoryItems == null) return;
    
    setState(() {
      List<dynamic> temp = _allInventoryItems!;
      
      // Category tag filtering
      if (_selectedCategory != 'ALL') {
        temp = temp.where((item) {
          final metadata = item['metadata'] as Map<String, dynamic>? ?? {};
          final category = (metadata['category'] ?? item['category'] ?? '').toString().toLowerCase();
          final eqType = (metadata['equipment_type'] ?? item['equipment_type'] ?? '').toString().toLowerCase();
          final fullCategoryMatch = '$category $eqType';
          
          switch (_selectedCategory) {
            case 'CLIMATISEURS':
              return fullCategoryMatch.contains('air') || fullCategoryMatch.contains('clim');
            case 'REFRIGERATEURS':
              return fullCategoryMatch.contains('ref') || fullCategoryMatch.contains('kitchen');
            case 'LAPTOPS':
              return fullCategoryMatch.contains('lap') || fullCategoryMatch.contains('pc') || fullCategoryMatch.contains('computer');
            case 'MONITORS':
              return fullCategoryMatch.contains('mon') || fullCategoryMatch.contains('screen') || fullCategoryMatch.contains('disp') || fullCategoryMatch.contains('tv');
            case 'MICROWAVES':
              return fullCategoryMatch.contains('micro') || fullCategoryMatch.contains('oven');
            default:
              return true;
          }
        }).toList();
      }
      
      // Text search filtering
      if (query.isNotEmpty) {
        final lowercaseQuery = query.toLowerCase().trim();
        temp = temp.where((item) {
          final brand = (item['brand'] ?? '').toString().toLowerCase();
          final model = (item['model'] ?? '').toString().toLowerCase();
          final btu = (item['btu'] ?? '').toString().toLowerCase();
          
          final metadata = item['metadata'] as Map<String, dynamic>? ?? {};
          final category = (metadata['category'] ?? item['category'] ?? '').toString().toLowerCase();
          final eqType = (metadata['equipment_type'] ?? item['equipment_type'] ?? '').toString().toLowerCase();
          
          final specsStr = (metadata['specs'] ?? {}).toString().toLowerCase();
          final summary = (metadata['summary'] ?? '').toString().toLowerCase();
          
          return brand.contains(lowercaseQuery) || 
                 model.contains(lowercaseQuery) || 
                 category.contains(lowercaseQuery) ||
                 eqType.contains(lowercaseQuery) ||
                 btu.contains(lowercaseQuery) ||
                 specsStr.contains(lowercaseQuery) ||
                 summary.contains(lowercaseQuery);
        }).toList();
      }
      
      _filteredItems = temp;
    });
  }

  Widget _buildFilterChips() {
    final List<String> categories = ['ALL', 'CLIMATISEURS', 'REFRIGERATEURS', 'LAPTOPS', 'MONITORS', 'MICROWAVES'];
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          Color activeColor = CybersightTheme.accent;
          if (cat == 'REFRIGERATEURS') activeColor = CybersightTheme.ok;
          if (cat == 'LAPTOPS') activeColor = Colors.purpleAccent;
          if (cat == 'MONITORS') activeColor = Colors.greenAccent;
          if (cat == 'MICROWAVES') activeColor = Colors.pinkAccent;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = cat;
                });
                _filterInventory(_searchController.text);
              },
              child: GlassContainer(
                opacity: isSelected ? 0.12 : 0.04,
                blur: 15,
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeColor,
                          boxShadow: [BoxShadow(color: activeColor, blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      cat,
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? Colors.white : Colors.white30,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getCategorySubtitle() {
    if (_allInventoryItems == null || _allInventoryItems!.isEmpty) {
      return 'NEURAL DATABASE • EMPTY';
    }
    final categories = _allInventoryItems!
        .map((item) {
          final cat = (item['metadata']?['category'] ?? 'UNKNOWN').toString().trim().toUpperCase();
          if (cat == 'UNKNOWN' || cat.isEmpty || cat == 'EQUIPMENT') {
            final type = (item['metadata']?['equipment_type'] ?? 'EQUIPMENT').toString().trim().toUpperCase();
            return type;
          }
          return cat;
        })
        .map((cat) {
          if (cat == 'AIRCONDITIONER' || cat == 'AIR_CONDITIONER') return 'CLIMATISEURS';
          if (cat == 'REFRIGERATOR') return 'REFRIGERATEURS';
          if (cat == 'MICROWAVE') return 'MICROWAVES';
          if (cat == 'LAPTOP') return 'LAPTOPS';
          if (cat == 'MONITOR') return 'MONITORS';
          return cat;
        })
        .toSet()
        .toList();
    categories.sort();
    return 'NEURAL DATABASE • ${categories.join(' • ')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadInventory,
        color: CybersightTheme.accent,
        backgroundColor: CybersightTheme.navy2,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. NEURAL HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          fontSize: 42,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getCategorySubtitle(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white24,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                  GlassContainer(
                    width: 52,
                    height: 52,
                    opacity: 0.05,
                    blur: 24,
                    borderRadius: 16,
                    child: const Icon(Icons.qr_code_scanner_rounded, color: CybersightTheme.accent, size: 24),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),

              // 2. SEARCH HUD
              Row(
                children: [
                  Expanded(
                    child: GlassContainer(
                      height: 56,
                      opacity: 0.05,
                      blur: 20,
                      borderRadius: 16,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterInventory,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Filter database...',
                          hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(colors: [CybersightTheme.accent, CybersightTheme.accent2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      boxShadow: [BoxShadow(color: CybersightTheme.accent.withOpacity(0.3), blurRadius: 15)],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.black, size: 28),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _buildFilterChips(),
              const SizedBox(height: 16),

              // 3. DATABASE LIST
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: CybersightTheme.accent),
                  ),
                )
              else if (_allInventoryItems == null || _allInventoryItems!.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CybersightTheme.accent.withOpacity(0.05),
                            border: Border.all(color: CybersightTheme.accent.withOpacity(0.2)),
                          ),
                          child: const Icon(Icons.radar_rounded, color: CybersightTheme.accent, size: 36),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Equipment Found',
                          style: GoogleFonts.plusJakartaSans(
                            color: CybersightTheme.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your digital inventory is currently empty.\nRun a neural scan to begin tracking assets.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredItems == null || _filteredItems!.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CybersightTheme.accent.withOpacity(0.02),
                            border: Border.all(color: CybersightTheme.accent.withOpacity(0.1)),
                          ),
                          child: Icon(Icons.search_off_rounded, color: CybersightTheme.accent.withOpacity(0.3), size: 36),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Matches Found',
                          style: GoogleFonts.plusJakartaSans(
                            color: CybersightTheme.accent.withOpacity(0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No equipment matches your neural filter.\nTry a different keyword or brand.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._filteredItems!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Interval(
                      (index * 0.1).clamp(0.0, 1.0),
                      1.0,
                      curve: Curves.easeOutCubic,
                    ),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _InventoryCard(
                        item: item,
                        onTap: () {
                          final metadata = item['metadata'] as Map<String, dynamic>? ?? {};
                          final specs = Map<String, dynamic>.from(metadata);
                          if (item['btu'] != null) specs['capacity_btu'] = item['btu'];
                          if (item['price'] != null) specs['price'] = item['price'];

                          final equipmentResult = EquipmentResult(
                            identity: EquipmentIdentity(
                              equipmentCategory: metadata['category']?.toString() ?? 'Equipment',
                              brand: item['brand']?.toString() ?? 'Unknown',
                              topModel: item['model']?.toString() ?? 'N/A',
                              confidence: 100,
                              allCandidates: [],
                              visualCues: [],
                            ),
                            specs: specs,
                            meta: EquipmentMeta(
                              sourceQuality: 'inventory',
                              sourceUrls: [],
                              verified: true,
                              summary: 'Retrieved from local inventory database.',
                              aiImage: metadata['ai_image']?.toString() ?? metadata['annotated_image']?.toString(),
                            ),
                          );

                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => FractionallySizedBox(
                              heightFactor: 0.85,
                              child: EquipmentDetailPage(result: equipmentResult),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _InventoryCard({
    required this.item,
    required this.onTap,
  });

  @override
  State<_InventoryCard> createState() => _InventoryCardState();
}

class _InventoryCardState extends State<_InventoryCard> {
  bool _isHovered = false;

  IconData _getIcon(String category) {
    category = category.toUpperCase();
    if (category.contains('AIR') || category.contains('CLIMAT')) return Icons.ac_unit_rounded;
    if (category.contains('REF')) return Icons.kitchen_rounded;
    if (category.contains('MICRO')) return Icons.microwave_rounded;
    if (category.contains('LAP')) return Icons.laptop_rounded;
    if (category.contains('MONITOR') || category.contains('SCREEN') || category.contains('DISP')) return Icons.monitor_rounded;
    return Icons.memory_rounded;
  }

  Map<String, String> _getSpecLabelAndValue() {
    final metadata = widget.item['metadata'] as Map<String, dynamic>? ?? {};
    final category = (metadata['category'] ?? 'unknown').toString().toLowerCase();
    
    if (category.contains('air') || category.contains('clim')) {
      final btu = widget.item['btu'] ?? metadata['capacity_btu'];
      return {
        'label': 'CAPACITY',
        'value': btu != null ? '$btu BTU' : 'N/A BTU',
      };
    } else if (category.contains('ref')) {
      final liters = metadata['capacity_liters'] ?? metadata['specs']?['capacity_liters'];
      return {
        'label': 'VOLUME',
        'value': liters != null ? '$liters LITERS' : 'N/A LITERS',
      };
    } else if (category.contains('micro')) {
      final liters = metadata['capacity_liters'] ?? metadata['specs']?['capacity_liters'];
      final power = metadata['power_watts'] ?? metadata['specs']?['power_watts'];
      if (liters != null && power != null) {
        return {
          'label': 'SPECIFICATION',
          'value': '$liters L • $power W',
        };
      } else if (liters != null) {
        return {
          'label': 'VOLUME',
          'value': '$liters LITERS',
        };
      } else if (power != null) {
        return {
          'label': 'POWER',
          'value': '$power W',
        };
      }
      return {
        'label': 'SPECIFICATION',
        'value': 'N/A',
      };
    } else if (category.contains('lap')) {
      final cpu = metadata['cpu'] ?? metadata['specs']?['cpu'];
      final ram = metadata['ram_gb'] ?? metadata['specs']?['ram_gb'];
      final storage = metadata['storage'] ?? metadata['specs']?['storage'];
      if (ram != null && storage != null) {
        return {
          'label': 'HARDWARE',
          'value': '${ram}GB RAM • $storage',
        };
      } else if (cpu != null) {
        return {
          'label': 'PROCESSOR',
          'value': cpu.toString().toUpperCase(),
        };
      }
      return {
        'label': 'HARDWARE',
        'value': 'N/A',
      };
    } else if (category.contains('monitor') || category.contains('screen') || category.contains('disp')) {
      final size = metadata['screen_size_inches'] ?? metadata['specs']?['screen_size_inches'];
      final resolution = metadata['resolution'] ?? metadata['specs']?['resolution'];
      if (size != null && resolution != null) {
        return {
          'label': 'DISPLAY',
          'value': '${size}" • $resolution',
        };
      } else if (size != null) {
        return {
          'label': 'SIZE',
          'value': '${size} INCHES',
        };
      }
      return {
        'label': 'DISPLAY',
        'value': 'N/A',
      };
    }
    
    // Default fallback
    final btu = widget.item['btu'];
    if (btu != null) {
      return {
        'label': 'CAPACITY',
        'value': '$btu BTU',
      };
    }
    
    final price = widget.item['price'] ?? metadata['price_tnd'] ?? metadata['price'];
    if (price != null) {
      return {
        'label': 'PRICE',
        'value': '$price TND',
      };
    }
    
    return {
      'label': 'SPECIFICATION',
      'value': 'VERIFIED',
    };
  }

  String _getFormattedDate() {
    final addedAtStr = widget.item['added_at'];
    if (addedAtStr == null) return 'RECENTLY';
    
    try {
      final addedAt = DateTime.parse(addedAtStr.toString());
      final now = DateTime.now();
      final difference = now.difference(addedAt);
      
      if (difference.inDays == 0) {
        return 'TODAY';
      } else if (difference.inDays == 1) {
        return 'YESTERDAY';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} DAYS AGO';
      } else {
        return addedAt.toIso8601String().substring(0, 10);
      }
    } catch (e) {
      return 'RECENTLY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = (widget.item['brand'] ?? 'UNKNOWN').toString().toUpperCase();
    final metadata = widget.item['metadata'] as Map<String, dynamic>? ?? {};
    final category = (metadata['category'] ?? 'CLIMATISEUR').toString().toUpperCase();
    final model = (widget.item['model'] ?? 'N/A').toString().toUpperCase();
    
    final spec = _getSpecLabelAndValue();
    final formattedDate = _getFormattedDate();

    // Map distinct neon colors for left indicator bar
    Color activeColor = CybersightTheme.accent;
    if (category.contains('REF')) activeColor = CybersightTheme.ok;
    if (category.contains('LAP')) activeColor = Colors.purpleAccent;
    if (category.contains('MONITOR') || category.contains('SCREEN') || category.contains('DISP')) activeColor = Colors.greenAccent;
    if (category.contains('MICRO')) activeColor = Colors.pinkAccent;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 0.98 : 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: _isHovered ? [
              BoxShadow(
                color: activeColor.withOpacity(0.12),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ] : [],
          ),
          child: GlassContainer(
            opacity: _isHovered ? 0.07 : 0.04,
            blur: 18,
            borderRadius: 24,
            padding: EdgeInsets.zero,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Flush left neon side indicator bar
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [activeColor.withOpacity(0.2), activeColor],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  
                  // Card body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: _isHovered ? activeColor.withOpacity(0.15) : Colors.white.withOpacity(0.02),
                                  border: Border.all(color: _isHovered ? activeColor.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                                ),
                                child: Center(
                                  child: Icon(_getIcon(category), color: _isHovered ? activeColor : Colors.white60, size: 20),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      brand,
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${category.replaceAll('_', ' ')} • $model',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusIndicator(label: 'VERIFIED', color: CybersightTheme.ok, isHovered: _isHovered),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              _MetaTag(label: spec['label']!, value: spec['value']!, color: activeColor),
                              const SizedBox(width: 24),
                              _MetaTag(label: 'LAST SCAN', value: formattedDate, color: Colors.white30),
                              const Spacer(),
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _isHovered ? 1.0 : 0.3,
                                child: Icon(Icons.arrow_forward_ios_rounded, color: activeColor, size: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final Color color;
  final bool isHovered;
  const _StatusIndicator({required this.label, required this.color, this.isHovered = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Blinking custom indicator icon
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: color, 
              boxShadow: [
                BoxShadow(
                  color: color, 
                  blurRadius: isHovered ? 6 : 3,
                  spreadRadius: isHovered ? 1 : 0,
                )
              ]
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label, 
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8, 
              fontWeight: FontWeight.w800, 
              color: color, 
              letterSpacing: 0.5
            )
          ),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetaTag({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white24, letterSpacing: 1.0)),
        const SizedBox(height: 4),
        Text(
          value, 
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: color == Colors.white30 ? Colors.white70 : color
          )
        ),
      ],
    );
  }
}
