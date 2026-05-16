import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/ad_blocker_provider.dart';
import 'screens/dashboard.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdBlockerProvider()),
      ],
      child: const AdMeniiApp(),
    ),
  );
}

class AdMeniiApp extends StatelessWidget {
  const AdMeniiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdMenii Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFFED5550), // Cinnabar
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFED5550),
          primary: const Color(0xFFED5550),
          secondary: const Color(0xFF47ACAF), // Tropical Teal
          surface: const Color(0xFFFCFBFA), // White
          onSurface: const Color(0xFF504A56), // Charcoal
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAF9), // Bright Snow
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF504A56),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: const Color(0xFFCCD0D0).withOpacity(0.3),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF504A56), fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: Color(0xFF504A56), fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(color: Color(0xFF717175)), // Dim Grey
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
