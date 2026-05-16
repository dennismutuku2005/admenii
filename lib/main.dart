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
        primaryColor: const Color(0xFF47ACAF), // Tropical Teal
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF47ACAF),
          primary: const Color(0xFF47ACAF),
          secondary: const Color(0xFF536B74), // Blue Slate
          surface: Colors.white,
          onSurface: const Color(0xFF504A56), // Charcoal
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF504A56),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
