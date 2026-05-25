import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';

import '../../../../core/network/api_service.dart';
import '../../data/models/detection_result_model.dart';
import 'equipment_detail_page.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic>? _allInventoryItems;
  List<dynamic>? _filteredItems;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
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
        _filteredItems = items;
        _isLoading = false;
      });
    }
  }

  void _filterInventory(String query) {
    if (_allInventoryItems == null) return;
    
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _allInventoryItems;
      } else {
        final lowercaseQuery = query.toLowerCase();
        _filteredItems = _allInventoryItems!.where((item) {
          final brand = (item['brand'] ?? '').toString().toLowerCase();
          final model = (item['model'] ?? '').toString().toLowerCase();
          final category = (item['metadata']?['category'] ?? '').toString().toLowerCase();
          final btu = (item['btu'] ?? '').toString().toLowerCase();
          
          return brand.contains(lowercaseQuery) || 
                 model.contains(lowercaseQuery) || 
                 category.contains(lowercaseQuery) ||
                 btu.contains(lowercaseQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
                      'NEURAL DATABASE • CLIMATISEURS',
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

            const SizedBox(height: 32),

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
                      title: (item['brand'] ?? 'UNKNOWN').toString().toUpperCase(),
                      category: (item['metadata']?['category'] ?? 'CLIMATISEUR').toString().toUpperCase(),
                      serial: (item['model'] ?? 'N/A').toString().toUpperCase(),
                      status: 'VERIFIED',
                      statusColor: CybersightTheme.ok,
                      btu: (item['btu'] ?? 'N/A').toString(),
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
    );
  }
}

class _InventoryCard extends StatefulWidget {
  final String title;
  final String category;
  final String serial;
  final String status;
  final Color statusColor;
  final String btu;
  final VoidCallback onTap;

  const _InventoryCard({
    required this.title,
    required this.category,
    required this.serial,
    required this.status,
    required this.statusColor,
    required this.btu,
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

  @override
  Widget build(BuildContext context) {
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
                color: widget.statusColor.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ] : [],
          ),
          child: CybersightCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _isHovered ? widget.statusColor.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                        border: Border.all(color: _isHovered ? widget.statusColor.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                      ),
                      child: Center(
                        child: Icon(_getIcon(widget.category), color: widget.statusColor.withOpacity(_isHovered ? 0.9 : 0.5), size: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.category} • ${widget.serial}',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    _StatusIndicator(label: widget.status, color: widget.statusColor),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _MetaTag(label: 'CAPACITY', value: '${widget.btu} BTU'),
                    const SizedBox(width: 24),
                    const _MetaTag(label: 'LAST SCAN', value: 'RECENTLY'),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isHovered ? 1.0 : 0.3,
                      child: Icon(Icons.arrow_forward_ios_rounded, color: widget.statusColor, size: 14),
                    ),
                  ],
                ),
              ],
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
  const _StatusIndicator({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 4)]),
          ),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String label;
  final String value;
  const _MetaTag({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white24, letterSpacing: 1.0)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
      ],
    );
  }
}
