import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/game_engine.dart';
import '../models/player.dart';
import 'game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _startGame(BuildContext context) {
    final engine = GameEngine(Player('Tu'), Player('Avversario'));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: engine,
          child: const GameScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Basic Land Game')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🃏 Basic Land Game',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Il gioco delle Terre Base — MTG Community',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Nuova Partita'),
              onPressed: () => _startGame(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.menu_book),
              label: const Text('Regole'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RulesScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regole')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Text(
          'BASIC LAND GAME — Regole\n\n'
          'MAZZO: 5 copie per ciascuno dei 5 tipi di terra base '
          '(Pianura, Isola, Palude, Montagna, Foresta) = 25 carte.\n\n'
          'SETUP: Mano iniziale di 3 carte. Chi inizia salta la prima pescata.\n\n'
          'TURNO:\n'
          '1. Pesca 1 carta (tranne il primo turno del primo giocatore)\n'
          '2. Gioca al massimo 1 terra dalla mano\n'
          '3. Attiva l\'effetto della terra giocata\n'
          '4. Scarta fino a 7 carte in mano\n\n'
          'EFFETTI:\n'
          '☀ Pianura: peschi 1 carta.\n'
          '💧 Isola: Profetizzare 1 (guarda la cima del grimorio). '
          'ISTANTANEO dalla mano: scarta Isola + un\'altra terra per '
          'neutralizzare una terra avversaria appena giocata.\n'
          '💀 Palude: l\'avversario mostra 3 carte e tu ne scegli 1 da scartare.\n'
          '⛰ Montagna: distruggi 1 terra sul campo (anche tua).\n'
          '🌲 Foresta: riprendi 1 terra dal tuo cimitero.\n\n'
          'VITTORIA:\n'
          '• Dominio Completo: 1 terra per ciascuno dei 5 tipi in campo.\n'
          '• Cinque di un Tipo: 5 terre dello stesso tipo in campo.\n\n'
          'DECK-OUT: se il grimorio è vuoto, rimescola il cimitero.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
      ),
    );
  }
}