import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 160});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/FINE_AID_Logo.png',
        width: size,
        height: size,
      ),
    );
  }
}
