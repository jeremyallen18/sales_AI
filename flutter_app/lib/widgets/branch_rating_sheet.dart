import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'star_rating.dart';

class BranchRatingSheet extends StatefulWidget {
  final int branchId;
  final String branchName;
  final String appToken;

  const BranchRatingSheet({
    super.key,
    required this.branchId,
    required this.branchName,
    required this.appToken,
  });

  @override
  State<BranchRatingSheet> createState() => _BranchRatingSheetState();
}

class _BranchRatingSheetState extends State<BranchRatingSheet> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

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
      await ApiService.postBranchReview(
        widget.branchId,
        _rating,
        _commentCtrl.text.trim(),
        widget.appToken,
      );
      setState(() => _submitted = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _submitted
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 52),
              const SizedBox(height: 12),
              Text('¡Gracias por tu reseña!',
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700, fontSize: 18,
                      color: cs.onSurface)),
              const SizedBox(height: 8),
            ])
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('¿Cómo fue tu experiencia?',
                    style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700, fontSize: 18,
                        color: cs.onSurface)),
                const SizedBox(height: 4),
                Text(widget.branchName,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 20),
                Center(
                  child: InteractiveStarRating(
                    onChanged: (v) => setState(() => _rating = v),
                    starSize: 40,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Comentario (opcional)...',
                    hintStyle: TextStyle(color: cs.onSurfaceVariant),
                    filled: true,
                    fillColor: cs.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Omitir'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Publicar'),
                    ),
                  ),
                ]),
              ],
            ),
    );
  }
}
