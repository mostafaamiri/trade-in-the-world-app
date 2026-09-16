import 'package:flutter/material.dart';

import 'models.dart';
import 'services/game_api.dart';
import 'ui.dart';

class GuardShopPage extends StatefulWidget {
  const GuardShopPage({super.key, required this.api});

  final GameApi api;

  @override
  State<GuardShopPage> createState() => _GuardShopPageState();
}

class _GuardShopPageState extends State<GuardShopPage> {
  GuardCollection? _collection;
  bool _loading = true;
  String? _error;
  String? _workingGuardId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final collection = await widget.api.guards();
      if (mounted) {
        setState(() {
          _collection = collection;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _select(GameGuard guard) async {
    final collection = _collection;
    if (collection == null || _workingGuardId != null) return;
    setState(() => _workingGuardId = guard.id);
    try {
      final result = collection.ownedGuardIds.contains(guard.id)
          ? await widget.api.equipGuard(guard.id)
          : await widget.api.buyGuard(guard.id);
      if (mounted) {
        setState(() => _collection = result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${guard.title} برای مسابقه بعدی انتخاب شد.')),
        );
      }
    } catch (error) {
      if (mounted) await showFailure(context, error);
    } finally {
      if (mounted) setState(() => _workingGuardId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('محافظ')),
    body: ScreenBackground(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'تازه‌سازی',
                    ),
                  ],
                ),
              ),
            )
          : _GuardGrid(
              collection: _collection!,
              workingGuardId: _workingGuardId,
              onSelect: _select,
            ),
    ),
  );
}

class _GuardGrid extends StatelessWidget {
  const _GuardGrid({
    required this.collection,
    required this.workingGuardId,
    required this.onSelect,
  });

  final GuardCollection collection;
  final String? workingGuardId;
  final ValueChanged<GameGuard> onSelect;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.monetization_on_outlined, color: appGold),
              const SizedBox(width: 6),
              Text(
                '${persianDigits(collection.coins)} کوین',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              const Icon(Icons.shield_outlined, color: appGreen),
              const SizedBox(width: 4),
              Text(
                collection.equippedGuardId == null
                    ? 'بدون محافظ'
                    : guardTitleForId(collection.equippedGuardId),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .67,
            ),
            itemCount: collection.guards.length,
            itemBuilder: (context, index) {
              final guard = collection.guards[index];
              final owned = collection.ownedGuardIds.contains(guard.id);
              final equipped = collection.equippedGuardId == guard.id;
              final working = workingGuardId == guard.id;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Image.asset(guard.imageAsset, fit: BoxFit.cover),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            guard.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          if (equipped)
                            const Text(
                              'انتخاب شده',
                              style: TextStyle(
                                color: appGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          else
                            FilledButton(
                              onPressed: working ? null : () => onSelect(guard),
                              style: FilledButton.styleFrom(
                                backgroundColor: owned ? appNavy : appGold,
                                foregroundColor: owned
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              child: working
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      owned
                                          ? 'انتخاب'
                                          : '${persianDigits(guard.price)} کوین',
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
