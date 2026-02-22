import 'dart:async'; // Agregado para capturar errores globales
import 'package:asystem_cobacam/widgets/auth_wrapper.dart';
import 'package:asystem_cobacam/widgets/inactivity_guard.dart';
import 'package:asystem_cobacam/providers/theme_provider.dart';
import 'package:asystem_cobacam/services/lock_service.dart';
import 'package:asystem_cobacam/widgets/session_guard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:asystem_cobacam/services/hive_service.dart';
import 'package:asystem_cobacam/services/connectivity_service.dart';
import 'package:asystem_cobacam/services/app_settings_service.dart';
import 'package:asystem_cobacam/services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final HiveService _hiveService = HiveService();
late final ConnectivityService _connectivityService;
late final AppSettingsService _appSettingsService;

void main() async {
  // Usamos runZonedGuarded para que si hay un error asíncrono, no se quede la pantalla en blanco
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_MX', null);

    debugPrint("🚀 INICIANDO APP...");

    // ---------------------------------------------------------
    // 1. INICIAR HIVE
    // ---------------------------------------------------------
    debugPrint("📦 Iniciando Hive...");
    await _hiveService.initHive();
    debugPrint("✅ Hive iniciado correctamente.");

    // ---------------------------------------------------------
    // 2. INICIAR FIREBASE (PRIORIDAD ALTA)
    // ---------------------------------------------------------
    // IMPORTANTE: Esto debe ir ANTES de iniciar AppSettingsService
    try {
      debugPrint("🔥 Inicializando Firebase...");
      
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint("✅ Firebase inicializado.");
      } else {
        debugPrint("ℹ️ Firebase ya estaba activo.");
      }

      // 2.5 Notificaciones (FCM)
      await NotificationService.initialize();

      // Configuración de persistencia (segura para web)
      try {
        FirebaseDatabase.instance.setPersistenceEnabled(true);
        debugPrint("💾 Persistencia activada.");
      } catch (e) {
        debugPrint("⚠️ Aviso: Persistencia no soportada o ya activa: $e");
      }
    } catch (e) {
      debugPrint("🚨 ERROR CRÍTICO AL INICIAR FIREBASE: $e");
      // Continuamos, pero sabiendo que Firebase falló
    }

    // ---------------------------------------------------------
    // 3. INICIAR SERVICIOS
    // ---------------------------------------------------------
    debugPrint("🌐 Inicializando ConnectivityService...");
    _connectivityService = ConnectivityService();
    debugPrint("✅ ConnectivityService listo.");

    try {
      debugPrint("⚙️ Inicializando AppSettingsService...");
      // AHORA SÍ es seguro crear esto, porque Firebase ya existe
      _appSettingsService = AppSettingsService(_hiveService, _connectivityService);
      debugPrint("✅ AppSettingsService inicializado correctamente.");
    } catch (e, stack) {
      debugPrint("🚨 ERROR FATAL EN APP_SETTINGS_SERVICE: $e");
      debugPrint("Stack: $stack");
      // Si esto falla, la app podría no funcionar, pero intentamos seguir
    }

    // ---------------------------------------------------------
    // 4. ARRANCAR LA UI
    // ---------------------------------------------------------
    debugPrint("🚀 Ejecutando runApp...");
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LockService()),
          Provider<HiveService>(create: (_) => _hiveService),
          Provider<ConnectivityService>(create: (_) => _connectivityService),
          Provider<AppSettingsService>(create: (_) => _appSettingsService),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    // Bloque global de captura de errores (evita la pantalla gris/blanca en muchos casos)
    debugPrint("🔥 ERROR NO CAPTURADO (Global): $error");
    debugPrint(stack.toString());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("🏗️ Construyendo MyApp...");
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Asystem-Cobacam',
          themeMode: themeProvider.themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'MX'),
          ],
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Inter',
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
            scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Tailwind Slate-50
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
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF3B82F6), width: 2),
              ),
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
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
              seedColor: const Color(0xFF3B82F6),
              primary: const Color(0xFF60A5FA),
              secondary: const Color(0xFF34D399),
              tertiary: const Color(0xFFFBBF24),
              surface: const Color(0xFF1E293B),
              onPrimary: const Color(0xFF0F172A),
              onSecondary: const Color(0xFF0F172A),
              onSurface: const Color(0xFFF1F5F9),
              error: const Color(0xFFF87171),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
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
                  fontSize: 15.0, color: Color(0xFFCBD5E1)),
              bodySmall: TextStyle(
                  fontSize: 13.0, color: Color(0xFF94A3B8)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF60A5FA),
                foregroundColor: const Color(0xFF0F172A),
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
              fillColor: const Color(0xFF1E293B),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF60A5FA), width: 2),
              ),
              labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: Colors.white),
            ),
          ),
          home: const InactivityGuard(
            child: SessionGuard(
              child: AuthWrapper(),
            ),
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}