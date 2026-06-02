import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
  final List<Product> mentioned; // productos mencionados por el AI

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
    // Cargar productos si aún no están disponibles
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

  /// Detecta qué productos del catálogo son mencionados en el texto del AI.
  List<Product> _findMentioned(String text, List<Product> catalog) {
    final lower = text.toLowerCase();
    return catalog.where((p) {
      // Solo coincide si el nombre tiene al menos 4 caracteres (evita falsos positivos)
      return p.name.length >= 4 &&
          lower.contains(p.name.toLowerCase());
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
      backgroundColor: AppColors.navyBg,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined,
                size: 20, color: AppColors.catHeader),
            SizedBox(width: 8),
            Text('Asistente IA'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Historial ──
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _msgs.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _msgs.length) return const _TypingBubble();
                return _MsgTile(msg: _msgs[i]);
              },
            ),
          ),

          // ── Sugerencias (solo al inicio) ──
          if (_msgs.length == 1 && !_thinking)
            _SuggestionRow(suggestions: _suggestions, onTap: _send),

          // ── Input ──
          _InputBar(ctrl: _ctrl, onSend: _send, enabled: !_thinking),
        ],
      ),
    );
  }
}

// ── Tile completo (burbuja + tarjetas de producto) ────────────────────────────

class _MsgTile extends StatelessWidget {
  final _Msg msg;
  const _MsgTile({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bubble(msg: msg),
        // Tarjetas de productos recomendados solo para mensajes del AI
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
    final Color bg = msg.isError
        ? AppColors.danger.withValues(alpha: 0.2)
        : msg.isUser
            ? AppColors.accent.withValues(alpha: 0.9)
            : AppColors.navyCard;

    final Color textColor = msg.isError ? AppColors.danger : Colors.white;

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
          border: !msg.isUser ? Border.all(color: AppColors.navyLight) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              const Icon(Icons.smart_toy_outlined,
                  size: 15, color: AppColors.catHeader),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(msg.text,
                  style: TextStyle(
                      color: textColor, fontSize: 14, height: 1.45)),
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
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 6),
            child: Text('Productos mencionados',
                style: TextStyle(
                    color: AppColors.catHeader,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _ProductChip(product: products[i]),
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

    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: AppColors.navyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: inCart ? AppColors.cartAmber : AppColors.navyLight,
          width: inCart ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Imagen ──
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(11)),
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: imgUrl,
                    height: 56,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _imgPlaceholder(),
                    placeholder: (_, __) => _imgPlaceholder(),
                  )
                : _imgPlaceholder(),
          ),

          // ── Info + botón ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: AppColors.cartAmber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
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
                              ? AppColors.cartAmber.withValues(alpha: 0.15)
                              : AppColors.accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          inCart ? '✓ En carrito' : '+ Agregar',
                          style: TextStyle(
                            color: inCart
                                ? AppColors.cartAmber
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

  Widget _imgPlaceholder() => Container(
        height: 56,
        width: double.infinity,
        color: AppColors.navyLight,
        child: const Icon(Icons.inventory_2_outlined,
            color: AppColors.textSec, size: 24),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.navyCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.navyLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined,
                size: 15, color: AppColors.catHeader),
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
                      color: AppColors.catHeader
                          .withValues(alpha: 0.4 + 0.6 * v),
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
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onTap(suggestions[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.navyCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.navyLight),
            ),
            child: Text(suggestions[i],
                style: const TextStyle(
                    color: AppColors.catHeader, fontSize: 12)),
          ),
        ),
      ),
    );
  }
}

// ── Barra de entrada ──────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onSend;
  final bool enabled;
  const _InputBar(
      {required this.ctrl, required this.onSend, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: const BoxDecoration(
        color: AppColors.navyCard,
        border: Border(top: BorderSide(color: AppColors.divider)),
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
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Escribe tu pregunta...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: enabled ? AppColors.accent : AppColors.navyLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.send_rounded,
                    color: enabled ? Colors.white : AppColors.textSec,
                    size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
