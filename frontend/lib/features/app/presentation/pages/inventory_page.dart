import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/design_system/cybersight_theme.dart';
import '../../../../core/widgets/hud_widgets.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';

import '../../../../core/network/api_service.dart';

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
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
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
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [CybersightTheme.accent, Colors.white, CybersightTheme.accent2],
                      ).createShader(rect),
                      child: Text(
                        'INVENTORY',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          fontSize: 26,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NEURAL DATABASE • CLIMATISEURS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: Colors.white24,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
                GlassContainer(
                  width: 42,
                  height: 42,
                  opacity: 0.05,
                  blur: 20,
                  borderRadius: 12,
                  child: const Icon(Icons.qr_code_scanner_rounded, color: CybersightTheme.accent, size: 20),
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            // 2. SEARCH HUD
            Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    height: 48,
                    opacity: 0.05,
                    blur: 15,
                    borderRadius: 14,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterInventory,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'FILTER DATABASE...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white10, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white24, size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(colors: [CybersightTheme.accent, CybersightTheme.accent2]),
                    boxShadow: [BoxShadow(color: CybersightTheme.accent.withOpacity(0.15), blurRadius: 12)],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.black, size: 24),
                ),
              ],
            ),

            const SizedBox(height: 28),

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
                padding: const EdgeInsets.only(top: 60),
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
                      const SizedBox(height: 20),
                      Text(
                        'NO EQUIPMENT FOUND',
                        style: GoogleFonts.plusJakartaSans(
                          color: CybersightTheme.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your digital inventory is currently empty.\nRun a neural scan to begin tracking assets.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_filteredItems == null || _filteredItems!.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
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
                      const SizedBox(height: 20),
                      Text(
                        'NO MATCHES FOUND',
                        style: GoogleFonts.plusJakartaSans(
                          color: CybersightTheme.accent.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No equipment matches your neural filter.\nTry a different keyword or brand.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.15),
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._filteredItems!.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _InventoryCard(
                  title: (item['brand'] ?? 'UNKNOWN').toString().toUpperCase(),
                  category: (item['metadata']?['category'] ?? 'CLIMATISEUR').toString().toUpperCase(),
                  serial: (item['model'] ?? 'N/A').toString().toUpperCase(),
                  status: 'VERIFIED',
                  statusColor: CybersightTheme.ok,
                  btu: (item['btu'] ?? 'N/A').toString(),
                ),
              )),
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

  const _InventoryCard({
    required this.title,
    required this.category,
    required this.serial,
    required this.status,
    required this.statusColor,
    required this.btu,
  });

  @override
  State<_InventoryCard> createState() => _InventoryCardState();
}

class _InventoryCardState extends State<_InventoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 0.98 : 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: _isHovered ? [
              BoxShadow(
                color: widget.statusColor.withOpacity(0.15),
                blurRadius: 15,
                spreadRadius: 1,
              )
            ] : [],
          ),
          child: CybersightCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _isHovered ? widget.statusColor.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                        border: Border.all(color: _isHovered ? widget.statusColor.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                      ),
                      child: Center(
                        child: Icon(Icons.ac_unit_rounded, color: widget.statusColor.withOpacity(_isHovered ? 0.8 : 0.4), size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14),
                          ),
                          Text(
                            '${widget.category} • ${widget.serial}',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                          ),
                        ],
                      ),
                    ),
                    _StatusIndicator(label: widget.status, color: widget.statusColor),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _MetaTag(label: 'CAPACITY', value: '${widget.btu} BTU'),
                    const SizedBox(width: 12),
                    _MetaTag(label: 'LAST SCAN', value: '24H AGO'),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isHovered ? 1.0 : 0.2,
                      child: Icon(Icons.arrow_forward_ios_rounded, color: widget.statusColor, size: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4, height: 4,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 4)]),
          ),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 7, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.8)),
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
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 6.5, fontWeight: FontWeight.w900, color: Colors.white24, letterSpacing: 1.2)),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white60)),
      ],
    );
  }
}
