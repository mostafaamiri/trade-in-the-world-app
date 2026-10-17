import 'package:flutter/material.dart';

import 'models.dart';
import 'ui.dart';

class ChingActionArgs {
  const ChingActionArgs({
    this.targetId,
    this.recipientId,
    this.slot,
    this.targetSlot,
  });

  final String? targetId;
  final String? recipientId;
  final int? slot;
  final int? targetSlot;
}

class ChingGame extends StatelessWidget {
  const ChingGame({
    super.key,
    required this.snapshot,
    required this.me,
    required this.busy,
    required this.drawnCard,
    required this.pendingPower,
    required this.hidePeekEdges,
    required this.onDraw,
    required this.onSwap,
    required this.onPower,
    required this.onDetective,
  });

  final GameSnapshot snapshot;
  final MatchPlayer? me;
  final bool busy;
  final Json? drawnCard;
  final int? pendingPower;
  final bool hidePeekEdges;
  final Future<void> Function() onDraw;
  final Future<void> Function(int? slot) onSwap;
  final Future<void> Function(ChingActionArgs args) onPower;
  final Future<void> Function() onDetective;

  String _powerText(int value) => switch (value) {
    1 => 'یک کارت حریف را برای بازیکن دیگری بفرست.',
    2 => 'نوبتت دوباره ادامه پیدا می‌کند.',
    3 => 'دست یک حریف را بر بزن؛ او دیگر شروع و پایان دستش را نمی‌بیند.',
    4 => 'یک کارت حریف را بسوزان، کارت خودت را بده و از وسط بردار.',
    5 => 'یکی از کارت‌های وسط دست خودت را ببین.',
    6 => 'دست حریف را بر بزن، یک کارت بسوزان و از وسط جایگزین کن.',
    7 || 10 => 'یک کارت از حریف را ببین.',
    8 => 'تمام کارت‌های خودت را ببین.',
    9 => 'همهٔ دست‌ها یک خانه ساعت‌گرد جابه‌جا می‌شوند.',
    _ => 'قدرتی ندارد.',
  };

  String _asset(Json card) {
    final asset = jsonString(card['imageAsset']);
    if (asset.isNotEmpty) return asset;
    return 'assets/images/ching/ching-0.webp';
  }

  Widget _card(Json card, {bool hidden = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 74,
        height: 104,
        decoration: BoxDecoration(
          color: hidden ? appNavy : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: appGold, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 5)],
        ),
        clipBehavior: Clip.antiAlias,
        child: hidden
            ? const Center(
                child: Icon(Icons.style_rounded, color: appGold, size: 34),
              )
            : Image.asset(_asset(card), fit: BoxFit.cover),
      ),
    );
  }

  Future<String?> _pickPlayer(
    BuildContext context,
    List<MatchPlayer> players,
  ) => showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('انتخاب حریف'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: players
            .map(
              (player) => ListTile(
                title: Text(player.displayName),
                onTap: () => Navigator.pop(dialogContext, player.uid),
              ),
            )
            .toList(),
      ),
    ),
  );

  Future<int?> _pickSlot(
    BuildContext context,
    int count, {
    String title = 'انتخاب کارت',
  }) => showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Wrap(
        spacing: 8,
        children: List.generate(
          count,
          (index) => FilledButton(
            onPressed: () => Navigator.pop(dialogContext, index),
            child: Text('کارت ${persianDigits(index + 1)}'),
          ),
        ),
      ),
    ),
  );

  Future<void> _runPower(BuildContext context) async {
    final power = pendingPower;
    final meValue = me;
    if (power == null || meValue == null) return;
    final others = snapshot.players
        .where((player) => player.uid != meValue.uid)
        .toList();
    if (power == 9 || power == 8 || power == 2) {
      await onPower(const ChingActionArgs());
      return;
    }
    if (power == 5) {
      final slot = await _pickSlot(context, meValue.chingHand.length);
      if (!context.mounted) return;
      if (slot != null) {
        await onPower(ChingActionArgs(slot: slot));
      }
      return;
    }
    final targetId = await _pickPlayer(context, others);
    if (!context.mounted || targetId == null) return;
    final target = others.firstWhere((player) => player.uid == targetId);
    if (power == 7 || power == 10) {
      final slot = await _pickSlot(context, target.chingHandCount);
      if (!context.mounted) return;
      if (slot != null) {
        await onPower(ChingActionArgs(targetId: targetId, slot: slot));
      }
      return;
    }
    if (power == 1) {
      final recipients = others
          .where((player) => player.uid != targetId)
          .toList();
      final recipientId = await _pickPlayer(context, recipients);
      if (!context.mounted || recipientId == null) return;
      final slot = await _pickSlot(context, target.chingHandCount);
      if (!context.mounted) return;
      if (slot != null) {
        await onPower(
          ChingActionArgs(
            targetId: targetId,
            recipientId: recipientId,
            targetSlot: slot,
          ),
        );
      }
      return;
    }
    if (power == 3) {
      await onPower(ChingActionArgs(targetId: targetId));
      return;
    }
    if (power == 4) {
      final ownSlot = await _pickSlot(
        context,
        meValue.chingHand.length,
        title: 'کارت خودت برای دادن',
      );
      if (!context.mounted || ownSlot == null) return;
      final targetSlot = await _pickSlot(
        context,
        target.chingHandCount,
        title: 'کارت حریف برای سوزاندن',
      );
      if (!context.mounted) return;
      if (targetSlot != null) {
        await onPower(
          ChingActionArgs(
            targetId: targetId,
            slot: ownSlot,
            targetSlot: targetSlot,
          ),
        );
      }
      return;
    }
    if (power == 6) {
      final targetSlot = await _pickSlot(
        context,
        target.chingHandCount,
        title: 'کارت حریف برای سوزاندن',
      );
      if (!context.mounted) return;
      if (targetSlot != null) {
        await onPower(
          ChingActionArgs(targetId: targetId, targetSlot: targetSlot),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = me;
    final myTurn = snapshot.match.currentTurnPlayerId == mine?.uid;
    final finished = snapshot.match.status == 'finished';
    final winner = snapshot.players
        .where((player) => player.uid == snapshot.match.winnerId)
        .firstOrNull;
    final others = snapshot.players
        .where((player) => player.uid != mine?.uid)
        .toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            color: appNavy,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'کاراگاه چینگ',
                    style: TextStyle(
                      color: appGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    finished
                        ? 'برنده: ${winner?.displayName ?? 'نامشخص'}'
                        : (myTurn
                              ? 'نوبت توست؛ یک کارت از وسط بردار.'
                              : 'نوبت بازیکن دیگر است.'),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  if (finished)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'کارت‌ها آشکار شدند؛ کمترین مجموع برنده است.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...others.map(
            (player) => Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    AvatarCircle(avatarId: player.avatarId, size: 38),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        player.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: List.generate(
                        player.chingHandCount,
                        (_) => _card(const {}, hidden: true),
                      ),
                    ),
                    if (finished && player.chingScore != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          'مجموع ${persianDigits(player.chingScore!)}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (mine != null) ...[
            Text(
              'کارت‌های تو (${persianDigits(mine.chingHandCount)})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: mine.chingHand.asMap().entries.map((entry) {
                final edge =
                    entry.key == 0 || entry.key == mine.chingHand.length - 1;
                final hidden =
                    (hidePeekEdges && edge) ||
                    jsonString(entry.value['imageAsset']).isEmpty;
                return _card(entry.value, hidden: hidden);
              }).toList(),
            ),
          ],
          if (drawnCard != null) ...[
            const SizedBox(height: 14),
            Card(
              color: const Color(0xfffff9e6),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const Text(
                      'کارت وسط را دیدی؛ با کدام کارت عوض شود؟',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    _card(drawnCard!),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...List.generate(
                          mine?.chingHandCount ?? 0,
                          (index) => OutlinedButton(
                            onPressed: busy ? null : () => onSwap(index),
                            child: Text('تعویض ${persianDigits(index + 1)}'),
                          ),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => onSwap(null),
                          child: const Text('رد کردن کارت'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (pendingPower != null) ...[
            const SizedBox(height: 12),
            Card(
              color: const Color(0xfffff1cf),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Text(
                      'قدرت کارت ${persianDigits(pendingPower!)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _powerText(pendingPower!),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: busy ? null : () => _runPower(context),
                      icon: const Icon(Icons.bolt),
                      label: const Text('اجرای قدرت'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (snapshot.match.status == 'active' &&
              myTurn &&
              drawnCard == null &&
              pendingPower == null)
            FilledButton.icon(
              onPressed: busy ? null : onDraw,
              icon: const Icon(Icons.style_rounded),
              label: const Text('برداشتن کارت از وسط'),
            ),
          if (snapshot.match.status == 'active') ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: appRed),
              onPressed: busy ? null : onDetective,
              icon: const Icon(Icons.search_rounded),
              label: const Text('کاراگاه چینگ'),
            ),
          ],
        ],
      ),
    );
  }
}
