import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sudoku_dart/sudoku_dart.dart';
import 'package:sudoku_game/database_helper.dart';
import 'package:sudoku_game/statistics_page.dart';

void main() {
  runApp(const SudokuAppWrapper());
}

class SudokuAppWrapper extends StatefulWidget {
  const SudokuAppWrapper({super.key});

  @override
  _SudokuAppWrapperState createState() => _SudokuAppWrapperState();
}

class _SudokuAppWrapperState extends State<SudokuAppWrapper> {
  bool _isDarkMode = false;

  void toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: SudokuHomePage(
        isDarkMode: _isDarkMode,
        onToggleDarkMode: toggleDarkMode,
      ),
    );
  }
}

class SudokuHomePage extends StatefulWidget {
  final VoidCallback onToggleDarkMode;
  final bool isDarkMode;

  const SudokuHomePage(
      {super.key, required this.onToggleDarkMode, required this.isDarkMode});

  @override
  _SudokuHomePageState createState() => _SudokuHomePageState();
}

class _SudokuHomePageState extends State<SudokuHomePage> {
  final TextEditingController _nicknameController = TextEditingController();
  Level _selectedDifficulty = Level.easy;
  bool _gameStarted = false;
  Sudoku? _sudoku;
  String? _nickname;
  final List<bool> _isInitial = List.filled(81, false);
  final List<bool> _isCorrect = List.filled(81, true);
  Timer? _timer;
  int _elapsedSeconds = 0;
  int? _selectedCell;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _nickname = _nicknameController.text.isEmpty
          ? 'Convidado'
          : _nicknameController.text;
      _sudoku = Sudoku.generate(_selectedDifficulty);
      _gameStarted = true;
      _elapsedSeconds = 0;
      _startTimer();

      for (int i = 0; i < 81; i++) {
        _isInitial[i] = _sudoku!.puzzle[i] != -1;
        _isCorrect[i] = true;
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  String _formattedTime() {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _newGame() {
    setState(() {
      _nicknameController.clear();
      _gameStarted = false;
      _sudoku = null;
      _timer?.cancel();
      _elapsedSeconds = 0;
      _selectedCell = null;
    });
  }

  void _resetPuzzle() {
    setState(() {
      for (int i = 0; i < 81; i++) {
        if (!_isInitial[i]) {
          _sudoku?.puzzle[i] = -1;
          _isCorrect[i] = true;
        }
      }
      _selectedCell = null;
    });
  }

  void _giveHint() {
    setState(() {
      if (_sudoku == null) return;
      for (int i = 0; i < 81; i++) {
        if (_sudoku!.puzzle[i] == -1) {
          _sudoku!.puzzle[i] = _sudoku!.solution[i];
          _isInitial[i] = true;
          _isCorrect[i] = true;
          break;
        }
      }
    });
  }

  void _selectNumber(int number) {
    if (_selectedCell != null && !_isInitial[_selectedCell!]) {
      setState(() {
        _sudoku?.puzzle[_selectedCell!] = number;
        _isCorrect[_selectedCell!] = _checkCorrectness(_selectedCell!, number);
      });
    }
  }

  bool _checkCorrectness(int index, int number) {
    int row = index ~/ 9;
    int col = index % 9;

    for (int i = 0; i < 9; i++) {
      if (i != col && _sudoku!.puzzle[row * 9 + i] == number) return false;
      if (i != row && _sudoku!.puzzle[i * 9 + col] == number) return false;
    }

    int boxRowStart = (row ~/ 3) * 3;
    int boxColStart = (col ~/ 3) * 3;

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        int boxIndex = (boxRowStart + i) * 9 + (boxColStart + j);
        if (boxIndex != index && _sudoku!.puzzle[boxIndex] == number) {
          return false;
        }
      }
    }
    return true;
  }

  void _clearCell() {
    if (_selectedCell != null && !_isInitial[_selectedCell!]) {
      setState(() {
        _sudoku?.puzzle[_selectedCell!] = -1;
        _isCorrect[_selectedCell!] = true;
      });
    }
  }

  void _checkSolution() async {
    if (_sudoku == null) return;

    bool isPuzzleCorrect = true;
    setState(() {
      for (int i = 0; i < 81; i++) {
        if (_sudoku!.puzzle[i] != -1) {
          _isCorrect[i] = _sudoku!.puzzle[i] == _sudoku!.solution[i];
          if (!_isCorrect[i]) {
            isPuzzleCorrect = false;
          }
        } else {
          isPuzzleCorrect = false;
        }
      }
    });

    String resultMessage;
    int resultValue;

    if (isPuzzleCorrect) {
      resultMessage = "Parabéns! Sudoku completo!";
      resultValue = 1; // Vitória
    } else {
      resultMessage = "Ainda há erros ou espaços vazios!";
      resultValue = 0; // Derrota
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resultMessage)),
    );

    // Salvar no banco de dados
    await DatabaseHelper.instance.insertMatch({
      'name': _nickname ?? 'Convidado',
      'result': resultValue,
      'date': DateTime.now().toIso8601String(),
      'level': _selectedDifficulty.index,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatisticsPage()),
              );
            },
            tooltip: 'Estatísticas',
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.nights_stay : Icons.wb_sunny),
            onPressed: () => widget.onToggleDarkMode(),
            tooltip: widget.isDarkMode ? 'Modo Claro' : 'Modo Escuro',
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
            tooltip: 'Buscar Partidas',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                _gameStarted ? _buildGameScreen() : _buildStartScreen(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNicknameInput(),
          const SizedBox(height: 16),
          _buildDifficultySelection(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _startGame,
            child: const Text('Iniciar Jogo'),
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameInput() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: TextField(
        controller: _nicknameController,
        decoration: const InputDecoration(labelText: 'Apelido:'),
      ),
    );
  }

  Widget _buildDifficultySelection() {
    return Column(
      children: [
        const Text('Escolha a dificuldade:'),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: Level.values.map((level) {
            return Row(
              children: [
                Radio<Level>(
                  value: level,
                  groupValue: _selectedDifficulty,
                  onChanged: (Level? value) => setState(() {
                    _selectedDifficulty = value!;
                  }),
                ),
                Text(level.name),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGameScreen() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'Jogador: ${_nickname ?? 'Convidado'} | Time: ${_formattedTime()}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          SudokuGrid(
            puzzle: _sudoku?.puzzle,
            isInitial: _isInitial,
            isCorrect: _isCorrect,
            selectedCell: _selectedCell,
            onCellTap: (index) => setState(() => _selectedCell = index),
          ),
          const SizedBox(height: 12),
          _buildNumberSelection(),
          const SizedBox(height: 12),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildNumberSelection() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8.0,
      children: List.generate(9, (index) {
        return ElevatedButton(
          onPressed: () => _selectNumber(index + 1),
          child: Text('${index + 1}'),
        );
      })
        ..add(
          ElevatedButton(
            onPressed: _clearCell,
            child: const Text('Limpar'),
          ),
        ),
    );
  }

  Widget _buildControls() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 1.0,
      runSpacing: 2.0,
      children: [
        ElevatedButton(onPressed: _newGame, child: const Text('Menu')),
        ElevatedButton(onPressed: _resetPuzzle, child: const Text('Reiniciar')),
        ElevatedButton(onPressed: _giveHint, child: const Text('Dica')),
        ElevatedButton(
            onPressed: _checkSolution, child: const Text('Terminar')),
      ],
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  Level _selectedDifficulty = Level.easy;
  List<Map<String, dynamic>> _matches = [];

  void _fetchMatches() async {
    final matches = await DatabaseHelper.instance
        .fetchMatchesByLevel(_selectedDifficulty.index);
    setState(() {
      _matches = matches;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Partidas'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<Level>(
              value: _selectedDifficulty,
              items: Level.values.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value!;
                });
              },
            ),
            ElevatedButton(
              onPressed: _fetchMatches,
              child: const Text('Buscar'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _matches.length,
                itemBuilder: (context, index) {
                  final match = _matches[index];
                  return ExpansionTile(
                    title: Text("Jogador: ${match['name']}"),
                    subtitle: Text(
                      "Resultado: ${match['result'] == 1 ? 'Vitória' : 'Derrota'}",
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Data: ${match['date']}"),
                            Text("Nível: ${match['level']}"),
                          ],
                        ),
                      ),
                    ],
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

class SudokuGrid extends StatelessWidget {
  final List<int>? puzzle;
  final List<bool> isInitial;
  final List<bool> isCorrect;
  final int? selectedCell;
  final ValueChanged<int> onCellTap;

  const SudokuGrid({
    super.key,
    required this.puzzle,
    required this.isInitial,
    required this.isCorrect,
    required this.selectedCell,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    double gridSize = screenSize.width < screenSize.height * 0.8
        ? screenSize.width * 0.9
        : screenSize.height * 0.6;

    gridSize = gridSize.clamp(300.0, 600.0);
    double cellSize = gridSize / 9;

    return SizedBox(
      width: gridSize,
      height: gridSize,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 9,
          childAspectRatio: 1.0,
        ),
        itemCount: 81,
        itemBuilder: (context, index) {
          return GridTile(
            child: SudokuCell(
              index: index,
              puzzle: puzzle,
              isInitial: isInitial,
              isCorrect: isCorrect,
              selectedCell: selectedCell,
              onCellTap: onCellTap,
              cellSize: cellSize,
            ),
          );
        },
      ),
    );
  }
}

class SudokuCell extends StatelessWidget {
  final int index;
  final List<int>? puzzle;
  final List<bool> isInitial;
  final List<bool> isCorrect;
  final int? selectedCell;
  final ValueChanged<int> onCellTap;
  final double cellSize;

  const SudokuCell({
    super.key,
    required this.index,
    required this.puzzle,
    required this.isInitial,
    required this.isCorrect,
    required this.selectedCell,
    required this.onCellTap,
    required this.cellSize,
  });

  Color _getBackgroundColor() {
    bool isHighlighted = selectedCell == index;
    bool isSameRowOrCol = selectedCell != null &&
        ((selectedCell! ~/ 9 == index ~/ 9) ||
            (selectedCell! % 9 == index % 9));

    if (isHighlighted) return Colors.yellow[100]!;
    if (isSameRowOrCol) return Colors.blue[50]!;
    return isInitial[index] ? Colors.blue[300]! : Colors.blue[100]!;
  }

  @override
  Widget build(BuildContext context) {
    int row = index ~/ 9;
    int col = index % 9;

    return GestureDetector(
      onTap: isInitial[index] ? null : () => onCellTap(index),
      child: Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          border: Border(
            top: BorderSide(
                color: Colors.black,
                width: row % 3 == 0 ? 2.0 : 0.5), // Bold top border for 3x3
            bottom: BorderSide(
                color: Colors.black,
                width: (row + 1) % 3 == 0 ? 2.0 : 0.5), // Bold bottom border
            left: BorderSide(
                color: Colors.black,
                width: col % 3 == 0 ? 2.0 : 0.5), // Bold left border
            right: BorderSide(
                color: Colors.black,
                width: (col + 1) % 3 == 0 ? 2.0 : 0.5), // Bold right border
          ),
        ),
        child: Center(
          child: Text(
            puzzle?[index] != -1 ? puzzle![index].toString() : '',
            style: TextStyle(
              fontSize: cellSize * 0.6,
              color: isInitial[index]
                  ? Colors.black
                  : isCorrect[index]
                      ? Colors.black54
                      : Colors.red,
            ),
          ),
        ),
      ),
    );
  }
}
