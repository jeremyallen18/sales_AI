import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../main.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';

// ── Modelo de mensaje ─────────────────────────────────────────────────────────

class _Msg {
  final String text;
  final bool isUser;
  final bool isError;
  final List<Product> mentioned;

  const _Msg({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.mentioned = const [],
  });
}

// ── Pantalla principal ────────────────────────────────────────────────────────

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_Msg> _msgs = [];
  // Mensajes que ya reprodujeron su animación de entrada (evita re-animar
  // cuando el ListView reconstruye tiles al hacer scroll).
  final Set<_Msg> _animated = {};
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _thinking = false;

  static const List<String> _suggestions = [
    '¿Qué me recomiendas hoy?',
    '¿Qué chocolates tienen?',
    '¿Cuáles son los más baratos?',
    '¿Tienen botanas saladas?',
  ];

  @override
  void initState() {
    super.initState();
    _msgs.add(const _Msg(
      text: '¡Hola! 👋 Soy tu asistente de tienda. Puedo recomendarte '
          'productos y ayudarte a encontrar lo que buscas. ¿En qué te ayudo?',
      isUser: false,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pp = context.read<ProductsProvider>();
      if (pp.allProducts.isEmpty && !pp.loading) pp.load();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<Product> _findMentioned(String text, List<Product> catalog) {
    final lower = text.toLowerCase();
    return catalog.where((p) {
      return p.name.length >= 4 && lower.contains(p.name.toLowerCase());
    }).toList();
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _thinking) return;
    _ctrl.clear();

    setState(() {
      _msgs.add(_Msg(text: msg, isUser: true));
      _thinking = true;
    });
    _scrollToBottom();

    try {
      final response = await ApiService.sendChatMessage(msg);
      if (!mounted) return;
      final catalog = context.read<ProductsProvider>().allProducts;
      final mentioned = _findMentioned(response, catalog);
      setState(() => _msgs.add(_Msg(
            text: response,
            isUser: false,
            mentioned: mentioned,
          )));
    } catch (e) {
      if (!mounted) return;
      setState(() => _msgs.add(const _Msg(
            text: 'Lo siento, no pude conectarme al asistente. '
                'Verifica la conexión en Configuración.',
            isUser: false,
            isError: true,
          )));
    } finally {
      if (mounted) setState(() => _thinking = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.smart_toy_outlined, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text('Asistente IA'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _msgs.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _msgs.length) {
                  return const _AnimatedIn(
                    fromRight: false,
                    child: _TypingBubble(),
                  );
                }
                final msg = _msgs[i];
                return _AnimatedIn(
                  // Set.add devuelve true solo la primera vez que se ve el
                  // mensaje: anima la entrada una única vez.
                  animate: _animated.add(msg),
                  fromRight: msg.isUser,
                  child: _MsgTile(msg: msg),
                );
              },
            ),
          ),
          if (_msgs.length == 1 && !_thinking)
            _SuggestionRow(suggestions: _suggestions, onTap: _send),
          _InputBar(ctrl: _ctrl, onSend: _send, enabled: !_thinking),
        ],
      ),
    );
  }
}

// ── Animaciones de entrada ────────────────────────────────────────────────────

/// Fade + deslizamiento direccional al aparecer (una sola vez).
class _AnimatedIn extends StatelessWidget {
  final Widget child;
  final bool fromRight;
  final bool animate;
  const _AnimatedIn({
    required this.child,
    this.fromRight = false,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset((fromRight ? 16 : -16) * (1 - v), 6 * (1 - v)),
          child: c,
        ),
      ),
    );
  }
}

/// Entrada escalonada por índice (para chips y tarjetas).
class _StaggeredIn extends StatelessWidget {
  final Widget child;
  final int index;
  const _StaggeredIn({required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    final delayMs = 60 * index;
    final totalMs = 280 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - v)),
          child: Transform.scale(scale: 0.92 + 0.08 * v, child: c),
        ),
      ),
    );
  }
}

// ── Tile (burbuja + tarjetas de producto) ─────────────────────────────────────

class _MsgTile extends StatelessWidget {
  final _Msg msg;
  const _MsgTile({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bubble(msg: msg),
        if (!msg.isUser && msg.mentioned.isNotEmpty)
          _ProductCards(products: msg.mentioned),
      ],
    );
  }
}

// ── Burbuja ───────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final _Msg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color bg = msg.isError
        ? cs.error.withValues(alpha: 0.12)
        : msg.isUser
            ? cs.primary
            : cs.surfaceContainer;

    final Color textColor = msg.isError
        ? cs.error
        : msg.isUser
            ? Colors.white
            : cs.onSurface;

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
          border: !msg.isUser && !msg.isError
              ? Border.all(color: cs.outline)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              Icon(Icons.smart_toy_outlined,
                  size: 15, color: cs.primary),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                msg.text,
                style: TextStyle(
                    color: textColor, fontSize: 14, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjetas de productos recomendados ────────────────────────────────────────

class _ProductCards extends StatelessWidget {
  final List<Product> products;
  const _ProductCards({required this.products});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              'Productos mencionados',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _StaggeredIn(
                index: i,
                child: _ProductChip(product: products[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  final Product product;
  const _ProductChip({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inCart = cart.items.containsKey(product.id);
    final hasImage = product.imageUrl.isNotEmpty;
    final imgUrl = ApiConfig.productImage(product.imageUrl);
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: inCart ? cs.primary : cs.outline,
          width: inCart ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: imgUrl,
                    height: 56,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _imgPlaceholder(cs),
                    placeholder: (_, __) => _imgPlaceholder(cs),
                  )
                : _imgPlaceholder(cs),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: GoogleFonts.montserrat(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (inCart) {
                          cart.remove(product.id);
                        } else {
                          cart.add(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} agregado'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: inCart
                              ? AppColors.secondary
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          inCart ? '✓ En carrito' : '+ Agregar',
                          style: TextStyle(
                            color: inCart
                                ? AppColors.onSecondary
                                : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder(ColorScheme cs) => Container(
        height: 56,
        width: double.infinity,
        color: cs.surfaceContainerLow,
        child: const Icon(Icons.inventory_2_outlined,
            color: AppColors.onSurfaceVariant, size: 24),
      );
}

// ── Indicador de escritura ────────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined,
                size: 15, color: cs.primary),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _ac,
              builder: (_, __) => Row(
                children: List.generate(3, (i) {
                  final v = Curves.easeInOut
                      .transform(((_ac.value + i / 3) % 1.0));
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.3 + 0.7 * v),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sugerencias ───────────────────────────────────────────────────────────────

class _SuggestionRow extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;
  const _SuggestionRow({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cs = Theme.of(context).colorScheme;
          return _StaggeredIn(
            index: i,
            child: GestureDetector(
              onTap: () => onTap(suggestions[i]),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  suggestions[i],
                  style: TextStyle(
                      color: cs.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Barra de entrada ──────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onSend;
  final bool enabled;
  const _InputBar(
      {required this.ctrl, required this.onSend, required this.enabled});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ctrl = widget.ctrl;
    final onSend = widget.onSend;
    final enabled = widget.enabled;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                enabled: enabled,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Escribe tu pregunta...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                ),
                onSubmitted: onSend,
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: enabled ? () => onSend(ctrl.text) : null,
              onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: AnimatedScale(
                scale: _pressed ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: enabled ? cs.primary : cs.outline,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      enabled ? Icons.send_rounded : Icons.more_horiz_rounded,
                      key: ValueKey(enabled),
                      color:
                          enabled ? Colors.white : AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
