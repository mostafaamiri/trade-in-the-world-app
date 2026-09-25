import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'business_progress_page.dart';
import 'services/game_api.dart';
import 'services/game_music_service.dart';
import 'ui.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.api, required this.matchId});

  final GameApi api;
  final String matchId;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  GameSnapshot? _snapshot;
  List<Json> _cities = const [];
  Timer? _pollTimer;
  bool _loading = true;
  bool _working = false;
  String? _error;
  int _refreshRequest = 0;

  @override
  void initState() {
    super.initState();
    unawaited(GameMusicService.acquire());
    _loadCities();
    _refresh();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(GameMusicService.release());
    super.dispose();
  }

  Future<void> _loadCities() async {
    final raw = await rootBundle.loadString(
      'assets/data/world_trade_config.json',
    );
    final data = (jsonDecode(raw) as Map).cast<String, dynamic>();
    if (mounted) setState(() => _cities = jsonMaps(data['cities']));
  }

  Future<void> _refresh({bool silent = false}) async {
    final request = ++_refreshRequest;
    if (!silent && mounted) {
      setState(() {
        _loading = _snapshot == null;
        _error = null;
      });
    }
    try {
      final snapshot = await widget.api.snapshot(widget.matchId);
      if (mounted && request == _refreshRequest) {
        setState(() {
          _snapshot = snapshot;
          _loading = false;
          _error = null;
        });
        _maybePlayResultSound(snapshot);
      }
    } catch (error) {
      if (mounted && !silent && request == _refreshRequest) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  void _maybePlayResultSound(GameSnapshot snapshot) {
    if (snapshot.match.status != 'finished') return;
    if (snapshot.match.winnerId == widget.api.userId) {
      unawaited(GameMusicService.playWinner(widget.matchId));
    } else {
      unawaited(GameMusicService.playLoser(widget.matchId));
    }
  }

  MatchPlayer? get _me => _snapshot?.player(widget.api.userId ?? '');

  Json? _cityForPosition(int position) {
    for (final city in _cities) {
      if (jsonInt(city['routeOrder']) == position) return city;
    }
    return null;
  }

  Future<void> _invoke(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
      await _refresh(silent: true);
    } catch (error) {
      if (mounted) await showFailure(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _buyCard(Future<CardPurchase> Function() action) async {
    if (_working) return false;
    setState(() => _working = true);
    try {
      final purchase = await action();
      if (!mounted) return false;
      _applyCardPurchase(purchase);
      unawaited(_refresh(silent: true));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${purchase.card.title}» به کارت‌های من اضافه شد.'),
        ),
      );
      return true;
    } catch (error) {
      if (mounted) await showFailure(context, error);
      return false;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _applyCardPurchase(CardPurchase purchase) {
    final snapshot = _snapshot;
    if (snapshot == null) return;

    // Invalidate in-flight polls before showing the confirmed purchase.
    _refreshRequest++;
    final cards = [...snapshot.cards];
    final cardIndex = cards.indexWhere(
      (card) => card.cardId == purchase.card.cardId,
    );
    if (cardIndex < 0) {
      cards.add(purchase.card);
    } else {
      cards[cardIndex] = purchase.card;
    }
    final players = snapshot.players
        .map(
          (player) =>
              player.uid == purchase.player.uid ? purchase.player : player,
        )
        .toList();

    setState(() {
      _snapshot = GameSnapshot(
        match: snapshot.match,
        players: players,
        cards: cards,
        events: snapshot.events,
        trades: snapshot.trades,
        business: snapshot.business,
      );
    });
  }

  Future<void> _coupAction(String action, String? targetId) => _invoke(
    () => widget.api.coupAction(widget.matchId, action, targetId: targetId),
  );

  Future<void> _coupChallenge() =>
      _invoke(() => widget.api.challengeCoup(widget.matchId));

  Future<void> _coupResolve() =>
      _invoke(() => widget.api.resolveCoup(widget.matchId));

  Future<void> _coupBlock() =>
      _invoke(() => widget.api.blockCoup(widget.matchId));

  Future<void> _coupLoseInfluence(int roleIndex) =>
      _invoke(() => widget.api.loseCoupInfluence(widget.matchId, roleIndex));

  Future<void> _unoPlay(
    String cardId, {
    String? chosenColor,
    bool uno = false,
  }) => _invoke(
    () => widget.api.unoPlay(
      widget.matchId,
      cardId,
      chosenColor: chosenColor,
      uno: uno,
    ),
  );

  Future<void> _unoDraw() => _invoke(() => widget.api.unoDraw(widget.matchId));

  Future<void> _unoCall() => _invoke(() => widget.api.unoCall(widget.matchId));

  Future<void> _unoCatch() =>
      _invoke(() => widget.api.unoCatch(widget.matchId));

  Future<void> _roll() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final result = await widget.api.roll(widget.matchId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DiceResultDialog(value: jsonInt(result['dice'], 1)),
      );
      final eventCard = result['eventCard'];
      if (eventCard is Map && mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) =>
              EventCardDialog(card: eventCard.cast<String, dynamic>()),
        );
      }
      await _refresh(silent: true);
      if (!mounted) return;

      if (jsonBool(result['bankrupt'])) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('ورشکستگی'),
            content: const Text(
              'دارایی‌ها برای پرداخت بدهی استفاده شد، اما کافی نبود. از این مسابقه حذف شدی.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('متوجه شدم'),
              ),
            ],
          ),
        );
      }
      if (_me?.isEliminated ?? true) return;

      final cellType = jsonString(result['cellType']);
      if (cellType == 'bandit') {
        await _showBandit();
      } else if (const {
        'souvenir',
        'landmark',
        'market',
        'blackMarket',
      }.contains(cellType)) {
        await _showCityActions();
      }
    } catch (error) {
      if (mounted) await showFailure(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showBandit() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('راهزن در مسیر'),
        content: const Text(
          'راهزن ممکن است از پول یا کالای قاچاق تو کم کند. ادامه می‌دهی؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('بعداً'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: appRed),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رویارویی'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    try {
      final result = await widget.api.resolveBandit(widget.matchId);
      if (!mounted) return;
      final candidates = (result['candidateCardIds'] as List? ?? const [])
          .map(jsonString)
          .toList();
      if (candidates.isNotEmpty) {
        final cardId = await showDialog<String>(
          context: context,
          builder: (_) => _BanditChooseDialog(
            cards:
                _snapshot?.cards
                    .where((card) => candidates.contains(card.cardId))
                    .toList() ??
                const [],
          ),
        );
        if (cardId != null) {
          await widget.api.chooseBanditCard(widget.matchId, cardId);
        }
      }
      if (mounted) {
        final protectedBySheriff = jsonBool(result['protectedBySheriff']);
        final protectedByGuard = jsonBool(result['protectedByGuard']);
        final message = protectedBySheriff
            ? 'سپر داروغه جلوی حمله راهزن را گرفت.'
            : protectedByGuard
            ? 'محافظ جلوی حمله راهزن را گرفت.'
            : 'راهزن ${money(jsonInt(result['cashStolen']))} تومان برداشت.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      await _refresh(silent: true);
    } catch (error) {
      if (mounted) await showFailure(context, error);
    }
  }

  Future<void> _showCityActions() async {
    final snapshot = _snapshot;
    final me = _me;
    if (snapshot == null || me == null || me.isEliminated) return;
    final city = _cityForPosition(me.position);
    if (city == null) return;

    final cityId = jsonString(city['cityId']);
    final cellType = jsonString(city['cellType']);
    final legalCards = snapshot.cards
        .where(
          (card) =>
              card.ownerId == null &&
              card.cityId == cityId &&
              (card.type == 'souvenir' || card.type == 'landmark'),
        )
        .toList();
    final contrabandCards = snapshot.cards
        .where((card) => card.ownerId == null && card.type == 'contraband')
        .take(6)
        .toList();

    if (cellType != 'blackMarket') {
      if (legalCards.isEmpty) return;
      final card = legalCards.first;
      final shouldBuy = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(card.title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('خرید'),
            ),
          ],
        ),
      );
      if (shouldBuy == true) {
        await _buyCard(() => widget.api.buyLegal(widget.matchId, card.cardId));
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .76,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  jsonString(city['cityName']),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(jsonString(city['description'])),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      const Text(
                        'بازار سیاه',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: appRed,
                        ),
                      ),
                      if (me.hasSheriffShield)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'با سپر داروغه، خرید کالای قاچاق ممکن نیست.',
                          ),
                        ),
                      ...contrabandCards.map(
                        (card) => _CardRow(
                          card: card,
                          actionLabel: 'خرید',
                          onAction: me.hasSheriffShield
                              ? null
                              : () async {
                                  final bought = await _buyCard(
                                    () => widget.api.buyContraband(
                                      widget.matchId,
                                      card.cardId,
                                    ),
                                  );
                                  if (bought && sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _inventory() async {
    final snapshot = _snapshot;
    final me = _me;
    if (snapshot == null || me == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .84,
          child: _InventorySheet(
            cards: snapshot.cards
                .where(
                  (card) =>
                      card.ownerId == me.uid ||
                      me.cardIds.contains(card.cardId),
                )
                .toList(),
            allCards: snapshot.cards,
            players: snapshot.players
                .where((player) => player.uid != me.uid && !player.isEliminated)
                .toList(),
            pending: snapshot.trades,
            myId: me.uid,
            onOffer: (card, buyerId, price) async {
              await widget.api.createTrade(widget.matchId, buyerId, [
                card.cardId,
              ], price);
              await _refresh(silent: true);
            },
            onTradeAction: (trade, action) async {
              await widget.api.changeTrade(
                widget.matchId,
                trade.tradeId,
                action,
              );
              await _refresh(silent: true);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _uploadProduct() async {
    final draft = await showDialog<_ProductDraft>(
      context: context,
      builder: (_) => const _ProductDialog(),
    );
    if (draft == null) return;
    await _invoke(() async {
      await widget.api.uploadProduct(widget.matchId, draft.title, draft.image);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('محصول به کارت‌های من اضافه شد.')),
        );
      }
    });
  }

  Future<void> _useWeapon() async {
    final snapshot = _snapshot;
    final me = _me;
    if (snapshot == null || me == null || me.isEliminated) return;
    final competitors = snapshot.players
        .where((player) => player.uid != me.uid && !player.isEliminated)
        .toList();
    if (competitors.isEmpty) return;
    final targetId = await showDialog<String>(
      context: context,
      builder: (_) => _WeaponTargetDialog(players: competitors),
    );
    if (targetId == null) return;
    await _invoke(() async {
      final result = await widget.api.useWeapon(widget.matchId, targetId);
      if (mounted) {
        final target = MatchPlayer.fromJson(
          (result['target'] as Map).cast<String, dynamic>(),
        );
        final message = jsonBool(result['sheriffShieldRemoved'])
            ? 'سپر داروغه ${target.displayName} از بین رفت.'
            : target.isEliminated
            ? '${target.displayName} از مسابقه حذف شد.'
            : 'یک جان از ${target.displayName} کم شد.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  Future<void> _wheel(bool zoo) async {
    await _invoke(() async {
      final result = zoo
          ? await widget.api.useZooWheel(widget.matchId)
          : await widget.api.useSouvenirWheel(widget.matchId);
      if (!mounted) return;
      final card = TradeCard.fromJson(
        (result['card'] as Map).cast<String, dynamic>(),
      );
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(zoo ? 'کارت گردونه حیوانات' : 'کارت سوغات'),
          content: _CardDetails(card: card),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('بستن'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(
        title: Text(snapshot?.match.name ?? 'اتاق مسابقه'),
        actions: [
          IconButton(
            onPressed: _working ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'تازه‌سازی',
          ),
        ],
      ),
      body: ScreenBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : snapshot == null
            ? const SizedBox()
            : switch (snapshot.match.status) {
                'waiting' => _WaitingRoom(
                  snapshot: snapshot,
                  me: _me,
                  onReady: (value) =>
                      _invoke(() => widget.api.ready(widget.matchId, value)),
                  onStart: () =>
                      _invoke(() => widget.api.start(widget.matchId)),
                  onDelete: () async {
                    await _invoke(() => widget.api.deleteMatch(widget.matchId));
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                'finished' =>
                  snapshot.match.section == 'کودتا'
                      ? _CoupGame(
                          snapshot: snapshot,
                          me: _me,
                          busy: _working,
                          onAction: _coupAction,
                          onChallenge: _coupChallenge,
                          onBlock: _coupBlock,
                          onResolve: _coupResolve,
                          onLoseInfluence: _coupLoseInfluence,
                        )
                      : snapshot.match.section == 'اونو'
                      ? _UnoGame(
                          snapshot: snapshot,
                          me: _me,
                          busy: _working,
                          onPlay: _unoPlay,
                          onDraw: _unoDraw,
                          onCall: _unoCall,
                          onCatch: _unoCatch,
                        )
                      : _FinishedGame(snapshot: snapshot),
                _ =>
                  snapshot.match.section == 'کودتا'
                      ? _CoupGame(
                          snapshot: snapshot,
                          me: _me,
                          busy: _working,
                          onAction: _coupAction,
                          onChallenge: _coupChallenge,
                          onBlock: _coupBlock,
                          onResolve: _coupResolve,
                          onLoseInfluence: _coupLoseInfluence,
                        )
                      : snapshot.match.section == 'اونو'
                      ? _UnoGame(
                          snapshot: snapshot,
                          me: _me,
                          busy: _working,
                          onPlay: _unoPlay,
                          onDraw: _unoDraw,
                          onCall: _unoCall,
                          onCatch: _unoCatch,
                        )
                      : _ActiveGame(
                          snapshot: snapshot,
                          me: _me,
                          cities: _cities,
                          busy: _working,
                          cityForPosition: _cityForPosition,
                          onRoll: _roll,
                          onCity: _showCityActions,
                          onInventory: _inventory,
                          onBusiness: () {
                            Navigator.of(context)
                                .push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => BusinessProgressPage(
                                      api: widget.api,
                                      matchId: widget.matchId,
                                      initialBusiness: snapshot.business,
                                    ),
                                  ),
                                )
                                .then((_) {
                                  if (mounted) _refresh(silent: true);
                                });
                          },
                          onUploadProduct: _uploadProduct,
                          onWeapon: _useWeapon,
                          onSouvenir: () => _wheel(false),
                          onZoo: () => _wheel(true),
                          onBandit: _showBandit,
                        ),
              },
      ),
    );
  }
}

class _WaitingRoom extends StatelessWidget {
  const _WaitingRoom({
    required this.snapshot,
    required this.me,
    required this.onReady,
    required this.onStart,
    required this.onDelete,
  });

  final GameSnapshot snapshot;
  final MatchPlayer? me;
  final ValueChanged<bool> onReady;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isHost = me?.uid == snapshot.match.hostId;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            color: appNavy,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Text(
                    'کد اتاق',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    child: Text(
                      persianDigits(snapshot.match.roomCode),
                      style: const TextStyle(
                        color: appGold,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w900,
                        fontSize: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.match.section} | '
                    '${persianDigits(snapshot.players.length)} از '
                    '${persianDigits(snapshot.match.maxPlayers)} بازیکن',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'بازیکنان اتاق',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...snapshot.players.map(
            (player) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: AvatarCircle(avatarId: player.avatarId),
                title: Text(player.displayName),
                subtitle: Text('نسخه ${player.appVersion}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (player.uid == snapshot.match.hostId)
                      const Icon(Icons.workspace_premium, color: appGold),
                    Icon(
                      player.isReady
                          ? Icons.check_circle
                          : Icons.hourglass_empty,
                      color: player.isReady ? appGreen : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: me?.isReady ?? false,
            onChanged: onReady,
            title: const Text('برای شروع آماده‌ام'),
          ),
          if (isHost) ...[
            FilledButton.icon(
              onPressed: snapshot.players.length >= snapshot.match.minPlayers
                  ? onStart
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(
                snapshot.match.section == 'کودتا'
                    ? 'شروع کودتا (۲ تا ۴ نفر)'
                    : snapshot.match.section == 'اونو'
                    ? 'شروع اونو (۲ تا ۱۰ نفر)'
                    : 'شروع بازی (۲ تا ۶ نفر)',
              ),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: appRed),
              label: const Text(
                'حذف این مسابقه',
                style: TextStyle(color: appRed),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _coupRoleLabel(String role) => switch (role) {
  'duke' => 'دوک',
  'assassin' => 'قاتل',
  'contessa' => 'کنتس',
  'captain' => 'کاپیتان',
  'ambassador' => 'سفیر',
  'banker' => 'بانکدار',
  'capitalist' => 'سرمایه‌دار',
  'farmer' => 'کشاورز',
  'tax_collector' => 'مالیه‌چی',
  'landowner' => 'مالک مزرعه',
  'spy' => 'جاسوس',
  'guerrilla' => 'چریک',
  'crime_boss' => 'رئیس جنایتکاران',
  'general' => 'ژنرال',
  'mercenary' => 'مزدور',
  'director' => 'کارگردان',
  'journalist' => 'خبرنگار',
  'producer' => 'تهیه‌کننده',
  'reporter' => 'گزارشگر',
  'writer' => 'نویسنده',
  'communist' => 'کمونیست',
  'customs_officer' => 'مأمور گمرک',
  'foreign_advisor' => 'مشاور خارجی',
  'intellectual' => 'روشنفکر',
  'lawyer' => 'وکیل',
  _ => 'نقش مخفی',
};

String _coupActionLabel(String action) => switch (action) {
  'income' => 'درآمد',
  'foreignAid' => 'کمک خارجی',
  'tax' => 'مالیات',
  'bankerIncome' => 'درآمد بانکدار',
  'capitalistIncome' => 'درآمد سرمایه‌دار',
  'farmerIncome' => 'برداشت کشاورز',
  'taxCollectorIncome' => 'دریافت مالیه‌چی',
  'landownerIncome' => 'درآمد مالک مزرعه',
  'spyIncome' => 'اقدام جاسوس',
  'steal' => 'سرقت',
  'assassinate' => 'ترور',
  'guerrilla' => 'حمله چریک',
  'crimeBoss' => 'باج‌گیری',
  'general' => 'فشار ژنرال',
  'mercenary' => 'تهدید مزدور',
  'exchange' => 'تبادل نفوذ',
  'directorExchange' => 'انتخاب کارگردان',
  'journalist' => 'خبرنگار',
  'producer' => 'تهیه‌کننده',
  'reporter' => 'گزارشگر',
  'writerExchange' => 'بررسی نویسنده',
  'communist' => 'برداشت کمونیست',
  'customsOfficer' => 'عوارض گمرک',
  'foreignAdvisor' => 'پیمان مشاور خارجی',
  'block' => 'دفاع',
  'coup' => 'کودتا',
  _ => action,
};

class _CoupActionDefinition {
  const _CoupActionDefinition(
    this.action,
    this.label,
    this.icon, {
    this.targeted = false,
  });

  final String action;
  final String label;
  final IconData icon;
  final bool targeted;
}

const _coupRoleGuide = <({String role, String category, String description})>[
  (role: 'duke', category: 'مالی', description: '۳ سکه از خزانه بگیر.'),
  (
    role: 'assassin',
    category: 'قدرت',
    description: 'با پرداخت ۳ سکه، یک نفوذ از هدف کم کن.',
  ),
  (
    role: 'contessa',
    category: 'قدرت',
    description: 'در برابر قاتل ادعای دفاع کن.',
  ),
  (
    role: 'captain',
    category: 'قدرت',
    description: 'تا ۲ سکه از یک بازیکن بگیر.',
  ),
  (
    role: 'ambassador',
    category: 'ارتباطات',
    description: 'کارت‌ها را با بانک مبادله کن.',
  ),
  (role: 'banker', category: 'مالی', description: '۳ سکه بگیر.'),
  (role: 'capitalist', category: 'مالی', description: '۴ سکه بگیر.'),
  (
    role: 'farmer',
    category: 'مالی',
    description: '۳ سکه بگیر و ۱ سکه به بازیکن انتخابی بده.',
  ),
  (
    role: 'tax_collector',
    category: 'مالی',
    description: '۵ سکه از خزانه دریافت کن.',
  ),
  (role: 'landowner', category: 'مالی', description: '۱ سکه بگیر.'),
  (
    role: 'spy',
    category: 'مالی',
    description: '۱ سکه بگیر و یک اقدام اضافه انجام بده.',
  ),
  (
    role: 'guerrilla',
    category: 'قدرت',
    description: 'با پرداخت ۲ سکه، یک نفوذ از هدف کم کن.',
  ),
  (
    role: 'crime_boss',
    category: 'قدرت',
    description: 'هدف ۲ سکه می‌دهد تا نفوذش را نگه دارد.',
  ),
  (
    role: 'general',
    category: 'قدرت',
    description: 'با پرداخت ۵ سکه، به همهٔ رقیبان فشار مالی وارد کن.',
  ),
  (
    role: 'mercenary',
    category: 'قدرت',
    description: 'با پرداخت ۲ سکه، هدف را وادار به از دست‌دادن نفوذ کن.',
  ),
  (
    role: 'director',
    category: 'ارتباطات',
    description: 'دو کارت بانک را بررسی و مبادله کن.',
  ),
  (
    role: 'journalist',
    category: 'ارتباطات',
    description: 'یک کارت و یک سکه دریافت کن.',
  ),
  (
    role: 'producer',
    category: 'ارتباطات',
    description: 'یک کارت از بانک و یک کارت از بازیکن هدف بگیر.',
  ),
  (
    role: 'reporter',
    category: 'ارتباطات',
    description: 'یک کارت و یک سکه بگیر.',
  ),
  (
    role: 'writer',
    category: 'ارتباطات',
    description: 'سه کارت بانک را بررسی و مبادله کن.',
  ),
  (
    role: 'communist',
    category: 'منافع ویژه',
    description: 'تا ۳ سکه از ثروتمندترین بازیکن بگیر.',
  ),
  (
    role: 'customs_officer',
    category: 'منافع ویژه',
    description: '۲ سکه عوارض از هدف بگیر.',
  ),
  (
    role: 'foreign_advisor',
    category: 'منافع ویژه',
    description: 'با یک بازیکن پیمان عدم تعرض بساز.',
  ),
  (
    role: 'intellectual',
    category: 'منافع ویژه',
    description: 'پس از از دست‌دادن نفوذ، ۵ سکه دریافت کن.',
  ),
  (
    role: 'lawyer',
    category: 'منافع ویژه',
    description: 'پس از حذف بازیکن، سکه‌های او را بگیر.',
  ),
];

const _coupActions = <_CoupActionDefinition>[
  _CoupActionDefinition(
    'tax',
    'دوک: مالیات (+۳)',
    Icons.account_balance_outlined,
  ),
  _CoupActionDefinition(
    'bankerIncome',
    'بانکدار: +۳ سکه',
    Icons.account_balance_wallet_outlined,
  ),
  _CoupActionDefinition(
    'capitalistIncome',
    'سرمایه‌دار: +۴ سکه',
    Icons.trending_up_outlined,
  ),
  _CoupActionDefinition(
    'farmerIncome',
    'کشاورز: +۳ و اهدای ۱',
    Icons.agriculture_outlined,
    targeted: true,
  ),
  _CoupActionDefinition(
    'taxCollectorIncome',
    'مالیه‌چی: +۵ سکه',
    Icons.receipt_long_outlined,
  ),
  _CoupActionDefinition(
    'landownerIncome',
    'مالک مزرعه: +۱ سکه',
    Icons.landscape_outlined,
  ),
  _CoupActionDefinition(
    'spyIncome',
    'جاسوس: +۱ و اقدام اضافه',
    Icons.visibility_outlined,
  ),
  _CoupActionDefinition(
    'steal',
    'کاپیتان: سرقت تا ۲',
    Icons.monetization_on_outlined,
    targeted: true,
  ),
  _CoupActionDefinition(
    'assassinate',
    'قاتل: ترور (۳ سکه)',
    Icons.bolt_outlined,
    targeted: true,
  ),
  _CoupActionDefinition(
    'guerrilla',
    'چریک: حمله (۲ سکه)',
    Icons.flash_on_outlined,
    targeted: true,
  ),
  _CoupActionDefinition(
    'crimeBoss',
    'رئیس جنایتکاران: باج‌گیری',
    Icons.local_police_outlined,
    targeted: true,
  ),
  _CoupActionDefinition(
    'general',
    'ژنرال: فشار همهٔ رقیبان (۵ سکه)',
    Icons.groups_outlined,
  ),
  _CoupActionDefinition(
    'mercenary',
    'مزدور: تهدید (۲ سکه)',
    Icons.security_outlined,
    targeted: true,
  ),
  _CoupActionDefinition(
    'exchange',
    'سفیر: تبادل کارت',
    Icons.sync_alt_outlined,
  ),
  _CoupActionDefinition(
    'directorExchange',
    'کارگردان: بررسی ۲ کارت',
    Icons.movie_outlined,
  ),
  _CoupActionDefinition(
    'journalist',
    'خبرنگار: کارت و سکه',
    Icons.article_outlined,
  ),
  _CoupActionDefinition(
    'producer',
    'تهیه‌کننده: کارت بانک و هدف',
    Icons.video_camera_back_outlined,
    targeted: true,
  ),
  _CoupActionDefinition(
    'reporter',
    'گزارشگر: کارت و سکه',
    Icons.photo_camera_outlined,
  ),
  _CoupActionDefinition(
    'writerExchange',
    'نویسنده: بررسی ۳ کارت',
    Icons.edit_note_outlined,
  ),
  _CoupActionDefinition(
    'communist',
    'کمونیست: تا ۳ از ثروتمندترین',
    Icons.balance_outlined,
    targeted: true,
  ),
  _CoupActionDefinition(
    'customsOfficer',
    'مأمور گمرک: عوارض ۲',
    Icons.assignment_outlined,
    targeted: true,
  ),
  _CoupActionDefinition(
    'foreignAdvisor',
    'مشاور خارجی: پیمان',
    Icons.handshake_outlined,
    targeted: true,
  ),
];

class _CoupGame extends StatelessWidget {
  const _CoupGame({
    required this.snapshot,
    required this.me,
    required this.busy,
    required this.onAction,
    required this.onChallenge,
    required this.onBlock,
    required this.onResolve,
    required this.onLoseInfluence,
  });

  final GameSnapshot snapshot;
  final MatchPlayer? me;
  final bool busy;
  final Future<void> Function(String action, String? targetId) onAction;
  final Future<void> Function() onChallenge;
  final Future<void> Function() onBlock;
  final Future<void> Function() onResolve;
  final Future<void> Function(int roleIndex) onLoseInfluence;

  Future<void> _targetAction(BuildContext context, String action) async {
    var targets = snapshot.players
        .where((player) => player.uid != me?.uid && !player.isEliminated)
        .toList();
    if (action == 'communist' && targets.isNotEmpty) {
      final greatestCash = targets
          .map((player) => player.cashBalance)
          .reduce(max);
      targets = targets
          .where((player) => player.cashBalance == greatestCash)
          .toList();
    }
    final targetId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          action == 'coup'
              ? 'هدف کودتا'
              : 'انتخاب هدف برای ${_coupActionLabel(action)}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: targets
              .map(
                (player) => ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(player.displayName),
                  subtitle: Text(
                    'نفوذ: ${persianDigits(player.coupInfluenceCount)}',
                  ),
                  onTap: () => Navigator.pop(dialogContext, player.uid),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (targetId != null) await onAction(action, targetId);
  }

  Widget _actionButton(
    BuildContext context,
    String action,
    String label,
    IconData icon, {
    String? targetAction,
  }) {
    return FilledButton.icon(
      onPressed: busy
          ? null
          : () => targetAction == null
                ? onAction(action, null)
                : _targetAction(context, targetAction),
      icon: Icon(icon),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = snapshot.match.coupPendingAction;
    final isMyTurn = snapshot.match.currentTurnPlayerId == me?.uid;
    final isPendingActor = pending?['actorId']?.toString() == me?.uid;
    final isInfluenceChoice = pending?['kind']?.toString() == 'influenceLoss';
    final isDefenceClaim = pending?['kind']?.toString() == 'block';
    final isAssassinationTarget =
        pending?['action'] == 'assassinate' &&
        pending?['targetId']?.toString() == me?.uid;
    final winner = snapshot.players
        .where((player) => player.uid == snapshot.match.winnerId)
        .firstOrNull;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: appNavy,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Text(
                    'کودتا',
                    style: TextStyle(
                      color: appGold,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.match.status == 'finished'
                        ? 'برنده: ${winner?.displayName ?? 'نامشخص'}'
                        : (isMyTurn ? 'نوبت توست' : 'نوبت بازیکن دیگر است'),
                    style: const TextStyle(color: Colors.white, fontSize: 17),
                  ),
                  if (snapshot.match.status == 'finished')
                    const Text(
                      'پاداش برنده: ۲۰ کوین',
                      style: TextStyle(color: Color(0xffffd166)),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'سکه‌های تو: ${persianDigits(me?.cashBalance ?? 0)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          if (me != null) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نفوذهای مخفی تو',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: me!.coupRoles.isEmpty
                          ? [
                              Text(
                                'نفوذ باقی‌مانده: ${persianDigits(me!.coupInfluenceCount)}',
                              ),
                            ]
                          : me!.coupRoles
                                .map(
                                  (role) => Chip(
                                    label: Text(_coupRoleLabel(role)),
                                    avatar: const Icon(
                                      Icons.visibility_off_outlined,
                                      size: 16,
                                    ),
                                  ),
                                )
                                .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'بازیکنان',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...snapshot.players.map(
            (player) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  player.isEliminated
                      ? Icons.remove_circle_outline
                      : Icons.shield_outlined,
                  color: player.isEliminated ? Colors.grey : appGreen,
                ),
                title: Text(
                  '${player.displayName}${player.uid == me?.uid ? ' (تو)' : ''}',
                ),
                subtitle: Text(
                  player.isEliminated
                      ? 'حذف شده'
                      : 'نفوذ: ${persianDigits(player.coupInfluenceCount)} | سکه: ${persianDigits(player.cashBalance)}',
                ),
                trailing: player.uid == snapshot.match.currentTurnPlayerId
                    ? const Icon(Icons.play_arrow, color: appGold)
                    : null,
              ),
            ),
          ),
          if (pending != null) ...[
            const SizedBox(height: 8),
            Card(
              color: const Color(0xfffff3d6),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isInfluenceChoice
                          ? 'یک کارت نقش را برای حذف انتخاب کن؛ سپس اقدام بازی ادامه پیدا می‌کند.'
                          : isDefenceClaim
                          ? '${_coupRoleLabel(pending['claimedRole']?.toString() ?? '')} برای دفاع ادعا شده است؛ این ادعا هم قابل چالش است.'
                          : pending['action'] == 'foreignAid'
                          ? 'کمک خارجی در انتظار است؛ بازیکنان می‌توانند با ادعای دوک آن را بلاک کنند.'
                          : 'ادعای «${_coupRoleLabel(pending['claimedRole']?.toString() ?? '')}» برای ${_coupActionLabel(pending['action']?.toString() ?? '')} در انتظار است.',
                    ),
                    const SizedBox(height: 10),
                    if (isInfluenceChoice && isPendingActor && me != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: me!.coupRoles.asMap().entries.map((entry) {
                          final roleIndex = entry.key;
                          final role = entry.value;
                          return OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => onLoseInfluence(roleIndex),
                            icon: const Icon(Icons.remove_circle_outline),
                            label: Text(_coupRoleLabel(role)),
                          );
                        }).toList(),
                      )
                    else if (isPendingActor)
                      FilledButton.icon(
                        onPressed: busy ? null : onResolve,
                        icon: const Icon(Icons.check),
                        label: Text(
                          isDefenceClaim ? 'تأیید دفاع' : 'تأیید و اجرای اقدام',
                        ),
                      )
                    else if (!isInfluenceChoice &&
                        me != null &&
                        !me!.isEliminated)
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : (pending['action'] == 'foreignAid' ||
                                      isAssassinationTarget
                                  ? onBlock
                                  : onChallenge),
                        icon: Icon(
                          pending['action'] == 'foreignAid' ||
                                  isAssassinationTarget
                              ? Icons.block
                              : Icons.gavel_outlined,
                        ),
                        label: Text(
                          pending['action'] == 'foreignAid'
                              ? 'بلاک کمک خارجی'
                              : (isAssassinationTarget
                                    ? 'بلاک با کنتسا'
                                    : 'چالش ادعا'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (snapshot.match.status == 'active' &&
              pending == null &&
              isMyTurn &&
              me != null &&
              !me!.isEliminated) ...[
            const SizedBox(height: 14),
            const Text(
              'اقدام این نوبت',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _actionButton(
              context,
              'income',
              'درآمد (+۱)',
              Icons.add_circle_outline,
            ),
            _actionButton(
              context,
              'foreignAid',
              'کمک خارجی (+۲)',
              Icons.volunteer_activism_outlined,
            ),
            ..._coupActions.map(
              (definition) => _actionButton(
                context,
                definition.action,
                definition.label,
                definition.icon,
                targetAction: definition.targeted ? definition.action : null,
              ),
            ),
            _actionButton(
              context,
              'coup',
              'کودتا (۷ سکه)',
              Icons.gavel_outlined,
              targetAction: 'coup',
            ),
          ],
          const SizedBox(height: 18),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.style_outlined),
              title: const Text('نقش‌ها و توانایی‌ها'),
              children: _coupRoleGuide
                  .map(
                    (role) => ListTile(
                      title: Text(_coupRoleLabel(role.role)),
                      subtitle: Text(role.description),
                      trailing: Text(role.category),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'قانون چالش: می‌توانی هر نقش را ادعا کنی، حتی اگر کارت آن را نداشته باشی. اگر چالش شوی و نقش را داشته باشی، چالش‌گر یک نفوذ از دست می‌دهد؛ و اگر ادعایت نادرست باشد، خودت یک نفوذ از دست می‌دهی.',
            style: TextStyle(height: 1.7),
          ),
          const SizedBox(height: 8),
          const Text(
            'قانون برد: آخرین بازیکنی که حداقل یک نفوذ داشته باشد برنده است.',
            style: TextStyle(height: 1.7),
          ),
        ],
      ),
    );
  }
}

Color _unoCardColor(String color) => switch (color) {
  'red' => const Color(0xffd83b3b),
  'yellow' => const Color(0xffe4b51d),
  'green' => const Color(0xff23945e),
  'blue' => const Color(0xff2876c7),
  _ => appNavy,
};

String _unoColorLabel(String color) => switch (color) {
  'red' => 'قرمز',
  'yellow' => 'زرد',
  'green' => 'سبز',
  'blue' => 'آبی',
  _ => 'نامشخص',
};

String _unoCardLabel(Json card) => switch (jsonString(card['type'])) {
  'number' => persianDigits(jsonInt(card['value'])),
  'skip' => 'رد',
  'reverse' => 'برعکس',
  'draw2' => '+۲',
  'wild' => 'وحشی',
  'wild4' => '+۴',
  _ => '?',
};

class _UnoGame extends StatelessWidget {
  const _UnoGame({
    required this.snapshot,
    required this.me,
    required this.busy,
    required this.onPlay,
    required this.onDraw,
    required this.onCall,
    required this.onCatch,
  });

  final GameSnapshot snapshot;
  final MatchPlayer? me;
  final bool busy;
  final Future<void> Function(String cardId, {String? chosenColor, bool uno})
  onPlay;
  final Future<void> Function() onDraw;
  final Future<void> Function() onCall;
  final Future<void> Function() onCatch;

  Future<String?> _chooseColor(BuildContext context) => showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('رنگ بعدی را انتخاب کن'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children:
            const [
                  ['red', 'قرمز'],
                  ['yellow', 'زرد'],
                  ['green', 'سبز'],
                  ['blue', 'آبی'],
                ]
                .map(
                  (item) => ListTile(
                    title: Text(item[1]),
                    leading: Icon(Icons.circle, color: _unoCardColor(item[0])),
                    onTap: () => Navigator.pop(dialogContext, item[0]),
                  ),
                )
                .toList(),
      ),
    ),
  );

  Future<void> _play(BuildContext context, Json card) async {
    final type = jsonString(card['type']);
    final color = type == 'wild' || type == 'wild4'
        ? await _chooseColor(context)
        : null;
    if (!context.mounted) return;
    if ((type == 'wild' || type == 'wild4') && color == null) return;
    var shouldCallUno = false;
    if ((me?.unoHand.length ?? 0) == 2) {
      shouldCallUno =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('یک کارت می‌ماند'),
              content: const Text('می‌خواهی قبل از بازی اعلام کنی «اونو!»؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('بدون اعلام'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('اونو!'),
                ),
              ],
            ),
          ) ??
          false;
    }
    await onPlay(card['id'].toString(), chosenColor: color, uno: shouldCallUno);
  }

  Widget _cardButton(BuildContext context, Json card, bool enabled) {
    final color = jsonString(card['color']);
    return SizedBox(
      width: 76,
      height: 104,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _unoCardColor(color),
          foregroundColor: color == 'yellow' ? Colors.black : Colors.white,
          padding: const EdgeInsets.all(4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: enabled && !busy ? () => _play(context, card) : null,
        child: Text(
          _unoCardLabel(card),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMyTurn = snapshot.match.currentTurnPlayerId == me?.uid;
    final top = snapshot.match.unoDiscardTop;
    final atRisk = snapshot.players
        .where((player) => player.unoAtRisk && player.uid != me?.uid)
        .toList();
    final scores = snapshot.match.unoScores;
    final winner = snapshot.players
        .where((player) => player.uid == snapshot.match.winnerId)
        .firstOrNull;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: appNavy,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'اونو',
                    style: TextStyle(
                      color: appGold,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.match.status == 'finished'
                        ? 'برنده: ${winner?.displayName ?? 'نامشخص'}'
                        : (isMyTurn ? 'نوبت توست' : 'نوبت بازیکن دیگر است'),
                    style: const TextStyle(color: Colors.white, fontSize: 17),
                  ),
                  if (snapshot.match.status == 'finished')
                    const Text(
                      'پاداش برنده: ۲۰ کوین',
                      style: TextStyle(color: Color(0xffffd166)),
                    ),
                  const SizedBox(height: 12),
                  if (top != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _cardButton(context, top, false),
                        const SizedBox(width: 14),
                        Text(
                          'رنگ فعلی: ${_unoColorLabel(snapshot.match.unoCurrentColor ?? '')}\n${snapshot.match.unoDirection == 1 ? 'جهت ساعتگرد' : 'جهت پادساعتگرد'}',
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.8,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'بازیکنان',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...snapshot.players.map(
            (player) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  player.uid == snapshot.match.currentTurnPlayerId
                      ? Icons.play_arrow
                      : Icons.person_outline,
                  color: player.uid == snapshot.match.currentTurnPlayerId
                      ? appGold
                      : appNavy,
                ),
                title: Text(
                  '${player.displayName}${player.uid == me?.uid ? ' (تو)' : ''}',
                ),
                subtitle: Text(
                  'کارت‌ها: ${persianDigits(player.unoHandCount)} | امتیاز: ${persianDigits(jsonInt(scores[player.uid]))}',
                ),
                trailing: player.unoAtRisk
                    ? const Chip(label: Text('اونو؟'))
                    : null,
              ),
            ),
          ),
          if (me != null) ...[
            const SizedBox(height: 14),
            Text(
              'دست تو (${persianDigits(me!.unoHand.length)} کارت)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: me!.unoHand
                  .map(
                    (card) => _cardButton(
                      context,
                      card,
                      isMyTurn && snapshot.match.status == 'active',
                    ),
                  )
                  .toList(),
            ),
          ],
          if (snapshot.match.status == 'active' && isMyTurn && me != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: busy ? null : onDraw,
              icon: const Icon(Icons.download_outlined),
              label: const Text('کشیدن ۴ کارت در صورت نداشتن تطابق'),
            ),
          ],
          if (me?.unoAtRisk == true) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy ? null : onCall,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('اعلام اونو!'),
            ),
          ],
          if (snapshot.match.status == 'active' &&
              isMyTurn &&
              atRisk.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onCatch,
              icon: const Icon(Icons.gavel_outlined),
              label: const Text('گرفتن بازیکنِ بدون اونو'),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            snapshot.match.unoScoringMode == 'points'
                ? 'حالت امتیازی: بازی تا رسیدن یک بازیکن به ۵۰۰ امتیاز ادامه دارد.'
                : 'حالت ساده: اولین بازیکنی که همه کارت‌هایش را بازی کند برنده است.',
            style: const TextStyle(height: 1.7),
          ),
          const SizedBox(height: 8),
          const Text(
            'قانون کشیدن: اگر کارت هم‌رنگ، هم‌عدد یا هم‌عملکرد نداشته باشی، ۴ کارت می‌گیری و نوبتت تمام می‌شود.',
            style: TextStyle(height: 1.7),
          ),
        ],
      ),
    );
  }
}

class _ActiveGame extends StatelessWidget {
  const _ActiveGame({
    required this.snapshot,
    required this.me,
    required this.cities,
    required this.busy,
    required this.cityForPosition,
    required this.onRoll,
    required this.onCity,
    required this.onInventory,
    required this.onBusiness,
    required this.onUploadProduct,
    required this.onWeapon,
    required this.onSouvenir,
    required this.onZoo,
    required this.onBandit,
  });

  final GameSnapshot snapshot;
  final MatchPlayer? me;
  final List<Json> cities;
  final bool busy;
  final Json? Function(int) cityForPosition;
  final VoidCallback onRoll;
  final VoidCallback onCity;
  final VoidCallback onInventory;
  final VoidCallback onBusiness;
  final VoidCallback onUploadProduct;
  final VoidCallback onWeapon;
  final VoidCallback onSouvenir;
  final VoidCallback onZoo;
  final VoidCallback onBandit;

  @override
  Widget build(BuildContext context) {
    if (me == null) {
      return const Center(child: Text('بازیکن این مسابقه پیدا نشد.'));
    }
    final city = cityForPosition(me!.position);
    final myTurn = snapshot.match.currentTurnPlayerId == me!.uid;
    final hasActiveCompetitor = snapshot.players.any(
      (player) => player.uid != me!.uid && !player.isEliminated,
    );
    final canUseWeapon =
        me!.guardId != null &&
        !me!.isEliminated &&
        hasActiveCompetitor &&
        (me!.weaponUseCount == 0 || me!.cashBalance >= 100) &&
        !busy;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'پول جهانی',
                  value: '${money(me!.cashBalance)} تومان',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: Icons.favorite_outline,
                  label: 'جان',
                  value: persianDigits(me!.lives),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WorldBoard(
            cities: cities,
            players: snapshot.players,
            currentTurn: snapshot.match.currentTurnPlayerId,
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'اکنون: ${jsonString(city?['cityName'], 'مسیر جهانی')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(jsonString(city?['description'], 'نقشه جهانی تجارت')),
                  if (const {
                    'chance',
                    'communityChest',
                  }.contains(jsonString(city?['cellType'])))
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Row(
                        children: [
                          Icon(
                            jsonString(city?['cellType']) == 'chance'
                                ? Icons.style_outlined
                                : Icons.inventory_2_outlined,
                            color: jsonString(city?['cellType']) == 'chance'
                                ? appGold
                                : appGreen,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            jsonString(city?['cellType']) == 'chance'
                                ? 'خانه شانس'
                                : 'خانه صندوق جامعه',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  if (me!.hasSheriffShield)
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, color: appGreen),
                          SizedBox(width: 5),
                          Text('سپر داروغه فعال است'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (me!.isEliminated)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.person_off_outlined, color: appRed),
                    SizedBox(width: 8),
                    Expanded(child: Text('شما از این مسابقه حذف شده‌اید.')),
                  ],
                ),
              ),
            ),
          if (me!.guardId != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: appGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${guardTitleForId(me!.guardId)} | ${persianDigits(me!.lives)} جان${me!.guardProtectionUsed ? ' | سپر استفاده شده' : ' | سپر راهزن آماده'}${me!.weaponUseCount == 0 ? ' | سلاح اول رایگان' : ' | استفاده بعدی: ۱۰۰ تومان'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: myTurn ? appGold : Colors.grey,
              foregroundColor: myTurn ? Colors.black : Colors.white,
              minimumSize: const Size.fromHeight(55),
            ),
            onPressed: myTurn && !busy && !me!.isEliminated ? onRoll : null,
            icon: const Icon(Icons.casino_outlined),
            label: Text(
              myTurn
                  ? (busy ? 'در حال پرتاب...' : 'پرتاب تاس')
                  : 'نوبت بازیکن دیگر است',
            ),
          ),
          const SizedBox(height: 10),
          if (!me!.isEliminated && me!.guardId != null) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/characters/bandit.png',
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    semanticLabel: 'جاسوس',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: appRed,
                      minimumSize: const Size.fromHeight(58),
                    ),
                    onPressed: canUseWeapon ? onWeapon : null,
                    icon: const Icon(Icons.person_search_outlined),
                    label: Text(
                      me!.weaponUseCount == 0
                          ? 'انتخاب کشتن یک بازیکن'
                          : 'انتخاب کشتن بازیکن | ۱۰۰ تومان',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (!me!.isEliminated)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onCity,
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('شهر'),
                ),
                OutlinedButton.icon(
                  onPressed: onInventory,
                  icon: const Icon(Icons.style_outlined),
                  label: const Text('کارت‌های من'),
                ),
                OutlinedButton.icon(
                  onPressed: onBusiness,
                  icon: const Icon(Icons.business_center_outlined),
                  label: const Text('کسب‌وکار'),
                ),
                OutlinedButton.icon(
                  onPressed: onUploadProduct,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('افزودن کالا'),
                ),
                OutlinedButton.icon(
                  onPressed: onSouvenir,
                  icon: const Icon(Icons.card_giftcard_outlined),
                  label: const Text('گردونه سوغات'),
                ),
                OutlinedButton.icon(
                  onPressed: onZoo,
                  icon: const Icon(Icons.pets_outlined),
                  label: const Text('گردونه حیوانات'),
                ),
                if (jsonString(city?['cellType']) == 'bandit')
                  OutlinedButton.icon(
                    onPressed: onBandit,
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('راهزن'),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'رویدادهای اخیر',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  ...snapshot.events
                      .take(4)
                      .map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text('• ${jsonString(event['message'])}'),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: appNavy),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11)),
                FittedBox(
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class WorldBoard extends StatelessWidget {
  const WorldBoard({
    super.key,
    required this.cities,
    required this.players,
    required this.currentTurn,
  });

  final List<Json> cities;
  final List<MatchPlayer> players;
  final String currentTurn;

  Json? _cityForPosition(int position) {
    for (final city in cities) {
      if (jsonInt(city['routeOrder']) == position) return city;
    }
    return null;
  }

  double _coordinate(Json city, String key, double fallback) {
    final value = city[key];
    return value is num ? value.toDouble().clamp(0, 1) : fallback;
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.78,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/world_map_equirectangular.png',
              fit: BoxFit.cover,
            ),
            const ColoredBox(color: Color(0x10000000)),
            ...cities.map(
              (city) => Positioned(
                left: constraints.maxWidth * _coordinate(city, 'longitude', .5),
                top: constraints.maxHeight * _coordinate(city, 'latitude', .5),
                child: const IgnorePointer(
                  child: Icon(Icons.circle, color: appGold, size: 4),
                ),
              ),
            ),
            ...players.where((player) => !player.isEliminated).map((player) {
              final city = _cityForPosition(player.position);
              final x = city == null ? .5 : _coordinate(city, 'longitude', .5);
              final y = city == null ? .5 : _coordinate(city, 'latitude', .5);
              return Positioned(
                left: constraints.maxWidth * x - 19,
                top: constraints.maxHeight * y - 37,
                child: Column(
                  children: [
                    AvatarCircle(
                      avatarId: player.avatarId,
                      size: player.uid == currentTurn ? 36 : 30,
                      borderColor: player.uid == currentTurn
                          ? appRed
                          : Colors.white,
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.red,
                      size: 25,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

class _FinishedGame extends StatelessWidget {
  const _FinishedGame({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final winner = snapshot.player(snapshot.match.winnerId ?? '');
    final players = [...snapshot.players]
      ..sort((a, b) {
        final winnerComparison =
            (b.uid == snapshot.match.winnerId ? 1 : 0) -
            (a.uid == snapshot.match.winnerId ? 1 : 0);
        if (winnerComparison != 0) return winnerComparison;
        if (a.isEliminated != b.isEliminated) return a.isEliminated ? 1 : -1;
        return b.totalWealth.compareTo(a.totalWealth);
      });
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
        children: [
          const Icon(Icons.emoji_events_rounded, color: appGold, size: 76),
          const SizedBox(height: 12),
          const Text(
            'مسابقه تمام شد',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            winner == null
                ? 'نتیجه در حال ثبت است.'
                : 'برنده مسابقه: ${winner.displayName}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'پاداش برنده: ۲۰ کوین',
            textAlign: TextAlign.center,
            style: TextStyle(color: appGold, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 28),
          const Text(
            'نتیجه بازیکنان',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...players.map((player) {
            final isWinner = player.uid == snapshot.match.winnerId;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: AvatarCircle(avatarId: player.avatarId),
                title: Text(player.displayName),
                subtitle: Text(money(player.totalWealth)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isWinner
                          ? Icons.emoji_events_rounded
                          : Icons.cancel_outlined,
                      color: isWinner ? appGold : appRed,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isWinner ? 'برد' : 'باخت',
                      style: TextStyle(
                        color: isWinner ? appGreen : appRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home_rounded),
            label: const Text('بازگشت به خانه'),
          ),
        ],
      ),
    );
  }
}

class DiceResultDialog extends StatefulWidget {
  const DiceResultDialog({super.key, required this.value});

  final int value;

  @override
  State<DiceResultDialog> createState() => _DiceResultDialogState();
}

class _DiceResultDialogState extends State<DiceResultDialog> {
  int _value = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    var steps = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      setState(() => _value = (_value % 6) + 1);
      if (++steps == 10) {
        timer.cancel();
        setState(() => _value = widget.value);
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    content: SizedBox(
      width: 180,
      height: 180,
      child: Center(
        child: Text(
          persianDigits(_value),
          style: const TextStyle(
            fontSize: 116,
            color: appGold,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class EventCardDialog extends StatelessWidget {
  const EventCardDialog({super.key, required this.card});

  final Json card;

  @override
  Widget build(BuildContext context) {
    final isChance = jsonString(card['deck']) == 'chance';
    final effect = jsonString(card['effect']);
    final amount = jsonInt(card['amount']);
    final moved = jsonBool(card['moved']);
    final debt = card['debtSettlement'];
    final bankrupt = debt is Map && jsonBool(debt['bankrupt']);
    final effectText = switch (effect) {
      'credit' => 'دریافت ${money(amount)} تومان',
      'debit' => 'پرداخت ${money(amount)} تومان',
      'move' => moved ? 'به مقصد کارت منتقل شدی' : 'حرکت انجام نشد',
      _ => '',
    };
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isChance ? Icons.style_outlined : Icons.inventory_2_outlined,
            color: isChance ? appGold : appGreen,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(jsonString(card['deckTitle']))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            jsonString(card['title']),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(jsonString(card['description'])),
          if (effectText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              effectText,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (bankrupt) ...[
            const SizedBox(height: 10),
            const Text(
              'دارایی‌ها برای پرداخت بدهی کافی نبود.',
              style: TextStyle(color: appRed, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ادامه'),
        ),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.actionLabel,
    required this.onAction,
  });

  final TradeCard card;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: ListTile(
      title: Text(card.title),
      subtitle: Text(
        '${money(card.purchasePrice)} تومان | ارزش ${money(card.currentValue)}',
      ),
      trailing: FilledButton(onPressed: onAction, child: Text(actionLabel)),
    ),
  );
}

class _CardDetails extends StatelessWidget {
  const _CardDetails({required this.card});

  final TradeCard card;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (card.imageAsset.startsWith('http'))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              card.imageAsset,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
          ),
        ),
      Text(card.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      if (card.description.isNotEmpty) Text(card.description),
      const SizedBox(height: 5),
      Text('ارزش: ${money(card.currentValue)} تومان'),
    ],
  );
}

class _InventorySheet extends StatefulWidget {
  const _InventorySheet({
    required this.cards,
    required this.allCards,
    required this.players,
    required this.pending,
    required this.myId,
    required this.onOffer,
    required this.onTradeAction,
  });

  final List<TradeCard> cards;
  final List<TradeCard> allCards;
  final List<MatchPlayer> players;
  final List<PendingTrade> pending;
  final String myId;
  final Future<void> Function(TradeCard card, String buyerId, int price)
  onOffer;
  final Future<void> Function(PendingTrade trade, String action) onTradeAction;

  @override
  State<_InventorySheet> createState() => _InventorySheetState();
}

class _InventorySheetState extends State<_InventorySheet> {
  final _price = TextEditingController();
  String? _cardId;
  String? _buyerId;
  bool _working = false;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  int? get _offerPrice {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var raw = _price.text.trim();
    for (var index = 0; index < 10; index++) {
      raw = raw.replaceAll(persian[index], '$index');
      raw = raw.replaceAll(arabic[index], '$index');
    }
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitOffer() async {
    final selectedCardId = _cardId;
    final selectedBuyerId = _buyerId;
    final price = _offerPrice;
    if (selectedCardId == null ||
        selectedBuyerId == null ||
        price == null ||
        price <= 0) {
      _message('کارت، بازیکن و قیمت معتبر را انتخاب کن.');
      return;
    }
    final card = widget.cards
        .where((item) => item.cardId == selectedCardId)
        .firstOrNull;
    if (card == null) {
      _message('این کارت دیگر برای پیشنهاد در دسترس نیست.');
      return;
    }
    await _run(
      () => widget.onOffer(card, selectedBuyerId, price),
      'پیشنهاد ارسال شد.',
    );
  }

  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } on GameApiException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('ارتباط با سرور بازی برقرار نشد.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incoming = widget.pending
        .where((item) => item.buyerId == widget.myId)
        .toList();
    final outgoing = widget.pending
        .where((item) => item.sellerId == widget.myId)
        .toList();
    final offeredCardIds = outgoing.expand((item) => item.cardIds).toSet();
    final availableCards = widget.cards
        .where((card) => !offeredCardIds.contains(card.cardId))
        .toList();
    final cardsById = {for (final card in widget.allCards) card.cardId: card};
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'کارت‌های من'),
                Tab(text: 'پیشنهادها'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  widget.cards.isEmpty
                      ? const Center(child: Text('هنوز کارتی نداری.'))
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 12),
                          itemCount: widget.cards.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final card = widget.cards[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: _CardDetails(card: card),
                              ),
                            );
                          },
                        ),
                  ListView(
                    padding: const EdgeInsets.only(top: 12),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'ارسال پیشنهاد جدید',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                key: ValueKey('trade-card-$_cardId'),
                                initialValue:
                                    availableCards.any(
                                      (card) => card.cardId == _cardId,
                                    )
                                    ? _cardId
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'کارت من',
                                ),
                                items: availableCards
                                    .map(
                                      (card) => DropdownMenuItem(
                                        value: card.cardId,
                                        child: Text(
                                          card.title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _working || availableCards.isEmpty
                                    ? null
                                    : (value) =>
                                          setState(() => _cardId = value),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                key: ValueKey('trade-buyer-$_buyerId'),
                                initialValue:
                                    widget.players.any(
                                      (player) => player.uid == _buyerId,
                                    )
                                    ? _buyerId
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'بازیکن دریافت‌کننده',
                                ),
                                items: widget.players
                                    .map(
                                      (player) => DropdownMenuItem(
                                        value: player.uid,
                                        child: Text(
                                          player.displayName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _working || widget.players.isEmpty
                                    ? null
                                    : (value) =>
                                          setState(() => _buyerId = value),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _price,
                                enabled: !_working,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'قیمت پیشنهاد',
                                ),
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed:
                                    _working ||
                                        availableCards.isEmpty ||
                                        widget.players.isEmpty
                                    ? null
                                    : _submitOffer,
                                icon: _working
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send_outlined),
                                label: const Text('ارسال پیشنهاد'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'پیشنهادهای دریافتی',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (incoming.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text('پیشنهاد دریافتی نداری.'),
                        )
                      else
                        ...incoming.map(
                          (trade) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TradeListItem(
                              trade: trade,
                              cardsById: cardsById,
                              player: widget.players
                                  .where((item) => item.uid == trade.sellerId)
                                  .firstOrNull,
                              actionButtons: [
                                IconButton(
                                  onPressed: _working
                                      ? null
                                      : () => _run(
                                          () => widget.onTradeAction(
                                            trade,
                                            'accept',
                                          ),
                                          'پیشنهاد پذیرفته شد.',
                                        ),
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: appGreen,
                                  ),
                                  tooltip: 'پذیرفتن',
                                ),
                                IconButton(
                                  onPressed: _working
                                      ? null
                                      : () => _run(
                                          () => widget.onTradeAction(
                                            trade,
                                            'reject',
                                          ),
                                          'پیشنهاد رد شد.',
                                        ),
                                  icon: const Icon(Icons.cancel, color: appRed),
                                  tooltip: 'رد کردن',
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'پیشنهادهای ارسال‌شده',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (outgoing.isEmpty)
                        const Text('پیشنهاد ارسال‌شده‌ای نداری.')
                      else
                        ...outgoing.map(
                          (trade) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TradeListItem(
                              trade: trade,
                              cardsById: cardsById,
                              player: widget.players
                                  .where((item) => item.uid == trade.buyerId)
                                  .firstOrNull,
                              actionButtons: [
                                IconButton(
                                  onPressed: _working
                                      ? null
                                      : () => _run(
                                          () => widget.onTradeAction(
                                            trade,
                                            'cancel',
                                          ),
                                          'پیشنهاد لغو شد.',
                                        ),
                                  icon: const Icon(Icons.undo, color: appRed),
                                  tooltip: 'لغو پیشنهاد',
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeListItem extends StatelessWidget {
  const _TradeListItem({
    required this.trade,
    required this.cardsById,
    required this.player,
    required this.actionButtons,
  });

  final PendingTrade trade;
  final Map<String, TradeCard> cardsById;
  final MatchPlayer? player;
  final List<Widget> actionButtons;

  @override
  Widget build(BuildContext context) {
    final cardNames = trade.cardIds
        .map((id) => cardsById[id]?.title ?? 'کارت حذف‌شده')
        .join('، ');
    final playerName = player?.displayName ?? 'بازیکن';
    return Card(
      child: ListTile(
        leading: player == null
            ? null
            : AvatarCircle(avatarId: player!.avatarId, size: 36),
        title: Text('${money(trade.price)} تومان'),
        subtitle: Text('$playerName | $cardNames'),
        trailing: Wrap(spacing: 2, children: actionButtons),
      ),
    );
  }
}

class _WeaponTargetDialog extends StatefulWidget {
  const _WeaponTargetDialog({required this.players});

  final List<MatchPlayer> players;

  @override
  State<_WeaponTargetDialog> createState() => _WeaponTargetDialogState();
}

class _WeaponTargetDialogState extends State<_WeaponTargetDialog> {
  String? _targetId;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('استفاده از سلاح'),
    content: SizedBox(
      width: double.maxFinite,
      child: ListView(
        shrinkWrap: true,
        children: widget.players
            .map(
              (player) => ListTile(
                onTap: () => setState(() => _targetId = player.uid),
                leading: AvatarCircle(avatarId: player.avatarId, size: 32),
                title: Text(player.displayName),
                subtitle: Text(
                  player.hasSheriffShield
                      ? 'دارای سپر داروغه | ${persianDigits(player.lives)} جان'
                      : '${persianDigits(player.lives)} جان | ${money(player.cashBalance)} تومان',
                ),
                trailing: Icon(
                  _targetId == player.uid
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _targetId == player.uid ? appRed : Colors.grey,
                ),
              ),
            )
            .toList(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: appRed),
        onPressed: _targetId == null
            ? null
            : () => Navigator.pop(context, _targetId),
        child: const Text('تأیید'),
      ),
    ],
  );
}

class _ProductDraft {
  const _ProductDraft(this.title, this.image);

  final String title;
  final XFile image;
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog();

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _title = TextEditingController();
  XFile? _image;
  bool _picking = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (mounted) setState(() => _image = selected);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('افزودن کالای شخصی'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'برای ثبت کارت، یک اسکناس ۱۰ واحدی یا ده اسکناس ۱ واحدی پرداخت می‌شود.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'نام محصول'),
        ),
        OutlinedButton.icon(
          onPressed: _picking ? null : _pick,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_image == null ? 'انتخاب عکس محصول' : 'عکس انتخاب شد'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(
        onPressed: () {
          if (_title.text.trim().length >= 2 && _image != null) {
            Navigator.pop(context, _ProductDraft(_title.text.trim(), _image!));
          }
        },
        child: const Text('ثبت محصول'),
      ),
    ],
  );
}

class _BanditChooseDialog extends StatelessWidget {
  const _BanditChooseDialog({required this.cards});

  final List<TradeCard> cards;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('یک کارت را انتخاب کن'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: cards
          .map(
            (card) => ListTile(
              title: Text(card.title),
              onTap: () => Navigator.pop(context, card.cardId),
            ),
          )
          .toList(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('بستن'),
      ),
    ],
  );
}
