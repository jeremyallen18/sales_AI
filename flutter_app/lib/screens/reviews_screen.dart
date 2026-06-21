import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/customer_auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/star_rating.dart';

class ReviewsScreen extends StatefulWidget {
  final int? productId;
  final int? branchId;
  final String entityName;

  const ReviewsScreen({
    super.key,
    this.productId,
    this.branchId,
    required this.entityName,
  }) : assert(productId != null || branchId != null,
            'Debe proporcionarse productId o branchId');

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0.0;
  int _totalReviews = 0;
  Map<String, dynamic>? _myReview;
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
      final auth = context.read<CustomerAuthProvider>();
      final Map<String, dynamic> data;

      if (widget.productId != null) {
        data = await ApiService.fetchProductReviews(widget.productId!);
      } else {
        data = await ApiService.fetchBranchReviews(widget.branchId!);
      }

      _reviews = List<Map<String, dynamic>>.from(data['reviews'] ?? []);
      _avgRating = (data['average_rating'] as num?)?.toDouble() ?? 0.0;
      _totalReviews = (data['total_reviews'] as num?)?.toInt() ?? 0;

      if (auth.isLoggedIn && auth.appToken != null) {
        try {
          final Map<String, dynamic> myData;
          if (widget.productId != null) {
            myData = await ApiService.fetchMyProductReview(
                widget.productId!, auth.appToken!);
          } else {
            myData = await ApiService.fetchMyBranchReview(
                widget.branchId!, auth.appToken!);
          }
          _myReview = myData['review'] as Map<String, dynamic>?;
        } catch (_) {}
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _openReviewForm() {
    final auth = context.read<CustomerAuthProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReviewFormSheet(
        productId: widget.productId,
        branchId: widget.branchId,
        entityName: widget.entityName,
        appToken: auth.appToken!,
        initialRating: (_myReview?['rating'] as int?) ?? 0,
        initialComment: (_myReview?['comment'] as String?) ?? '',
        onSubmitted: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<CustomerAuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.entityName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: auth.isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: _openReviewForm,
              icon: const Icon(Icons.rate_review_outlined),
              label:
                  Text(_myReview != null ? 'Editar reseña' : 'Escribir reseña'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_outlined,
                            size: 48, color: cs.outlineVariant),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.error)),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _load,
                            child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _SummaryHeader(
                          avgRating: _avgRating,
                          totalReviews: _totalReviews,
                          myReview: _myReview,
                          onEditTap:
                              auth.isLoggedIn ? _openReviewForm : null,
                        ),
                      ),
                      if (_reviews.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star_outline_rounded,
                                    size: 64, color: cs.outlineVariant),
                                const SizedBox(height: 12),
                                Text('Aún no hay reseñas',
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 6),
                                if (auth.isLoggedIn)
                                  Text('¡Sé el primero en opinar!',
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 13)),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) =>
                                  _ReviewTile(review: _reviews[i]),
                              childCount: _reviews.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

// ── Encabezado con promedio ───────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final double avgRating;
  final int totalReviews;
  final Map<String, dynamic>? myReview;
  final VoidCallback? onEditTap;

  const _SummaryHeader({
    required this.avgRating,
    required this.totalReviews,
    required this.myReview,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                totalReviews > 0 ? avgRating.toStringAsFixed(1) : '—',
                style: GoogleFonts.montserrat(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface),
              ),
              StarRating(
                  rating: avgRating,
                  starSize: 20,
                  showCount: false),
              const SizedBox(height: 4),
              Text(
                '$totalReviews reseña${totalReviews != 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(width: 20),
          if (myReview != null)
            Expanded(
              child: GestureDetector(
                onTap: onEditTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Tu reseña',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                          const Spacer(),
                          if (onEditTap != null)
                            const Icon(Icons.edit_outlined,
                                size: 14, color: AppColors.primary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      StarRating(
                          rating: (myReview!['rating'] as int).toDouble(),
                          starSize: 14,
                          showCount: false),
                      if ((myReview!['comment'] as String).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          myReview!['comment'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: cs.onSurface),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          else if (onEditTap != null)
            Expanded(
              child: GestureDetector(
                onTap: onEditTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.rate_review_outlined,
                          color: cs.onSurfaceVariant, size: 28),
                      const SizedBox(height: 6),
                      Text('Escribe tu opinión',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Tarjeta de una reseña ─────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rating = (review['rating'] as int?) ?? 0;
    final comment = (review['comment'] as String?) ?? '';
    final name = (review['customer_name'] as String?) ?? 'Cliente';
    final createdAt = review['created_at'] as String? ?? '';

    String dateStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      if (dateStr.isNotEmpty)
                        Text(dateStr,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                StarRating(
                    rating: rating.toDouble(),
                    starSize: 13,
                    showCount: false),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(comment,
                  style:
                      TextStyle(fontSize: 13, color: cs.onSurface)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Hoja de formulario de reseña ──────────────────────────────────────────────

class _ReviewFormSheet extends StatefulWidget {
  final int? productId;
  final int? branchId;
  final String entityName;
  final String appToken;
  final int initialRating;
  final String initialComment;
  final VoidCallback onSubmitted;

  const _ReviewFormSheet({
    this.productId,
    this.branchId,
    required this.entityName,
    required this.appToken,
    required this.initialRating,
    required this.initialComment,
    required this.onSubmitted,
  });

  @override
  State<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<_ReviewFormSheet> {
  late int _rating;
  late final TextEditingController _commentCtrl;
  bool _loading = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _commentCtrl = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una calificación')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (widget.productId != null) {
        await ApiService.postProductReview(widget.productId!, _rating,
            _commentCtrl.text.trim(), widget.appToken);
      } else {
        await ApiService.postBranchReview(widget.branchId!, _rating,
            _commentCtrl.text.trim(), widget.appToken);
      }
      setState(() => _submitted = true);
      widget.onSubmitted();
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.initialRating > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _submitted
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 52),
              const SizedBox(height: 12),
              Text(
                isEdit ? '¡Reseña actualizada!' : '¡Gracias por tu reseña!',
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: cs.onSurface),
              ),
              const SizedBox(height: 8),
            ])
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEdit ? 'Editar tu reseña' : '¿Cómo fue tu experiencia?',
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Text(widget.entityName,
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 20),
                Center(
                  child: InteractiveStarRating(
                    initialRating: _rating,
                    onChanged: (v) => setState(() => _rating = v),
                    starSize: 40,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'Comentario (opcional)...',
                    hintStyle:
                        TextStyle(color: cs.onSurfaceVariant),
                    filled: true,
                    fillColor: cs.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : Text(isEdit ? 'Actualizar' : 'Publicar'),
                    ),
                  ),
                ]),
              ],
            ),
    );
  }
}
