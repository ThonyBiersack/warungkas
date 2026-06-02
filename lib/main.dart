import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'services/database_service.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseService.instance.initDB();

  // Ambil preferensi tema
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('is_dark_mode') ?? false; // Default light
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const WarungKasApp());
}

class WarungKasApp extends StatelessWidget {
  const WarungKasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) {
        return MaterialApp(
          title: 'WARUNGKAS - Cashier',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF9FAFB),
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData.light().textTheme,
            ),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00A67E),
              secondary: Color(0xFFFFB800),
              surface: Colors.white,
              onSurface: Color(0xFF111827),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF111827),
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0A0F1E),
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00A67E),
              secondary: Color(0xFFFFB800),
              surface: Color(0xFF111827),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
