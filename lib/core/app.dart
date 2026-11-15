import 'package:flutter/material.dart';
import '../pages/home_page.dart';

class DrawerXApp extends StatelessWidget {
  const DrawerXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DrawerX',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF070B18),
      ),
      home: const HomePage(),
    );
  }
}
