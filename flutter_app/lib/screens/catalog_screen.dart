import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../main.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';
import 'cart_screen.dart';
import 'chatbot_screen.dart';
import 'settings_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductsProvider>().load();
    });
  }

  void _openCart() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductsProvider>();
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      appBar: _buildAppBar(cart),
      drawer: _AppDrawer(onReload: () => context.read<ProductsProvider>().load()),
      body: _buildBody(products),
      floatingActionButton: _CartFab(count: cart.count, onTap: _openCart),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(CartProvider cart) {
    return AppBar(
      backgroundColor: AppColors.navyBg,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, size: 26),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: const Text('MENÚ'),
      actions: [
        if (cart.count > 0)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cartAmber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cart.count} en carrito',
                  style: const TextStyle(
                    color: AppColors.navyBg,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────

  Widget _buildBody(ProductsProvider products) {
    if (products.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (products.error != null) {
      return _ErrorView(
        message: products.error!,
        onRetry: () => context.read<ProductsProvider>().load(),
      );
    }

    if (products.allProducts.isEmpty) {
      return const Center(
        child: Text('Sin productos disponibles',
            style: TextStyle(color: AppColors.textSec)),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.navyCard,
      onRefresh: () => context.read<ProductsProvider>().load(),
      child: _MenuList(productsByCategory: products.byCategory),
    );
  }
}

// ── Lista estilo menú ────────────────────────────────────────────────────────

class _MenuList extends StatelessWidget {
  final Map<String, List<Product>> productsByCategory;
  const _MenuList({required this.productsByCategory});

  @override
  Widget build(BuildContext context) {
    final categories = productsByCategory.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final cat = categories[i];
        final items = productsByCategory[cat]!;
        return _CategorySection(category: cat, products: items);
      },
    );
  }
}

// ── Sección de categoría ─────────────────────────────────────────────────────

class _CategorySection extends StatefulWidget {
  final String category;
  final List<Product> products;
  const _CategorySection({required this.category, required this.products});

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabecera de categoría ──
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  '>${widget.category}',
                  style: const TextStyle(
                    color: AppColors.catHeader,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.catHeader,
                  size: 18,
                ),
              ],
            ),
          ),
        ),

        // ── Productos ──
        if (_expanded)
          ...widget.products.map((p) => _ProductRow(product: p)),

        // ── Separador ──
        const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}

// ── Fila de producto ─────────────────────────────────────────────────────────

class _ProductRow extends StatelessWidget {
  final Product product;
  const _ProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inCart = cart.items.containsKey(product.id);
    final qty = inCart ? cart.items[product.id]!.quantity : 0;
    final hasImage = product.imageUrl.isNotEmpty;

    return InkWell(
      onTap: () => _handleTap(context, cart, inCart),
      splashColor: AppColors.navyLight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // ── Miniatura o bullet ──
            _ProductThumb(imageUrl: product.imageUrl, inCart: inCart,
                hasImage: hasImage),
            const SizedBox(width: 10),
            // ── Nombre ──
            Expanded(
              child: Text(
                product.name,
                style: TextStyle(
                  color: inCart ? AppColors.cartAmber : Colors.white,
                  fontSize: 14,
                  fontWeight: inCart ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            // ── Badge cantidad ──
            if (inCart)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cartAmber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('x$qty',
                    style: const TextStyle(
                        color: AppColors.navyBg,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            // ── Precio ──
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: TextStyle(
                color: inCart ? AppColors.cartAmber : AppColors.textSec,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext ctx, CartProvider cart, bool inCart) {
    if (!inCart) {
      cart.add(product);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('${product.name} agregado al carrito'),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      // Si ya está en carrito, mostrar opciones
      showModalBottomSheet(
        context: ctx,
        backgroundColor: AppColors.navyCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _CartQuickSheet(product: product),
      );
    }
  }
}

// ── Miniatura de producto ─────────────────────────────────────────────────────

class _ProductThumb extends StatelessWidget {
  final String imageUrl;
  final bool inCart;
  final bool hasImage;
  const _ProductThumb(
      {required this.imageUrl, required this.inCart, required this.hasImage});

  @override
  Widget build(BuildContext context) {
    if (!hasImage) {
      // Bullet de texto cuando no hay imagen
      return SizedBox(
        width: 36,
        child: Text(
          'o',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: inCart ? AppColors.cartAmber : AppColors.textSec,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final url = ApiConfig.productImage(imageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 36,
          height: 36,
          color: AppColors.navyLight,
          child: const Icon(Icons.image_outlined,
              size: 18, color: AppColors.textSec),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 36,
          height: 36,
          color: AppColors.navyLight,
          child: const Icon(Icons.broken_image_outlined,
              size: 18, color: AppColors.textSec),
        ),
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

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(product.name,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text('\$${product.price.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.catHeader)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _iconBtn(Icons.remove, () {
                cart.updateQuantity(product.id, qty - 1);
                if (qty - 1 <= 0) Navigator.pop(context);
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('$qty',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              _iconBtn(Icons.add, () {
                if (qty < product.stock) cart.updateQuantity(product.id, qty + 1);
              }),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    cart.remove(product.id);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  label: const Text('Quitar', style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
          width: 38, height: 38,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.navyLight, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
}

// ── FAB del carrito ───────────────────────────────────────────────────────────

class _CartFab extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _CartFab({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.navyCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.navyLight, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                color: Colors.white, size: 26),
          ),
          if (count > 0)
            Positioned(
              right: -4, top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.cartAmber,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.navyBg,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Drawer de navegación ─────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final VoidCallback onReload;
  const _AppDrawer({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.navyCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.navyBg,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.storefront, color: AppColors.catHeader, size: 36),
                  SizedBox(height: 10),
                  Text('Tienda',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text('Menú de productos',
                      style: TextStyle(color: AppColors.textSec, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Chatbot ──
            _drawerItem(
              context,
              icon: Icons.smart_toy_outlined,
              label: 'Asistente IA',
              subtitle: 'Recomendaciones de productos',
              color: AppColors.catHeader,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChatbotScreen()));
              },
            ),

            const Divider(color: AppColors.divider, height: 1),

            // ── Configuración ──
            _drawerItem(
              context,
              icon: Icons.settings_outlined,
              label: 'Configuración',
              subtitle: 'Dirección del servidor',
              color: AppColors.textSec,
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
                onReload();
              },
            ),

            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sales AI Store v1.0',
                  style: TextStyle(color: AppColors.divider, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.textSec, fontSize: 11)),
      onTap: onTap,
      horizontalTitleGap: 12,
    );
  }
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
            const Icon(Icons.wifi_off, size: 60, color: AppColors.textSec),
            const SizedBox(height: 16),
            const Text('Sin conexión al servidor',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: AppColors.textSec, fontSize: 12),
                textAlign: TextAlign.center),
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
