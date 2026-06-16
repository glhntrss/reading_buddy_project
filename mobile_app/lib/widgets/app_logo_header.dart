import 'package:flutter/material.dart';

class AppLogoHeader extends StatelessWidget {
  final double height;

  const AppLogoHeader({
    super.key,
    this.height = 58,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      "assets/images/reading_buddy_logo.png",
      height: height,
      fit: BoxFit.contain,
    );
  }
}