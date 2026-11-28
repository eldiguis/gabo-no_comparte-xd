import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/circle_button.dart';
import '../../core/widgets/fade_slide_route.dart';
import '../../features/swipe_to_match/presentation/swipe_to_match_screen.dart';
import '../stores/nearby_stores_page.dart';
import 'models/garment.dart';

/// Helper: returns Unsplash CDN URL or the [source] itself if already a full URL.
String photo(String source, {int width = 800}) {
  if (source.startsWith('https://') || source.startsWith('http://')) {
    return source;
  }
  return 'https://images.unsplash.com/$source?auto=format&fit=crop&w=$width&q=85';
}

class ProductDetailPage extends StatefulWidget {
  final Garment product;
  final List<Garment>? catalog;
  final VoidCallback onAddToCart;
  final VoidCallback onTryWithAi;
  final void Function(Garment top, Garment bottom)? onTryOutfitInFittingRoom;
  final VoidCallback? onOpenCart;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const ProductDetailPage({
    super.key,
    required this.product,
    this.catalog,
    required this.onAddToCart,
    required this.onTryWithAi,
    this.onTryOutfitInFittingRoom,
    this.onOpenCart,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  String? size;
  String? color;
  int quantity = 1;
  int imageIndex = 0;
  late bool localFavorite;

  @override
  void initState() {
    super.initState();
    localFavorite = widget.isFavorite;
    final available = widget.product.availableSizes;
    if (available.isNotEmpty) {
      size = available.contains('M')
          ? 'M'
          : available.contains('38')
              ? '38'
              : available.first;
    } else {
      size = null;
    }

    final colors = widget.product.availableColors;
    if (colors.isNotEmpty) {
      color = colors.first;
    } else {
      color = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = [p.image];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Detalles',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenCart?.call();
                      },
                      icon: const Icon(Icons.shopping_basket_outlined),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 360,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'garment_photo_${p.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            photo(images[imageIndex], width: 950),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFECEAE4),
                              child: const Icon(Icons.checkroom,
                                  size: 72, color: muted),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        top: 12,
                        child: CircleButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 12,
                        child: CircleButton(
                          icon: localFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          onTap: () {
                            setState(() => localFavorite = !localFavorite);
                            widget.onToggleFavorite?.call();
                          },
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 12,
                        child: Column(
                          children: [
                            for (var i = 0; i < images.length; i++)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => imageIndex = i),
                                child: Container(
                                  margin: const EdgeInsets.only(top: 7),
                                  width: 48,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color:
                                          imageIndex == i ? ink : Colors.white,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    photo(images[i], width: 140),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const ColoredBox(color: line),
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
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.category.toUpperCase(),
                          style: const TextStyle(
                            color: muted,
                            fontSize: 10,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F0ED),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.productType.toUpperCase(),
                            style: const TextStyle(
                              color: ink,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Row(
                      children: [
                        Icon(Icons.star, color: ink, size: 15),
                        SizedBox(width: 4),
                        Text(
                          '4.8  Ratings',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '1.5k reseñas  •  3.4k vendidos',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          p.price,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 21,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'S/ 320.00',
                          style: TextStyle(
                            color: muted,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          color: const Color(0xFFF1F0ED),
                          child: const Text(
                            '15% OFF',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      p.description.trim().isNotEmpty
                          ? p.description.trim()
                          : 'Una pieza versátil, cómoda y de alta calidad. Diseñada para acompañarte con elegancia en cualquier ocasión.',
                      style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
                    ),
                    if (p.hasSizes && p.availableSizes.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      Text(
                        p.availableSizes.length == 1
                            ? 'TALLA DISPONIBLE'
                            : 'SELECCIONA TU TALLA',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: p.availableSizes
                            .map(
                              (value) => ChoiceChip(
                                label: Text(value),
                                selected: size == value,
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  setState(() => size = value);
                                },
                                selectedColor: ink,
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: size == value ? ink : line,
                                ),
                                labelStyle: TextStyle(
                                  color: size == value ? Colors.white : ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (p.hasColors && p.availableColors.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      Text(
                        p.availableColors.length == 1
                            ? 'COLOR DISPONIBLE'
                            : 'SELECCIONA COLOR',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: p.availableColors
                            .map(
                              (value) => ChoiceChip(
                                label: Text(value),
                                selected: color == value,
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  setState(() => color = value);
                                },
                                selectedColor: ink,
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: color == value ? ink : line,
                                ),
                                labelStyle: TextStyle(
                                  color: color == value ? Colors.white : ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        widget.onTryWithAi();
                      },
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Probarme esta prenda con IA'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        side: const BorderSide(color: line),
                        minimumSize: const Size(double.infinity, 44),
                        shape: const StadiumBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(
                          FadeSlideRoute<void>(
                            builder: (_) => SwipeToMatchScreen(
                              catalog: widget.catalog ?? [p],
                              initialGarment: p,
                              onAddOutfitToCart: (top, bottom) {
                                widget.onAddToCart();
                                widget.onAddToCart();
                              },
                              onTryOutfitInFittingRoom: (top, bottom) {
                                Navigator.pop(context);
                                if (widget.onTryOutfitInFittingRoom != null) {
                                  widget.onTryOutfitInFittingRoom!(top, bottom);
                                } else {
                                  widget.onTryWithAi();
                                }
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.style_outlined, size: 16),
                      label: const Text('Combinar en Swipe to Match'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        side: const BorderSide(color: line),
                        minimumSize: const Size(double.infinity, 44),
                        shape: const StadiumBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(
                          FadeSlideRoute<void>(
                            builder: (_) => NearbyStoresPage(product: p),
                          ),
                        );
                      },
                      icon: const Icon(Icons.location_on_outlined, size: 17),
                      label: const Text('Ver tiendas cercanas con stock'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        side: const BorderSide(color: line),
                        minimumSize: const Size(double.infinity, 44),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: line)),
          ),
          child: Row(
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: quantity > 1
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() => quantity--);
                            }
                          : null,
                      icon: const Icon(Icons.remove,
                          color: Colors.white, size: 16),
                    ),
                    Text(
                      '$quantity',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => quantity++);
                      },
                      icon: const Icon(Icons.add,
                          color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      for (var i = 0; i < quantity; i++) {
                        widget.onAddToCart();
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: ink,
                          elevation: 6,
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                                color: Color(0xFF2A2A2A), width: 1),
                          ),
                          duration: const Duration(seconds: 3),
                          content: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: lime,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check,
                                    color: ink, size: 14),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  () {
                                    final details = [
                                      if (p.hasSizes && size != null) 'Talla $size',
                                      if (p.hasColors && color != null) 'Color $color',
                                    ].join(' • ');
                                    return details.isNotEmpty
                                        ? '${widget.product.name} ($details) añadido a la bolsa'
                                        : '${widget.product.name} añadido a la bolsa';
                                  }(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          action: SnackBarAction(
                            label: 'VER BOLSA',
                            textColor: lime,
                            onPressed: () {
                              messenger.hideCurrentSnackBar();
                              widget.onOpenCart?.call();
                            },
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'AÑADIR A LA BOLSA',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: .4,
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
}
