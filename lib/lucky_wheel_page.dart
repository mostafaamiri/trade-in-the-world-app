import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'services/game_api.dart';
import 'ui.dart';

class LuckyWheelPage extends StatefulWidget {
  const LuckyWheelPage({
    super.key,
    required this.api,
    required this.initialBusiness,
  });

  final GameApi api;
  final BusinessProgress initialBusiness;

  @override
  State<LuckyWheelPage> createState() => _LuckyWheelPageState();
}

class _LuckyWheelPageState extends State<LuckyWheelPage>
    with SingleTickerProviderStateMixin {
  static const _labels = [
    '۱۰۰ سکه',
    '۲۰۰ کوین',
    'ماموریت',
    'پوچ',
    'شانس مجدد',
    '۵۰ سکه',
  ];

  late final AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late BusinessProgress _business;
  double _rotation = 0;
  bool _spinning = false;
  LuckyWheelOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _business = widget.initialBusiness;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _rotationAnimation = AlwaysStoppedAnimation(_rotation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning || !_business.canSpinLuckyWheel) return;
    setState(() {
      _spinning = true;
      _outcome = null;
    });
    try {
      final result = await widget.api.spinLuckyWheel();
      final target = _targetRotation(result.outcome.index);
      if (!mounted) return;
      setState(() {
        _rotationAnimation = Tween<double>(begin: _rotation, end: target)
            .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            );
      });
      _controller.reset();
      await _controller.forward().orCancel;
      if (!mounted) return;
      setState(() {
        _rotation = target;
        _business = result.business;
        _outcome = result.outcome;
      });
    } on TickerCanceled {
      return;
    } catch (error) {
      if (mounted) await showFailure(context, error);
    } finally {
      if (mounted) setState(() => _spinning = false);
    }
  }

  double _targetRotation(int outcomeIndex) {
    const fullTurn = math.pi * 2;
    final sweep = fullTurn / _labels.length;
    var target =
        ((_rotation / fullTurn).floor() + 6) * fullTurn -
        outcomeIndex * sweep -
        sweep / 2;
    while (target <= _rotation + fullTurn * 4) {
      target += fullTurn;
    }
    return target;
  }

  @override
  Widget build(BuildContext context) {
    final freeSpin = _business.freeLuckySpins > 0;
    final canSpin = _business.canSpinLuckyWheel && !_spinning;
    return Scaffold(
      appBar: AppBar(title: const Text('گردونه شانس')),
      body: ScreenBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _BalanceChip(
                        icon: Icons.monetization_on_outlined,
                        label: 'کوین: ${persianDigits(_business.coins)}',
                        color: appGold,
                      ),
                      _BalanceChip(
                        icon: Icons.toll_outlined,
                        label: 'سکه: ${persianDigits(_business.tokens)}',
                        color: const Color(0xffa9d9ce),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: SizedBox(
                      width: 290,
                      height: 310,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _rotationAnimation,
                            builder: (context, child) => Transform.rotate(
                              angle: _rotationAnimation.value,
                              child: child,
                            ),
                            child: const CustomPaint(
                              size: Size.square(280),
                              painter: _LuckyWheelPainter(labels: _labels),
                            ),
                          ),
                          const Align(
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.arrow_drop_down,
                              size: 58,
                              color: appRed,
                            ),
                          ),
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: appNavy,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: _spinning
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.casino_outlined,
                                    color: Colors.white,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    freeSpin
                        ? 'چرخش رایگان: ${persianDigits(_business.freeLuckySpins)}'
                        : 'هزینه هر چرخش: ${persianDigits(_business.luckyWheelCost)} سکه',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: canSpin ? _spin : null,
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(freeSpin ? 'چرخاندن رایگان' : 'چرخاندن گردونه'),
                  ),
                  if (!canSpin && !_spinning) ...[
                    const SizedBox(height: 8),
                    Text(
                      'برای چرخاندن گردونه به ${persianDigits(_business.luckyWheelCost)} سکه نیاز داری.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: appRed),
                    ),
                  ],
                  if (_outcome != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: _outcome!.id == 'nothing'
                          ? const Color(0xffffefef)
                          : const Color(0xffe8f6f1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              _outcome!.id == 'nothing'
                                  ? Icons.remove_circle_outline
                                  : Icons.celebration_outlined,
                              color: _outcome!.id == 'nothing'
                                  ? appRed
                                  : appGreen,
                              size: 34,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _outcome!.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _outcome!.missionTitle.isEmpty
                                  ? _outcome!.description
                                  : '${_outcome!.description}\n${_outcome!.missionTitle}',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class _LuckyWheelPainter extends CustomPainter {
  const _LuckyWheelPainter({required this.labels});

  final List<String> labels;

  static const _colors = [
    Color(0xfff4b500),
    Color(0xff46a3a7),
    Color(0xffc84242),
    Color(0xffd9dee6),
    Color(0xff16815d),
    Color(0xff851d3a),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final sweep = math.pi * 2 / labels.length;
    final circle = Rect.fromCircle(center: center, radius: radius);
    final textPainter = TextPainter(textDirection: TextDirection.rtl);

    for (var index = 0; index < labels.length; index++) {
      final start = -math.pi / 2 + index * sweep;
      canvas.drawArc(
        circle,
        start,
        sweep,
        true,
        Paint()..color = _colors[index],
      );
      final angle = start + sweep / 2;
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * .62;
      textPainter.text = TextSpan(
        text: labels[index],
        style: TextStyle(
          color: index == 3 ? Colors.black87 : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      );
      textPainter.layout(maxWidth: 78);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + math.pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _LuckyWheelPainter oldDelegate) =>
      oldDelegate.labels != labels;
}
