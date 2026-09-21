import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'services/game_api.dart';
import 'ui.dart';

class TouchCarPage extends StatefulWidget {
  const TouchCarPage({super.key, required this.api});

  final GameApi api;

  @override
  State<TouchCarPage> createState() => _TouchCarPageState();
}

class _TouchCarPageState extends State<TouchCarPage>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  final _focusNode = FocusNode();
  final List<_TouchCar> _enemies = [];
  final List<_TouchCarParticle> _particles = [];

  late final Ticker _ticker;
  Duration? _lastTick;
  Size _gameSize = Size.zero;
  double _roadX = 0;
  double _roadWidth = 0;
  double _playerX = 0;
  double _playerY = 0;
  double _carStartX = 0;
  double _dragStartX = 0;
  double _speed = 7;
  double _roadOffset = 0;

  String? _sessionId;
  String _rewardMessage = '';
  int _score = 0;
  int _bestScore = 0;
  int _coinsAwarded = 0;
  bool _running = false;
  bool _gameOver = false;
  bool _nitro = false;
  bool _starting = false;
  bool _claimingReward = false;
  bool _leftPressed = false;
  bool _rightPressed = false;

  @override
  void initState() {
    super.initState();
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
    if (_running) {
      _updateRace(seconds);
      needsPaint = true;
    }
    if (_particles.isNotEmpty) {
      _updateParticles(seconds);
      needsPaint = true;
    }
    if (needsPaint && mounted) setState(() {});
  }

  void _syncLayout(Size size) {
    if (size.isEmpty) return;
    _gameSize = size;
    _roadWidth = min(size.width * .72, 520.0);
    _roadX = (size.width - _roadWidth) / 2;
    _playerY = size.height - 145;
    if (_playerX == 0) {
      _playerX = size.width / 2 - _playerWidth / 2;
    }
    _keepPlayerInside();
  }

  Future<void> _startRace() async {
    if (_starting || _claimingReward) return;
    _focusNode.requestFocus();
    setState(() {
      _starting = true;
      _rewardMessage = '';
      _coinsAwarded = 0;
    });
    try {
      final session = await widget.api.startTouchCarMatch();
      if (!mounted) return;
      setState(() {
        _sessionId = session.sessionId;
        _resetRace();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rewardMessage = error.toString();
      });
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _resetRace() {
    _score = 0;
    _speed = 7;
    _roadOffset = 0;
    _enemies.clear();
    _particles.clear();
    _nitro = false;
    _gameOver = false;
    _running = true;
    _playerX = _gameSize.width / 2 - _playerWidth / 2;
    _playerY = _gameSize.height - 145;
    _keepPlayerInside();
  }

  void _updateRace(double seconds) {
    if (_gameSize.isEmpty) return;
    final frame = seconds * 60;
    var movement = 0.0;
    if (_leftPressed) movement -= 8;
    if (_rightPressed) movement += 8;
    _playerX += movement * frame;
    _keepPlayerInside();

    _speed += (_nitro ? .07 : .012) * frame;
    _speed = min(_nitro ? 24 : 17, max(5, _speed));
    _roadOffset += _speed * frame;

    final spawnChance = (.018 + _speed * .0018) * frame;
    if (_random.nextDouble() < spawnChance && _enemies.length < 9) {
      _createEnemy();
    }

    final player = _TouchCar(
      x: _playerX,
      y: _playerY,
      width: _playerWidth,
      height: _playerHeight,
      color: const Color(0xffe53935),
    );
    for (var index = _enemies.length - 1; index >= 0; index--) {
      final enemy = _enemies[index];
      enemy.y += (_speed * .72 + enemy.extraSpeed) * frame;
      if (_carsCollide(player, enemy)) {
        _explode(_playerX + _playerWidth / 2, _playerY + _playerHeight / 2);
        _finishRace();
        return;
      }
      if (enemy.y > _gameSize.height + 150) {
        _enemies.removeAt(index);
        _score += 10;
        if (_score % 100 == 0) _speed += 1;
      }
    }
  }

  void _createEnemy() {
    final laneWidth = _roadWidth / 3;
    final lane = _random.nextInt(3);
    _enemies.add(
      _TouchCar(
        x: _roadX + lane * laneWidth + laneWidth / 2 - _enemyWidth / 2,
        y: -120,
        width: _enemyWidth,
        height: _enemyHeight,
        color: _enemyColors[_random.nextInt(_enemyColors.length)],
        extraSpeed: 1 + _random.nextDouble() * 2.5,
      ),
    );
  }

  bool _carsCollide(_TouchCar first, _TouchCar second) =>
      first.x + 8 < second.x + second.width - 8 &&
      first.x + first.width - 8 > second.x + 8 &&
      first.y + 8 < second.y + second.height - 8 &&
      first.y + first.height - 8 > second.y + 8;

  void _explode(double x, double y) {
    for (var index = 0; index < 40; index++) {
      final angle = _random.nextDouble() * pi * 2;
      final force = 2 + _random.nextDouble() * 7;
      _particles.add(
        _TouchCarParticle(
          x: x,
          y: y,
          vx: cos(angle) * force,
          vy: sin(angle) * force,
          size: 3 + _random.nextDouble() * 5,
          orange: _random.nextBool(),
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
      particle.vy += .15 * frame;
      particle.life -= .025 * frame;
      if (particle.life <= 0) _particles.removeAt(index);
    }
  }

  void _finishRace() {
    if (_gameOver) return;
    _running = false;
    _gameOver = true;
    _nitro = false;
    _bestScore = max(_bestScore, _score);
    HapticFeedback.heavyImpact();
    unawaited(_claimReward());
  }

  Future<void> _claimReward() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    if (mounted) setState(() => _claimingReward = true);
    try {
      final reward = await widget.api.completeTouchCarMatch(sessionId, _score);
      if (!mounted) return;
      setState(() {
        _coinsAwarded = reward.coinsAwarded;
        _rewardMessage = reward.message;
        _sessionId = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _rewardMessage = error.toString());
    } finally {
      if (mounted) setState(() => _claimingReward = false);
    }
  }

  void _keepPlayerInside() {
    if (_roadWidth == 0) return;
    final minX = _roadX + 12;
    final maxX = _roadX + _roadWidth - _playerWidth - 12;
    if (_playerX < minX) _playerX = minX;
    if (_playerX > maxX) _playerX = maxX;
  }

  void _startDrag(DragStartDetails details) {
    if (!_running) return;
    _dragStartX = details.globalPosition.dx;
    _carStartX = _playerX;
  }

  void _updateDrag(DragUpdateDetails details) {
    if (!_running) return;
    setState(() {
      _playerX = _carStartX + details.globalPosition.dx - _dragStartX;
      _keepPlayerInside();
    });
  }

  void _setNitro(bool value) {
    if (_running && _nitro != value) setState(() => _nitro = value);
  }

  void _handleKey(KeyEvent event) {
    final key = event.logicalKey;
    final left =
        key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA;
    final right =
        key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (left) _leftPressed = true;
      if (right) _rightPressed = true;
    }
    if (event is KeyUpEvent) {
      if (left) _leftPressed = false;
      if (right) _rightPressed = false;
    }
    if (event is KeyDownEvent && key == LogicalKeyboardKey.space) {
      _setNitro(true);
    }
    if (event is KeyUpEvent && key == LogicalKeyboardKey.space) {
      _setNitro(false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('مسابقه ماشین لمسی'),
      actions: const [
        Padding(
          padding: EdgeInsetsDirectional.only(end: 12),
          child: Center(
            child: Text(
              '۲۰ کوین',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        _syncLayout(constraints.biggest);
        return KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _startDrag,
            onPanUpdate: _updateDrag,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _TouchCarPainter(
                    roadX: _roadX,
                    roadWidth: _roadWidth,
                    roadOffset: _roadOffset,
                    player: _TouchCar(
                      x: _playerX,
                      y: _playerY,
                      width: _playerWidth,
                      height: _playerHeight,
                      color: const Color(0xffe53935),
                    ),
                    enemies: _enemies,
                    particles: _particles,
                    nitro: _nitro,
                  ),
                ),
                _buildHud(),
                if (_running)
                  Positioned(
                    left: 20,
                    bottom: 20,
                    child: Listener(
                      onPointerDown: (_) => _setNitro(true),
                      onPointerUp: (_) => _setNitro(false),
                      onPointerCancel: (_) => _setNitro(false),
                      child: Semantics(
                        button: true,
                        label: 'نیترو',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 78,
                          height: 78,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _nitro
                                ? const Color(0xffff5b1a)
                                : const Color(0xffff9b1f),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 12,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                color: Colors.white,
                              ),
                              Text(
                                'NITRO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!_running) _buildOverlay(),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _buildHud() => Positioned(
    top: 12,
    left: 12,
    right: 12,
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _RaceInfo(label: 'امتیاز', value: persianDigits(_score)),
        _RaceInfo(label: 'سرعت', value: persianDigits(_speed.round() * 14)),
        _RaceInfo(label: 'رکورد', value: persianDigits(_bestScore)),
      ],
    ),
  );

  Widget _buildOverlay() => ColoredBox(
    color: const Color(0xa8000000),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xff25303d),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0xcc000000), blurRadius: 26),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _gameOver
                    ? Icons.car_crash_rounded
                    : Icons.directions_car_filled,
                size: 48,
                color: const Color(0xffffd21c),
              ),
              const SizedBox(height: 10),
              Text(
                _gameOver ? 'تصادف کردی!' : 'مسابقه ماشین لمسی',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (_gameOver) ...[
                const SizedBox(height: 8),
                Text(
                  'امتیاز نهایی: ${persianDigits(_score)}',
                  style: const TextStyle(
                    color: Color(0xffe7f6ff),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text(
                  'با پایان هر مسابقهٔ کامل، ۲۰ کوین دریافت می‌کنی.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xffe7f6ff), height: 1.6),
                ),
              ],
              const SizedBox(height: 14),
              if (_claimingReward)
                const Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(color: Color(0xffffd21c)),
                )
              else if (_rewardMessage.isNotEmpty)
                Text(
                  _coinsAwarded > 0
                      ? '+${persianDigits(_coinsAwarded)} کوین\n$_rewardMessage'
                      : _rewardMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _coinsAwarded > 0
                        ? const Color(0xffffd21c)
                        : const Color(0xffffd6d6),
                    fontWeight: FontWeight.w800,
                    height: 1.6,
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffffd21c),
                  foregroundColor: const Color(0xff202020),
                ),
                onPressed: _starting || _claimingReward ? null : _startRace,
                icon: _starting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _starting
                      ? 'در حال آماده‌سازی...'
                      : _gameOver
                      ? 'مسابقه بعدی'
                      : 'شروع مسابقه',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const _playerWidth = 58.0;
const _playerHeight = 100.0;
const _enemyWidth = 56.0;
const _enemyHeight = 96.0;
const _enemyColors = [
  Color(0xff2196f3),
  Color(0xffff9800),
  Color(0xff8e24aa),
  Color(0xff00acc1),
  Color(0xff43a047),
  Color(0xfffdd835),
  Color(0xffef5350),
];

class _TouchCar {
  _TouchCar({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
    this.extraSpeed = 0,
  });

  double x;
  double y;
  final double width;
  final double height;
  final Color color;
  final double extraSpeed;
}

class _TouchCarParticle {
  _TouchCarParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.orange,
  });

  double x;
  double y;
  final double vx;
  double vy;
  final double size;
  final bool orange;
  double life = 1;
}

class _RaceInfo extends StatelessWidget {
  const _RaceInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 88),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xad000000),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xffffd42a),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _TouchCarPainter extends CustomPainter {
  const _TouchCarPainter({
    required this.roadX,
    required this.roadWidth,
    required this.roadOffset,
    required this.player,
    required this.enemies,
    required this.particles,
    required this.nitro,
  });

  final double roadX;
  final double roadWidth;
  final double roadOffset;
  final _TouchCar player;
  final List<_TouchCar> enemies;
  final List<_TouchCarParticle> particles;
  final bool nitro;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    canvas.drawRect(
      screen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff55b5ff), Color(0xffd8f4ff)],
        ).createShader(screen),
    );
    final road = Rect.fromLTWH(roadX, 0, roadWidth, size.height);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, roadX, size.height),
      Paint()..color = const Color(0xff38a94b),
    );
    canvas.drawRect(
      Rect.fromLTWH(road.right, 0, size.width - road.right, size.height),
      Paint()..color = const Color(0xff38a94b),
    );
    _drawTrees(canvas, size);
    canvas.drawRect(
      road,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xff252525), Color(0xff444444), Color(0xff252525)],
        ).createShader(road),
    );
    _drawRoadLines(canvas, size, road);
    for (final enemy in enemies) {
      _drawCar(canvas, enemy, false);
    }
    _drawCar(canvas, player, true);
    for (final particle in particles) {
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        Paint()
          ..color =
              (particle.orange
                      ? const Color(0xffff9800)
                      : const Color(0xffffe600))
                  .withValues(alpha: particle.life.clamp(0, 1).toDouble()),
      );
    }
  }

  void _drawTrees(Canvas canvas, Size size) {
    for (var index = 0; index < 20; index++) {
      final left = index.isEven;
      final x = left
          ? roadX - 30 - (index * 31 % 100)
          : roadX + roadWidth + 30 + (index * 27 % 100);
      final y = ((index * 130 + roadOffset * .35) % (size.height + 140)) - 100;
      canvas.drawRect(
        Rect.fromLTWH(x - 5, y + 20, 10, 38),
        Paint()..color = const Color(0xff75451f),
      );
      final leaves = Paint()..color = const Color(0xff157a2b);
      canvas.drawCircle(Offset(x, y + 10), 27, leaves);
      canvas.drawCircle(Offset(x - 18, y + 25), 20, leaves);
      canvas.drawCircle(Offset(x + 18, y + 25), 20, leaves);
    }
  }

  void _drawRoadLines(Canvas canvas, Size size, Rect road) {
    for (var y = -100.0; y < size.height + 100; y += 80) {
      final offset = (y + roadOffset) % 80 - 80;
      for (final x in [road.left - 9, road.right]) {
        canvas.drawRect(
          Rect.fromLTWH(x, offset, 9, 40),
          Paint()..color = Colors.white,
        );
        canvas.drawRect(
          Rect.fromLTWH(x, offset + 40, 9, 40),
          Paint()..color = const Color(0xffd62020),
        );
      }
    }
    final lanePaint = Paint()..color = const Color(0xffeeeeee);
    for (var lane = 1; lane < 3; lane++) {
      final x = road.left + road.width / 3 * lane - 4;
      for (var y = -100.0; y < size.height + 100; y += 90) {
        final offset = (y + roadOffset) % 90 - 90;
        canvas.drawRect(Rect.fromLTWH(x, offset, 8, 48), lanePaint);
      }
    }
  }

  void _drawCar(Canvas canvas, _TouchCar car, bool isPlayer) {
    final body = Rect.fromLTWH(car.x, car.y, car.width, car.height);
    final rounded = RRect.fromRectAndRadius(body, const Radius.circular(13));
    canvas.drawRRect(
      rounded.shift(const Offset(5, 7)),
      Paint()
        ..color = const Color(0x59000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      rounded,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xff151515),
            car.color,
            car.color,
            const Color(0xff111111),
          ],
          stops: const [0, .18, .55, 1],
        ).createShader(body),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(car.x + 8, car.y + 17, car.width - 16, 47),
        const Radius.circular(10),
      ),
      Paint()..color = car.color,
    );
    final windscreen = Rect.fromLTWH(
      car.x + 13,
      car.y + 23,
      car.width - 26,
      28,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(windscreen, const Radius.circular(7)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffd9f8ff), Color(0xff3995bb)],
        ).createShader(windscreen),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(car.x + 13, car.y + 58, car.width - 26, 16),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xff69bad4),
    );
    final headlights = Paint()..color = const Color(0xfffff4a0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(car.x + 7, car.y + 8, 13, 8),
        const Radius.circular(3),
      ),
      headlights,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(car.x + car.width - 20, car.y + 8, 13, 8),
        const Radius.circular(3),
      ),
      headlights,
    );
    final tires = Paint()..color = const Color(0xff111111);
    for (final y in [car.y + 20, car.y + car.height - 45]) {
      canvas.drawRect(Rect.fromLTWH(car.x - 5, y, 8, 25), tires);
      canvas.drawRect(Rect.fromLTWH(car.x + car.width - 3, y, 8, 25), tires);
    }
    if (isPlayer && nitro) {
      final flame = Path()
        ..moveTo(car.x + 14, car.y + car.height)
        ..lineTo(car.x + car.width / 2, car.y + car.height + 58)
        ..lineTo(car.x + car.width - 14, car.y + car.height)
        ..close();
      canvas.drawPath(flame, Paint()..color = const Color(0xffff9800));
      final core = Path()
        ..moveTo(car.x + 23, car.y + car.height)
        ..lineTo(car.x + car.width / 2, car.y + car.height + 30)
        ..lineTo(car.x + car.width - 23, car.y + car.height)
        ..close();
      canvas.drawPath(core, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _TouchCarPainter oldDelegate) => true;
}
