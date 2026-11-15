import 'package:uuid/uuid.dart';

enum LandType { plains, island, swamp, mountain, forest }

extension LandTypeExt on LandType {
  String get label {
    switch (this) {
      case LandType.plains: return 'Pianura';
      case LandType.island: return 'Isola';
      case LandType.swamp: return 'Palude';
      case LandType.mountain: return 'Montagna';
      case LandType.forest: return 'Foresta';
    }
  }

  String get symbol {
    switch (this) {
      case LandType.plains: return '☀';
      case LandType.island: return '💧';
      case LandType.swamp: return '💀';
      case LandType.mountain: return '⛰';
      case LandType.forest: return '🌲';
    }
  }
}

class Card {
  final String id;
  final LandType type;

  Card(this.type) : id = const Uuid().v4();

  Card copy() => Card(type);

  @override
  String toString() => '${type.label}#${id.substring(0, 4)}';
}