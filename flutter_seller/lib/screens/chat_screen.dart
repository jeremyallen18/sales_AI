import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  // Mensajes que ya reprodujeron su animación de entrada (evita re-animar
  // cuando el ListView reconstruye burbujas al hacer scroll).
  final Set<_ChatMessage> _animated = {};
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await ApiService.sendChatMessage(text);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: response, isUser: false));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: 'Error: ${e.toString().replaceFirst("Exception: ", "")}',
            isUser: false,
            isError: true,
          ));
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smart_toy_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'Asistente IA de Ventas',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Pregunta sobre ventas, inventario,\ntendencias o estrategias de negocio.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _StaggeredIn(
                            index: 0,
                            child: _SuggestionChip(
                              label: 'Resumen de ventas',
                              onTap: () {
                                _controller.text =
                                    '¿Cuál es el resumen de ventas de hoy?';
                                _send();
                              },
                            ),
                          ),
                          _StaggeredIn(
                            index: 1,
                            child: _SuggestionChip(
                              label: 'Productos más vendidos',
                              onTap: () {
                                _controller.text =
                                    '¿Cuáles son los productos más vendidos?';
                                _send();
                              },
                            ),
                          ),
                          _StaggeredIn(
                            index: 2,
                            child: _SuggestionChip(
                              label: 'Stock bajo',
                              onTap: () {
                                _controller.text =
                                    '¿Qué productos tienen stock bajo?';
                                _send();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length && _sending) {
                      return const _AnimatedIn(
                        fromRight: false,
                        child: _TypingIndicator(),
                      );
                    }
                    final message = _messages[i];
                    return _AnimatedIn(
                      // Set.add devuelve true solo la primera vez: anima la
                      // entrada una única vez por mensaje.
                      animate: _animated.add(message),
                      fromRight: message.isUser,
                      child: _MessageBubble(message: message),
                    );
                  },
                ),
        ),

        // Input bar
        Builder(builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            border: Border(top: BorderSide(color: cs.outline)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu pregunta...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    style: TextStyle(color: cs.onSurface),
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedScale(
                  scale: _sending ? 0.85 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _sending
                          ? cs.onSurface.withValues(alpha: 0.08)
                          : cs.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sending ? null : _send,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          _sending ? Icons.more_horiz : Icons.send,
                          key: ValueKey(_sending),
                          color: _sending
                              ? cs.onSurface.withValues(alpha: 0.4)
                              : cs.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        }),
      ],
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? cs.primary
              : message.isError
                  ? cs.error.withValues(alpha: 0.2)
                  : cs.surfaceContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isUser
              ? null
              : Border.all(
                  color: message.isError
                      ? cs.error
                      : cs.outline),
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(
            color: message.isUser
                ? Colors.white
                : message.isError
                    ? cs.error
                    : cs.onSurface,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
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
            AnimatedBuilder(
              animation: _ac,
              builder: (context, child) => Row(
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
            const SizedBox(width: 10),
            Text('Analizando...',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13)),
          ],
        ),
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

/// Entrada escalonada por índice (para chips de sugerencias).
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

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      label: Text(label,
          style: TextStyle(color: cs.primary, fontSize: 12)),
      backgroundColor: cs.primary.withValues(alpha: 0.1),
      side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
      onPressed: onTap,
    );
  }
}
