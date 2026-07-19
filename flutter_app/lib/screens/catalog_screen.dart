import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../main.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';
import '../widgets/star_rating.dart';
import 'reviews_screen.dart';
import 'settings_screen.dart';

class CatalogScreen extends StatefulWidget {
  final VoidCallback? onGoToCart;
  const CatalogScreen({super.key, this.onGoToCart});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pp = context.read<ProductsProvider>();
      pp.load();
      pp.loadRatings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductsProvider>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Tienda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (mounted) context.read<ProductsProvider>().load();
            },
          ),
        ],
      ),
      body: _buildBody(products),
    );
  }

  Widget _buildBody(ProductsProvider products) {
    if (products.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (products.error != null) {
      return _ErrorView(
        message: products.error!,
        onRetry: () => context.read<ProductsProvider>().load(),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<ProductsProvider>().load(),
      child: CustomScrollView(
        slivers: [
          // ── Banner Flash Sale ──
          const SliverToBoxAdapter(child: _FlashSaleBanner()),

          // ── Categorías ──
          if (products.byCategory.isNotEmpty)
            SliverToBoxAdapter(
              child: _CategoryRow(
                categories: products.byCategory.keys.toList()..sort(),
                selected: _selectedCategory,
                onSelect: (cat) => setState(() =>
                    _selectedCategory =
                        (_selectedCategory == cat) ? null : cat),
              ),
            ),

          // ── Título de sección ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                _selectedCategory ?? 'Todos los productos',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ),

          // ── Grid ──
          _buildProductGrid(products),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildProductGrid(ProductsProvider products) {
    final items = _selectedCategory != null
        ? (products.byCategory[_selectedCategory] ?? <Product>[])
        : products.allProducts;

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              'Sin productos disponibles',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => _ProductCard(product: items[i]),
          childCount: items.length,
        ),
      ),
    );
  }
}

// ── Banner Flash Sale ─────────────────────────────────────────────────────────

class _FlashSaleBanner extends StatelessWidget {
  const _FlashSaleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xBB000000), Colors.transparent],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'OFERTA DEL DÍA',
                    style: GoogleFonts.montserrat(
                      color: AppColors.onSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Lo mejor\nde la tienda',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Descubre nuestros productos',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selector de categorías ────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _CategoryRow({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  static const _catIcons = <String, IconData>{
    'snack': Icons.cookie_outlined,
    'botana': Icons.set_meal_outlined,
    'bebida': Icons.local_drink_outlined,
    'refresco': Icons.water_drop_outlined,
    'lácteo': Icons.egg_outlined,
    'confite': Icons.cake_outlined,
    'dulce': Icons.icecream_outlined,
    'abarrote': Icons.shopping_bag_outlined,
    'limpieza': Icons.cleaning_services_outlined,
    'higiene': Icons.soap_outlined,
    'pharma': Icons.medical_services_outlined,
    'caliente': Icons.fastfood_outlined,
  };

  IconData _iconFor(String cat) {
    final lower = cat.toLowerCase();
    for (final entry in _catIcons.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isSelected = selected == cat;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceContainerLow,
                    border:
                        Border.all(color: AppColors.outline, width: 1),
                  ),
                  child: Icon(
                    _iconFor(cat),
                    color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 60,
                  child: Text(
                    cat,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Tarjeta de producto OXXO ──────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inCart = cart.items.containsKey(product.id);
    final ratings = context.watch<ProductsProvider>().ratings;
    final rData = ratings[product.id.toString()];
    final avgRating = (rData?['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = (rData?['total_reviews'] as num?)?.toInt() ?? 0;

    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _handleTap(context, cart, inCart),
      child: Container(
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
            // ── Imagen ──
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Container(
                      width: double.infinity,
                      color: cs.surfaceContainerLow,
                      child: _ProductImage(imageUrl: product.imageUrl),
                    ),
                  ),
                  if (product.discountPct > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '−${product.discountPct % 1 == 0 ? product.discountPct.toInt() : product.discountPct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (inCart)
                    Positioned(
                      top: 6,
                      right: 6,
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
            // ── Nombre ──
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
            // ── Rating ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewsScreen(
                      productId: product.id,
                      entityName: product.name,
                    ),
                  ),
                ),
                child: avgRating > 0
                    ? StarRating(
                        rating: avgRating,
                        count: totalReviews,
                        starSize: 11,
                      )
                    : Text(
                        'Ver reseñas',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.primary,
                        ),
                      ),
              ),
            ),
            // ── Precio + botón ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (product.discountPct > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        Text(
                          '\$${(product.price * (1 - product.discountPct / 100)).toStringAsFixed(2)}',
                          style: GoogleFonts.montserrat(
                            color: const Color(0xFF16A34A),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: GoogleFonts.montserrat(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  GestureDetector(
                    onTap: () => _handleTap(context, cart, inCart),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: inCart
                            ? AppColors.surfaceContainer
                            : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        inCart ? Icons.edit_outlined : Icons.add,
                        color: inCart ? AppColors.primary : Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, CartProvider cart, bool inCart) {
    if (!inCart) {
      cart.add(product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} agregado al carrito'),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _CartQuickSheet(product: product),
      );
    }
  }
}

class _ProductImage extends StatelessWidget {
  final String imageUrl;
  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.productImage(imageUrl);
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

// ── Hoja rápida de carrito ────────────────────────────────────────────────────

class _CartQuickSheet extends StatelessWidget {
  final Product product;
  const _CartQuickSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final item = cart.items[product.id];
    final qty = item?.quantity ?? 0;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            product.name,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          if (product.discountPct > 0) ...[
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            Text(
              '\$${(product.price * (1 - product.discountPct / 100)).toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Color(0xFF16A34A), fontWeight: FontWeight.w700),
            ),
          ] else
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: TextStyle(
                  color: cs.primary, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _iconBtn(Icons.remove, () {
                cart.updateQuantity(product.id, qty - 1);
                if (qty - 1 <= 0) Navigator.pop(context);
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  '$qty',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              _iconBtn(Icons.add, () {
                if (qty < product.stock) {
                  cart.updateQuantity(product.id, qty + 1);
                }
              }),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    cart.remove(product.id);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  label:
                      const Text('Quitar', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Listo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outline),
          ),
          child: Icon(icon, color: AppColors.onSurface, size: 20),
        ),
      );
}

// ── Vista de error ────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off,
                size: 60, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Sin conexión al servidor',
              style: GoogleFonts.montserrat(
                color: AppColors.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
