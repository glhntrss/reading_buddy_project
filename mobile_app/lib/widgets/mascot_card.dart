import 'package:flutter/material.dart';

class MascotCard extends StatelessWidget {
  const MascotCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 245,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: Text(
          "🐥",
          style: TextStyle(fontSize: 110),
        ),
      ),
    );
  }
}