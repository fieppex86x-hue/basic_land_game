import 'package:flutter/material.dart';
import '../../models/card.dart' as models;

Color landColor(models.LandType t) {
  switch (t) {
    case models.LandType.plains: return const Color(0xFFF5E6C8);
    case models.LandType.island: return const Color(0xFFB3D4F0);
    case models.LandType.swamp: return const Color(0xFF6B6B6B);
    case models.LandType.mountain: return const Color(0xFFE8B0A0);
    case models.LandType.forest: return const Color(0xFFB8D8B8);
  }
}

class CardWidget extends StatelessWidget {
  final models.Card card;
  final double width;
  final VoidCallback? onTap;
  final bool selected;

  const CardWidget({
    super.key,
    required this.card,
    this.width = 70,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: width * 1.4,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: landColor(card.type),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.amber : Colors.black54,
            width: selected ? 3 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(card.type.symbol, style: TextStyle(fontSize: width * 0.5)),
            const SizedBox(height: 4),
            Text(
              card.type.label,
              style: TextStyle(
                fontSize: width * 0.14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class CardBackWidget extends StatelessWidget {
  final double width;
  const CardBackWidget({super.key, this.width = 70});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 1.4,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A5A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black54),
      ),
      child: Center(
        child: Text('🂠', style: TextStyle(fontSize: width * 0.5, color: Colors.white)),
      ),
    );
  }
}