import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _InventoryPageState extends State<InventoryPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final itemId = item['item_id'] as String?;
    if (itemId == null) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _allInventoryItems?.remove(item);
      _filteredItems?.remove(item);
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 17),
            const SizedBox(width: 10),
            Text(
              'Item removed',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ]),
          backgroundColor: const Color(0xFF151B2A),
          duration: const Duration(milliseconds: 2000),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );

    // Fire-and-forget — never dismiss the snackbar ourselves.
    // If the call fails, reload silently so the item reappears.
    _apiService.deleteInventoryItem(itemId).then((success) {
      if (!success && mounted) _loadInventory();
    });
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
      if (_selectedCategory != 'ALL') {
        temp = temp.where((item) {
          final metadata = item['metadata'] as Map<String, dynamic>? ?? {};
          final category = (metadata['category'] ?? item['category'] ?? '').toString().toLowerCase();
          final eqType = (metadata['equipment_type'] ?? item['equipment_type'] ?? '').toString().toLowerCase();
          final full = '$category $eqType';
          switch (_selectedCategory) {
            case 'CLIMATISEURS': return full.contains('air') || full.contains('clim');
            case 'RÉFRIGÉRATEURS': return full.contains('ref') || full.contains('kitchen');
            case 'LAPTOPS': return full.contains('lap') || full.contains('pc') || full.contains('computer');
            case 'MONITORS': return full.contains('mon') || full.contains('screen') || full.contains('disp') || full.contains('tv');
            case 'MICROWAVES': return full.contains('micro') || full.contains('oven');
            default: return true;
          }
        }).toList();
      }
      if (query.isNotEmpty) {
        final q = query.toLowerCase().trim();
        temp = temp.where((item) {
          final brand = (item['brand'] ?? '').toString().toLowerCase();
          final model = (item['model'] ?? '').toString().toLowerCase();
          final btu = (item['btu'] ?? '').toString().toLowerCase();
          final metadata = item['metadata'] as Map<String, dynamic>? ?? {};
          final category = (metadata['category'] ?? item['category'] ?? '').toString().toLowerCase();
          final eqType = (metadata['equipment_type'] ?? item['equipment_type'] ?? '').toString().toLowerCase();
          final specsStr = (metadata['specs'] ?? {}).toString().toLowerCase();
          final summary = (metadata['summary'] ?? '').toString().toLowerCase();
          return brand.contains(q) || model.contains(q) || category.contains(q) ||
                 eqType.contains(q) || btu.contains(q) || specsStr.contains(q) || summary.contains(q);
        }).toList();
      }
      _filteredItems = temp;
    });
  }

  List<String> _deriveFilterCategories() {
    final Set<String> cats = {'ALL'};
    if (_allInventoryItems == null) return cats.toList();
    for (final item in _allInventoryItems!) {
      final metadata = item['metadata'] as Map<String, dynamic>? ?? {};
      String cat = (metadata['category'] ?? '').toString().trim().toUpperCase();
      if (cat.isEmpty || cat == 'UNKNOWN' || cat == 'EQUIPMENT') {
        cat = (metadata['equipment_type'] ?? item['equipment_type'] ?? '').toString().trim().toUpperCase();
      }
      if (cat.contains('AIR') || cat.contains('CLIM')) cats.add('CLIMATISEURS');
      else if (cat.contains('REF')) cats.add('RÉFRIGÉRATEURS');
      else if (cat.contains('MICRO')) cats.add('MICROWAVES');
      else if (cat.contains('LAP')) cats.add('LAPTOPS');
      else if (cat.contains('MON') || cat.contains('SCREEN') || cat.contains('DISPLAY') || cat.contains('TV')) cats.add('MONITORS');
      else if (cat.isNotEmpty) cats.add(cat);
    }
    final list = cats.toList()..sort();
    if (list.first != 'ALL') { list.remove('ALL'); list.insert(0, 'ALL'); }
    return list;
  }

  Color _categoryColor(String cat) {
    if (cat.contains('CLIM') || cat.contains('AIR')) return CybersightTheme.accent;
    if (cat.contains('REF')) return CybersightTheme.ok;
    if (cat.contains('LAP')) return const Color(0xFFB84DFF);
    if (cat.contains('MON') || cat.contains('SCREEN')) return const Color(0xFF4DFFB8);
    if (cat.contains('MICRO')) return const Color(0xFFFF6B9D);
    return CybersightTheme.accent;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final totalCount = _allInventoryItems?.length ?? 0;
    final shownCount = _filteredItems?.length ?? 0;
    final isFiltered = _selectedCategory != 'ALL' || _searchController.text.isNotEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadInventory,
        color: CybersightTheme.accent,
        backgroundColor: CybersightTheme.navy2,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ─────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventory',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 32,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _isLoading ? 'Loading assets...' : '$totalCount asset${totalCount != 1 ? 's' : ''} tracked',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.white30,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Count badge
                        if (!_isLoading && totalCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: CybersightTheme.accent.withOpacity(0.08),
                              border: Border.all(color: CybersightTheme.accent.withOpacity(0.22)),
                            ),
                            child: Text(
                              '$totalCount',
                              style: GoogleFonts.plusJakartaSans(
                                color: CybersightTheme.accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ── Search ─────────────────────────────────────────
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withOpacity(0.04),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterInventory,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search brand, model, specs…',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: Colors.white24,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white24, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterInventory('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Filter chips ───────────────────────────────────
                    _buildFilterChips(),

                    // ── Result count ───────────────────────────────────
                    if (!_isLoading && isFiltered && (_filteredItems?.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Text(
                          '$shownCount result${shownCount != 1 ? 's' : ''}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white24,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── List ─────────────────────────────────────────────────
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 40),
                  child: _SkeletonList(),
                ),
              )
            else if (_allInventoryItems == null || _allInventoryItems!.isEmpty)
              SliverFillRemaining(child: _EmptyState())
            else if (_filteredItems == null || _filteredItems!.isEmpty)
              SliverFillRemaining(child: _NoResultsState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _filteredItems![index] as Map<String, dynamic>;
                      final itemId = item['item_id']?.toString() ?? 'item_$index';
                      return Dismissible(
                        key: Key(itemId),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteItem(item),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: Colors.red.withOpacity(0.12),
                            border: Border.all(color: Colors.red.withOpacity(0.28)),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 400 + index * 50),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _InventoryCard(
                              item: item,
                              onTap: () => _openDetail(context, item),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _filteredItems!.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildFilterChips() {
    final categories = _deriveFilterCategories();
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          final color = _categoryColor(cat);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = cat);
                _filterInventory(_searchController.text);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isSelected ? color.withOpacity(0.14) : Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: isSelected ? color.withOpacity(0.45) : Colors.white.withOpacity(0.07),
                    width: isSelected ? 1.2 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Container(
                        width: 5, height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [BoxShadow(color: color, blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      cat,
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? color : Colors.white38,
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.6,
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

  void _openDetail(BuildContext context, Map<String, dynamic> item) {
    final metadata = item['metadata'] as Map<String, dynamic>? ?? {};
    const nonSpecKeys = {
      'category', 'equipment_category', 'equipment_type',
      'ai_image', 'annotated_image', 'summary', 'pipeline',
      'source_quality', 'fields_found', 'source_urls',
      'verified', 'brand', 'model', 'price_tnd', 'price',
    };
    final specs = Map<String, dynamic>.from(metadata)
      ..removeWhere((k, _) => nonSpecKeys.contains(k.toLowerCase()));
    if (item['btu'] != null) specs['capacity_btu'] = item['btu'];

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
  }
}

// ── Inventory Card ─────────────────────────────────────────────────────────

class _InventoryCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _InventoryCard({required this.item, required this.onTap});

  @override
  State<_InventoryCard> createState() => _InventoryCardState();
}

class _InventoryCardState extends State<_InventoryCard> {
  bool _pressed = false;

  IconData _icon(String cat) {
    cat = cat.toUpperCase();
    if (cat.contains('AIR') || cat.contains('CLIM')) return Icons.ac_unit_rounded;
    if (cat.contains('REF')) return Icons.kitchen_rounded;
    if (cat.contains('MICRO')) return Icons.microwave_rounded;
    if (cat.contains('LAP')) return Icons.laptop_rounded;
    if (cat.contains('MON') || cat.contains('SCREEN') || cat.contains('DISP')) return Icons.monitor_rounded;
    return Icons.memory_rounded;
  }

  Color _color(String cat) {
    cat = cat.toUpperCase();
    if (cat.contains('AIR') || cat.contains('CLIM')) return CybersightTheme.accent;
    if (cat.contains('REF')) return CybersightTheme.ok;
    if (cat.contains('LAP')) return const Color(0xFFB84DFF);
    if (cat.contains('MON') || cat.contains('SCREEN') || cat.contains('DISP')) return const Color(0xFF4DFFB8);
    if (cat.contains('MICRO')) return const Color(0xFFFF6B9D);
    return CybersightTheme.accent;
  }

  String _specValue() {
    final metadata = widget.item['metadata'] as Map<String, dynamic>? ?? {};
    final category = (metadata['category'] ?? 'unknown').toString().toLowerCase();
    if (category.contains('air') || category.contains('clim')) {
      final btu = widget.item['btu'] ?? metadata['capacity_btu'];
      return btu != null ? '$btu BTU' : '— BTU';
    }
    if (category.contains('ref')) {
      final l = metadata['capacity_liters'] ?? metadata['specs']?['capacity_liters'];
      return l != null ? '$l L' : '— L';
    }
    if (category.contains('micro')) {
      final l = metadata['capacity_liters'];
      final w = metadata['power_watts'];
      if (l != null && w != null) return '$l L • $w W';
      if (l != null) return '$l L';
      if (w != null) return '$w W';
      return '—';
    }
    if (category.contains('lap')) {
      final ram = metadata['ram_gb'];
      final storage = metadata['storage'];
      if (ram != null && storage != null) return '${ram}GB • $storage';
      final cpu = metadata['cpu'];
      return cpu?.toString() ?? '—';
    }
    if (category.contains('mon') || category.contains('screen') || category.contains('disp')) {
      final size = metadata['screen_size_inches'];
      final res = metadata['resolution'];
      if (size != null && res != null) return '${size}" $res';
      if (size != null) return '${size}"';
      return '—';
    }
    final btu = widget.item['btu'];
    if (btu != null) return '$btu BTU';
    return 'VERIFIED';
  }

  String _date() {
    final raw = widget.item['added_at'];
    if (raw == null) return 'Recently';
    try {
      final dt = DateTime.parse(raw.toString());
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return 'Recently'; }
  }

  @override
  Widget build(BuildContext context) {
    final brand = (widget.item['brand'] ?? 'Unknown').toString();
    final model = (widget.item['model'] ?? '').toString();
    final metadata = widget.item['metadata'] as Map<String, dynamic>? ?? {};
    final rawCat = (metadata['category'] ?? metadata['equipment_type'] ?? 'Equipment').toString();
    final catLabel = rawCat.replaceAll('_', ' ');
    final accent = _color(rawCat);
    final specVal = _specValue();
    final dateStr = _date();
    final aiImage = metadata['ai_image']?.toString() ?? metadata['annotated_image']?.toString();

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_pressed ? 0.974 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: _pressed
              ? [BoxShadow(color: accent.withOpacity(0.15), blurRadius: 24, spreadRadius: 1)]
              : [],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withOpacity(_pressed ? 0.055 : 0.03),
            border: Border.all(
              color: _pressed ? accent.withOpacity(0.28) : Colors.white.withOpacity(0.07),
              width: _pressed ? 1.2 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Left accent bar
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent.withOpacity(0.0), accent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),

                  // Card body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon badge
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  color: accent.withOpacity(0.10),
                                  border: Border.all(color: accent.withOpacity(0.22)),
                                ),
                                child: Center(
                                  child: Icon(_icon(rawCat), color: accent, size: 20),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Brand + model + category chip
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      brand,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontSize: 15,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    if (model.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        model,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    // Category chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        color: accent.withOpacity(0.10),
                                        border: Border.all(color: accent.withOpacity(0.25)),
                                      ),
                                      child: Text(
                                        catLabel.toUpperCase(),
                                        style: GoogleFonts.plusJakartaSans(
                                          color: accent,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              // Thumbnail or VERIFIED badge
                              if (aiImage != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    base64Decode(aiImage),
                                    width: 54,
                                    height: 54,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: CybersightTheme.ok.withOpacity(0.06),
                                    border: Border.all(color: CybersightTheme.ok.withOpacity(0.22)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 4, height: 4,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: CybersightTheme.ok,
                                          boxShadow: [BoxShadow(color: CybersightTheme.ok, blurRadius: 4)],
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'OK',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: CybersightTheme.ok,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 14),
                          Container(height: 1, color: Colors.white.withOpacity(0.05)),
                          const SizedBox(height: 12),

                          // Bottom row — spec + date + arrow
                          Row(
                            children: [
                              // Spec pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: accent.withOpacity(0.07),
                                ),
                                child: Text(
                                  specVal,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                dateStr,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white24,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: accent.withOpacity(_pressed ? 0.9 : 0.35),
                                size: 12,
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

// ── Skeleton loading ───────────────────────────────────────────────────────

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Column(
        children: List.generate(5, (i) => _SkeletonCard(t: _anim.value, index: i)),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double t;
  final int index;
  const _SkeletonCard({required this.t, required this.index});

  @override
  Widget build(BuildContext context) {
    // Stagger: each card's phase is offset so they ripple like a wave
    final phase = ((t + index * 0.15) % 1.0);
    final opacity = 0.04 + phase * 0.07;

    Widget box(double w, double h, {double radius = 6, double? opacityScale}) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: Colors.white.withOpacity(opacity * (opacityScale ?? 1.0)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar
              Container(width: 3, color: Colors.white.withOpacity(opacity)),
              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon badge
                          box(46, 46, radius: 13),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                box(90, 14),
                                const SizedBox(height: 8),
                                box(130, 11, opacityScale: 0.7),
                                const SizedBox(height: 8),
                                box(64, 20, radius: 999, opacityScale: 0.55),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Thumbnail
                          box(54, 54, radius: 10, opacityScale: 0.65),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(height: 1, color: Colors.white.withOpacity(0.05)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          box(60, 26, radius: 8, opacityScale: 0.6),
                          const Spacer(),
                          box(38, 10, radius: 4, opacityScale: 0.45),
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
    );
  }
}

// ── Empty / No-results states ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CybersightTheme.accent.withOpacity(0.05),
                border: Border.all(color: CybersightTheme.accent.withOpacity(0.18)),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: CybersightTheme.accent, size: 34),
            ),
            const SizedBox(height: 22),
            Text(
              'Empty Inventory',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No equipment tracked yet.\nRun a scan and save your first detection.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white38,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Icon(Icons.search_off_rounded, color: Colors.white24, size: 30),
            ),
            const SizedBox(height: 20),
            Text(
              'No Matches',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different keyword or clear the filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
