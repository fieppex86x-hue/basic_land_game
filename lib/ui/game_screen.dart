import 'package:flutter/material.dart' hide Card;
import 'package:provider/provider.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../logic/game_engine.dart';
import '../models/card.dart';
import '../models/player.dart';
import 'widgets/card_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  Card? _selectedOther;
  Card? _hoveredCard;
  
  bool _isAiThinking = false;
  bool _showTurnEndMessage = false;
  
  bool _isVictorySequenceRunning = false;
  bool _showFinalScreen = false;
  List<Card> _winningCards = [];
  int _currentWinningCardIndex = -1;

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  AudioSource? _sparkleSource;
  final List<SoundHandle> _activeHandles = []; // Lista di tutti i suoni attivi
  bool _audioInitialized = false;

  @override
  void initState() {
    super.initState();
    final engine = context.read<GameEngine>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      engine.startTurn();
    });

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeOut),
    );

    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init();
      }
      _sparkleSource = await SoLoud.instance.loadWaveform(
        WaveForm.sin,
        false,
        0.2,
        0.0,
      );
      _audioInitialized = true;
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  void _playSparkleSound() {
    if (!_audioInitialized || _sparkleSource == null) return;
    try {
      SoLoud.instance.setWaveformFreq(_sparkleSource!, 600);
      final handle = SoLoud.instance.play(_sparkleSource!);
      SoLoud.instance.setVolume(handle, 0.2);
      _activeHandles.add(handle); // Salva l'handle per fermarlo dopo
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  // Ferma TUTTI i suoni attivi
  void _stopAllSparkleSounds() {
    for (final handle in _activeHandles) {
      try {
        SoLoud.instance.stop(handle);
      } catch (e) {
        debugPrint('Audio stop error: $e');
      }
    }
    _activeHandles.clear();
  }

  @override
  void dispose() {
    _stopAllSparkleSounds();
    _blinkController.dispose();
    if (_sparkleSource != null) {
      SoLoud.instance.disposeSource(_sparkleSource!);
    }
    super.dispose();
  }

  void _handleAiTurn(GameEngine engine) async {
    setState(() {
      _isAiThinking = true;
      _showTurnEndMessage = false;
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) engine.playAiTurn();

    if (mounted) {
      setState(() {
        _isAiThinking = false;
        _showTurnEndMessage = true;
      });
    }

    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      setState(() {
        _showTurnEndMessage = false;
      });
    }
  }

  void _startVictorySequence(GameEngine engine) async {
    if (_isVictorySequenceRunning || _showFinalScreen) return;
    
    setState(() {
      _isVictorySequenceRunning = true;
    });

    final winner = engine.winner!;
    final battlefield = winner.battlefield;
    _winningCards = [];

    final types = battlefield.map((c) => c.type).toSet();
    if (types.length == 5) {
      for (final t in types) {
        _winningCards.add(battlefield.firstWhere((c) => c.type == t));
      }
    } else {
      final counts = <LandType, int>{};
      for (final c in battlefield) {
        counts[c.type] = (counts[c.type] ?? 0) + 1;
      }
      final winningType = counts.entries.firstWhere((e) => e.value >= 5).key;
      _winningCards = battlefield.where((c) => c.type == winningType).toList();
    }

    for (int i = 0; i < _winningCards.length; i++) {
      if (!mounted) return;
      
      setState(() {
        _currentWinningCardIndex = i;
      });

      _playSparkleSound();
      _blinkController.forward(from: 0.0);
      
      await _blinkController.forward(from: 0.0).orCancel;
      
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // FERMA TUTTI I SUONI PRIMA DI MOSTRARE LA SCHERMATA FINALE
    _stopAllSparkleSounds();

    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _isVictorySequenceRunning = false;
        _showFinalScreen = true;
        _currentWinningCardIndex = -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameEngine>(
      builder: (context, engine, _) {
        if (engine.winner != null && !_isVictorySequenceRunning && !_showFinalScreen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startVictorySequence(engine);
          });
        }

        if (engine.winner != null && _showFinalScreen) {
          // Ferma i suoni anche qui, per sicurezza
          _stopAllSparkleSounds();
          return _gameOverScreen(context, engine);
        }

        if (engine.aiNotification != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAiNotification(context, engine, engine.aiNotification!);
            engine.clearAiNotification();
          });
        }

        return _buildGameBody(context, engine);
      },
    );
  }

  Widget _buildGameBody(BuildContext context, GameEngine engine) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C35),
        elevation: 0,
        title: Text(
          'Turno ${engine.turnNumber} — ${engine.activePlayer.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showLog(context, engine),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 4,
                  child: _playerBoard(context, engine: engine, player: engine.p2, isOpponent: true, label: 'Avversario (AI)', color: Colors.redAccent),
                ),
                Container(height: 2, color: Colors.black),
                Expanded(
                  flex: 5,
                  child: _playerBoard(context, engine: engine, player: engine.p1, isOpponent: false, label: 'Il Tuo Campo', color: Colors.lightBlueAccent),
                ),
                _actionBar(engine),
              ],
            ),
            
            if (_isAiThinking || _showTurnEndMessage)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.75),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isAiThinking
                          ? _buildOverlayMessage(
                              key: const ValueKey('thinking'),
                              icon: const CircularProgressIndicator(color: Colors.lightBlueAccent),
                              text: "L'avversario sta giocando...",
                            )
                          : _buildOverlayMessage(
                              key: const ValueKey('end'),
                              icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 50),
                              text: "Turno concluso!\nTocca a te.",
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayMessage({required Key key, required Widget icon, required String text}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.lightBlueAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
        ]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedCards(List<Card> battlefield, {bool isOpponent = false}) {
    final Map<LandType, List<Card>> grouped = {};
    for (final c in battlefield) {
      grouped.putIfAbsent(c.type, () => []).add(c);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final entry in grouped.entries)
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _blinkAnimation,
                builder: (context, child) {
                  final isWinningGroup = _winningCards.any((w) => entry.value.contains(w));
                  final isCurrentlyBlinking = _isVictorySequenceRunning && isWinningGroup && _currentWinningCardIndex >= 0;
                  
                  final glowOpacity = isCurrentlyBlinking ? _blinkAnimation.value : 0.0;
                  final scale = isCurrentlyBlinking ? 1.0 + (0.1 * _blinkAnimation.value) : 1.0;

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: isCurrentlyBlinking
                            ? [BoxShadow(color: Colors.amber.withOpacity(glowOpacity), blurRadius: 20, spreadRadius: 5)]
                            : [],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: child,
                    ),
                  );
                },
                child: CardWidget(card: entry.value.last, width: 55),
              ),
              if (entry.value.length > 1)
                Positioned(
                  bottom: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: Text(
                      '${entry.value.length}',
                      style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _gameOverScreen(BuildContext context, GameEngine engine) {
    bool isHumanWinner = engine.winner == engine.p1;
    String reason = "";
    final types = engine.winner!.battlefield.map((c) => c.type).toSet();
    if (types.length == 5) {
      reason = "Vittoria per DOMINIO COMPLETO (5 tipi diversi).";
    } else {
      final counts = <LandType, int>{};
      for (final c in engine.winner!.battlefield) {
        counts[c.type] = (counts[c.type] ?? 0) + 1;
      }
      final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
      if (maxCount >= 5) {
        reason = "Vittoria per CINQUE DI UN TIPO.";
      }
    }

    return Scaffold(
      backgroundColor: isHumanWinner ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isHumanWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                size: 120,
                color: Colors.amber,
              ),
              const SizedBox(height: 24),
              Text(
                isHumanWinner ? 'HAI VINTO!' : 'HAI PERSO!',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                isHumanWinner ? 'Hai dominato il campo di battaglia.' : 'L\'avversario ha avuto la meglio.',
                style: const TextStyle(fontSize: 20, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Gioca Ancora'),
                onPressed: () {
                  Navigator.pop(context); 
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAiNotification(BuildContext context, GameEngine engine, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C35),
        title: const Text('Mossa Avversario', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('OK', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }

  Widget _playerBoard(BuildContext context, {required GameEngine engine, required Player player, required bool isOpponent, required String label, required Color color}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border(
          top: isOpponent ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
          bottom: isOpponent ? BorderSide(color: Colors.white.withOpacity(0.1), width: 1) : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color, letterSpacing: 1.2)),
                Text('Mano: ${player.hand.length} | Cimitero: ${player.graveyard.length} | Deck: ${player.deck.length}', style: const TextStyle(fontSize: 11, color: Colors.white54))
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
                      child: _buildStackedCards(player.battlefield, isOpponent: isOpponent),
                    ),
                  ),
                ),
                _sidePile(context, player: player, isOpponent: isOpponent, isGraveyard: false),
              ],
            ),
          ),
          if (!isOpponent)
            Container(
              height: 120, 
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double cardWidth = player.hand.isEmpty ? 60 : (constraints.maxWidth / player.hand.length) - 6;
                  if (cardWidth > 75) cardWidth = 75; 
                  if (cardWidth < 35) cardWidth = 35;  

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final c in player.hand)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTapDown: (_) => setState(() => _hoveredCard = c),
                            onTapUp: (_) => setState(() => _hoveredCard = null),
                            onTapCancel: () => setState(() => _hoveredCard = null),
                            onTap: engine.canPlayLand(player) && !_isAiThinking && !_isVictorySequenceRunning ? () {
                              setState(() => _hoveredCard = null);
                              engine.playLand(c);
                              setState(() {});
                              Future.delayed(const Duration(milliseconds: 10), () {
                                if (mounted) {
                                  engine.triggerLandEffect(c);
                                  setState(() {});
                                }
                              });
                            } : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              transform: Matrix4.translationValues(0, _hoveredCard?.id == c.id ? -15 : 0, 0),
                              child: CardWidget(card: c, width: cardWidth),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          if (isOpponent)
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [for (int i = 0; i < player.hand.length; i++) const Padding(padding: EdgeInsets.only(right: 8), child: CardBackWidget(width: 40))],
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
      width: 55,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isGraveyard ? 'Cimitero' : 'Deck', style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () { if (isGraveyard) _showGraveyard(context, player, isOpponent); },
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isGraveyard && count > 0) CardWidget(card: cards.last, width: 40)
                else if (!isGraveyard && count > 0) const CardBackWidget(width: 40)
                else Container(
                  width: 40, height: 56, 
                  decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(6)), 
                  child: const Center(child: Text('Vuoto', style: TextStyle(fontSize: 9, color: Colors.white38)))
                ),
                if (count > 0)
                  Positioned(bottom: -2, right: -2, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.lightBlueAccent, shape: BoxShape.circle), child: Text('$count', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)))),
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
        backgroundColor: const Color(0xFF2C2C35),
        title: Text('Cimitero (${isOpponent ? "Avversario" : "Tuo"})', style: const TextStyle(color: Colors.white)),
        content: SizedBox(width: double.maxFinite, height: 300, child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: player.graveyard.length, itemBuilder: (context, index) => CardWidget(card: player.graveyard[index], width: 60))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi', style: TextStyle(color: Colors.lightBlueAccent)))],
      ),
    );
  }

  void _showLog(BuildContext context, GameEngine engine) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C35),
        title: const Text('Log partita', style: TextStyle(color: Colors.white)),
        content: SizedBox(width: double.maxFinite, child: ListView(children: [for (final line in engine.log.reversed) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(line, style: const TextStyle(fontSize: 13, color: Colors.white70)))])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi', style: TextStyle(color: Colors.lightBlueAccent)))],
      ),
    );
  }

  Widget _actionBar(GameEngine engine) {
    if (engine.phase == GamePhase.waitingIslandReaction) return _islandReactionBar(engine);
    if (engine.phase == GamePhase.choosingScry && engine.pending != null) return _scryBar(engine);
    if (engine.phase == GamePhase.choosingBlackmail && engine.pending != null) return _blackmailBar(engine);
    if (engine.phase == GamePhase.choosingMountainTarget && engine.pending != null) return _mountainTargetBar(engine);
    if (engine.phase == GamePhase.choosingRegrowth && engine.pending != null) return _regrowthBar(engine);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFF2C2C35), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -2))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (engine.activePlayer == engine.p1)
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlueAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.skip_next),
                label: const Text('Fine turno', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: _isAiThinking || _showTurnEndMessage || _isVictorySequenceRunning || _showFinalScreen ? null : () { 
                  engine.endTurn(); 
                  engine.startTurn(); 
                  setState(() {}); 
                },
              ),
            )
          else
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.smart_toy),
                label: const Text('Gioca AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: _isAiThinking || _showTurnEndMessage || _isVictorySequenceRunning || _showFinalScreen ? null : () { _handleAiTurn(engine); },
              ),
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
      color: const Color(0xFF3E3E4A), padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(engine.activePlayer == engine.aiPlayer ? "L'avversario ha giocato ${counteredCard.type.label}. Vuoi neutralizzarla?" : "Hai giocato ${counteredCard.type.label}. L'avversario può neutralizzarla...", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 6), 
          Text(engine.activePlayer == engine.aiPlayer ? 'Serve 1 Isola + 1 altra carta. Scegli l\'altra carta:' : 'Se non vuoi aspettare, scegli l\'altra carta per far rispondere l\'AI:', style: const TextStyle(fontSize: 12, color: Colors.white70)), 
          const SizedBox(height: 10),
          SizedBox(height: 90, child: ListView(scrollDirection: Axis.horizontal, children: [for (final c in others) Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(onTap: () => setState(() => _selectedOther = c), child: Container(decoration: BoxDecoration(border: Border.all(color: _selectedOther?.id == c.id ? Colors.amber : Colors.transparent, width: 3), borderRadius: BorderRadius.circular(8)), child: CardWidget(card: c, width: 50))))])),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () { setState(() => _selectedOther = null); engine.declineIslandReaction(); }, child: const Text('No, lascia entrare', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _selectedOther == null ? null : () { engine.playIslandCounter(islands.first, _selectedOther!); setState(() => _selectedOther = null); }, child: const Text('Neutralizza!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ]),
        ]
      ),
    );
  }

  Widget _scryBar(GameEngine engine) {
    final caster = engine.pending!.data as dynamic;
    Card? top;
    if (caster.deck.isNotEmpty) top = caster.deck.first as Card;
    if (top == null) { WidgetsBinding.instance.addPostFrameCallback((_) => engine.resolveScry(keepOnTop: true)); return const SizedBox.shrink(); }
    return Container(
      color: const Color(0xFF3E3E4A), padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          const Text('Profetizzare 1: guarda la prima carta.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 10),
          Row(children: [
            CardWidget(card: top, width: 60), 
            const SizedBox(width: 16),
            Expanded(child: Column(children: [
              ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40), backgroundColor: Colors.lightBlueAccent), onPressed: () => engine.resolveScry(keepOnTop: true), child: const Text('Lascia in cima', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40), backgroundColor: Colors.grey[700]), onPressed: () => engine.resolveScry(keepOnTop: false), child: const Text('Metti in fondo', style: TextStyle(color: Colors.white))),
            ]))
          ]),
        ]
      ),
    );
  }

  Widget _blackmailBar(GameEngine engine) {
    final shown = engine.pending!.data as List<Card>;
    return Container(
      color: const Color(0xFF3E3E4A), padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          const Text('Ricatto: scegli 1 carta avversaria.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 10),
          SizedBox(height: 105, child: ListView(scrollDirection: Axis.horizontal, children: [for (final c in shown) Padding(padding: const EdgeInsets.only(right: 8), child: Column(children: [const Text('Avversario', style: TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)), GestureDetector(onTap: () => engine.resolveBlackmail(c), child: CardWidget(card: c, width: 55))]))])),
        ]
      ),
    );
  }

  Widget _mountainTargetBar(GameEngine engine) {
    final targets = engine.pending!.data as List<Card>;
    return Container(
      color: const Color(0xFF3E3E4A), padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          const Text('Pioggia di Pietre: distruggi 1 terra.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 10),
          SizedBox(height: 105, child: ListView(scrollDirection: Axis.horizontal, children: [for (final c in targets) Padding(padding: const EdgeInsets.only(right: 8), child: Column(children: [Text(engine.p2.battlefield.contains(c) ? 'Avversario' : 'Tua', style: TextStyle(fontSize: 10, color: engine.p2.battlefield.contains(c) ? Colors.redAccent : Colors.lightBlueAccent, fontWeight: FontWeight.bold)), GestureDetector(onTap: () => engine.resolveMountainTarget(c), child: CardWidget(card: c, width: 55))]))])),
        ]
      ),
    );
  }

  Widget _regrowthBar(GameEngine engine) {
    final caster = engine.pending!.data as dynamic;
    final lands = (caster.graveyard as List).cast<Card>();
    if (lands.isEmpty) { WidgetsBinding.instance.addPostFrameCallback((_) => engine.resolveRegrowth(caster.graveyard.first as Card)); return const SizedBox.shrink(); }
    return Container(
      color: const Color(0xFF3E3E4A), padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          const Text('Ricrescita: riprendi 1 terra.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 10),
          SizedBox(height: 90, child: ListView(scrollDirection: Axis.horizontal, children: [for (final c in lands) Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(onTap: () => engine.resolveRegrowth(c), child: CardWidget(card: c, width: 55)))])),
        ]
      ),
    );
  }
}