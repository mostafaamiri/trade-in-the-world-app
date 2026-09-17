import 'dart:async';
import 'dart:convert';

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
    if (!silent && mounted) {
      setState(() {
        _loading = _snapshot == null;
        _error = null;
      });
    }
    try {
      final snapshot = await widget.api.snapshot(widget.matchId);
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _loading = false;
          _error = null;
        });
        _maybePlayWinnerSound(snapshot);
      }
    } catch (error) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  void _maybePlayWinnerSound(GameSnapshot snapshot) {
    if (snapshot.match.status != 'finished' ||
        snapshot.match.winnerId != widget.api.userId) {
      return;
    }
    unawaited(GameMusicService.playWinner(widget.matchId));
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
      await _refresh(silent: true);
      if (!mounted) return;

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
    if (snapshot == null || me == null) return;
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
        await _invoke(() => widget.api.buyLegal(widget.matchId, card.cardId));
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
                                  try {
                                    await widget.api.buyContraband(
                                      widget.matchId,
                                      card.cardId,
                                    );
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                    await _refresh(silent: true);
                                  } catch (error) {
                                    if (sheetContext.mounted) {
                                      await showFailure(sheetContext, error);
                                    }
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
                .where((card) => card.ownerId == me.uid)
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
          title: Text(zoo ? 'کارت باغ وحش' : 'کارت سوغات'),
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
                    if (mounted) Navigator.pop(context);
                  },
                ),
                'finished' => _FinishedGame(snapshot: snapshot),
                _ => _ActiveGame(
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
              onPressed: snapshot.players.length >= 2 ? onStart : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('شروع بازی (۲ تا ۶ نفر)'),
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
        (me!.weaponUseCount == 0 || me!.cashBalance >= 200) &&
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
                        '${guardTitleForId(me!.guardId)} | ${persianDigits(me!.lives)} جان${me!.guardProtectionUsed ? ' | سپر استفاده شده' : ' | سپر راهزن آماده'}${me!.weaponUseCount == 0 ? ' | سلاح اول رایگان' : ' | استفاده بعدی: ۲۰۰ تومان'}',
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
                          : 'انتخاب کشتن بازیکن | ۲۰۰ تومان',
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
                  label: const Text('باغ وحش'),
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
                  child: Icon(Icons.circle, color: appGold, size: 5),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: appGold,
                  size: 76,
                ),
                const SizedBox(height: 12),
                const Text(
                  'مسابقه تمام شد',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  winner == null
                      ? 'نتیجه در حال ثبت است.'
                      : 'برنده: ${winner.displayName}',
                ),
                const SizedBox(height: 16),
                ...players.map(
                  (player) => ListTile(
                    leading: AvatarCircle(avatarId: player.avatarId),
                    title: Text(player.displayName),
                    subtitle: player.isEliminated
                        ? const Text('حذف شده')
                        : null,
                    trailing: Text(money(player.totalWealth)),
                  ),
                ),
              ],
            ),
          ),
        ),
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
