import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/branch_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/customer_auth_provider.dart';
import 'providers/products_provider.dart';
import 'providers/theme_provider.dart';
import 'widgets/main_shell.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SettingsService.init();
  final themeProvider = await ThemeProvider.load();
  runApp(SalesStoreApp(themeProvider: themeProvider));
}

// ── Paleta OXXO — Light ───────────────────────────────────────────────────────
class AppColors {
  static const Color primary             = Color(0xFFB5000B);
  static const Color primaryContainer    = Color(0xFFFFDAD5);
  static const Color onPrimary           = Color(0xFFFFFFFF);
  static const Color secondary           = Color(0xFFFFD400);
  static const Color onSecondary         = Color(0xFF6F5C00);
  static const Color surface             = Color(0xFFFBF9F8);
  static const Color surfaceContainer    = Color(0xFFF0EDED);
  static const Color surfaceContainerLow = Color(0xFFF6F3F2);
  static const Color onSurface          = Color(0xFF1B1C1C);
  static const Color onSurfaceVariant    = Color(0xFF5E3F3B);
  static const Color outline             = Color(0xFFE4E2E1);
  static const Color outlineVariant      = Color(0xFFE9BCB6);
  static const Color error              = Color(0xFFBA1A1A);
  static const Color success            = Color(0xFF4CAF50);
}

// ── Paleta OXXO — Dark (Warm Dark) ───────────────────────────────────────────
class AppColorsDark {
  static const Color primary             = Color(0xFFB5000B);
  static const Color primaryContainer    = Color(0xFF690006);
  static const Color onPrimary           = Color(0xFFFFFFFF);
  static const Color secondary           = Color(0xFFFFD400);
  static const Color onSecondary         = Color(0xFF3A2E00);
  static const Color surface             = Color(0xFF1A1210);
  static const Color surfaceContainer    = Color(0xFF251917);
  static const Color surfaceContainerLow = Color(0xFF201614);
  static const Color onSurface          = Color(0xFFEDE0DC);
  static const Color onSurfaceVariant    = Color(0xFFC5ADA8);
  static const Color outline             = Color(0xFF3D2925);
  static const Color outlineVariant      = Color(0xFF5C3330);
  static const Color error              = Color(0xFFFF5449);
  static const Color success            = Color(0xFF5DB870);
}

class SalesStoreApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const SalesStoreApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => CustomerAuthProvider()..tryAutoLogin()),
        ChangeNotifierProvider(create: (_) => ProductsProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => BranchProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, theme, __) {
          SystemChrome.setSystemUIOverlayStyle(
            theme.isDark
                ? const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                  )
                : const SystemUiOverlayStyle(
                    statusBarColor: AppColors.primary,
                    statusBarIconBrightness: Brightness.light,
                  ),
          );
          return MaterialApp(
            title: 'TiendIA',
            debugShowCheckedModeBanner: false,
            themeMode: theme.mode,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            home: const MainShell(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
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
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerLow: AppColors.surfaceContainerLow,
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
        color: AppColors.surfaceContainer,
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

  ThemeData _buildDarkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColorsDark.surface,
      colorScheme: const ColorScheme.dark(
        primary: AppColorsDark.primary,
        onPrimary: AppColorsDark.onPrimary,
        primaryContainer: AppColorsDark.primaryContainer,
        secondary: AppColorsDark.secondary,
        onSecondary: AppColorsDark.onSecondary,
        surface: AppColorsDark.surface,
        surfaceContainer: AppColorsDark.surfaceContainer,
        surfaceContainerLow: AppColorsDark.surfaceContainerLow,
        onSurface: AppColorsDark.onSurface,
        error: AppColorsDark.error,
        outline: AppColorsDark.outline,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColorsDark.onSurface,
        displayColor: AppColorsDark.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsDark.surfaceContainer,
        foregroundColor: AppColorsDark.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
          color: AppColorsDark.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: AppColorsDark.onSurface),
      ),
      cardTheme: CardThemeData(
        color: AppColorsDark.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(
          color: AppColorsDark.outline, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsDark.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColorsDark.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColorsDark.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColorsDark.primary, width: 2),
        ),
        labelStyle:
            const TextStyle(color: AppColorsDark.onSurfaceVariant),
        hintStyle:
            const TextStyle(color: AppColorsDark.onSurfaceVariant),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(foregroundColor: AppColorsDark.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsDark.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsDark.surfaceContainer,
        contentTextStyle:
            TextStyle(color: AppColorsDark.onSurface),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
