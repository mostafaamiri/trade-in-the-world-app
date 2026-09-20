import 'dart:async';

import 'package:flutter/material.dart';

class ChessPage extends StatefulWidget {
  const ChessPage({super.key});

  @override
  State<ChessPage> createState() => _ChessPageState();
}

class _ChessMove {
  const _ChessMove({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.enPassant = false,
    this.castle = false,
  });

  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final bool enPassant;
  final bool castle;
}

class _ChessSquare {
  const _ChessSquare(this.row, this.col);

  final int row;
  final int col;
}

class _ChessPageState extends State<ChessPage> {
  static const _human = 'w';
  static const _ai = 'b';
  static const _symbols = <String, String>{
    'wk': '♔',
    'wq': '♕',
    'wr': '♖',
    'wb': '♗',
    'wn': '♘',
    'wp': '♙',
    'bk': '♚',
    'bq': '♛',
    'br': '♜',
    'bb': '♝',
    'bn': '♞',
    'bp': '♟',
  };
  static const _values = <String, int>{
    'p': 100,
    'n': 320,
    'b': 330,
    'r': 500,
    'q': 900,
    'k': 20000,
  };
  static const _pawnTable = <int>[
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, -20, -20, 10, 10, 5,
    5, -5, -10, 0, 0, -10, -5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, 5, 10, 25, 25, 10, 5, 5,
    10, 10, 20, 30, 30, 20, 10, 10,
    50, 50, 50, 50, 50, 50, 50, 50,
    0, 0, 0, 0, 0, 0, 0, 0,
  ];
  static const _knightTable = <int>[
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ];

  late List<List<String?>> _board;
  String _difficulty = '2';
  bool _whiteTurn = true;
  bool _gameOver = false;
  bool _aiThinking = false;
  bool _flipped = false;
  bool _whiteKingSide = true;
  bool _whiteQueenSide = true;
  bool _blackKingSide = true;
  bool _blackQueenSide = true;
  _ChessSquare? _selected;
  _ChessSquare? _enPassant;
  _ChessMove? _pendingPromotion;
  _ChessMove? _lastMove;
  List<_ChessMove> _legalMoves = const [];
  String _status = '♙ نوبت شماست';
  int _gameVersion = 0;

  @override
  void initState() {
    super.initState();
    _resetState();
  }

  List<List<String?>> _initialBoard() => [
    ['br', 'bn', 'bb', 'bq', 'bk', 'bb', 'bn', 'br'],
    ['bp', 'bp', 'bp', 'bp', 'bp', 'bp', 'bp', 'bp'],
    List<String?>.filled(8, null),
    List<String?>.filled(8, null),
    List<String?>.filled(8, null),
    List<String?>.filled(8, null),
    ['wp', 'wp', 'wp', 'wp', 'wp', 'wp', 'wp', 'wp'],
    ['wr', 'wn', 'wb', 'wq', 'wk', 'wb', 'wn', 'wr'],
  ];

  void _resetState() {
    _gameVersion++;
    _board = _initialBoard();
    _whiteTurn = true;
    _gameOver = false;
    _aiThinking = false;
    _flipped = false;
    _whiteKingSide = true;
    _whiteQueenSide = true;
    _blackKingSide = true;
    _blackQueenSide = true;
    _selected = null;
    _enPassant = null;
    _pendingPromotion = null;
    _lastMove = null;
    _legalMoves = const [];
    _status = '♙ نوبت شماست';
  }

  void _newGame() => setState(_resetState);

  bool _inside(int row, int col) => row >= 0 && row < 8 && col >= 0 && col < 8;

  String? _color(String? piece) => piece?.substring(0, 1);

  String? _type(String? piece) => piece?.substring(1);

  String _enemy(String color) => color == 'w' ? 'b' : 'w';

  List<List<String?>> _cloneBoard(List<List<String?>> board) =>
      board.map((row) => [...row]).toList();

  _ChessSquare? _findKing(List<List<String?>> board, String color) {
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        if (board[row][col] == '${color}k') return _ChessSquare(row, col);
      }
    }
    return null;
  }

  bool _attacked(
    List<List<String?>> board,
    int row,
    int col,
    String by,
  ) {
    const knight = [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1],
    ];
    for (final step in knight) {
      final nextRow = row + step[0];
      final nextCol = col + step[1];
      if (_inside(nextRow, nextCol) && board[nextRow][nextCol] == '${by}n') {
        return true;
      }
    }

    final pawnDirection = by == 'w' ? -1 : 1;
    for (final deltaCol in [-1, 1]) {
      final pawnRow = row - pawnDirection;
      final pawnCol = col + deltaCol;
      if (_inside(pawnRow, pawnCol) &&
          board[pawnRow][pawnCol] == '${by}p') {
        return true;
      }
    }

    for (var deltaRow = -1; deltaRow <= 1; deltaRow++) {
      for (var deltaCol = -1; deltaCol <= 1; deltaCol++) {
        if (deltaRow == 0 && deltaCol == 0) continue;
        final nextRow = row + deltaRow;
        final nextCol = col + deltaCol;
        if (_inside(nextRow, nextCol) &&
            board[nextRow][nextCol] == '${by}k') {
          return true;
        }
      }
    }

    const rookDirections = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    for (final direction in rookDirections) {
      var nextRow = row + direction[0];
      var nextCol = col + direction[1];
      while (_inside(nextRow, nextCol)) {
        final piece = board[nextRow][nextCol];
        if (piece != null) {
          if (_color(piece) == by &&
              (_type(piece) == 'r' || _type(piece) == 'q')) {
            return true;
          }
          break;
        }
        nextRow += direction[0];
        nextCol += direction[1];
      }
    }

    const bishopDirections = [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1],
    ];
    for (final direction in bishopDirections) {
      var nextRow = row + direction[0];
      var nextCol = col + direction[1];
      while (_inside(nextRow, nextCol)) {
        final piece = board[nextRow][nextCol];
        if (piece != null) {
          if (_color(piece) == by &&
              (_type(piece) == 'b' || _type(piece) == 'q')) {
            return true;
          }
          break;
        }
        nextRow += direction[0];
        nextCol += direction[1];
      }
    }
    return false;
  }

  bool _inCheck(List<List<String?>> board, String color) {
    final king = _findKing(board, color);
    if (king == null) return true;
    return _attacked(board, king.row, king.col, _enemy(color));
  }

  List<_ChessMove> _pseudoMoves(List<List<String?>> board, int row, int col) {
    final piece = board[row][col];
    if (piece == null) return const [];
    final color = _color(piece)!;
    final type = _type(piece)!;
    final moves = <_ChessMove>[];

    void add(int nextRow, int nextCol) {
      if (!_inside(nextRow, nextCol)) return;
      final target = board[nextRow][nextCol];
      if (target == null ||
          (_color(target) != color && _type(target) != 'k')) {
        moves.add(
          _ChessMove(
            fromRow: row,
            fromCol: col,
            toRow: nextRow,
            toCol: nextCol,
          ),
        );
      }
    }

    if (type == 'p') {
      final direction = color == 'w' ? -1 : 1;
      final startRow = color == 'w' ? 6 : 1;
      if (_inside(row + direction, col) &&
          board[row + direction][col] == null) {
        moves.add(
          _ChessMove(
            fromRow: row,
            fromCol: col,
            toRow: row + direction,
            toCol: col,
          ),
        );
        if (row == startRow && board[row + 2 * direction][col] == null) {
          moves.add(
            _ChessMove(
              fromRow: row,
              fromCol: col,
              toRow: row + 2 * direction,
              toCol: col,
            ),
          );
        }
      }
      for (final deltaCol in [-1, 1]) {
        final nextRow = row + direction;
        final nextCol = col + deltaCol;
        if (!_inside(nextRow, nextCol)) continue;
        final target = board[nextRow][nextCol];
        if (target != null &&
            _color(target) != color &&
            _type(target) != 'k') {
          moves.add(
            _ChessMove(
              fromRow: row,
              fromCol: col,
              toRow: nextRow,
              toCol: nextCol,
            ),
          );
        }
        if (_enPassant?.row == nextRow &&
            _enPassant?.col == nextCol &&
            board[row][nextCol] == '${_enemy(color)}p') {
          moves.add(
            _ChessMove(
              fromRow: row,
              fromCol: col,
              toRow: nextRow,
              toCol: nextCol,
              enPassant: true,
            ),
          );
        }
      }
    }

    if (type == 'n') {
      const jumps = [
        [-2, -1],
        [-2, 1],
        [-1, -2],
        [-1, 2],
        [1, -2],
        [1, 2],
        [2, -1],
        [2, 1],
      ];
      for (final jump in jumps) {
        add(row + jump[0], col + jump[1]);
      }
    }

    if (type == 'b' || type == 'r' || type == 'q') {
      final directions = <List<int>>[];
      if (type == 'b' || type == 'q') {
        directions.addAll([
          [-1, -1],
          [-1, 1],
          [1, -1],
          [1, 1],
        ]);
      }
      if (type == 'r' || type == 'q') {
        directions.addAll([
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1],
        ]);
      }
      for (final direction in directions) {
        var nextRow = row + direction[0];
        var nextCol = col + direction[1];
        while (_inside(nextRow, nextCol)) {
          final target = board[nextRow][nextCol];
          if (target == null) {
            moves.add(
              _ChessMove(
                fromRow: row,
                fromCol: col,
                toRow: nextRow,
                toCol: nextCol,
              ),
            );
          } else {
            if (_color(target) != color && _type(target) != 'k') {
              moves.add(
                _ChessMove(
                  fromRow: row,
                  fromCol: col,
                  toRow: nextRow,
                  toCol: nextCol,
                ),
              );
            }
            break;
          }
          nextRow += direction[0];
          nextCol += direction[1];
        }
      }
    }

    if (type == 'k') {
      for (var deltaRow = -1; deltaRow <= 1; deltaRow++) {
        for (var deltaCol = -1; deltaCol <= 1; deltaCol++) {
          if (deltaRow == 0 && deltaCol == 0) continue;
          add(row + deltaRow, col + deltaCol);
        }
      }
      if (!_inCheck(board, color)) {
        if (color == 'w' && row == 7 && col == 4) {
          if (_whiteKingSide &&
              board[7][5] == null &&
              board[7][6] == null &&
              board[7][7] == 'wr' &&
              !_attacked(board, 7, 5, 'b') &&
              !_attacked(board, 7, 6, 'b')) {
            moves.add(
              const _ChessMove(
                fromRow: 7,
                fromCol: 4,
                toRow: 7,
                toCol: 6,
                castle: true,
              ),
            );
          }
          if (_whiteQueenSide &&
              board[7][1] == null &&
              board[7][2] == null &&
              board[7][3] == null &&
              board[7][0] == 'wr' &&
              !_attacked(board, 7, 3, 'b') &&
              !_attacked(board, 7, 2, 'b')) {
            moves.add(
              const _ChessMove(
                fromRow: 7,
                fromCol: 4,
                toRow: 7,
                toCol: 2,
                castle: true,
              ),
            );
          }
        }
        if (color == 'b' && row == 0 && col == 4) {
          if (_blackKingSide &&
              board[0][5] == null &&
              board[0][6] == null &&
              board[0][7] == 'br' &&
              !_attacked(board, 0, 5, 'w') &&
              !_attacked(board, 0, 6, 'w')) {
            moves.add(
              const _ChessMove(
                fromRow: 0,
                fromCol: 4,
                toRow: 0,
                toCol: 6,
                castle: true,
              ),
            );
          }
          if (_blackQueenSide &&
              board[0][1] == null &&
              board[0][2] == null &&
              board[0][3] == null &&
              board[0][0] == 'br' &&
              !_attacked(board, 0, 3, 'w') &&
              !_attacked(board, 0, 2, 'w')) {
            moves.add(
              const _ChessMove(
                fromRow: 0,
                fromCol: 4,
                toRow: 0,
                toCol: 2,
                castle: true,
              ),
            );
          }
        }
      }
    }
    return moves;
  }

  List<List<String?>> _simulate(
    List<List<String?>> board,
    _ChessMove move,
  ) {
    final next = _cloneBoard(board);
    final piece = next[move.fromRow][move.fromCol];
    if (piece == null) return next;
    next[move.fromRow][move.fromCol] = null;
    next[move.toRow][move.toCol] = piece;
    if (move.enPassant) {
      final direction = _color(piece) == 'w' ? 1 : -1;
      next[move.toRow + direction][move.toCol] = null;
    }
    if (move.castle) {
      if (move.toCol == 6) {
        next[move.toRow][5] = next[move.toRow][7];
        next[move.toRow][7] = null;
      } else {
        next[move.toRow][3] = next[move.toRow][0];
        next[move.toRow][0] = null;
      }
    }
    if (_type(piece) == 'p' && (move.toRow == 0 || move.toRow == 7)) {
      next[move.toRow][move.toCol] = '${_color(piece)}q';
    }
    return next;
  }

  List<_ChessMove> _legalFor(List<List<String?>> board, int row, int col) {
    final piece = board[row][col];
    if (piece == null) return const [];
    final color = _color(piece)!;
    return _pseudoMoves(board, row, col)
        .where((move) => !_inCheck(_simulate(board, move), color))
        .toList();
  }

  List<_ChessMove> _allMoves(List<List<String?>> board, String color) {
    final moves = <_ChessMove>[];
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        if (_color(board[row][col]) == color) {
          moves.addAll(_legalFor(board, row, col));
        }
      }
    }
    return moves;
  }

  bool _makeMove(_ChessMove move, {required bool human}) {
    final piece = _board[move.fromRow][move.fromCol]!;
    final color = _color(piece)!;
    final type = _type(piece)!;
    if (move.enPassant) {
      final direction = color == 'w' ? 1 : -1;
      _board[move.toRow + direction][move.toCol] = null;
    }
    _board[move.toRow][move.toCol] = piece;
    _board[move.fromRow][move.fromCol] = null;

    if (move.castle) {
      if (move.toCol == 6) {
        _board[move.toRow][5] = _board[move.toRow][7];
        _board[move.toRow][7] = null;
      } else {
        _board[move.toRow][3] = _board[move.toRow][0];
        _board[move.toRow][0] = null;
      }
    }

    if (type == 'k') {
      if (color == 'w') {
        _whiteKingSide = false;
        _whiteQueenSide = false;
      } else {
        _blackKingSide = false;
        _blackQueenSide = false;
      }
    }
    if (type == 'r') {
      if (color == 'w' && move.fromRow == 7) {
        if (move.fromCol == 0) _whiteQueenSide = false;
        if (move.fromCol == 7) _whiteKingSide = false;
      }
      if (color == 'b' && move.fromRow == 0) {
        if (move.fromCol == 0) _blackQueenSide = false;
        if (move.fromCol == 7) _blackKingSide = false;
      }
    }
    if (move.toRow == 7 && move.toCol == 0) _whiteQueenSide = false;
    if (move.toRow == 7 && move.toCol == 7) _whiteKingSide = false;
    if (move.toRow == 0 && move.toCol == 0) _blackQueenSide = false;
    if (move.toRow == 0 && move.toCol == 7) _blackKingSide = false;

    _enPassant = null;
    if (type == 'p' && (move.toRow - move.fromRow).abs() == 2) {
      _enPassant = _ChessSquare(
        (move.toRow + move.fromRow) ~/ 2,
        move.fromCol,
      );
    }

    if (type == 'p' && (move.toRow == 0 || move.toRow == 7)) {
      if (color == 'w' && human) {
        _pendingPromotion = move;
        _status = 'مهرهٔ ترفیع را انتخاب کنید';
        return false;
      }
      _board[move.toRow][move.toCol] = '${color}q';
    }
    return true;
  }

  void _clickSquare(int row, int col) {
    if (_gameOver || _aiThinking || !_whiteTurn || _pendingPromotion != null) {
      return;
    }
    final piece = _board[row][col];
    if (_selected != null) {
      final move = _legalMoves.where(
        (item) => item.toRow == row && item.toCol == col,
      );
      if (move.isNotEmpty) {
        _playHumanMove(move.first);
        return;
      }
      if (_color(piece) == _human) {
        setState(() {
          _selected = _ChessSquare(row, col);
          _legalMoves = _legalFor(_board, row, col);
        });
      } else {
        setState(() {
          _selected = null;
          _legalMoves = const [];
        });
      }
      return;
    }
    if (_color(piece) == _human) {
      setState(() {
        _selected = _ChessSquare(row, col);
        _legalMoves = _legalFor(_board, row, col);
      });
    }
  }

  void _playHumanMove(_ChessMove move) {
    late bool completed;
    setState(() {
      completed = _makeMove(move, human: true);
      _lastMove = move;
      _selected = null;
      _legalMoves = const [];
    });
    if (!completed) {
      _showPromotion();
      return;
    }
    setState(() => _whiteTurn = false);
    if (!_gameState()) _scheduleAi();
  }

  Future<void> _showPromotion() async {
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('انتخاب مهرهٔ ترفیع'),
        content: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: ['q', 'r', 'b', 'n']
              .map(
                (type) => IconButton(
                  tooltip: _symbols['w$type'],
                  iconSize: 46,
                  onPressed: () => Navigator.pop(context, type),
                  icon: Text(_symbols['w$type']!),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (!mounted || choice == null || _pendingPromotion == null) return;
    setState(() {
      final move = _pendingPromotion!;
      _board[move.toRow][move.toCol] = 'w$choice';
      _pendingPromotion = null;
      _whiteTurn = false;
    });
    if (!_gameState()) _scheduleAi();
  }

  void _scheduleAi() {
    final version = _gameVersion;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!mounted || version != _gameVersion) return;
        _beginAiMove(version);
      }),
    );
  }

  void _beginAiMove(int version) {
    if (_gameOver || _whiteTurn || _aiThinking) return;
    setState(() {
      _aiThinking = true;
      _status = '🤖 ربات در حال فکر کردن است...';
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!mounted || version != _gameVersion || _gameOver) return;
        try {
          final move = _bestAiMove();
          if (move == null) {
            setState(() => _aiThinking = false);
            _gameState();
            return;
          }
          setState(() {
            _makeMove(move, human: false);
            _lastMove = move;
            _selected = null;
            _legalMoves = const [];
            _whiteTurn = true;
            _aiThinking = false;
          });
          _gameState();
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _aiThinking = false;
            _whiteTurn = true;
            _status = '⚠️ اجرای حرکت ربات ناموفق بود.';
          });
        }
      }),
    );
  }

  int _evaluate(List<List<String?>> board) {
    var score = 0;
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final piece = board[row][col];
        if (piece == null) continue;
        final color = _color(piece)!;
        final type = _type(piece)!;
        var value = _values[type]!;
        final index = row * 8 + col;
        if (type == 'p') {
          value += color == 'w' ? _pawnTable[index] : _pawnTable[63 - index];
        }
        if (type == 'n') {
          value +=
              color == 'w' ? _knightTable[index] : _knightTable[63 - index];
        }
        score += color == 'b' ? value : -value;
      }
    }
    return score;
  }

  List<_ChessMove> _orderMoves(
    List<List<String?>> board,
    List<_ChessMove> moves,
  ) => [...moves]
    ..sort((first, second) {
      final firstValue = _values[_type(board[first.toRow][first.toCol])] ?? 0;
      final secondValue =
          _values[_type(board[second.toRow][second.toCol])] ?? 0;
      return secondValue - firstValue;
    });

  int _minimax(
    List<List<String?>> board,
    int depth,
    int alpha,
    int beta,
    bool maximizing,
  ) {
    if (depth == 0) return _evaluate(board);
    final color = maximizing ? _ai : _human;
    final moves = _allMoves(board, color);
    if (moves.isEmpty) {
      if (_inCheck(board, color)) return maximizing ? -1000000 : 1000000;
      return 0;
    }
    final ordered = _orderMoves(board, moves);
    if (maximizing) {
      var best = -1000000;
      for (final move in ordered) {
        final score = _minimax(
          _simulate(board, move),
          depth - 1,
          alpha,
          beta,
          false,
        );
        if (score > best) best = score;
        if (score > alpha) alpha = score;
        if (beta <= alpha) break;
      }
      return best;
    }
    var best = 1000000;
    for (final move in ordered) {
      final score = _minimax(
        _simulate(board, move),
        depth - 1,
        alpha,
        beta,
        true,
      );
      if (score < best) best = score;
      if (score < beta) beta = score;
      if (beta <= alpha) break;
    }
    return best;
  }

  _ChessMove? _bestAiMove() {
    final moves = _allMoves(_board, _ai);
    if (moves.isEmpty) return null;
    final level = int.tryParse(_difficulty) ?? 2;
    if (level == 1) {
      final scored = moves
          .map((move) => MapEntry(move, _evaluate(_simulate(_board, move))))
          .toList()
        ..sort((a, b) => b.value - a.value);
      final count = scored.length < 3 ? scored.length : 3;
      final top = scored.take(count).toList()..shuffle();
      return top.first.key;
    }
    final depth = level == 2 ? 2 : 3;
    var best = moves.first;
    var bestScore = -1000000;
    for (final move in _orderMoves(_board, moves)) {
      final score = _minimax(
        _simulate(_board, move),
        depth - 1,
        -1000000,
        1000000,
        false,
      );
      if (score > bestScore) {
        bestScore = score;
        best = move;
      }
    }
    return best;
  }

  bool _gameState() {
    final color = _whiteTurn ? _human : _ai;
    final moves = _allMoves(_board, color);
    if (moves.isEmpty) {
      setState(() {
        _gameOver = true;
        if (_inCheck(_board, color)) {
          _status = _whiteTurn
              ? '🤖 کیش و مات! ربات برنده شد.'
              : '🎉 کیش و مات! شما برنده شدید!';
        } else {
          _status = '🤝 مساوی؛ پات!';
        }
      });
      return true;
    }
    if (_inCheck(_board, color)) {
      setState(() {
        _status = _whiteTurn ? '⚠️ کیش! مراقب شاه باشید.' : '⚠️ ربات در کیش است.';
      });
      return false;
    }
    _updateStatus();
    return false;
  }

  void _updateStatus() {
    if (_gameOver) return;
    setState(() {
      _status = _aiThinking
          ? '🤖 ربات در حال فکر کردن است...'
          : _whiteTurn
          ? '♙ نوبت شماست'
          : '♟️ نوبت ربات است';
    });
  }

  Widget _buildControls() => Card(
    color: const Color(0xdd182238),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _status,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            dropdownColor: Colors.white,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              labelText: 'سطح ربات',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: '1', child: Text('آسان')),
              DropdownMenuItem(value: '2', child: Text('متوسط')),
              DropdownMenuItem(value: '3', child: Text('سخت')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _difficulty = value);
            },
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _newGame,
            icon: const Icon(Icons.refresh),
            label: const Text('بازی جدید'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xff536174)),
            onPressed: () => setState(() => _flipped = !_flipped),
            icon: const Icon(Icons.flip),
            label: const Text('برگرداندن صفحه'),
          ),
          const Divider(color: Color(0x55FFFFFF), height: 28),
          const Text(
            'راهنما',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'روی مهرهٔ سفید کلیک کن و سپس خانهٔ مقصد را انتخاب کن.\n\n'
            '● نقطه یعنی حرکت مجاز\n'
            '🔴 دایره یعنی گرفتن مهره\n\n'
            'قوانین کیش، مات، قلعه، آن‌پاسان و ترفیع سرباز پشتیبانی می‌شوند.',
            style: TextStyle(color: Color(0xffdbeafe), height: 1.8),
          ),
        ],
      ),
    ),
  );

  Widget _buildBoard(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xff4d321c), width: 8),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Color(0x73000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, visualIndex) {
            final visualRow = visualIndex ~/ 8;
            final visualCol = visualIndex % 8;
            final row = _flipped ? 7 - visualRow : visualRow;
            final col = _flipped ? 7 - visualCol : visualCol;
            return _buildSquare(context, row, col, visualRow, visualCol);
          },
        ),
      ),
    ),
  );

  Widget _buildSquare(
    BuildContext context,
    int row,
    int col,
    int visualRow,
    int visualCol,
  ) {
    final piece = _board[row][col];
    final isSelected = _selected?.row == row && _selected?.col == col;
    final isLast = _lastMove != null &&
        ((_lastMove!.fromRow == row && _lastMove!.fromCol == col) ||
            (_lastMove!.toRow == row && _lastMove!.toCol == col));
    final move = _legalMoves.where(
      (item) => item.toRow == row && item.toCol == col,
    );
    final isLegal = move.isNotEmpty;
    return GestureDetector(
      onTap: () => _clickSquare(row, col),
      child: Container(
        color: isSelected
            ? const Color(0xffffe34d)
            : isLast
            ? const Color(0x99ffd700)
            : (row + col).isEven
            ? const Color(0xfff0d9b5)
            : const Color(0xffb58863),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isLegal)
              Center(
                child: piece == null
                    ? Container(
                        width: 13,
                        height: 13,
                        decoration: const BoxDecoration(
                          color: Color(0x99000000),
                          shape: BoxShape.circle,
                        ),
                      )
                    : Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0x99dc2828),
                            width: 4,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            if (piece != null)
              Center(
                child: FittedBox(
                  child: Text(
                    _symbols[piece]!,
                    style: TextStyle(
                      fontSize: 54,
                      height: 1,
                      color: _color(piece) == 'w'
                          ? Colors.white
                          : const Color(0xff151515),
                      shadows: [
                        Shadow(
                          color: _color(piece) == 'w'
                              ? const Color(0xff111111)
                              : Colors.white,
                          blurRadius: 2,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (visualRow == 7)
              Positioned(
                bottom: 1,
                left: 3,
                child: Text(
                  String.fromCharCode(97 + col),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xaa000000),
                  ),
                ),
              ),
            if (visualCol == 0)
              Positioned(
                top: 1,
                right: 3,
                child: Text(
                  '${8 - row}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xaa000000),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('شطرنج هوشمند')),
    body: Container(
      color: const Color(0xff101827),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final controls = _buildControls();
            final board = _buildBoard(context);
            if (constraints.maxWidth > 800) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 280, child: controls),
                        const SizedBox(width: 20),
                        Expanded(child: board),
                      ],
                    ),
                  ),
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  board,
                  const SizedBox(height: 16),
                  controls,
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
