import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class PlantWidget extends StatelessWidget {
  final String stage;
  final double size;

  const PlantWidget({
    super.key,
    required this.stage,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    String assetPath;
    switch (stage) {
      case 'login':
        assetPath = 'assets/lottie/flower_plant_login.json';
        break;
      case 'mascot':
        assetPath = 'assets/lottie/mascot.json';
        break;
      case 'walking':
        assetPath = 'assets/lottie/walking_pothos.json';
        break;
      case 'plants':
        assetPath = 'assets/lottie/plants.json';
        break;
      case 'seedling':
        assetPath = 'assets/lottie/seedling.json';
        break;
      case 'waving':
      default:
        assetPath = 'assets/lottie/waving_plant.json';
        break;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        repeat: true,
        animate: true,
      ),
    );
  }
}
