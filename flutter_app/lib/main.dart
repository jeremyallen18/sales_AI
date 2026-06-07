import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'providers/products_provider.dart';
import 'widgets/main_shell.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.primary,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SalesStoreApp());
}

// ── Paleta OXXO ───────────────────────────────────────────────────────────────
class AppColors {
  static const Color primary              = Color(0xFFB5000B);
  static const Color primaryContainer     = Color(0xFFFFDAD5);
  static const Color onPrimary            = Color(0xFFFFFFFF);
  static const Color secondary            = Color(0xFFFFD400);
  static const Color onSecondary          = Color(0xFF6F5C00);
  static const Color surface              = Color(0xFFFBF9F8);
  static const Color surfaceContainer     = Color(0xFFF0EDED);
  static const Color surfaceContainerLow  = Color(0xFFF6F3F2);
  static const Color onSurface           = Color(0xFF1B1C1C);
  static const Color onSurfaceVariant     = Color(0xFF5E3F3B);
  static const Color outline              = Color(0xFFE4E2E1);
  static const Color outlineVariant       = Color(0xFFE9BCB6);
  static const Color error               = Color(0xFFBA1A1A);
  static const Color success             = Color(0xFF4CAF50);
}

class SalesStoreApp extends StatelessWidget {
  const SalesStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductsProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Tienda',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const MainShell(),
      ),
    );
  }

  ThemeData _buildTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        error: AppColors.error,
        outline: AppColors.outline,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.onSurface,
        displayColor: AppColors.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outline, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
        hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.onSurface,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
