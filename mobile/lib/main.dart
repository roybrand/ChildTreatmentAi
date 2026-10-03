import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'strings.dart';

void main() {
  runApp(const ChildTreatmentApp());
}

class ChildTreatmentApp extends StatelessWidget {
  const ChildTreatmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appTitle,
      debugShowCheckedModeBanner: false,
      // Hebrew only for now. The Hebrew locale makes the whole app right-to-left.
      locale: const Locale('he'),
      supportedLocales: const [Locale('he')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F7D7B)),
      ),
      home: const HomeScreen(),
    );
  }
}
