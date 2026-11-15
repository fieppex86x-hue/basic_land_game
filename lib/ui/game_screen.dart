import 'package:flutter/material.dart' hide Card;
import 'package:provider/provider.dart';
import '../logic/game_engine.dart';
import '../models/card.dart';
import '../models/player.dart';
import 'widgets/card_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Card? _selectedOther;

  @override
  void initState() {
    super.initState();
    final engine = context.read<GameEngine>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      engine.startTurn();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameEngine>(
      builder: (context, engine, _) {
        // Mostra un popup se c'è una notifica dall'AI
        if (engine.aiNotification != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAiNotification(context, engine, engine.aiNotification!);
            engine.clearAiNotification();
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Turno ${engine.turnNumber} — ${engine.activePlayer.name}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showLog(context, engine),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 4,
                  child: _playerBoard(context, engine: engine, player: engine.p2, isOpponent: true, label: 'Avversario (AI)', color: Colors.red),
                ),
                Container(height: 2, color: Colors.black26),
                Expanded(
                  flex: 5,
                  child: _playerBoard(context, engine: engine, player: engine.p1, isOpponent: false, label: 'Il Tuo Campo', color: Colors.blue),
                ),
                _actionBar(engine),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAiNotification(BuildContext context, GameEngine engine, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mossa Avversario'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Widget _playerBoard(BuildContext context, {required GameEngine engine, required Player player, required bool isOpponent, required String label, required Color color}) {
    return Container(
      width: double.infinity,
      color: color.withOpacity(0.03),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                Text('Mano: ${player.hand.length} | Cimitero: ${player.graveyard.length} | Deck: ${player.deck.length}', style: const TextStyle(fontSize: 10, color: Colors.grey))
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _sidePile(context, player: player, isOpponent: isOpponent, isGraveyard: true),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [for (final c in player.battlefield) CardWidget(card: c, width: 75)],
                      ),
                    ),
                  ),
                ),
                _sidePile(context, player: player, isOpponent: isOpponent, isGraveyard: false),
              ],
            ),
          ),
          if (!isOpponent)
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in player.hand)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CardWidget(
                        card: c,
                        width: 80,
                        onTap: engine.canPlayLand(player) ? () {
                          engine.playLand(c);
                          setState(() {});
                          
                          Future.delayed(const Duration(milliseconds: 10), () {
                            if (mounted) {
                              engine.triggerLandEffect(c);
                              setState(() {});
                            }
                          });
                        } : null,
                      ),
                    ),
                ],
              ),
            ),
          if (isOpponent)
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [for (int i = 0; i < player.hand.length; i++) const Padding(padding: EdgeInsets.only(right: 8), child: CardBackWidget(width: 55))],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sidePile(BuildContext context, {required Player player, required bool isOpponent, required bool isGraveyard}) {
    final List<Card> cards = isGraveyard ? player.graveyard : player.deck;
    final int count = cards.length;
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isGraveyard ? 'Cimitero' : 'Deck', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () { if (isGraveyard) _showGraveyard(context, player, isOpponent); },
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isGraveyard && count > 0) CardWidget(card: cards.last, width: 50)
                else if (!isGraveyard && count > 0) const CardBackWidget(width: 50)
                else Container(width: 50, height: 70, decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('Vuoto', style: TextStyle(fontSize: 10, color: Colors.grey)))),
                if (count > 0)
                  Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGraveyard(BuildContext context, Player player, bool isOpponent) {
    if (player.graveyard.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Cimitero (${isOpponent ? "Avversario" : "Tuo"})'),
        content: SizedBox(width: double.maxFinite, height: 300, child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: player.graveyard.length, itemBuilder: (context, index) => CardWidget(card: player.graveyard[index], width: 60))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi'))],
      ),
    );
  }

  void _showLog(BuildContext context, GameEngine engine) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log partita'),
        content: SizedBox(width: double.maxFinite, child: ListView(children: [for (final line in engine.log.reversed) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(line, style: const TextStyle(fontSize: 12)))])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi'))],
      ),
    );
  }

  Widget _actionBar(GameEngine engine) {
    if (engine.phase == GamePhase.waitingIslandReaction) return _islandReactionBar(engine);
    if (engine.phase == GamePhase.choosingScry && engine.pending != null) return _scryBar(engine);
    if (engine.phase == GamePhase.choosingBlackmail && engine.pending != null) return _blackmailBar(engine);
    if (engine.phase == GamePhase.choosingMountainTarget && engine.pending != null) return _mountainTargetBar(engine);
    if (engine.phase == GamePhase.choosingRegrowth && engine.pending != null) return _regrowthBar(engine);

    if (engine.winner != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.amber.shade100,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Flexible(child: Text('🏆 Vince ${engine.winner!.name}!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Menu'))]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (engine.activePlayer == engine.p1)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              icon: const Icon(Icons.skip_next),
              label: const Text('Fine turno (Passa all\'AI)'),
              onPressed: () { 
                engine.endTurn(); 
                engine.startTurn(); 
                setState(() {}); 
              },
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              icon: const Icon(Icons.smart_toy),
              label: const Text('Lascia giocare l\'AI'),
              onPressed: () { engine.playAiTurn(); setState(() {}); },
            ),
        ],
      ),
    );
  }

  Widget _islandReactionBar(GameEngine engine) {
    Player responder = engine.activePlayer == engine.aiPlayer ? engine.p1 : engine.p2;
    Card counteredCard = engine.pending!.data as Card;
    
    final islands = responder.hand.where((c) => c.type == LandType.island).toList();
    final others = responder.hand.where((c) => c.type != LandType.island).toList();
    
    if (islands.isEmpty || others.isEmpty) { 
       WidgetsBinding.instance.addPostFrameCallback((_) => engine.declineIslandReaction()); 
       return const SizedBox.shrink(); 
    }

    return Container(
      color: Colors.amber.shade100, padding: const EdgeInsets.all(8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          engine.activePlayer == engine.aiPlayer 
            ? "L'avversario ha giocato ${counteredCard.type.label}. Vuoi neutralizzarla?" 
            : "Hai giocato ${counteredCard.type.label}. L'avversario può neutralizzarla...",
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: 4), 
        Text(
          engine.activePlayer == engine.aiPlayer
            ? 'Serve 1 Isola + 1 altra carta. Scegli l\'altra carta:'
            : 'Se non vuoi aspettare, scegli l\'altra carta per far rispondere l\'AI:', 
          style: const TextStyle(fontSize: 12)
        ), 
        const SizedBox(height: 6),
        SizedBox(height: 90, child: ListView(scrollDirection: Axis.horizontal, children: [for (final c in others) CardWidget(card: c, width: 50, selected: _selectedOther?.id == c.id, onTap: () => setState(() => _selectedOther = c))])),
        const SizedBox(height: 6),
        Row(children: [
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { setState(() => _selectedOther = null); engine.declineIslandReaction(); }, child: const Text('No, lascia entrare')),
          const SizedBox(width: 8),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: _selectedOther == null ? null : () { engine.playIslandCounter(islands.first, _selectedOther!); setState(() => _selectedOther = null); }, child: const Text('Neutralizza!')),
        ]),
      ]),
    );
  }

  Widget _scryBar(GameEngine engine) {
    final caster = engine.pending!.data as dynamic;
    Card? top;
    if (caster.deck.isNotEmpty) top = caster.deck.first as Card;
    if (top == null) { WidgetsBinding.instance.addPostFrameCallback((_) => engine.resolveScry(keepOnTop: true)); return const SizedBox.shrink(); }
    return Container(
      color: Colors.amber.shade100, padding: const EdgeInsets.all(8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Profetizzare 1: guarda la prima carta.', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(children: [
          CardWidget(card: top, width: 60), const SizedBox(width: 12),
          ElevatedButton(onPressed: () => engine.resolveScry(keepOnTop: true), child: const Text('Lascia in cima')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: () => engine.resolveScry(keepOnTop: false), child: const Text('Metti in fondo')),
        ]),
      ]),
    );
  }

  Widget _blackmailBar(GameEngine engine) {
    final shown = engine.pending!.data as List<Card>;
    return Container(
      color: Colors.amber.shade100, padding: const EdgeInsets.all(8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ricatto: scegli 1 carta dalla mano avversaria.', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(height: 105, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final c in shown) Column(children: [
            const Text('Avversario', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
            CardWidget(card: c, width: 55, onTap: () => engine.resolveBlackmail(c)),
          ])
        ])),
      ]),
    );
  }

  Widget _mountainTargetBar(GameEngine engine) {
    final targets = engine.pending!.data as List<Card>;
    return Container(
      color: Colors.amber.shade100, padding: const EdgeInsets.all(8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pioggia di Pietre: distruggi 1 terra.', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(height: 105, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final c in targets) Column(children: [
            Text(engine.p2.battlefield.contains(c) ? 'Avversario' : 'Tua', style: TextStyle(fontSize: 10, color: engine.p2.battlefield.contains(c) ? Colors.red : Colors.blue, fontWeight: FontWeight.bold)),
            CardWidget(card: c, width: 55, onTap: () => engine.resolveMountainTarget(c)),
          ])
        ])),
      ]),
    );
  }

  Widget _regrowthBar(GameEngine engine) {
    final caster = engine.pending!.data as dynamic;
    final lands = (caster.graveyard as List).cast<Card>();
    if (lands.isEmpty) { WidgetsBinding.instance.addPostFrameCallback((_) => engine.resolveRegrowth(caster.graveyard.first as Card)); return const SizedBox.shrink(); }
    return Container(
      color: Colors.amber.shade100, padding: const EdgeInsets.all(8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ricrescita: riprendi 1 terra dal cimitero.', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(height: 90, child: ListView(scrollDirection: Axis.horizontal, children: [for (final c in lands) CardWidget(card: c, width: 55, onTap: () => engine.resolveRegrowth(c))])),
      ]),
    );
  }
}