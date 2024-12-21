import 'package:flutter/material.dart';
import 'package:sudoku_dart/sudoku_dart.dart';
import 'package:sudoku_game/database_helper.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int _totalGames = 0;
  double _winLossRatio = 0.0;
  List<Map<String, dynamic>> _lastMatches = [];

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    final db = DatabaseHelper.instance;

    try {
      // Fetch total games played
      final totalGames = await db.database
          .then((db) => db.rawQuery('SELECT COUNT(*) as count FROM sudoku'));
      _totalGames = totalGames.first['count'] as int;

      // Fetch win/loss ratio
      final winCount = await db.database.then((db) =>
          db.rawQuery('SELECT COUNT(*) as count FROM sudoku WHERE result = 1'));
      final lossCount = await db.database.then((db) =>
          db.rawQuery('SELECT COUNT(*) as count FROM sudoku WHERE result = 0'));

      final wins = winCount.first['count'] as int;
      final losses = lossCount.first['count'] as int;
      _winLossRatio =
          losses > 0 ? wins / losses : (wins > 0 ? wins.toDouble() : 0.0);

      // Fetch last matches
      final lastMatchesQuery = await db.database.then((db) => db.rawQuery('''
        SELECT name, result, date, level
        FROM sudoku
        ORDER BY date DESC
        LIMIT 10
      '''));

      _lastMatches = lastMatchesQuery;

      setState(() {});
    } catch (e) {
      print('Error fetching statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total de Jogos: $_totalGames',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Taxa Vitória/Derrota: ${_winLossRatio.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            const Text('Histórico de Partidas:',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _lastMatches.length,
                itemBuilder: (context, index) {
                  final match = _lastMatches[index];
                  return ListTile(
                    title: Text("Jogador: ${match['name']}"),
                    subtitle: Text(
                      "Resultado: ${match['result'] == 1 ? 'Vitória' : 'Derrota'} | "
                      "Nível: ${Level.values[match['level']].name}",
                    ),
                    trailing: Text(
                      "Data: ${DateTime.parse(match['date']).toLocal()}",
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
