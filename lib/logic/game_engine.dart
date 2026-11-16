import 'dart:math';
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
  final Random _random = Random();

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
    p1.deck.shuffle(_random);
    p2.deck.shuffle(_random);
    for (int i = 0; i < 3; i++) {
      _drawCard(p1);
      _drawCard(p2);
    }
    _log('Partita iniziata. Mano iniziale: 3 carte a testa.');
    notifyListeners();
  }

  void _fillDeck(Player p) {
    p.deck.clear();
    for (final t in LandType.values) {
      for (int i = 0; i < 5; i++) {
        p.deck.add(Card(t));
      }
    }
  }

  void _log(String s) => log.add(s);
  void clearAiNotification() { aiNotification = null; notifyListeners(); }

  void _drawCard(Player p) {
    if (p.deck.isEmpty) {
      if (p.graveyard.isEmpty) return;
      p.deck.addAll(p.graveyard);
      p.graveyard.clear();
      p.deck.shuffle(_random);
      _log('${p.name} rimescola il cimitero nel grimorio.');
    }
    if (p.deck.isNotEmpty) {
      p.hand.add(p.deck.removeAt(0));
    }
  }

  void startTurn() {
    if (phase == GamePhase.gameOver) return;
    activePlayer.hasPlayedLandThisTurn = false;

    if (turnNumber == 1 && activePlayer == p1 && !firstTurnSkippedDraw) {
      firstTurnSkippedDraw = true;
      _log('Turno 1: ${activePlayer.name} salta la pescata.');
    } else {
      _drawCard(activePlayer);
      _log('${activePlayer.name} pesca una carta.');
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

    final aiIslands = p2.hand.where((c) => c.type == LandType.island).toList();
    if (aiIslands.isNotEmpty && p2.hand.length >= 2 && _shouldAiCounter(card)) {
      Card islandToDiscard = aiIslands.first;
      Card otherToDiscard = p2.hand.firstWhere((c) => c.id != islandToDiscard.id);
      
      p2.hand.remove(islandToDiscard);
      p2.hand.remove(otherToDiscard);
      p2.graveyard.add(islandToDiscard);
      p2.graveyard.add(otherToDiscard);
      
      p1.battlefield.remove(card); 
      p1.graveyard.add(card);
      
      aiNotification = "L'avversario ha usato un'Isola per neutralizzare la tua ${card.type.label}!";
      _log('AI ha neutralizzato ${card.type.label}.');
      _checkWinner();
      notifyListeners();
      return;
    }

    _log('${card.type.label} attiva il suo effetto.');
    
    switch (card.type) {
      case LandType.plains:
        _drawCard(activePlayer);
        _log('${activePlayer.name} pesca 1 carta.');
        break;
      case LandType.island:
        if (activePlayer.deck.isEmpty) {
          _log('Grimorio vuoto.');
        } else {
          pending = PendingAction(PendingType.scryOne, activePlayer);
          phase = GamePhase.choosingScry;
          notifyListeners();
          return;
        }
        break;
      case LandType.swamp:
        final opp = opponent;
        final count = opp.hand.length < 3 ? opp.hand.length : 3;
        if (count == 0) {
          _log('Mano avversaria vuota.');
        } else {
          final shown = opp.hand.take(count).toList();
          pending = PendingAction(PendingType.blackmail, shown);
          phase = GamePhase.choosingBlackmail;
          notifyListeners();
          return;
        }
        break;
      case LandType.mountain:
        final targets = <Card>[...p1.battlefield, ...p2.battlefield];
        if (targets.isEmpty) {
          _log('Nessuna terra bersaglio.');
        } else {
          pending = PendingAction(PendingType.mountainTarget, targets);
          phase = GamePhase.choosingMountainTarget;
          notifyListeners();
          return;
        }
        break;
      case LandType.forest:
        final lands = activePlayer.graveyard.where((c) => c is Card).toList();
        if (lands.isEmpty) {
          _log('Cimitero vuoto.');
        } else {
          pending = PendingAction(PendingType.regrowth, activePlayer);
          phase = GamePhase.choosingRegrowth;
          notifyListeners();
          return;
        }
        break;
    }
    _checkWinner();
    notifyListeners();
  }

  bool _shouldAiCounter(Card card) {
    if (card.type == LandType.mountain) return true;
    final types = p1.battlefield.map((c) => c.type).toSet();
    if (types.length == 4 && !types.contains(card.type)) return true;
    final counts = <LandType, int>{};
    for (final c in p1.battlefield) {
      counts[c.type] = (counts[c.type] ?? 0) + 1;
    }
    if ((counts[card.type] ?? 0) == 4) return true;
    return false;
  }

  // --- ISOLA ISTANTANEA ---
  void declineIslandReaction() {
    if (phase != GamePhase.waitingIslandReaction || pending == null) return;
    final card = pending!.data as Card;
    pending = null;
    phase = GamePhase.playing;
    
    if (activePlayer == aiPlayer) {
       // Se la carta dell'AI non è stata neutralizzata, la facciamo entrare in campo e attiviamo l'effetto
       aiPlayer.battlefield.add(card); 
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
      p1.hand.remove(island);
      p1.hand.remove(other);
      p1.graveyard.add(island);
      p1.graveyard.add(other);
      
      aiPlayer.battlefield.remove(countered);
      aiPlayer.graveyard.add(countered);
      
      aiNotification = 'Hai neutralizzato ${countered.type.label} dell\'avversario!';
    } else {
      p2.hand.remove(island);
      p2.hand.remove(other);
      p2.graveyard.add(island);
      p2.graveyard.add(other);
      
      p1.battlefield.remove(countered);
      p1.graveyard.add(countered);
      
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

  // --- GESTIONE TURNO AI ---
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
        aiPlayer.hand.remove(choice);
        
        // CONTROLLO ISOLA: prima di aggiungere al campo, chiediamo se l'umano vuole neutralizzare
        final humanIslands = p1.hand.where((c) => c.type == LandType.island).toList();
        if (humanIslands.isNotEmpty && p1.hand.length >= 2) {
          pending = PendingAction(PendingType.islandReaction, choice);
          phase = GamePhase.waitingIslandReaction;
          notifyListeners();
          return; 
        }

        // Se l'umano non può neutralizzare, aggiungiamo la carta al campo SOLO ORA
        aiPlayer.battlefield.add(choice);
        notifyListeners();

        // Se è una Montagna, l'AI sceglie il bersaglio
        if (choice.type == LandType.mountain) {
          _aiChooseBestMountainTarget();
        } else {
          _applyAiEffect(choice, aiPlayer);
        }
      }
    }
    
    _completeAiTurn();
  }

  void _aiChooseBestMountainTarget() {
    final humanLands = p1.battlefield;
    if (humanLands.isEmpty) {
      aiNotification = "L'avversario ha giocato una Montagna, ma non avevi terre da distruggere.";
      notifyListeners();
      _checkWinner();
      return;
    }

    final types = humanLands.map((c) => c.type).toSet();
    Card? target;
    
    if (types.length == 4) {
      target = humanLands.first;
    } else {
      final counts = <LandType, int>{};
      for (final c in humanLands) {
        counts[c.type] = (counts[c.type] ?? 0) + 1;
      }
      final maxType = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      if ((counts[maxType] ?? 0) >= 4) {
        target = humanLands.firstWhere((c) => c.type == maxType);
      } else {
        target = humanLands.first;
      }
    }

    if (target != null) {
      p1.battlefield.remove(target);
      p1.graveyard.add(target);
      aiNotification = "L'avversario ha giocato una Montagna e ha distrutto la tua ${target.type.label}.";
      _log('${aiPlayer.name} distrugge una ${target.type.label} avversaria.');
    }
    _checkWinner();
    notifyListeners();
  }

  void _completeAiTurn() {
    if (winner != null) return;
    endTurn(); 
    if (winner == null) {
      startTurn(); 
    }
    notifyListeners();
  }

  void _applyAiEffect(Card card, Player caster) {
    String effectMessage = '';
    
    switch (card.type) {
      case LandType.plains:
        _drawCard(caster);
        effectMessage = "L'avversario ha giocato una Pianura e ha pescato una carta.";
        break;
      case LandType.island:
        if (caster.deck.isNotEmpty) {
          final top = caster.deck.removeAt(0);
          caster.deck.add(top);
          effectMessage = "L'avversario ha giocato un'Isola e ha messo la prima carta del grimorio in fondo.";
        } else {
          effectMessage = "L'avversario ha giocato un'Isola, ma il grimorio era vuoto.";
        }
        break;
      case LandType.swamp:
        final opp = opponent;
        final count = opp.hand.length < 3 ? opp.hand.length : 3;
        if (count > 0) {
          final shown = opp.hand.take(count).toList();
          final chosen = shown.first;
          opp.hand.remove(chosen);
          opp.graveyard.add(chosen);
          effectMessage = "L'avversario ha giocato una Palude e ti ha fatto scartare una ${chosen.type.label}.";
        } else {
          effectMessage = "L'avversario ha giocato una Palude, ma non avevi carte da scartare.";
        }
        break;
      case LandType.mountain:
        // Già gestito in _aiChooseBestMountainTarget
        effectMessage = "L'avversario ha giocato una Montagna.";
        break;
      case LandType.forest:
        final lands = caster.graveyard.where((c) => c is Card).toList();
        if (lands.isNotEmpty) {
          final target = lands.first;
          caster.graveyard.remove(target);
          caster.hand.add(target);
          effectMessage = "L'avversario ha giocato una Foresta e ha ripreso una ${target.type.label} dal cimitero.";
        } else {
          effectMessage = "L'avversario ha giocato una Foresta, ma non c'era nulla da recuperare nel cimitero.";
        }
        break;
    }
    
    _checkWinner();
    if (effectMessage.isNotEmpty) {
      aiNotification = effectMessage;
    }
    notifyListeners();
  }

  // --- RISOLUZIONE EFFETTI ---
  void resolveScry({required bool keepOnTop}) {
    if (phase != GamePhase.choosingScry || pending == null) return;
    final caster = pending!.data as Player;
    if (caster.deck.isEmpty) { _afterEffect(); return; }
    if (!keepOnTop) {
      final top = caster.deck.removeAt(0);
      caster.deck.add(top);
    }
    _afterEffect();
  }

  void resolveBlackmail(Card chosen) {
    if (phase != GamePhase.choosingBlackmail || pending == null) return;
    final opp = opponent;
    if (opp.hand.remove(chosen)) opp.graveyard.add(chosen);
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
    if (caster.graveyard.remove(chosen)) caster.hand.add(chosen);
    _afterEffect();
  }

  void _afterEffect() {
    pending = null;
    if (phase != GamePhase.gameOver) phase = GamePhase.playing;
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
    
    // Valuta il pericolo: se l'umano è vicino alla vittoria, usa una Montagna o un'Isola per fermarlo
    final humanTypes = p1.battlefield.map((c) => c.type).toSet();
    final humanCounts = <LandType, int>{};
    for (final c in p1.battlefield) {
      humanCounts[c.type] = (humanCounts[c.type] ?? 0) + 1;
    }
    
    if (humanTypes.length == 4 || humanCounts.values.any((v) => v >= 4)) {
      for (final c in aiPlayer.hand) {
        if (c.type == LandType.mountain) {
          return c;
        }
      }
      for (final c in aiPlayer.hand) {
        if (c.type == LandType.island) return c;
      }
    }
    
    // Priorità per completare la vittoria
    final aiTypes = aiPlayer.battlefield.map((c) => c.type).toSet();
    final aiCounts = <LandType, int>{};
    for (final c in aiPlayer.battlefield) {
      aiCounts[c.type] = (aiCounts[c.type] ?? 0) + 1;
    }
    
    if (aiTypes.length == 4) {
      for (final c in aiPlayer.hand) {
        if (!aiTypes.contains(c.type)) return c;
      }
    }
    
    for (final c in aiPlayer.hand) {
      if ((aiCounts[c.type] ?? 0) == 4) return c;
    }
    
    // Altrimenti gioca una carta che non sprechi risorse
    if (p1.battlefield.isEmpty) {
      for (final c in aiPlayer.hand) {
        if (c.type != LandType.mountain) return c;
      }
    }
    
    if (aiPlayer.graveyard.isEmpty) {
      for (final c in aiPlayer.hand) {
        if (c.type != LandType.forest) return c;
      }
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