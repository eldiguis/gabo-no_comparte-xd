import 'package:flutter/material.dart';

const Color _kInk = Color(0xFF171717);
const Color _kLine = Color(0xFFE6E4DE);

/// ============================================================================
/// 1. EFECTO SHIMMER (BARRIDO DE LUZ SUAVE) - PURO FLUTTER (Sin dependencias)
/// ============================================================================
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFE8E6E0),
                Color(0xFFF9F8F5),
                Color(0xFFE8E6E0),
              ],
              stops: [
                (_animation.value - 0.35).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.35).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// ============================================================================
/// 2. SKELETON DE TARJETA DE PRENDA (RESPETA EXACTO EL LAYOUT .59)
/// ============================================================================
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cuadro de imagen de prenda
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E6E0),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
        const SizedBox(height: 9),
        // Barra categoría
        Container(
          width: 50,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFE8E6E0),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        // Fila nombre y precio
        Row(
          children: [
            Expanded(
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E6E0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 42,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E6E0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ============================================================================
/// 3. CUADRÍCULA SLIVER SKELETON PARA CATÁLOGO Y TIENDA
/// ============================================================================
class ProductGridSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsets padding;

  const ProductGridSkeleton({
    super.key,
    this.count = 4,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, _) => const ProductCardSkeleton(),
            childCount: count,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: .59,
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// 4. SKELETON PARA LISTA DE TIENDAS Y STOCK GPS
/// ============================================================================
class StoreListSkeleton extends StatelessWidget {
  const StoreListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kLine),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8E6E0),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E6E0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E6E0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 90,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E6E0),
                        borderRadius: BorderRadius.circular(4),
                      ),
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
}

/// ============================================================================
/// 5. EMPTY STATE VANGUARDISTA Y EDITORIAL (Reemplaza cuadros vacíos)
/// ============================================================================
class EditorialEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  const EditorialEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.checkroom_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F2EE),
                shape: BoxShape.circle,
                border: Border.all(color: _kLine),
              ),
              child: Center(
                child: Icon(icon, size: 32, color: _kInk),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF898780),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kInk,
                  side: const BorderSide(color: _kInk, width: 1.2),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
