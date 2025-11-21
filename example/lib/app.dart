import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/connection_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/theme_provider.dart';
import 'parsers/subscription_parser.dart';
import 'screens/home_screen.dart';

class NeonRayApp extends StatelessWidget {
  const NeonRayApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(
            SubscriptionParser(),
            prefs,
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final baseLight = ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF7F8FD),
            fontFamily: 'Vazir',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          );
          final baseDark = ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            fontFamily: 'Vazir',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          );

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'NeonRay',
            themeMode: theme.themeMode,
            theme: baseLight,
            darkTheme: baseDark,
            home: const NeonRayHome(),
          );
        },
      ),
    );
  }
}
