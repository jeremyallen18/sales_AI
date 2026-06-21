import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/branch_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/products_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SettingsService.init();
  final themeProvider = await ThemeProvider.load();
  runApp(SellerApp(themeProvider: themeProvider));
}

// ── Paleta OXXO — Dark ───────────────────────────────────────────────────────
class AppColors {
  static const Color navyBg    = Color(0xFF1A0002);  // fondo oscuro rojo OXXO
  static const Color navyCard  = Color(0xFF2D0003);  // tarjeta
  static const Color navyLight = Color(0xFF450004);  // tarjeta elevada
  static const Color accent    = Color(0xFFE30613);  // rojo OXXO primario
  static const Color cartAmber = Color(0xFFFED400);  // amarillo OXXO
  static const Color catHeader = Color(0xFFFFB3B3);  // texto rojo claro
  static const Color textSec   = Color(0xFFCF8A8A);  // texto secundario
  static const Color divider   = Color(0xFF3D0004);  // separador
  static const Color success   = Color(0xFF4CAF50);
  static const Color danger    = Color(0xFFFF5252);
}

// ── Paleta OXXO — Light ───────────────────────────────────────────────────────
class AppColorsLight {
  static const Color navyBg    = Color(0xFFFBF9F8);  // fondo OXXO claro
  static const Color navyCard  = Color(0xFFFFFFFF);
  static const Color navyLight = Color(0xFFFFF5F3);  // tinte rojo suave
  static const Color accent    = Color(0xFFB5000B);  // rojo OXXO oscuro
  static const Color cartAmber = Color(0xFFFED400);  // amarillo OXXO
  static const Color catHeader = Color(0xFFB5000B);
  static const Color textSec   = Color(0xFF936E69);
  static const Color divider   = Color(0xFFE9BCB6);
  static const Color success   = Color(0xFF2E7D32);
  static const Color danger    = Color(0xFFC62828);
  static const Color onSurface = Color(0xFF1B1C1C);
}

class SellerApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const SellerApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
        ChangeNotifierProvider(create: (_) => BranchProvider()),
        ChangeNotifierProvider(create: (_) => ProductsProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
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
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                  ),
          );
          return MaterialApp(
            title: 'TiendIA — Vendedor',
            debugShowCheckedModeBanner: false,
            themeMode: theme.mode,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            home: const _AuthGate(),
          );
        },
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.navyBg,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.navyBg,
        surfaceContainer: AppColors.navyCard,
        surfaceContainerLow: AppColors.navyLight,
        primary: AppColors.accent,
        secondary: AppColors.cartAmber,
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navyBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.navyCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.navyCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navyLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navyLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSec),
        hintStyle: const TextStyle(color: AppColors.textSec),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.catHeader),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.navyLight,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.navyCard,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSec,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColorsLight.navyBg,
      colorScheme: const ColorScheme.light(
        surface: AppColorsLight.navyBg,
        surfaceContainer: AppColorsLight.navyCard,
        surfaceContainerLow: AppColorsLight.navyLight,
        primary: AppColorsLight.accent,
        secondary: AppColorsLight.cartAmber,
        onPrimary: Colors.white,
        onSurface: AppColorsLight.onSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorsLight.navyBg,
        foregroundColor: AppColorsLight.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColorsLight.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        iconTheme: IconThemeData(color: AppColorsLight.onSurface),
      ),
      cardTheme: CardThemeData(
        color: AppColorsLight.navyCard,
        elevation: 1,
        shadowColor: Color(0x1A2979FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColorsLight.divider,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsLight.navyCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsLight.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsLight.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsLight.accent, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColorsLight.textSec),
        hintStyle: const TextStyle(color: AppColorsLight.textSec),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColorsLight.accent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsLight.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColorsLight.onSurface,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColorsLight.navyCard,
        selectedItemColor: AppColorsLight.accent,
        unselectedItemColor: AppColorsLight.textSec,
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.loggedIn ? const HomeShell() : const LoginScreen();
  }
}
