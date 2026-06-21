import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';
import '../config/api_config.dart';
import 'star_rating.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inCart = cart.items.containsKey(product.id);
    final cs = Theme.of(context).colorScheme;
    final ratingsMap = context.watch<ProductsProvider>().ratings;
    final ratingData = ratingsMap[product.id.toString()] as Map<String, dynamic>?;
    final avgRating = (ratingData?['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (ratingData?['total_reviews'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Container(
                    width: double.infinity,
                    color: cs.surfaceContainerLow,
                    child: _buildImage(),
                  ),
                ),
                if (inCart)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'En carrito',
                        style: TextStyle(
                          color: AppColors.onSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface,
                height: 1.3,
              ),
            ),
          ),
          if (reviewCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
              child: StarRating(
                rating: avgRating,
                count: reviewCount,
                starSize: 11,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: GoogleFonts.montserrat(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (!inCart) {
                      cart.add(product);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.name} agregado'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } else {
                      cart.remove(product.id);
                    }
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: inCart
                          ? cs.surfaceContainer
                          : cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      inCart ? Icons.remove : Icons.add,
                      color: inCart ? cs.primary : Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final url = ApiConfig.productImage(product.imageUrl);
    if (url.isEmpty) {
      return const Center(
        child: Icon(Icons.inventory_2_outlined,
            color: AppColors.onSurfaceVariant, size: 40),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.primary),
      ),
      errorWidget: (_, __, ___) => const Center(
        child: Icon(Icons.inventory_2_outlined,
            color: AppColors.onSurfaceVariant, size: 40),
      ),
    );
  }
}
