import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../providers/branch_provider.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branchId =
          context.read<BranchProvider>().selectedBranch?.id;
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/api/branches/offers'
          '${branchId != null ? '?branch_id=$branchId' : ''}');
      final res =
          await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');
      final data = json.decode(res.body) as List<dynamic>;
      if (mounted) {
        setState(() => _offers =
            data.map((e) => e as Map<String, dynamic>).toList());
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final branch = context.watch<BranchProvider>().selectedBranch;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────
            SliverAppBar(
              pinned: true,
              expandedHeight: 120,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 14),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ofertas',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22),
                    ),
                    if (branch != null)
                      Text(
                        branch.name,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                  ],
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF930007), Color(0xFFE30613)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment(0.9, 0.6),
                    child: Icon(Icons.local_offer,
                        size: 72, color: Colors.white10),
                  ),
                ),
              ),
            ),

            // ── Cuerpo ───────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 56, color: AppColors.outlineVariant),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.onSurfaceVariant)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_offers.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_offer_outlined,
                          size: 72, color: AppColors.outlineVariant),
                      const SizedBox(height: 16),
                      const Text('Sin ofertas activas',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Text(
                        'El vendedor aún no ha publicado\npromocion​es para esta tienda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${_offers.length} oferta${_offers.length != 1 ? 's' : ''} disponible${_offers.length != 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _OfferCard(offer: _offers[i]),
                    childCount: _offers.length,
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

// ── Tarjeta de oferta ─────────────────────────────────────────────────────────

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = offer['name'] as String? ?? '';
    final price = (offer['price'] as num?)?.toDouble() ?? 0;
    final discPct = (offer['discount_pct'] as num?)?.toDouble() ?? 0;
    final badge = offer['offer_badge'] as String?;
    final imageUrl = offer['image_url'] as String?;
    final branchName = offer['branch_name'] as String?;
    final stock = (offer['stock'] as num?)?.toInt() ?? 0;
    final discPrice = price * (1 - discPct / 100);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _addToCart(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen + badges
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    color: cs.surfaceContainerLow,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey),
                          )
                        : const Icon(Icons.local_offer_outlined,
                            size: 52, color: Colors.grey),
                  ),
                ),
                // Badge descuento
                if (discPct > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '−${discPct.round()}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                // Badge personalizado
                if (badge != null)
                  Positioned(
                    top: discPct > 0 ? 32 : 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                            color: AppColors.onSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                // Stock bajo
                if (stock > 0 && stock <= 5)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '¡Últimos $stock!',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    if (branchName != null) ...[
                      const SizedBox(height: 2),
                      Text(branchName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant)),
                    ],
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if (discPct > 0)
                                Text(
                                  '\$${price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: cs.onSurfaceVariant,
                                      decoration:
                                          TextDecoration.lineThrough),
                                ),
                              Text(
                                '\$${discPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: discPct > 0
                                        ? Colors.green[700]
                                        : AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 18),
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
    );
  }

  void _addToCart(BuildContext context) {
    final productId = offer['product_id'] as int?;
    if (productId == null) return;
    final product = Product(
      id: productId,
      name: offer['name'] as String? ?? '',
      price: (offer['price'] as num?)?.toDouble() ?? 0,
      stock: (offer['stock'] as num?)?.toInt() ?? 1,
      category: offer['category'] as String? ?? 'General',
      imageUrl: offer['image_url'] as String? ?? '',
      discountPct: (offer['discount_pct'] as num?)?.toDouble() ?? 0,
    );
    context.read<CartProvider>().add(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} agregado al carrito'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
