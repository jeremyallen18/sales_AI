import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/cart_provider.dart';
import '../screens/catalog_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/chatbot_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  void _switchTab(int index) => setState(() => _tab = index);

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().count;

    final screens = [
      CatalogScreen(onGoToCart: () => _switchTab(2)),
      const _OffersPlaceholder(),
      const CartScreen(),
      const ChatbotScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: _OxxoNavBar(
        currentIndex: _tab,
        cartCount: cartCount,
        onTap: _switchTab,
      ),
    );
  }
}

// ── Barra de navegación OXXO ──────────────────────────────────────────────────

class _OxxoNavBar extends StatelessWidget {
  final int currentIndex;
  final int cartCount;
  final ValueChanged<int> onTap;

  const _OxxoNavBar({
    required this.currentIndex,
    required this.cartCount,
    required this.onTap,
  });

  static const _items = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    _NavItem(Icons.local_offer_outlined, Icons.local_offer, 'Ofertas'),
    _NavItem(Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'Carrito'),
    _NavItem(Icons.smart_toy_outlined, Icons.smart_toy_rounded, 'Asistente'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final isActive = currentIndex == i;
              final item = _items[i];
              return _NavButton(
                item: item,
                isActive: isActive,
                badge: (i == 2 && cartCount > 0) ? cartCount : null,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData outlineIcon;
  final IconData filledIcon;
  final String label;
  const _NavItem(this.outlineIcon, this.filledIcon, this.label);
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final int? badge;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isActive,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 14 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? item.filledIcon : item.outlineIcon,
                  color: isActive
                      ? AppColors.onSecondary
                      : AppColors.onSurfaceVariant,
                  size: 22,
                ),
                if (badge != null)
                  Positioned(
                    right: -7,
                    top: -7,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badge! > 9 ? '9+' : '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                item.label,
                style: const TextStyle(
                  color: AppColors.onSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Placeholder de Ofertas ────────────────────────────────────────────────────

class _OffersPlaceholder extends StatelessWidget {
  const _OffersPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ofertas')),
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined,
                size: 72, color: AppColors.outlineVariant),
            const SizedBox(height: 16),
            const Text(
              'Próximamente',
              style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
