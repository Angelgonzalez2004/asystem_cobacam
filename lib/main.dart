import 'package:asystem_cobacam/providers/theme_provider.dart';
import 'package:asystem_cobacam/widgets/auth_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:intl/date_symbol_data_local.dart';

final HiveService _hiveService = HiveService();
final ConnectivityService _connectivityService = ConnectivityService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);

  // ---------------------------------------------------------
  // 1. INICIAR HIVE
  // ---------------------------------------------------------
  try {
    debugPrint("📦 Iniciando Hive...");
    await _hiveService.initHive();
    debugPrint("✅ Hive iniciado correctamente.");
  } catch (e) {
    debugPrint("⚠️ Error al iniciar Hive (La app continuará): $e");
  }

  // Inicializar Connectivity
  _connectivityService;

  // ---------------------------------------------------------
  // 2. INICIAR FIREBASE (FORZADO)
  // ---------------------------------------------------------
  try {
    debugPrint("🔥 Inicializando Firebase desde Flutter...");

    // Verificar si ya está inicializado para evitar "duplicate-app"
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("✅ Firebase inicializado manualmente con opciones.");
    } else {
      debugPrint("ℹ️ Firebase ya estaba inicializado (Nativo/Automático). Usando instancia existente.");
    }

    debugPrint("✅ Firebase listo.");
  } catch (e) {
    // Si falla aquí, es un error real de configuración (faltan credenciales, internet, etc.)
    debugPrint("🚨 ERROR CRÍTICO DE FIREBASE: $e");
  }

  // ---------------------------------------------------------
  // 3. ARRANCAR LA APP
  // ---------------------------------------------------------
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<HiveService>(create: (_) => _hiveService),
        Provider<ConnectivityService>(create: (_) => _connectivityService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Asystem-Cobacam',
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily:
                'Inter', // Si 'Inter' no está disponible, Flutter usará la fuente por defecto.
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B82F6), // Tailwind Blue-500
              primary: const Color(0xFF2563EB), // Tailwind Blue-600
              secondary: const Color(0xFF10B981), // Tailwind Emerald-500
              tertiary: const Color(0xFFF59E0B), // Tailwind Amber-500
              surface: Colors.white,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: const Color(0xFF1E293B), // Tailwind Slate-800
              error: const Color(0xFFEF4444), // Tailwind Red-500
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor:
                const Color(0xFFF8FAFC), // Tailwind Slate-50
            textTheme: const TextTheme(
              displayLarge: TextStyle(
                  fontSize: 32.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.0,
                  color: Color(0xFF0F172A)), // Slate-900
              titleLarge: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B)), // Slate-800
              bodyMedium: TextStyle(
                  fontSize: 15.0, color: Color(0xFF334155)), // Slate-700
              bodySmall: TextStyle(
                  fontSize: 13.0, color: Color(0xFF64748B)), // Slate-500
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB), // Blue-600
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12), // Modern slightly rounded
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0)), // Slate-200
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF3B82F6), width: 2), // Blue-500
              ),
              labelStyle:
                  const TextStyle(color: Color(0xFF64748B)), // Slate-500
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF1E293B),
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: Color(0xFF334155)),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Inter',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B82F6), // Tailwind Blue-500
              primary: const Color(
                  0xFF60A5FA), // Tailwind Blue-400 (Lighter for dark mode)
              secondary: const Color(0xFF34D399), // Tailwind Emerald-400
              tertiary: const Color(0xFFFBBF24), // Tailwind Amber-400
              surface: const Color(0xFF1E293B), // Tailwind Slate-800
              onPrimary: const Color(0xFF0F172A), // Slate-900
              onSecondary: const Color(0xFF0F172A),
              onSurface: const Color(0xFFF1F5F9), // Slate-100
              error: const Color(0xFFF87171), // Tailwind Red-400
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor:
                const Color(0xFF0F172A), // Tailwind Slate-900
            textTheme: const TextTheme(
              displayLarge: TextStyle(
                  fontSize: 32.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.0,
                  color: Colors.white),
              titleLarge: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
              bodyMedium: TextStyle(
                  fontSize: 15.0, color: Color(0xFFCBD5E1)), // Slate-300
              bodySmall: TextStyle(
                  fontSize: 13.0, color: Color(0xFF94A3B8)), // Slate-400
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF60A5FA), // Blue-400
                foregroundColor: const Color(0xFF0F172A), // Slate-900
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1E293B), // Slate-800
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF334155)), // Slate-700
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF60A5FA), width: 2), // Blue-400
              ),
              labelStyle:
                  const TextStyle(color: Color(0xFF94A3B8)), // Slate-400
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: Colors.white),
            ),
          ),
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
