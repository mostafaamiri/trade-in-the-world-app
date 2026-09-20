import 'dart:async';

import 'package:flutter/material.dart';

import 'ui.dart';

class DuzPage extends StatefulWidget {
  const DuzPage({super.key});

  @override
  State<DuzPage> createState() => _DuzPageState();
}

class _DuzPageState extends State<DuzPage> {
  static const _winningLines = <List<int>>[
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  List<String> _board = List<String>.filled(9, '');
  String _difficulty = 'medium';
  String _status = 'نوبت شماست ❌';
  List<int> _winningCells = const [];
  bool _gameOver = false;
  bool _aiThinking = false;
  int _playerScore = 0;
  int _drawScore = 0;
  int _aiScore = 0;
  int _gameVersion = 0;

  void _newGame() {
    setState(() {
      _gameVersion++;
      _board = List<String>.filled(9, '');
      _status = 'نوبت شماست ❌';
      _winningCells = const [];
      _gameOver = false;
      _aiThinking = false;
    });
  }

  void _playerMove(int index) {
    if (_gameOver || _aiThinking || _board[index].isNotEmpty) return;

    setState(() => _board[index] = 'X');
    final result = _checkWinner(_board);
    if (result != null) {
      _finishGame(result);
      return;
    }

    setState(() {
      _aiThinking = true;
      _status = '🤖 ربات در حال فکر کردن...';
    });
    final version = _gameVersion;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted || version != _gameVersion) return;
        _aiMove();
      }),
    );
  }

  void _aiMove() {
    if (!mounted || _gameOver) return;

    final move = switch (_difficulty) {
      'easy' => _randomMove(_board),
      'hard' => _bestMove(_board),
      _ => _mediumMove(_board),
    };
    setState(() {
      if (move != null) _board[move] = 'O';
      _aiThinking = false;
    });
    final result = _checkWinner(_board);
    if (result != null) {
      _finishGame(result);
      return;
    }
    setState(() => _status = 'نوبت شماست ❌');
  }

  void _finishGame(String result) {
    final winningLine = result == 'draw'
        ? const <int>[]
        : _winningLines.firstWhere(
            (line) => line.every((index) => _board[index] == result),
            orElse: () => const <int>[],
          );
    setState(() {
      _gameOver = true;
      _aiThinking = false;
      _winningCells = winningLine;
      if (result == 'X') {
        _playerScore++;
        _status = '🎉 شما برنده شدید!';
      } else if (result == 'O') {
        _aiScore++;
        _status = '🤖 ربات برنده شد!';
      } else {
        _drawScore++;
        _status = '🤝 بازی مساوی شد!';
      }
    });
  }

  String? _checkWinner(List<String> state) {
    for (final line in _winningLines) {
      final value = state[line[0]];
      if (value.isNotEmpty &&
          value == state[line[1]] &&
          value == state[line[2]]) {
        return value;
      }
    }
    return state.every((cell) => cell.isNotEmpty) ? 'draw' : null;
  }

  int? _randomMove(List<String> state) {
    final empty = [
      for (var index = 0; index < state.length; index++)
        if (state[index].isEmpty) index,
    ];
    if (empty.isEmpty) return null;
    empty.shuffle();
    return empty.first;
  }

  int? _mediumMove(List<String> state) {
    final win = _findWinningMove(state, 'O');
    if (win != null) return win;
    final block = _findWinningMove(state, 'X');
    if (block != null) return block;
    if (state[4].isEmpty) return 4;

    final corners = [0, 2, 6, 8]
        .where((index) => state[index].isEmpty)
        .toList()
      ..shuffle();
    return corners.isNotEmpty ? corners.first : _randomMove(state);
  }

  int? _findWinningMove(List<String> state, String player) {
    for (var index = 0; index < state.length; index++) {
      if (state[index].isNotEmpty) continue;
      state[index] = player;
      final result = _checkWinner(state);
      state[index] = '';
      if (result == player) return index;
    }
    return null;
  }

  int? _bestMove(List<String> state) {
    var bestScore = -1000;
    int? move;
    for (var index = 0; index < state.length; index++) {
      if (state[index].isNotEmpty) continue;
      state[index] = 'O';
      final score = _minimax(state, false);
      state[index] = '';
      if (score > bestScore) {
        bestScore = score;
        move = index;
      }
    }
    return move;
  }

  int _minimax(List<String> state, bool maximizing) {
    final result = _checkWinner(state);
    if (result == 'O') return 10;
    if (result == 'X') return -10;
    if (result == 'draw') return 0;

    if (maximizing) {
      var best = -1000;
      for (var index = 0; index < state.length; index++) {
        if (state[index].isNotEmpty) continue;
        state[index] = 'O';
        final score = _minimax(state, false);
        best = best > score ? best : score;
        state[index] = '';
      }
      return best;
    }

    var best = 1000;
    for (var index = 0; index < state.length; index++) {
      if (state[index].isNotEmpty) continue;
      state[index] = 'X';
      final score = _minimax(state, true);
      state[index] = '';
      best = best < score ? best : score;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بازی دوز')),
    body: Container(
      decoration: const BoxDecoration(color: Color(0xff172554)),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Card(
                color: const Color(0xff24356f),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '⭕❌ بازی دوز',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'بازی دوز با حریف هوشمند',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xffcbd5e1)),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              initialValue: _difficulty,
                              isDense: true,
                              dropdownColor: Colors.white,
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                labelText: 'سطح بازی',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'easy',
                                  child: Text('آسان'),
                                ),
                                DropdownMenuItem(
                                  value: 'medium',
                                  child: Text('متوسط'),
                                ),
                                DropdownMenuItem(
                                  value: 'hard',
                                  child: Text('سخت'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _difficulty = value);
                                }
                              },
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _newGame,
                            icon: const Icon(Icons.refresh),
                            label: const Text('بازی جدید'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AspectRatio(
                        aspectRatio: 1,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 9,
                                crossAxisSpacing: 9,
                              ),
                          itemCount: _board.length,
                          itemBuilder: (context, index) {
                            final value = _board[index];
                            final isWinning = _winningCells.contains(index);
                            return Semantics(
                              button: true,
                              label: value.isEmpty
                                  ? 'خانه خالی ${index + 1}'
                                  : 'خانه ${index + 1}: $value',
                              child: InkWell(
                                onTap: () => _playerMove(index),
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: isWinning
                                        ? const Color(0xfffacc15)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      value == 'X'
                                          ? '❌'
                                          : value == 'O'
                                          ? '⭕'
                                          : '',
                                      style: TextStyle(
                                        fontSize: 58,
                                        color: value == 'X'
                                            ? const Color(0xff2563eb)
                                            : const Color(0xffef4444),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _ScoreBox(
                              label: 'شما',
                              score: _playerScore,
                              color: const Color(0xff2563eb),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ScoreBox(
                              label: 'مساوی',
                              score: _drawScore,
                              color: const Color(0xff94a3b8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ScoreBox(
                              label: 'ربات',
                              score: _aiScore,
                              color: const Color(0xffef4444),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'شما با ❌ بازی می‌کنید.\nربات با ⭕ بازی می‌کند.\nسه مهره پشت سر هم برنده می‌شود.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xffcbd5e1), height: 1.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.label, required this.score, required this.color});

  final String label;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0x33000000),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Text(
          persianDigits(score),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
