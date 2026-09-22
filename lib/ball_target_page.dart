import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'services/game_api.dart';
import 'ui.dart';

class BallTargetPage extends StatefulWidget {
  const BallTargetPage({super.key, required this.api});

  final GameApi api;

  @override
  State<BallTargetPage> createState() => _BallTargetPageState();
}

class _BallTargetPageState extends State<BallTargetPage>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  late final Ticker _ticker;
  Duration? _lastTick;
  Size _gameSize = Size.zero;
  final List<_BallTarget> _targets = [];
  final List<_BallProjectile> _projectiles = [];

  String? _sessionId;
  String _message = '';
  String _rewardMessage = '';
  int _score = 0;
  int _balls = 20;
  int _stage = 1;
  bool _aiming = false;
  bool _running = false;
  bool _finished = false;
  bool _starting = false;
  bool _claimingReward = false;
  Offset _aimPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null || !_running) return;
    final seconds = min(
      (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond,
      .033,
    );
    _update(seconds * 60);
    if (mounted) setState(() {});
  }

  void _syncSize(Size size) {
    if (size.isEmpty) return;
    _gameSize = size;
    if (_aimPoint == Offset.zero) {
      _aimPoint = Offset(_cannonX + 170, _cannonY - 140);
    }
  }

  double get _cannonX => max(74.0, min(_gameSize.width * .2, 125.0));
  double get _cannonY => max(160.0, _gameSize.height - 92.0);

  Future<void> _startGame() async {
    if (_starting || _claimingReward) return;
    setState(() {
      _starting = true;
      _rewardMessage = '';
      _message = '';
    });
    try {
      final session = await widget.api.startBallTargetMatch();
      if (!mounted) return;
      setState(() {
        _sessionId = session.sessionId;
        _score = 0;
        _balls = 20;
        _stage = 1;
        _finished = false;
        _running = true;
        _projectiles.clear();
        _createTargets();
      });
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _createTargets() {
    _targets.clear();
    final width = _gameSize.width == 0 ? 900.0 : _gameSize.width;
    final height = _gameSize.height == 0 ? 560.0 : _gameSize.height;
    final count = min(3 + _stage, 10);
    for (var index = 0; index < count; index++) {
      _BallTarget target;
      do {
        target = _BallTarget(
          x: width * (.58 + _random.nextDouble() * .32),
          y: 72 + _random.nextDouble() * max(100.0, height - 230.0),
          radius: 20 + _random.nextDouble() * 8,
          speed: (1.05 + _stage * .07) * (_random.nextBool() ? 1 : -1),
        );
      } while (_distance(target.x - _cannonX, target.y - _cannonY) < 170);
      _targets.add(target);
    }
  }

  void _update(double frame) {
    for (final target in _targets) {
      target.x += target.speed * frame;
      if (target.x - target.radius < _gameSize.width * .52 ||
          target.x + target.radius > _gameSize.width - 18) {
        target.speed *= -1;
        target.x = target.x
            .clamp(
              _gameSize.width * .52 + target.radius,
              _gameSize.width - 18 - target.radius,
            )
            .toDouble();
      }
    }

    for (var index = _projectiles.length - 1; index >= 0; index--) {
      final projectile = _projectiles[index];
      projectile.x += projectile.vx * frame;
      projectile.y += projectile.vy * frame;
      projectile.vy += .18 * frame;
      projectile.life += frame;
      var hit = false;
      for (
        var targetIndex = _targets.length - 1;
        targetIndex >= 0;
        targetIndex--
      ) {
        final target = _targets[targetIndex];
        if (_distance(projectile.x - target.x, projectile.y - target.y) <
            projectile.radius + target.radius) {
          _targets.removeAt(targetIndex);
          _score += 100;
          hit = true;
          break;
        }
      }
      if (hit ||
          projectile.x < -50 ||
          projectile.x > _gameSize.width + 50 ||
          projectile.y > _gameSize.height + 60 ||
          projectile.life > 300) {
        _projectiles.removeAt(index);
      }
    }

    if (_targets.isEmpty && _projectiles.isEmpty) {
      _stage++;
      _balls += 8;
      _message = 'مرحلهٔ ${persianDigits(_stage)} شروع شد.';
      _createTargets();
    } else if (_balls == 0 && _projectiles.isEmpty && _targets.isNotEmpty) {
      _finishGame();
    }
  }

  void _beginAim(DragStartDetails details) {
    if (!_running || _balls <= 0) return;
    _aiming = true;
    _aimPoint = details.localPosition;
  }

  void _updateAim(DragUpdateDetails details) {
    if (!_aiming) return;
    _aimPoint = details.localPosition;
  }

  void _endAim(DragEndDetails details) {
    if (!_aiming) return;
    _aiming = false;
    _shoot(_aimPoint);
  }

  void _shoot(Offset point) {
    if (!_running || _balls <= 0) return;
    var dx = point.dx - _cannonX;
    var dy = point.dy - _cannonY;
    final distance = _distance(dx, dy);
    if (distance < 18) return;
    final power = min(distance / 18, 24.0);
    dx /= distance;
    dy /= distance;
    _projectiles.add(
      _BallProjectile(x: _cannonX, y: _cannonY, vx: dx * power, vy: dy * power),
    );
    _balls--;
  }

  void _finishGame() {
    if (_finished) return;
    _running = false;
    _finished = true;
    unawaited(_claimReward());
  }

  Future<void> _claimReward() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    setState(() => _claimingReward = true);
    try {
      final reward = await widget.api.completeBallTargetMatch(
        sessionId,
        _stage,
      );
      if (!mounted) return;
      setState(() {
        _rewardMessage = reward.message;
        _sessionId = null;
      });
    } catch (error) {
      if (mounted) setState(() => _rewardMessage = error.toString());
    } finally {
      if (mounted) setState(() => _claimingReward = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('مسابقه توپ و هدف'),
      actions: const [
        Padding(
          padding: EdgeInsetsDirectional.only(end: 12),
          child: Center(
            child: Text(
              'هر مرحله = یک کوین',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        _syncSize(constraints.biggest);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _beginAim,
          onPanUpdate: _updateAim,
          onPanEnd: _endAim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _BallTargetPainter(
                  targets: _targets,
                  projectiles: _projectiles,
                  cannon: Offset(_cannonX, _cannonY),
                  aiming: _aiming,
                  aimPoint: _aimPoint,
                ),
              ),
              _buildHud(),
              if (!_running) _buildOverlay(),
            ],
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
        _BallInfo(label: 'امتیاز', value: persianDigits(_score)),
        _BallInfo(label: 'توپ', value: persianDigits(_balls)),
        _BallInfo(label: 'مرحله', value: persianDigits(_stage)),
        _BallInfo(label: 'هدف', value: persianDigits(_targets.length)),
      ],
    ),
  );

  Widget _buildOverlay() => ColoredBox(
    color: const Color(0xa9000000),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xff12344a),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0xcc000000), blurRadius: 24),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _finished ? Icons.gps_fixed : Icons.sports_baseball,
                size: 58,
                color: appGold,
              ),
              const SizedBox(height: 10),
              Text(
                _finished ? 'بازی تمام شد!' : 'توپ و هدف',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _finished ? 'بالاترین مرحله: ${persianDigits(_stage)}' : 'توپ را بکش و به سمت هدف رها کن. هر مرحلهٔ کامل، ۸ توپ اضافه می‌کند.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.6),
              ),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_message, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 14),
              if (_claimingReward)
                const CircularProgressIndicator(color: appGold)
              else if (_rewardMessage.isNotEmpty)
                Text(
                  _rewardMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: appGold, height: 1.6),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _starting || _claimingReward ? null : _startGame,
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
                      : _finished
                      ? 'مسابقهٔ بعدی'
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

class _BallTarget {
  _BallTarget({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
  });

  double x;
  double y;
  final double radius;
  double speed;
}

double _distance(double dx, double dy) => sqrt(dx * dx + dy * dy);

class _BallProjectile {
  _BallProjectile({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });

  double x;
  double y;
  final double vx;
  double vy;
  double life = 0;
  final double radius = 9;
}

class _BallInfo extends StatelessWidget {
  const _BallInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 78),
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
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: appGold,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _BallTargetPainter extends CustomPainter {
  const _BallTargetPainter({
    required this.targets,
    required this.projectiles,
    required this.cannon,
    required this.aiming,
    required this.aimPoint,
  });

  final List<_BallTarget> targets;
  final List<_BallProjectile> projectiles;
  final Offset cannon;
  final bool aiming;
  final Offset aimPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    canvas.drawRect(
      screen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff174f70), Color(0xff071a25)],
        ).createShader(screen),
    );
    final stars = Paint()..color = const Color(0x66ffffff);
    for (var index = 0; index < 35; index++) {
      final x = (index * 97) % max(1, size.width).toInt();
      final y = (index * 53) % max(1, min(size.height, 350)).toInt();
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 2, 2), stars);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 52, size.width, 52),
      Paint()..color = const Color(0xff123d27),
    );
    for (final target in targets) {
      _drawTarget(canvas, target);
    }
    for (final projectile in projectiles) {
      canvas.drawCircle(
        Offset(projectile.x, projectile.y),
        projectile.radius,
        Paint()..color = const Color(0xffffcf33),
      );
      canvas.drawCircle(
        Offset(projectile.x - 3, projectile.y - 3),
        2.5,
        Paint()..color = Colors.white,
      );
    }
    _drawCannon(canvas);
    if (aiming) {
      canvas.drawLine(
        cannon,
        aimPoint,
        Paint()
          ..color = const Color(0xbbffffff)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawTarget(Canvas canvas, _BallTarget target) {
    final center = Offset(target.x, target.y);
    for (final ring in [1.0, .72, .43, .2]) {
      canvas.drawCircle(
        center,
        target.radius * ring,
        Paint()
          ..color = ring == 1.0 || ring == .43
              ? Colors.white
              : const Color(0xffe53935),
      );
    }
  }

  void _drawCannon(Canvas canvas) {
    final angle = aiming
        ? atan2(aimPoint.dy - cannon.dy, aimPoint.dx - cannon.dx)
        : 0.0;
    canvas.save();
    canvas.translate(cannon.dx, cannon.dy);
    canvas.rotate(angle);
    canvas.drawRect(
      const Rect.fromLTWH(0, -8, 72, 16),
      Paint()..color = const Color(0xff68757c),
    );
    canvas.drawCircle(
      const Offset(0, 0),
      26,
      Paint()..color = const Color(0xff263238),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BallTargetPainter oldDelegate) => true;
}
