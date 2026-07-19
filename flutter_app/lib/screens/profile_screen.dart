import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/branch_provider.dart';
import '../providers/customer_auth_provider.dart';
import 'reviews_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<CustomerAuthProvider>();
    final cs   = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: auth.isLoggedIn
          ? _SignedInView(auth: auth, cs: cs)
          : _GuestView(auth: auth, cs: cs),
    );
  }
}

// ── Vista: sesión iniciada ────────────────────────────────────────────────────

class _SignedInView extends StatelessWidget {
  final CustomerAuthProvider auth;
  final ColorScheme cs;
  const _SignedInView({required this.auth, required this.cs});

  @override
  Widget build(BuildContext context) {
    final branch = context.watch<BranchProvider>().selectedBranch;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        // Avatar
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            backgroundImage: auth.uid.isNotEmpty &&
                    auth.appToken != null &&
                    auth.email.isNotEmpty
                ? null
                : null,
            child: Text(
              auth.displayName.isNotEmpty
                  ? auth.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Nombre
        Center(
          child: Text(
            auth.displayName.isNotEmpty ? auth.displayName : 'Sin nombre',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface),
          ),
        ),
        Center(
          child: Text(
            auth.email,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 32),
        // Divider
        Divider(color: cs.outline),
        const SizedBox(height: 16),
        // Info tiles
        _InfoTile(icon: Icons.email_outlined, label: 'Correo', value: auth.email, cs: cs),
        const SizedBox(height: 12),
        _InfoTile(icon: Icons.verified_user_outlined, label: 'Cuenta', value: 'Google', cs: cs),
        const SizedBox(height: 24),
        // Reseñar tienda
        if (branch != null) ...[
          _ActionTile(
            icon: Icons.store_outlined,
            label: 'Reseñar sucursal',
            subtitle: branch.name,
            cs: cs,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewsScreen(
                  branchId: branch.id,
                  entityName: branch.name,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Cerrar sesión
        OutlinedButton.icon(
          onPressed: () async {
            await auth.signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final ColorScheme cs;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.cs,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style:
                      TextStyle(fontSize: 14, color: cs.onSurface)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Vista: invitado ───────────────────────────────────────────────────────────

class _GuestView extends StatelessWidget {
  final CustomerAuthProvider auth;
  final ColorScheme cs;
  const _GuestView({required this.auth, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle_outlined,
              size: 80, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 20),
          Text(
            'Inicia sesión para guardar tus datos',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Tus compras quedarán vinculadas a tu cuenta y tu nombre se rellenará automáticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          if (auth.loading)
            const CircularProgressIndicator()
          else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final ok = await auth.signInWithGoogle();
                  if (!ok && context.mounted && auth.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(auth.error!),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                icon: _GoogleLogo(),
                label: const Text('Continuar con Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: cs.outline),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'También puedes continuar como invitado desde el carrito.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paths = <(String, Color)>[
      (
        'M ${size.width * 0.5} ${size.height * 0.198} '
            'c ${size.width * 0.148} 0 ${size.width * 0.280} ${size.height * 0.051} ${size.width * 0.385} ${size.height * 0.150} '
            'l ${size.width * 0.285} -${size.height * 0.285} '
            'C ${size.width * 0.998} ${size.height * 0.099} ${size.width * 0.769} 0 ${size.width * 0.5} 0 '
            'C ${size.height * 0.305} 0 ${size.width * 0.021} ${size.height * 0.134} 0 ${size.height * 0.5} '
            'h 0',
        const Color(0xFFEA4335)
      ),
    ];
    // Simplified rendering — just draw a circular G shape
    final paint = Paint()..style = PaintingStyle.fill;
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height);
    // Red arc (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.6, true, paint);
    // Blue arc (right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.8, 1.6, true, paint);
    // Yellow arc (bottom)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 0.8, 1.6, true, paint);
    // Green arc (left)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 2.4, 1.6, true, paint);
    // White center
    paint.color = Colors.white;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2),
        size.width * 0.3, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
