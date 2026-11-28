import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../catalog/models/garment.dart';
import '../../onboarding/user_guide_dialogs.dart';
import '../models/capsule_outfit.dart';

const Color _kInk = Color(0xFF171717);
const Color _kPaper = Color(0xFFFAF9F6);
const Color _kLine = Color(0xFFE6E4DE);
const Color _kLime = Color(0xFFD7FF55);
const Color _kMuted = Color(0xFF737373);

/// Pantalla interactiva "Swipe to Match" (Outfit Matcher)
/// Permite combinar prendas superiores e inferiores con gestos de deslizamiento (swipe),
/// visualizar la armonía y precio del conjunto, bloquear prendas favoritas
/// y agregar todo el conjunto a la bolsa o al probador IA en 1 clic.
class SwipeToMatchScreen extends StatefulWidget {
  final List<Garment> catalog;
  final Garment? initialGarment;
  final void Function(Garment top, Garment bottom) onAddOutfitToCart;
  final void Function(Garment top, Garment bottom) onTryOutfitInFittingRoom;

  const SwipeToMatchScreen({
    super.key,
    required this.catalog,
    this.initialGarment,
    required this.onAddOutfitToCart,
    required this.onTryOutfitInFittingRoom,
  });

  @override
  State<SwipeToMatchScreen> createState() => _SwipeToMatchScreenState();
}

class _SwipeToMatchScreenState extends State<SwipeToMatchScreen> {
  late List<Garment> _tops;
  late List<Garment> _bottoms;

  late PageController _topController;
  late PageController _bottomController;

  int _currentTopIndex = 0;
  int _currentBottomIndex = 0;

  bool _isTopLocked = false;
  bool _isBottomLocked = false;

  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _setupGarments();

    _topController = PageController(
      initialPage: _currentTopIndex,
      viewportFraction: 0.82,
    );
    _bottomController = PageController(
      initialPage: _currentBottomIndex,
      viewportFraction: 0.82,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstTimeGuide());
  }

  Future<void> _checkFirstTimeGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('has_seen_swipe_to_match_guide') ?? false;
      if (!hasSeen && mounted) {
        await prefs.setBool('has_seen_swipe_to_match_guide', true);
        _showGuide();
      }
    } catch (_) {}
  }

  void _showGuide() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SwipeToMatchGuideDialog(),
    );
  }

  void _setupGarments() {
    final split = GarmentClassifier.splitCatalog(
      widget.catalog,
      initialGarment: widget.initialGarment,
    );
    _tops = split.tops;
    _bottoms = split.bottoms;

    // Si se pasa una prenda inicial desde el detalle, la posicionamos con precisión y la fijamos
    final init = widget.initialGarment;
    if (init != null) {
      if (GarmentClassifier.isBottom(init)) {
        final botIdx = _bottoms.indexWhere((g) => g.id == init.id);
        if (botIdx != -1) {
          _currentBottomIndex = botIdx;
          _isBottomLocked = true;
        } else {
          _bottoms.insert(0, init);
          _currentBottomIndex = 0;
          _isBottomLocked = true;
        }
      } else {
        final topIdx = _tops.indexWhere((g) => g.id == init.id);
        if (topIdx != -1) {
          _currentTopIndex = topIdx;
          _isTopLocked = true;
        } else {
          _tops.insert(0, init);
          _currentTopIndex = 0;
          _isTopLocked = true;
        }
      }
    }
  }

  @override
  void dispose() {
    _topController.dispose();
    _bottomController.dispose();
    super.dispose();
  }

  Garment? get currentTop =>
      _tops.isNotEmpty && _currentTopIndex < _tops.length ? _tops[_currentTopIndex] : null;

  Garment? get currentBottom =>
      _bottoms.isNotEmpty && _currentBottomIndex < _bottoms.length ? _bottoms[_currentBottomIndex] : null;

  CapsuleOutfit? get currentOutfit {
    final t = currentTop;
    final b = currentBottom;
    if (t == null || b == null) return null;
    return CapsuleOutfit(top: t, bottom: b);
  }

  void _shuffleOutfit() {
    HapticFeedback.mediumImpact();
    if (_tops.isEmpty || _bottoms.isEmpty) return;

    if (!_isTopLocked && _tops.length > 1) {
      int nextTop;
      do {
        nextTop = _random.nextInt(_tops.length);
      } while (nextTop == _currentTopIndex && _tops.length > 1);
      _topController.animateToPage(
        nextTop,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }

    if (!_isBottomLocked && _bottoms.length > 1) {
      int nextBottom;
      do {
        nextBottom = _random.nextInt(_bottoms.length);
      } while (nextBottom == _currentBottomIndex && _bottoms.length > 1);
      _bottomController.animateToPage(
        nextBottom,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎲 ¡Look aleatorio generado! Desliza para ajustar.'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outfit = currentOutfit;

    return Scaffold(
      backgroundColor: _kPaper,
      appBar: AppBar(
        backgroundColor: _kPaper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kInk),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Volver',
        ),
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'SWIPE TO MATCH',
              style: TextStyle(
                color: _kInk,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'Arma tu cápsula deslizando prendas',
              style: TextStyle(color: _kMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showGuide,
            icon: const Icon(Icons.help_outline, color: _kInk),
            tooltip: 'Guía de Swipe to Match',
          ),
          IconButton(
            onPressed: _shuffleOutfit,
            icon: const Icon(Icons.casino_outlined, color: _kInk),
            tooltip: 'Look aleatorio (Shuffle)',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _tops.isEmpty || _bottoms.isEmpty
          ? const Center(
              child: Text(
                'No hay suficientes prendas disponibles en el catálogo.',
                style: TextStyle(color: _kMuted),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Carrusel Superior (Tops)
                  Expanded(
                    flex: 48,
                    child: _buildTopCarousel(),
                  ),

                  // Barra Central de Match y Vibe
                  _buildMatchBridge(outfit),

                  // Carrusel Inferior (Bottoms / Calzado)
                  Expanded(
                    flex: 48,
                    child: _buildBottomCarousel(),
                  ),

                  // Barra Inferior de Acción y Precio Combinado
                  _buildBottomActionBar(outfit),
                ],
              ),
            ),
    );
  }

  // ==========================================
  // CARRUSEL SUPERIOR (TOPS)
  // ==========================================
  Widget _buildTopCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _kInk,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PRENDA SUPERIOR (${_currentTopIndex + 1}/${_tops.length})',
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isTopLocked = !_isTopLocked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isTopLocked ? _kLime : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isTopLocked ? _kLime : _kLine,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isTopLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 13,
                        color: _isTopLocked ? _kInk : _kMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isTopLocked ? 'Fijado' : 'Fijar',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _isTopLocked ? _kInk : _kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _topController,
            physics: _isTopLocked
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: _tops.length,
            onPageChanged: (index) {
              HapticFeedback.selectionClick();
              setState(() => _currentTopIndex = index);
            },
            itemBuilder: (context, index) {
              final garment = _tops[index];
              final isSelected = index == _currentTopIndex;
              return _GarmentCard(
                garment: garment,
                isSelected: isSelected,
                isLocked: _isTopLocked && isSelected,
                isTop: true,
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BARRA CENTRAL DE COMPATIBILIDAD ("MATCH BRIDGE")
  // ==========================================
  Widget _buildMatchBridge(CapsuleOutfit? outfit) {
    if (outfit == null) return const SizedBox(height: 12);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kLime,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${outfit.compatibilityScore}% MATCH',
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                outfit.vibeTitle,
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Icon(Icons.swap_vert_rounded, size: 18, color: _kMuted),
        ],
      ),
    );
  }

  // ==========================================
  // CARRUSEL INFERIOR (BOTTOMS)
  // ==========================================
  Widget _buildBottomCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _kInk,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PRENDA INFERIOR (${_currentBottomIndex + 1}/${_bottoms.length})',
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isBottomLocked = !_isBottomLocked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isBottomLocked ? _kLime : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isBottomLocked ? _kLime : _kLine,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isBottomLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 13,
                        color: _isBottomLocked ? _kInk : _kMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isBottomLocked ? 'Fijado' : 'Fijar',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _isBottomLocked ? _kInk : _kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _bottomController,
            physics: _isBottomLocked
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: _bottoms.length,
            onPageChanged: (index) {
              HapticFeedback.selectionClick();
              setState(() => _currentBottomIndex = index);
            },
            itemBuilder: (context, index) {
              final garment = _bottoms[index];
              final isSelected = index == _currentBottomIndex;
              return _GarmentCard(
                garment: garment,
                isSelected: isSelected,
                isLocked: _isBottomLocked && isSelected,
                isTop: false,
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BARRA INFERIOR DE ACCIÓN Y TOTAL
  // ==========================================
  Widget _buildBottomActionBar(CapsuleOutfit? outfit) {
    if (outfit == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kLine)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL DEL CONJUNTO',
                    style: TextStyle(
                      color: _kMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    outfit.formattedTotalPrice,
                    style: const TextStyle(
                      color: _kInk,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Text(
                '${outfit.top.price.trim()} + ${outfit.bottom.price.trim()}',
                style: const TextStyle(
                  color: _kMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Botón Probar en Probador IA
              Expanded(
                flex: 45,
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onTryOutfitInFittingRoom(outfit.top, outfit.bottom);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text(
                    'Probar en IA',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kInk,
                    side: const BorderSide(color: _kLine, width: 1.5),
                    minimumSize: const Size(double.infinity, 44),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botón Añadir Conjunto Completo a la Bolsa
              Expanded(
                flex: 55,
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onAddOutfitToCart(outfit.top, outfit.bottom);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '¡Conjunto añadido! (${outfit.top.name} + ${outfit.bottom.name})',
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(milliseconds: 2000),
                        action: SnackBarAction(
                          label: 'VER BOLSA',
                          textColor: _kLime,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                  label: const Text(
                    'Añadir conjunto',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kInk,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de prenda con animación sutil de escala al estar activa
class _GarmentCard extends StatelessWidget {
  final Garment garment;
  final bool isSelected;
  final bool isLocked;
  final bool isTop;

  const _GarmentCard({
    required this.garment,
    required this.isSelected,
    required this.isLocked,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked
                ? _kLime
                : (isSelected ? _kInk : _kLine),
            width: isLocked ? 2.5 : (isSelected ? 1.5 : 1.0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Foto de la prenda
              Image.network(
                garment.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFF0EFEB),
                  child: Center(
                    child: Icon(
                      isTop ? Icons.dry_cleaning_outlined : Icons.snowshoeing_outlined,
                      size: 40,
                      color: _kMuted,
                    ),
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFFF5F4F0),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kInk,
                      ),
                    ),
                  );
                },
              ),

              // Degradado inferior para legibilidad
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Información sobreimpresa
              Positioned(
                bottom: 8,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            garment.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            garment.tag,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kLime,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        garment.price,
                        style: const TextStyle(
                          color: _kInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Indicador de Fijado en la esquina superior
              if (isLocked)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: _kLime,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: _kInk,
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
