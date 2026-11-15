import 'package:flutter/foundation.dart';
import '../models/card.dart';
import '../models/player.dart';
import 'pending_action.dart';

enum GamePhase {
  playing,
  waitingIslandReaction,
  choosingMountainTarget,
  choosingScry,
  choosingBlackmail,
  choosingRegrowth,
  gameOver,
}

class GameEngine extends ChangeNotifier {
  final Player p1;
  final Player p2;
  late Player activePlayer;
  Player? winner;
  GamePhase phase = GamePhase.playing;
  PendingAction? pending;
  int turnNumber = 1;
  bool firstTurnSkippedDraw = false;
  final List<String> log = [];
  
  String? aiNotification;

  // Tiene traccia della carta che l'AI ha appena giocato ma che non è ancora entrata in campo
  Card? _pendingAiLand;

  GameEngine(this.p1, this.p2) {
    activePlayer = p1;
    _startGame();
  }

  Player get opponent => activePlayer == p1 ? p2 : p1;
  Player get humanPlayer => p1;
  Player get aiPlayer => p2;

  void _startGame() {
    _fillDeck(p1);
    _fillDeck(p2);
    p1.shuffleDeck();
    p2.shuffleDeck();
    for (int i = 0; i < 3; i++) {
      p1.drawCard();
      p2.drawCard();
    }
    _log('Partita iniziata. Mano iniziale: 3 carte a testa.');
    notifyListeners();
  }

  void _fillDeck(Player p) {
    for (final t in LandType.values) {
      for (int i = 0; i < 5; i++) {
        p.deck.add(Card(t));
      }
    }
  }

  void _log(String s) => log.add(s);
  void clearAiNotification() { aiNotification = null; notifyListeners(); }

  void startTurn() {
    if (phase == GamePhase.gameOver) return;
    activePlayer.hasPlayedLandThisTurn = false;

    if (!firstTurnSkippedDraw && turnNumber == 1 && activePlayer == p1) {
      firstTurnSkippedDraw = true;
      _log('Turno 1: ${activePlayer.name} salta la pescata.');
    } else {
      final c = activePlayer.drawCard();
      if (c != null) {
        _log('${activePlayer.name} pesca una carta.');
      } else {
        _log('${activePlayer.name} non ha carte da pescare.');
      }
    }
    notifyListeners();
  }

  void endTurn() {
    if (phase == GamePhase.gameOver) return;
    activePlayer.discardToSeven();
    activePlayer = opponent;
    turnNumber++;
    _log('--- Turno $turnNumber: ${activePlayer.name} ---');
    notifyListeners();
  }

  bool canPlayLand(Player p) =>
      p == activePlayer &&
      !p.hasPlayedLandThisTurn &&
      phase == GamePhase.playing &&
      winner == null;

  // --- LOGICA DI GIOCO (UMANO) ---
  void playLand(Card card) {
    if (!canPlayLand(activePlayer)) return;
    if (!activePlayer.hand.remove(card)) return;

    _log('${activePlayer.name} gioca ${card.type.label}.');
    activePlayer.hasPlayedLandThisTurn = true;
    activePlayer.battlefield.add(card);
    
    notifyListeners(); 
  }

  void triggerLandEffect(Card card) {
    if (phase != GamePhase.playing) return; 

    _log('${card.type.label} attiva il suo effetto.');
    
    switch (card.type) {
      case LandType.plains:
        activePlayer.drawCard();
        _log('${activePlayer.name} pesca 1 carta.');
        _checkWinner();
        notifyListeners();
        break;
      case LandType.island:
        if (activePlayer.deck.isEmpty) {
          _log('Grimorio vuoto: Profetizzare non ha effetto.');
          _checkWinner();
          notifyListeners();
        } else {
          pending = PendingAction(PendingType.scryOne, activePlayer);
          phase = GamePhase.choosingScry;
          notifyListeners();
        }
        break;
      case LandType.swamp:
        final opp = opponent;
        final count = opp.hand.length < 3 ? opp.hand.length : 3;
        if (count == 0) {
          _log('Mano avversaria vuota: Ricatto senza effetto.');
          _checkWinner();
          notifyListeners();
        } else {
          final shown = opp.hand.take(count).toList();
          pending = PendingAction(PendingType.blackmail, shown);
          phase = GamePhase.choosingBlackmail;
          notifyListeners();
        }
        break;
      case LandType.mountain:
        final targets = <Card>[...p1.battlefield, ...p2.battlefield];
        if (targets.isEmpty) {
          _log('Nessuna terra bersaglio: Montagna senza effetto.');
          _checkWinner();
          notifyListeners();
        } else {
          pending = PendingAction(PendingType.mountainTarget, targets);
          phase = GamePhase.choosingMountainTarget;
          notifyListeners();
        }
        break;
      case LandType.forest:
        final lands = activePlayer.graveyard.where((c) => c is Card).toList();
        if (lands.isEmpty) {
          _log('Cimitero vuoto: Ricrescita senza effetto.');
          _checkWinner();
          notifyListeners();
        } else {
          pending = PendingAction(PendingType.regrowth, activePlayer);
          phase = GamePhase.choosingRegrowth;
          notifyListeners();
        }
        break;
    }
  }

  // --- GESTIONE TURNO AI E ISOLA ---
  
  void declineIslandReaction() {
    if (phase != GamePhase.waitingIslandReaction || pending == null) return;
    final card = pending!.data as Card;
    pending = null;
    phase = GamePhase.playing;
    
    // Se la carta era dell'AI, ora la facciamo entrare in campo ed eseguiamo l'effetto
    if (activePlayer == aiPlayer) {
       _pendingAiLand = null;
       aiPlayer.battlefield.add(card); // <-- Aggiunge la carta al campo SOLO ORA
       notifyListeners();
       _applyAiEffect(card, aiPlayer);
       _completeAiTurn();
    } else {
       triggerLandEffect(card);
    }
  }

  void playIslandCounter(Card island, Card other) {
    if (phase != GamePhase.waitingIslandReaction || pending == null) return;
    final countered = pending!.data as Card;
    
    Player caster = activePlayer; 
    
    if (caster == aiPlayer) {
      // L'umano neutralizza l'AI
      p1.hand.remove(island);
      p1.hand.remove(other);
      p1.graveyard.add(island);
      p1.graveyard.add(other);
      
      // La carta neutralizzata va DIRETTAMENTE nel cimitero, non passa dal campo
      aiPlayer.graveyard.add(countered);
      _pendingAiLand = null;
      
      aiNotification = 'Hai neutralizzato ${countered.type.label} dell\'avversario!';
    } else {
      // L'AI neutralizza l'umano
      p2.hand.remove(island);
      p2.hand.remove(other);
      p2.graveyard.add(island);
      p2.graveyard.add(other);
      
      p1.graveyard.add(countered);
      // Se la carta neutralizzata era sul campo dell'umano, la rimuoviamo
      p1.battlefield.remove(countered);
      
      aiNotification = 'L\'avversario ha neutralizzato la tua ${countered.type.label}!';
    }
    
    _log('Neutralizzazione effettuata: ${countered.type.label}.');
    
    pending = null;
    phase = GamePhase.playing;
    
    if (activePlayer == aiPlayer) {
      _completeAiTurn(); 
    } else {
      notifyListeners();
    }
  }

  void playAiTurn() {
    if (winner != null) return;
    
    if (activePlayer != aiPlayer) {
      startTurn();
    }
    
    if (aiPlayer.hand.isNotEmpty && canPlayLand(aiPlayer)) {
      Card? choice = _aiChooseBestCard();
      if (choice != null) {
        _log('${aiPlayer.name} gioca ${choice.type.label}.');
        aiPlayer.hasPlayedLandThisTurn = true;
        
        // Rimuoviamo dalla mano ma NON mettiamo in campo (aspetta la reazione)
        aiPlayer.hand.remove(choice);
        _pendingAiLand = choice;
        
        // Controlla se l'UMANO può neutralizzare
        final humanIslands = p1.hand.where((c) => c.type == LandType.island).toList();
        if (humanIslands.isNotEmpty && p1.hand.length >= 2) {
          pending = PendingAction(PendingType.islandReaction, choice);
          phase = GamePhase.waitingIslandReaction;
          notifyListeners();
          return;
        }

        // Se l'umano non ha l'Isola, mettiamo subito in campo
        aiPlayer.battlefield.add(choice);
        _pendingAiLand = null;
        notifyListeners();
        _applyAiEffect(choice, aiPlayer);
      }
    }
    
    _completeAiTurn();
  }

  void _completeAiTurn() {
    if (winner != null) return;
    
    _log('${aiPlayer.name} termina il suo turno.');
    endTurn(); 
    
    if (winner == null) {
      startTurn(); 
    }
    notifyListeners();
  }

  void _applyAiEffect(Card card, Player caster) {
    switch (card.type) {
      case LandType.plains:
        caster.drawCard();
        _log('${caster.name} pesca 1 carta.');
        break;
      case LandType.island:
        if (caster.deck.isNotEmpty) _log('${caster.name} guarda la prima carta e la lascia in cima.');
        break;
      case LandType.swamp:
        final opp = opponent;
        final count = opp.hand.length < 3 ? opp.hand.length : 3;
        if (count > 0) {
          final shown = opp.hand.take(count).toList();
          final chosen = shown.first;
          opp.hand.remove(chosen);
          opp.graveyard.add(chosen);
          _log('${caster.name} fa scartare una carta a caso.');
        }
        break;
      case LandType.mountain:
        final humanLands = opponent.battlefield.toList();
        if (humanLands.isNotEmpty) {
          final target = humanLands.first;
          opponent.battlefield.remove(target);
          opponent.graveyard.add(target);
          _log('${caster.name} distrugge una ${target.type.label} avversaria.');
        }
        break;
      case LandType.forest:
        final lands = caster.graveyard.where((c) => c is Card).toList();
        if (lands.isNotEmpty) {
          final target = lands.first;
          caster.graveyard.remove(target);
          caster.hand.add(target);
          _log('${caster.name} riprende una ${target.type.label} dal cimitero.');
        }
        break;
    }
    _checkWinner();
    aiNotification = '${caster.name} ha giocato ${card.type.label} e ne ha attivato l\'effetto.';
    notifyListeners();
  }

  // --- RISOLUZIONE EFFETTI (UMANO) ---
  void resolveScry({required bool keepOnTop}) {
    if (phase != GamePhase.choosingScry || pending == null) return;
    final caster = pending!.data as Player;
    if (caster.deck.isEmpty) { _afterEffect(); return; }
    if (!keepOnTop) {
      final top = caster.deck.removeAt(0);
      caster.deck.add(top);
      _log('${caster.name} mette la carta in fondo.');
    } else {
      _log('${caster.name} lascia la carta in cima.');
    }
    _afterEffect();
  }

  void resolveBlackmail(Card chosen) {
    if (phase != GamePhase.choosingBlackmail || pending == null) return;
    final opp = opponent;
    if (opp.hand.remove(chosen)) {
      opp.graveyard.add(chosen);
      _log('${opp.name} scarta ${chosen.type.label} per Ricatto.');
    }
    _afterEffect();
  }

  void resolveMountainTarget(Card? target) {
    if (phase != GamePhase.choosingMountainTarget || pending == null) return;
    if (target != null) {
      final owner = p1.battlefield.contains(target) ? p1 : p2;
      owner.battlefield.remove(target);
      owner.graveyard.add(target);
      _log('${target.type.label} distrutta da Pioggia di Pietre.');
    }
    _afterEffect();
  }

  void resolveRegrowth(Card chosen) {
    if (phase != GamePhase.choosingRegrowth || pending == null) return;
    final caster = pending!.data as Player;
    if (caster.graveyard.remove(chosen)) {
      caster.hand.add(chosen);
      _log('${caster.name} riprende ${chosen.type.label} dal cimitero.');
    }
    _afterEffect();
  }

  void _afterEffect() {
    pending = null;
    if (phase != GamePhase.gameOver) {
      phase = GamePhase.playing;
    }
    _checkWinner();
    notifyListeners();
  }

  void _checkWinner() {
    for (final p in [p1, p2]) {
      final types = p.battlefield.map((c) => c.type).toSet();
      if (types.length == 5) {
        winner = p;
        phase = GamePhase.gameOver;
        _log('${p.name} vince per DOMINIO COMPLETO!');
        return;
      }
      final counts = <LandType, int>{};
      for (final c in p.battlefield) {
        counts[c.type] = (counts[c.type] ?? 0) + 1;
      }
      if (counts.values.any((v) => v >= 5)) {
        winner = p;
        phase = GamePhase.gameOver;
        _log('${p.name} vince per CINQUE DI UN TIPO!');
        return;
      }
    }
  }

  Card? _aiChooseBestCard() {
    if (aiPlayer.hand.isEmpty) return null;
    final counts = <LandType, int>{};
    for (final c in aiPlayer.battlefield) {
      counts[c.type] = (counts[c.type] ?? 0) + 1;
    }
    final types = counts.keys.toSet();
    if (types.length == 4) {
      for (final c in aiPlayer.hand) {
        if (!types.contains(c.type)) return c;
      }
    }
    for (final c in aiPlayer.hand) {
      if ((counts[c.type] ?? 0) == 4) return c;
    }
    final handCounts = <LandType, int>{};
    for (final c in aiPlayer.hand) {
      handCounts[c.type] = (handCounts[c.type] ?? 0) + 1;
    }
    aiPlayer.hand.sort((a, b) =>
        (handCounts[b.type] ?? 0).compareTo(handCounts[a.type] ?? 0));
    return aiPlayer.hand.first;
  }
}