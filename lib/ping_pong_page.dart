import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'ui.dart';

const _courtWidth = 960.0;
const _courtHeight = 540.0;
const _paddleWidth = 18.0;
const _paddleHeight = 110.0;
const _playerPaddleX = 35.0;
const _computerPaddleX = _courtWidth - 53.0;

class PingPongPage extends StatefulWidget {
  const PingPongPage({super.key});

  @override
  State<PingPongPage> createState() => _PingPongPageState();
}

class _PingPongPageState extends State<PingPongPage>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  final _focusNode = FocusNode();
  final List<_PingPongParticle> _particles = [];

  late final Ticker _ticker;
  Duration? _lastTick;
  _PingPongDifficulty _difficulty = _PingPongDifficulty.medium;

  double _playerY = (_courtHeight - _paddleHeight) / 2;
  double _computerY = (_courtHeight - _paddleHeight) / 2;
  double _ballX = _courtWidth / 2;
  double _ballY = _courtHeight / 2;
  double _ballVx = 6.2;
  double _ballVy = 0;

  int _playerScore = 0;
  int _computerScore = 0;
  bool _running = false;
  bool _paused = false;
  bool _gameOver = false;
  bool _upPressed = false;
  bool _downPressed = false;

  @override
  void initState() {
    super.initState();
    _resetBall(1);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null) return;

    final seconds = min(
      (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond,
      .033,
    );
    var needsPaint = false;
    if (_running && !_paused && !_gameOver) {
      _updateGame(seconds);
      needsPaint = true;
    }
    if (_particles.isNotEmpty) {
      _updateParticles(seconds);
      needsPaint = true;
    }
    if (needsPaint && mounted) setState(() {});
  }

  void _resetBall(int direction) {
    _ballX = _courtWidth / 2;
    _ballY = _courtHeight / 2;
    _ballVx = direction * 6.2;
    _ballVy = (_random.nextDouble() * 2 - 1) * 4.5;
  }

  void _startGame() {
    _focusNode.requestFocus();
    setState(() {
      if (_gameOver) {
        _resetGame();
      } else {
        _running = true;
        _paused = false;
      }
    });
  }

  void _resetGame() {
    _playerScore = 0;
    _computerScore = 0;
    _playerY = (_courtHeight - _paddleHeight) / 2;
    _computerY = (_courtHeight - _paddleHeight) / 2;
    _particles.clear();
    _gameOver = false;
    _paused = false;
    _running = true;
    _resetBall(_random.nextBool() ? 1 : -1);
  }

  void _restartGame() {
    _focusNode.requestFocus();
    setState(_resetGame);
  }

  void _togglePause() {
    if (!_running || _gameOver) return;
    setState(() => _paused = !_paused);
  }

  void _updateGame(double seconds) {
    final frame = seconds * 60;
    var direction = 0.0;
    if (_upPressed) direction -= 1;
    if (_downPressed) direction += 1;
    _playerY += direction * 8 * frame;
    _keepPaddlesInside();

    final target = _ballY - _paddleHeight / 2;
    final difference = target - (_computerY + _paddleHeight / 2);
    var move = difference * _difficulty.response;
    move *= _ballVx > 0 ? 1.45 : .35;
    _computerY += move * frame;
    _keepPaddlesInside();

    _ballX += _ballVx * frame;
    _ballY += _ballVy * frame;

    if (_ballY - 11 <= 0) {
      _ballY = 11;
      _ballVy = _ballVy.abs();
      HapticFeedback.selectionClick();
    } else if (_ballY + 11 >= _courtHeight) {
      _ballY = _courtHeight - 11;
      _ballVy = -_ballVy.abs();
      HapticFeedback.selectionClick();
    }

    if (_ballVx < 0 && _paddleCollision(_playerPaddleX, _playerY)) {
      _hitPaddle(_playerPaddleX, _playerY, true);
    } else if (_ballVx > 0 && _paddleCollision(_computerPaddleX, _computerY)) {
      _hitPaddle(_computerPaddleX, _computerY, false);
    }

    if (_ballX < -30) {
      _pointToComputer();
    } else if (_ballX > _courtWidth + 30) {
      _pointToPlayer();
    }
  }

  bool _paddleCollision(double x, double y) =>
      _ballX - 11 < x + _paddleWidth &&
      _ballX + 11 > x &&
      _ballY - 11 < y + _paddleHeight &&
      _ballY + 11 > y;

  void _hitPaddle(double x, double y, bool isPlayer) {
    final relative = (_ballY - (y + _paddleHeight / 2)) / (_paddleHeight / 2);
    final angle = relative * pi / 3;
    var speed = sqrt(_ballVx * _ballVx + _ballVy * _ballVy) + .22;
    speed = min(speed, 15);
    _ballVx = (isPlayer ? 1 : -1) * speed * cos(angle);
    _ballVy = speed * sin(angle);
    _ballX = isPlayer ? x + _paddleWidth + 11 : x - 11;
    _createParticles(_ballX, _ballY);
    HapticFeedback.selectionClick();
  }

  void _pointToPlayer() {
    _playerScore++;
    _createParticles(_courtWidth / 2, _courtHeight / 2);
    HapticFeedback.mediumImpact();
    if (_playerScore >= 11) {
      _gameOver = true;
      _running = false;
    } else {
      _resetBall(-1);
    }
  }

  void _pointToComputer() {
    _computerScore++;
    _createParticles(_courtWidth / 2, _courtHeight / 2);
    HapticFeedback.heavyImpact();
    if (_computerScore >= 11) {
      _gameOver = true;
      _running = false;
    } else {
      _resetBall(1);
    }
  }

  void _createParticles(double x, double y) {
    for (var index = 0; index < 10; index++) {
      _particles.add(
        _PingPongParticle(
          x: x,
          y: y,
          vx: (_random.nextDouble() - .5) * 5,
          vy: (_random.nextDouble() - .5) * 5,
          size: _random.nextDouble() * 4 + 2,
        ),
      );
    }
  }

  void _updateParticles(double seconds) {
    final frame = seconds * 60;
    for (var index = _particles.length - 1; index >= 0; index--) {
      final particle = _particles[index];
      particle.x += particle.vx * frame;
      particle.y += particle.vy * frame;
      particle.life -= seconds * 2;
      if (particle.life <= 0) _particles.removeAt(index);
    }
  }

  void _keepPaddlesInside() {
    _playerY = _playerY.clamp(0, _courtHeight - _paddleHeight);
    _computerY = _computerY.clamp(0, _courtHeight - _paddleHeight);
  }

  void _movePlayerTo(Offset position, Size size) {
    if (size.height == 0) return;
    setState(() {
      _playerY = position.dy * _courtHeight / size.height - _paddleHeight / 2;
      _keepPaddlesInside();
    });
  }

  void _handleKey(KeyEvent event) {
    final key = event.logicalKey;
    final up =
        key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW;
    final down =
        key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (up) _upPressed = true;
      if (down) _downPressed = true;
    }
    if (event is KeyUpEvent) {
      if (up) _upPressed = false;
      if (down) _downPressed = false;
    }
    if (event is KeyDownEvent && key == LogicalKeyboardKey.space) {
      _togglePause();
    }
  }

  String get _overlayTitle {
    if (_gameOver) {
      return _playerScore > _computerScore
          ? 'شما برنده شدید!'
          : 'کامپیوتر برنده شد!';
    }
    if (_paused) return 'بازی متوقف است';
    return 'آماده شروع';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('پینگ پنگ هوشمند'),
      actions: [
        IconButton(
          onPressed: _restartGame,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'بازی جدید',
        ),
      ],
    ),
    body: ScreenBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ScorePanel(
                          label: 'شما',
                          score: _playerScore,
                          color: const Color(0xff26c6ee),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ScorePanel(
                          label: 'کامپیوتر',
                          score: _computerScore,
                          color: const Color(0xffff526f),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildCourt(),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<_PingPongDifficulty>(
                          initialValue: _difficulty,
                          decoration: const InputDecoration(
                            labelText: 'سطح بازی',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          items: _PingPongDifficulty.values
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _difficulty = value);
                            }
                          },
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _startGame,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(_gameOver ? 'دوباره بازی کن' : 'شروع بازی'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff536174),
                        ),
                        onPressed: _running && !_gameOver ? _togglePause : null,
                        icon: Icon(
                          _paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        label: Text(_paused ? 'ادامه' : 'توقف'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _restartGame,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('بازی جدید'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'کنترل راکت: لمس زمین بازی یا کلیدهای بالا و پایین / W و S',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xffe6f6ff),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildCourt() => AspectRatio(
    aspectRatio: _courtWidth / _courtHeight,
    child: LayoutBuilder(
      builder: (context, constraints) => KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _movePlayerTo(details.localPosition, constraints.biggest),
          onPanStart: (details) =>
              _movePlayerTo(details.localPosition, constraints.biggest),
          onPanUpdate: (details) =>
              _movePlayerTo(details.localPosition, constraints.biggest),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffdcecff), width: 4),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _PingPongCourtPainter(
                      playerY: _playerY,
                      computerY: _computerY,
                      ballX: _ballX,
                      ballY: _ballY,
                      particles: _particles,
                    ),
                  ),
                  if (!_running || _paused || _gameOver)
                    IgnorePointer(
                      child: ColoredBox(
                        color: Color(_gameOver ? 0xbb000000 : 0x66000000),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _gameOver
                                    ? (_playerScore > _computerScore
                                          ? Icons.emoji_events_rounded
                                          : Icons.smart_toy_outlined)
                                    : _paused
                                    ? Icons.pause_circle_outline_rounded
                                    : Icons.sports_tennis_rounded,
                                size: 40,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _overlayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (_gameOver) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${persianDigits(_playerScore)} - ${persianDigits(_computerScore)}',
                                  style: const TextStyle(
                                    color: Color(0xffd9f6ff),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

enum _PingPongDifficulty {
  easy('آسان', .055),
  medium('متوسط', .075),
  hard('سخت', .105),
  expert('خیلی سخت', .14);

  const _PingPongDifficulty(this.label, this.response);

  final String label;
  final double response;
}

class _PingPongParticle {
  _PingPongParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final double size;
  double life = 1;
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    required this.label,
    required this.score,
    required this.color,
  });

  final String label;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xdd102032),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .6)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          persianDigits(score),
          style: TextStyle(
            color: color,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _PingPongCourtPainter extends CustomPainter {
  const _PingPongCourtPainter({
    required this.playerY,
    required this.computerY,
    required this.ballX,
    required this.ballY,
    required this.particles,
  });

  final double playerY;
  final double computerY;
  final double ballX;
  final double ballY;
  final List<_PingPongParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final court = Rect.fromLTWH(0, 0, _courtWidth, _courtHeight);
    canvas.save();
    canvas.scale(size.width / _courtWidth, size.height / _courtHeight);

    canvas.drawRect(
      court,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff102c39), Color(0xff07151d)],
        ).createShader(court),
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: .22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(const Rect.fromLTWH(20, 20, 920, 500), linePaint);
    for (var y = 20.0; y < 520; y += 26) {
      canvas.drawLine(Offset(480, y), Offset(480, min(y + 12, 520)), linePaint);
    }
    canvas.drawCircle(const Offset(480, 270), 75, linePaint);

    _drawPaddle(canvas, _playerPaddleX, playerY, true);
    _drawPaddle(canvas, _computerPaddleX, computerY, false);

    final ballCenter = Offset(ballX, ballY);
    canvas.drawCircle(
      ballCenter,
      25,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xf2ffffff),
            Color(0xb364f0ff),
            Color(0x0000c8ff),
          ],
          stops: const [0, .3, 1],
        ).createShader(Rect.fromCircle(center: ballCenter, radius: 25)),
    );
    canvas.drawCircle(
      ballCenter,
      11,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(ballCenter, 11, Paint()..color = Colors.white);

    for (final particle in particles) {
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        Paint()
          ..color = Colors.white.withValues(alpha: particle.life.clamp(0, 1)),
      );
    }
    canvas.restore();
  }

  void _drawPaddle(Canvas canvas, double x, double y, bool playerSide) {
    final paddle = Rect.fromLTWH(x, y, _paddleWidth, _paddleHeight);
    final color = playerSide
        ? const Color(0xff26d4ff)
        : const Color(0xffff3d5b);
    canvas.drawRRect(
      RRect.fromRectAndRadius(paddle, const Radius.circular(9)),
      Paint()
        ..color = color.withValues(alpha: .72)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(paddle, const Radius.circular(9)),
      Paint()
        ..shader = LinearGradient(
          colors: playerSide
              ? const [Color(0xff4de1ff), Color(0xff1777ff)]
              : const [Color(0xffff6a6a), Color(0xffff1744)],
        ).createShader(paddle),
    );
  }

  @override
  bool shouldRepaint(covariant _PingPongCourtPainter oldDelegate) => true;
}
