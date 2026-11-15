import 'card.dart';

class Player {
  final String name;
  final List<Card> deck = [];
  final List<Card> hand = [];
  final List<Card> battlefield = [];
  final List<Card> graveyard = [];
  bool hasPlayedLandThisTurn = false;

  Player(this.name);

  void shuffleDeck() => deck.shuffle();

  Card? drawCard() {
    if (deck.isEmpty) {
      if (graveyard.isEmpty) return null;
      deck.addAll(graveyard);
      graveyard.clear();
      deck.shuffle();
    }
    if (deck.isEmpty) return null;
    final c = deck.removeAt(0);
    hand.add(c);
    return c;
  }

  void discardToSeven() {
    while (hand.length > 7) {
      final c = hand.removeLast();
      graveyard.add(c);
    }
  }
}