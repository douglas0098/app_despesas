import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const AppDespesas());
}

class AppDespesas extends StatelessWidget {
  const AppDespesas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minhas Despesas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
