import 'package:flutter/material.dart';

import 'models.dart';
import 'services/game_api.dart';
import 'ui.dart';

const _legacyZooAnimals = <String>['شیر', 'باسیلیسک', 'لاما'];

const _zooAnimalAssets = <String, String>{
  'شیر': 'assets/zoo/lioness.jpg',
  'باسیلیسک': 'assets/zoo/basilisk.jpg',
  'لاما': 'assets/zoo/llama.jpg',
};

class ZooPage extends StatefulWidget {
  const ZooPage({super.key, required this.api});

  final GameApi api;

  @override
  State<ZooPage> createState() => _ZooPageState();
}

class _ZooPageState extends State<ZooPage> {
  ZooStatus? _zoo;
  Object? _error;
  var _loading = true;
  var _working = false;
  var _page = 0;

  List<_ZooAnimal> _animalsFor(ZooStatus zoo) {
    final names = zoo.animals.isEmpty ? _legacyZooAnimals : zoo.animals;
    return names
        .map((name) => _ZooAnimal(name, _zooAnimalAssets[name]))
        .toList();
  }

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
      final zoo = await widget.api.zoo();
      if (!mounted) return;
      setState(() => _zoo = zoo);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlock() async {
    final zoo = _zoo;
    if (zoo == null || _working) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بازگشایی باغ وحش'),
        content: Text(
          'برای بازگشایی باغ وحش ${persianDigits(zoo.unlockCost)} کوین پرداخت می‌کنی. ادامه می‌دهی؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('بازگشایی'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAction(widget.api.unlockZoo);
  }

  Future<void> _claimDailyReward() =>
      _runAction(widget.api.claimZooDailyReward);

  Future<void> _runAction(Future<ZooActionResult> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final result = await action();
      if (!mounted) return;
      setState(() => _zoo = result.zoo);
      if (result.message.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (error) {
      if (mounted) await showFailure(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('باغ وحش'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_outlined),
          tooltip: 'تازه‌سازی',
        ),
      ],
    ),
    body: ScreenBackground(
      child: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('تلاش دوباره'),
                  ),
                ),
              )
            : _buildZoo(_zoo!),
      ),
    ),
  );

  Widget _buildZoo(ZooStatus zoo) {
    final animals = _animalsFor(zoo);
    final pageCount = (animals.length / 6).ceil();
    final page = _page.clamp(0, pageCount - 1).toInt();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _ZooSummary(zoo: zoo),
        const SizedBox(height: 12),
        if (!zoo.isUnlocked)
          _ZooLockedCard(zoo: zoo, working: _working, onUnlock: _unlock)
        else ...[
          _DailyRewardCard(
            zoo: zoo,
            working: _working,
            onClaim: _claimDailyReward,
          ),
          const SizedBox(height: 14),
          _AnimalGrid(
            animals: animals,
            page: page,
            pageCount: pageCount,
            onPrevious: page > 0 ? () => setState(() => _page -= 1) : null,
            onNext: page + 1 < pageCount
                ? () => setState(() => _page += 1)
                : null,
          ),
        ],
      ],
    );
  }
}

class _ZooSummary extends StatelessWidget {
  const _ZooSummary({required this.zoo});

  final ZooStatus zoo;

  @override
  Widget build(BuildContext context) => Card(
    color: appNavy,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: appGold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.pets_rounded,
              color: Colors.black,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zoo.isUnlocked ? 'باغ وحش شما' : 'باغ وحش قفل است',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'کوین: ${persianDigits(zoo.coins)}  |  سکه: ${persianDigits(zoo.tokens)}',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (zoo.animalCount > 0)
                  Text(
                    '${persianDigits(zoo.animalCount)} حیوان در مجموعه',
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ZooLockedCard extends StatelessWidget {
  const _ZooLockedCard({
    required this.zoo,
    required this.working,
    required this.onUnlock,
  });

  final ZooStatus zoo;
  final bool working;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 52, color: appBurgundy),
          const SizedBox(height: 12),
          const Text(
            'قفس‌های باغ وحش هنوز بسته‌اند',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'با پرداخت ${persianDigits(zoo.unlockCost)} کوین، باغ وحش را برای همیشه باز کن.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: working ? null : onUnlock,
            icon: const Icon(Icons.lock_open_rounded),
            label: Text('بازگشایی با ${persianDigits(zoo.unlockCost)} کوین'),
          ),
        ],
      ),
    ),
  );
}

class _DailyRewardCard extends StatelessWidget {
  const _DailyRewardCard({
    required this.zoo,
    required this.working,
    required this.onClaim,
  });

  final ZooStatus zoo;
  final bool working;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.redeem_outlined, color: appGreen, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'پاداش روزانه',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${persianDigits(zoo.dailyCoinReward)} کوین و ${persianDigits(zoo.dailyTokenReward)} سکه',
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: zoo.canClaimDailyReward && !working ? onClaim : null,
            child: Text(zoo.canClaimDailyReward ? 'دریافت' : 'دریافت شد'),
          ),
        ],
      ),
    ),
  );
}

class _AnimalGrid extends StatelessWidget {
  const _AnimalGrid({
    required this.animals,
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final List<_ZooAnimal> animals;
  final int page;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final start = page * 6;
    final pageAnimals = animals.skip(start).take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'قفس‌ها',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pageAnimals.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .82,
              ),
              itemBuilder: (context, index) =>
                  _AnimalCage(animal: pageAnimals[index]),
            );
          },
        ),
        if (pageCount > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'شش تصویر قبلی',
                ),
                Text(
                  '${persianDigits(page + 1)} از ${persianDigits(pageCount)}',
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'شش تصویر بعدی',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AnimalCage extends StatelessWidget {
  const _AnimalCage({required this.animal});

  final _ZooAnimal animal;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'قفس ${animal.name}',
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: animal.asset == null
                    ? _ZooAnimalArtwork(name: animal.name)
                    : Image.asset(animal.asset!, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  animal.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: appNavy, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 5)],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    animal.asset == null
                        ? _ZooAnimalArtwork(name: animal.name)
                        : Image.asset(animal.asset!, fit: BoxFit.cover),
                    const IgnorePointer(
                      child: CustomPaint(painter: _CageBarsPainter()),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
              color: appNavy,
              child: Text(
                animal.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CageBarsPainter extends CustomPainter {
  const _CageBarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xb8141d26)
      ..strokeWidth = 5;
    for (var x = 10.0; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    canvas.drawLine(Offset(0, 10), Offset(size.width, 10), paint);
    canvas.drawLine(
      Offset(0, size.height - 10),
      Offset(size.width, size.height - 10),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CageBarsPainter oldDelegate) => false;
}

class _ZooAnimal {
  const _ZooAnimal(this.name, this.asset);

  final String name;
  final String? asset;
}

class _ZooAnimalArtwork extends StatelessWidget {
  const _ZooAnimalArtwork({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final aquatic = RegExp(
      'نهنگ|دلفین|کوسه|سفره|اره‌ماهی|شیر دریایی|گراز دریایی|ماهی|بادکنک|اردک|لاک‌پشت',
    ).hasMatch(name);
    final flying = RegExp(
      'عقاب|باز |شاهین|جغد|طاووس|طوطی|توکان|قو|درنا|پلیکان|حواصیل|لک‌لک|بوقیر|کاسکو|عروس هلندی|کلاغ|کرکس|مرغ|بوقلمون',
    ).hasMatch(name);
    final crawling = RegExp(
      'مار|تمساح|مارمولک|کبرا|ایگوانا|آفتاب‌پرست|رتیل|عقرب|قورباغه|وزغ|سمندر|باسیلیسک',
    ).hasMatch(name);
    final icon = aquatic
        ? Icons.water_rounded
        : flying
        ? Icons.air_rounded
        : crawling
        ? Icons.pest_control_rounded
        : Icons.pets_rounded;
    final color = aquatic
        ? const Color(0xffc4eaf5)
        : flying
        ? const Color(0xffd4edcf)
        : crawling
        ? const Color(0xfff1dfae)
        : const Color(0xffd9e3ed);
    return ColoredBox(
      color: color,
      child: Center(child: Icon(icon, size: 62, color: appNavy)),
    );
  }
}
