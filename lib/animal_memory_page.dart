import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'services/game_api.dart';
import 'ui.dart';

class AnimalMemoryPage extends StatefulWidget {
  const AnimalMemoryPage({super.key, required this.api});

  final GameApi api;

  @override
  State<AnimalMemoryPage> createState() => _AnimalMemoryPageState();
}

class _AnimalMemoryPageState extends State<AnimalMemoryPage> {
  static const _animals = <(String, String)>[
    ('🦁', 'شیر'),
    ('🐯', 'ببر'),
    ('🐘', 'فیل'),
    ('🦒', 'زرافه'),
    ('🐼', 'پاندا'),
    ('🐨', 'کوالا'),
    ('🐵', 'میمون'),
    ('🦊', 'روباه'),
    ('🐺', 'گرگ'),
    ('🐻', 'خرس'),
    ('🐰', 'خرگوش'),
    ('🐹', 'همستر'),
    ('🐭', 'موش'),
    ('🐱', 'گربه'),
    ('🐶', 'سگ'),
    ('🐮', 'گاو'),
    ('🐷', 'خوک'),
    ('🐸', 'قورباغه'),
    ('🐔', 'مرغ'),
    ('🐧', 'پنگوئن'),
    ('🐦', 'پرنده'),
    ('🦆', 'اردک'),
    ('🦅', 'عقاب'),
    ('🦉', 'جغد'),
    ('🐬', 'دلفین'),
  ];

  final _random = Random();
  Timer? _previewTimer;
  Timer? _mismatchTimer;
  List<_MemoryCard> _cards = const [];
  _MemoryCard? _first;
  _MemoryCard? _second;
  String? _sessionId;
  String _message = 'برای شروع مسابقه آماده‌ای؟';
  String _rewardMessage = '';
  int _score = 0;
  int _moves = 0;
  int _matched = 0;
  bool _locked = true;
  bool _running = false;
  bool _finished = false;
  bool _starting = false;
  bool _claimingReward = false;

  @override
  void dispose() {
    _previewTimer?.cancel();
    _mismatchTimer?.cancel();
    super.dispose();
  }

  Future<void> _startGame() async {
    if (_starting || _claimingReward) return;
    setState(() {
      _starting = true;
      _rewardMessage = '';
      _finished = false;
    });
    try {
      final session = await widget.api.startAnimalMemoryMatch();
      if (!mounted) return;
      _previewTimer?.cancel();
      _mismatchTimer?.cancel();
      final deck = <_MemoryCard>[];
      for (var index = 0; index < _animals.length; index++) {
        final animal = _animals[index];
        deck
          ..add(_MemoryCard(pairId: index, emoji: animal.$1, name: animal.$2))
          ..add(_MemoryCard(pairId: index, emoji: animal.$1, name: animal.$2));
      }
      deck.shuffle(_random);
      setState(() {
        _cards = deck;
        _sessionId = session.sessionId;
        _first = null;
        _second = null;
        _score = 0;
        _moves = 0;
        _matched = 0;
        _locked = true;
        _running = true;
        _message = 'همهٔ کارت‌ها را به خاطر بسپار!';
      });
      _previewTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          for (final card in _cards) {
            card.revealed = false;
          }
          _locked = false;
          _message = 'جفت حیوان‌ها را پیدا کن.';
        });
      });
    } catch (error) {
      if (mounted) setState(() => _rewardMessage = error.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _chooseCard(_MemoryCard card) {
    if (_locked || card.matched || card.revealed || !_running) return;
    setState(() => card.revealed = true);
    if (_first == null) {
      _first = card;
      setState(() => _message = 'حالا کارت دوم را انتخاب کن.');
      return;
    }
    _second = card;
    _moves++;
    _locked = true;
    if (_first!.pairId == _second!.pairId) {
      _first!.matched = true;
      _second!.matched = true;
      _matched++;
      _score += 20;
      _message = 'جفت درست پیدا شد!';
      _first = null;
      _second = null;
      _locked = false;
      if (_matched == _animals.length) {
        _finishGame();
      }
      setState(() {});
      return;
    }

    _score = max(0, _score - 2);
    _message = 'این دو حیوان یکی نیستند!';
    final first = _first!;
    final second = _second!;
    _mismatchTimer?.cancel();
    _mismatchTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        first.revealed = false;
        second.revealed = false;
        _first = null;
        _second = null;
        _locked = false;
        _message = 'دوباره امتحان کن.';
      });
    });
    setState(() {});
  }

  void _finishGame() {
    if (_finished) return;
    _running = false;
    _locked = true;
    _finished = true;
    unawaited(_claimReward());
  }

  Future<void> _claimReward() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    setState(() => _claimingReward = true);
    try {
      final reward = await widget.api.completeAnimalMemoryMatch(
        sessionId,
        _score,
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
      title: const Text('مسابقه حافظه حیوانات'),
      actions: const [
        Padding(
          padding: EdgeInsetsDirectional.only(end: 12),
          child: Center(
            child: Text(
              'امتیاز = کوین',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ),
    body: ScreenBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 850 ? 10 : 5;
            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    _buildInfo(),
                    const SizedBox(height: 8),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: appGold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_cards.isEmpty)
                      _buildIntro()
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cards.length,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              childAspectRatio: .86,
                            ),
                        itemBuilder: (context, index) => _buildCard(_cards[index]),
                      ),
                    const SizedBox(height: 14),
                    const Text(
                      'جفت درست: ۲۰ امتیاز، جفت اشتباه: ۲ امتیاز کسر. هر امتیاز در پایان برابر یک کوین است.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.6),
                    ),
                  ],
                ),
                if (_finished) _buildFinishOverlay(),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _buildInfo() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      _InfoChip(label: 'امتیاز', value: persianDigits(_score)),
      _InfoChip(label: 'حرکت', value: persianDigits(_moves)),
      _InfoChip(
        label: 'جفت‌ها',
        value: '${persianDigits(_matched)} / ${persianDigits(_animals.length)}',
      ),
    ],
  );

  Widget _buildIntro() => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.psychology_outlined, size: 64, color: appBurgundy),
          const SizedBox(height: 12),
          const Text(
            '۲۵ جفت حیوان را پیدا کن و به‌اندازهٔ امتیازت کوین بگیر.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, height: 1.7),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _starting ? null : _startGame,
            icon: _starting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_starting ? 'در حال آماده‌سازی...' : 'شروع مسابقه'),
          ),
          if (_rewardMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_rewardMessage, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );

  Widget _buildCard(_MemoryCard card) {
    final visible = card.revealed || card.matched;
    return Semantics(
      button: true,
      label: visible ? card.name : 'کارت حیوان',
      child: InkWell(
        onTap: () => _chooseCard(card),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: card.matched
                ? const Color(0xff55d887)
                : visible
                ? Colors.white
                : const Color(0xff164b82),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: card.matched ? const Color(0xffb9ffd0) : Colors.white54,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 5, offset: Offset(0, 3)),
            ],
          ),
          child: visible
              ? Text(card.emoji, style: const TextStyle(fontSize: 31))
              : const Text('🐾', style: TextStyle(fontSize: 27)),
        ),
      ),
    );
  }

  Widget _buildFinishOverlay() => Positioned.fill(
    child: ColoredBox(
      color: const Color(0xaa000000),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, size: 58, color: appGold),
                const SizedBox(height: 8),
                const Text(
                  'برنده شدی!',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text('امتیاز نهایی: ${persianDigits(_score)}'),
                const SizedBox(height: 5),
                Text('پاداش: ${persianDigits(_score)} کوین'),
                const SizedBox(height: 14),
                if (_claimingReward)
                  const CircularProgressIndicator()
                else ...[
                  if (_rewardMessage.isNotEmpty)
                    Text(
                      _rewardMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: appGreen, height: 1.5),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _starting ? null : _startGame,
                    icon: const Icon(Icons.replay),
                    label: const Text('مسابقهٔ بعدی'),
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

class _MemoryCard {
  _MemoryCard({required this.pairId, required this.emoji, required this.name});

  final int pairId;
  final String emoji;
  final String name;
  bool revealed = true;
  bool matched = false;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 92),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white24),
    ),
    child: Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    ),
  );
}
