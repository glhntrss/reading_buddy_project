import 'package:flutter/material.dart';

class MascotCard extends StatelessWidget {
  const MascotCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Center(
        child: Image.asset(
          "assets/images/civciv.png",
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}