import 'package:asystem_cobacam/providers/theme_provider.dart';
import 'package:asystem_cobacam/widgets/auth_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:asystem_cobacam/services/hive_service.dart'; 
import 'package:asystem_cobacam/services/connectivity_service.dart'; 

final HiveService _hiveService = HiveService();
final ConnectivityService _connectivityService = ConnectivityService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    
    // Al no tener scripts en HTML, inicializamos DIRECTAMENTE
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    debugPrint("✅ Firebase conectado exitosamente.");
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
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D47A1), // Deep Blue
              primary: const Color(0xFF1565C0), // Slightly Lighter Blue
              secondary: const Color(0xFFFFC107), // Amber for accents
              surface: Colors.white,
              onPrimary: Colors.white,
              onSecondary: Colors.black,
              onSurface: Colors.black,
              error: Colors.red.shade700,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F6F8), // Light grey background
            textTheme: const TextTheme(
              displayLarge:
                  TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
              titleLarge:
                  TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
              bodyMedium: TextStyle(fontSize: 14.0, fontFamily: 'Hind'),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0), // Primary blue
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 30),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFF0D47A1)),
              ),
              labelStyle: const TextStyle(color: Colors.grey),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D47A1), // Deep Blue
              primary: const Color(0xFF42A5F5), // Lighter Blue for Dark Mode
              secondary: const Color(0xFFFFCA28), // Lighter Amber
              surface: const Color(0xFF121212),
              onPrimary: Colors.black,
              onSecondary: Colors.black,
              onSurface: Colors.white,
              error: Colors.red.shade400,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            textTheme: const TextTheme(
              displayLarge: TextStyle(
                  fontSize: 72.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              titleLarge: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              bodyMedium: TextStyle(
                  fontSize: 14.0, fontFamily: 'Hind', color: Colors.white),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 30),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2C2C2C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFF42A5F5)),
              ),
              labelStyle: const TextStyle(color: Colors.grey),
            ),
          ),
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}