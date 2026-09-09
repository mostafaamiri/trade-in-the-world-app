import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import 'services/game_api.dart';
import 'ui.dart';

class BusinessProgressPage extends StatefulWidget {
  const BusinessProgressPage({
    super.key,
    required this.api,
    required this.initialBusiness,
    this.matchId,
    this.compact = false,
    this.missionFocus = false,
  });

  final GameApi api;
  final BusinessProgress initialBusiness;
  final String? matchId;
  final bool compact;
  final bool missionFocus;

  @override
  State<BusinessProgressPage> createState() => _BusinessProgressPageState();
}

class _BusinessProgressPageState extends State<BusinessProgressPage> {
  late BusinessProgress _business;
  Timer? _clock;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _business = widget.initialBusiness;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _run(
    Future<BusinessActionResult> Function() action, {
    bool celebrate = false,
  }) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final result = await action();
      if (!mounted) return;
      setState(() => _business = result.business);
      if (celebrate) {
        await _showUpgradeSuccess(result.message);
      } else if (result.message.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (error) {
      if (mounted) await showFailure(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showUpgradeSuccess(String message) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      content: TweenAnimationBuilder<double>(
        tween: Tween(begin: .7, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_stageIcon(_business.stageIcon), color: appGold, size: 68),
            const SizedBox(height: 14),
            Text(
              _business.stageName,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('ادامه'),
        ),
      ],
    ),
  );

  Future<void> _chooseMarket() async {
    final market = await showModalBottomSheet<BusinessMarket>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          itemCount: _business.markets.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = _business.markets[index];
            return ListTile(
              leading: Icon(
                item.unlocked ? Icons.public : Icons.lock_outline,
                color: item.unlocked ? appGreen : Colors.grey,
              ),
              title: Text(item.name),
              subtitle: Text(
                'حمل: ${money(item.shippingCost)} | بازده: ${money(item.revenue)}',
              ),
              onTap: _working ? null : () => Navigator.pop(sheetContext, item),
            );
          },
        ),
      ),
    );
    if (market == null || !mounted) return;
    await _run(
      () => widget.api.startInternationalContract(widget.matchId!, market.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextProgress = _business.isFinalStage
        ? 1.0
        : _requirementProgress(_business.requirements);
    final experienceProgress = _business.experienceForNextLevel == 0
        ? 1.0
        : (_business.experience / _business.experienceForNextLevel).clamp(
            0.0,
            1.0,
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.missionFocus
              ? 'ماموریت‌های روزانه و مرحله‌ای'
              : 'پیشرفت کسب‌وکار',
        ),
      ),
      body: ScreenBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Card(
                color: appNavy,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: appGold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _stageIcon(_business.stageIcon),
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
                                  _business.businessName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_business.stageName} | سطح ${persianDigits(_business.businessStage)}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _ProgressLine(
                        label: _business.isFinalStage
                            ? 'بالاترین مرحله کسب‌وکار'
                            : 'آمادگی برای ${_business.nextStageName}',
                        value: nextProgress,
                        color: appGold,
                      ),
                      const SizedBox(height: 11),
                      _ProgressLine(
                        label:
                            'کوین: ${persianDigits(_business.coins)} | هر برد: ${persianDigits(_business.coinRewardPerWin)} کوین',
                        value: _business.isFinalStage
                            ? 1
                            : (_business.coins / _business.nextStageCost).clamp(
                                0.0,
                                1.0,
                              ),
                        color: appGold,
                      ),
                      const SizedBox(height: 11),
                      _ProgressLine(
                        label:
                            'XP: ${money(_business.experience)} / ${money(_business.experienceForNextLevel)}',
                        value: experienceProgress,
                        color: appGreen,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _DashboardGrid(business: _business),
              const SizedBox(height: 14),
              _UpgradePanel(
                business: _business,
                working: _working,
                onUpgrade: () => _run(
                  () => widget.matchId == null
                      ? widget.api.upgradeBusinessProfile()
                      : widget.api.upgradeBusiness(widget.matchId!),
                  celebrate: true,
                ),
              ),
              if (!widget.compact || widget.missionFocus) ...[
                const SizedBox(height: 16),
                _SectionTitle(
                  icon: Icons.today_outlined,
                  title: 'ماموریت‌های روزانه',
                ),
                const SizedBox(height: 6),
                ..._business.dailyMissions.map(
                  (mission) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DailyMissionTile(
                      mission: mission,
                      working: _working,
                      onClaim: () => _run(
                        () => widget.api.claimDailyBusinessMission(mission.id),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SectionTitle(
                  icon: Icons.flag_outlined,
                  title: 'ماموریت‌های مرحله‌ای',
                ),
                const SizedBox(height: 6),
                ..._business.missions.map(
                  (mission) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MissionTile(
                      mission: mission,
                      working: _working,
                      onClaim: () => _run(
                        () => widget.matchId == null
                            ? widget.api.claimBusinessMissionProfile(mission.id)
                            : widget.api.claimBusinessMission(
                                widget.matchId!,
                                mission.id,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
              if (!widget.compact) ...[
                const SizedBox(height: 14),
                _SectionTitle(
                  icon: Icons.verified_outlined,
                  title: 'قابلیت‌های بازشده',
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _business.features
                      .map(
                        (item) => Chip(
                          avatar: const Icon(
                            Icons.check_circle_outline,
                            size: 17,
                          ),
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                _SectionTitle(
                  icon: Icons.domain_add_outlined,
                  title: 'دارایی‌ها',
                ),
                const SizedBox(height: 6),
                ..._business.buildingOptions
                    .where((item) => item.unlocked)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BuildingTile(
                          building: item,
                          working: _working,
                          onBuild: () => _run(
                            () => widget.api.buildBusinessAsset(
                              widget.matchId!,
                              item.type,
                            ),
                          ),
                        ),
                      ),
                    ),
                if (_business.productionAvailable) ...[
                  const SizedBox(height: 8),
                  _SectionTitle(
                    icon: Icons.factory_outlined,
                    title: 'خط تولید',
                  ),
                  const SizedBox(height: 6),
                  _ProductionPanel(
                    business: _business,
                    working: _working,
                    onMaterials: () => _run(
                      () => widget.api.buyBusinessMaterials(widget.matchId!),
                    ),
                    onProduce: () => _run(
                      () => widget.api.produceBusinessGoods(widget.matchId!),
                    ),
                    onSell: () => _run(
                      () => widget.api.sellBusinessGoods(widget.matchId!),
                    ),
                  ),
                ],
                if (_business.businessStage >= 7) ...[
                  const SizedBox(height: 16),
                  _SectionTitle(
                    icon: Icons.language_outlined,
                    title: 'بازار خارجی',
                  ),
                  const SizedBox(height: 6),
                  _InternationalPanel(
                    business: _business,
                    working: _working,
                    onStart: _chooseMarket,
                    onComplete: (contract) => _run(
                      () => widget.api.completeInternationalContract(
                        widget.matchId!,
                        contract.id,
                      ),
                    ),
                  ),
                ],
                if (_business.businessStage >= 8) ...[
                  const SizedBox(height: 16),
                  _SectionTitle(
                    icon: Icons.account_balance_outlined,
                    title: 'سرمایه‌گذاری هلدینگ',
                  ),
                  const SizedBox(height: 6),
                  _InvestmentPanel(
                    business: _business,
                    working: _working,
                    onStart: () => _run(
                      () => widget.api.startBusinessInvestment(widget.matchId!),
                    ),
                    onClaim: (investment) => _run(
                      () => widget.api.claimBusinessInvestment(
                        widget.matchId!,
                        investment.id,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.business});

  final BusinessProgress business;

  @override
  Widget build(BuildContext context) {
    final rank = jsonInt(business.dashboard['rank']);
    final items = [
      _DashboardItem(
        Icons.monetization_on_outlined,
        'کوین',
        persianDigits(business.coins),
      ),
      _DashboardItem(
        Icons.account_balance_wallet_outlined,
        'سرمایه',
        money(business.capital),
      ),
      _DashboardItem(
        Icons.workspace_premium_outlined,
        'اعتبار',
        money(business.reputation),
      ),
      _DashboardItem(Icons.savings_outlined, 'درآمد', money(business.revenue)),
      _DashboardItem(
        Icons.receipt_long_outlined,
        'هزینه',
        money(business.expenses),
      ),
      _DashboardItem(
        Icons.trending_up_outlined,
        'سود خالص',
        money(business.profit),
      ),
      _DashboardItem(
        Icons.inventory_2_outlined,
        'ارزش دارایی',
        money(business.totalAssets),
      ),
      _DashboardItem(
        Icons.handshake_outlined,
        'معاملات',
        persianDigits(business.dashboard['successfulTrades'] ?? 0),
      ),
      _DashboardItem(
        Icons.location_city_outlined,
        'شهرها',
        persianDigits(business.dashboard['cities'] ?? 0),
      ),
      _DashboardItem(
        Icons.warehouse_outlined,
        'انبارها',
        persianDigits(business.dashboard['warehouses'] ?? 0),
      ),
      _DashboardItem(
        Icons.factory_outlined,
        'کارخانه‌ها',
        persianDigits(business.dashboard['factories'] ?? 0),
      ),
      _DashboardItem(
        Icons.business_outlined,
        'شرکت‌ها',
        persianDigits(business.dashboard['companies'] ?? 0),
      ),
      _DashboardItem(
        Icons.emoji_events_outlined,
        'رتبه',
        rank > 0 ? persianDigits(rank) : '—',
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.7,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _DashboardMetric(item: items[index]),
    );
  }
}

class _DashboardItem {
  const _DashboardItem(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({required this.item});

  final _DashboardItem item;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xffd4dce7)),
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
    ),
    child: Row(
      children: [
        Icon(item.icon, color: appNavy, size: 20),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: const TextStyle(fontSize: 11)),
              Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _UpgradePanel extends StatelessWidget {
  const _UpgradePanel({
    required this.business,
    required this.working,
    required this.onUpgrade,
  });

  final BusinessProgress business;
  final bool working;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                business.isFinalStage
                    ? Icons.emoji_events_rounded
                    : _stageIcon(business.nextStageIcon),
                color: appGold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  business.isFinalStage
                      ? 'هلدینگ تو در بالاترین مرحله است'
                      : 'ارتقا به ${business.nextStageName}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (!business.isFinalStage) ...[
            const SizedBox(height: 12),
            ...business.requirements.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Icon(
                      item.complete
                          ? Icons.check_circle
                          : Icons.cancel_outlined,
                      color: item.complete ? appGreen : appRed,
                      size: 20,
                    ),
                    const SizedBox(width: 7),
                    Expanded(child: Text(item.label)),
                    Text(
                      '${_requirementValue(item)} / ${_requirementValue(item, required: true)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Text(
              'هزینه ارتقا: ${persianDigits(business.nextStageCost)} کوین',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 9),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: appGold,
                foregroundColor: Colors.black,
              ),
              onPressed: business.canUpgrade && !working ? onUpgrade : null,
              icon: const Icon(Icons.upgrade_outlined),
              label: const Text('ارتقا کسب‌وکار'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.mission,
    required this.working,
    required this.onClaim,
  });

  final BusinessMission mission;
  final bool working;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                mission.claimed
                    ? Icons.verified
                    : mission.complete
                    ? Icons.redeem_outlined
                    : Icons.radio_button_unchecked,
                color: mission.claimed || mission.complete
                    ? appGreen
                    : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text('مرحله ${persianDigits(mission.stage)}'),
            ],
          ),
          const SizedBox(height: 5),
          Text(mission.description),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: (mission.current / mission.target).clamp(0.0, 1.0),
            minHeight: 7,
            borderRadius: BorderRadius.circular(4),
            color: mission.complete ? appGreen : appGold,
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${persianDigits(mission.current)} / ${persianDigits(mission.target)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (!mission.claimed)
                FilledButton.icon(
                  onPressed: mission.complete && !working ? onClaim : null,
                  icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                  label: const Text('دریافت'),
                )
              else
                const Text('دریافت شد', style: TextStyle(color: appGreen)),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DailyMissionTile extends StatelessWidget {
  const _DailyMissionTile({
    required this.mission,
    required this.working,
    required this.onClaim,
  });

  final DailyBusinessMission mission;
  final bool working;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                mission.claimed
                    ? Icons.verified
                    : mission.complete
                    ? Icons.redeem_outlined
                    : Icons.today_outlined,
                color: mission.claimed || mission.complete ? appGreen : appNavy,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(persianDigits(mission.issuedOn)),
            ],
          ),
          const SizedBox(height: 5),
          Text(mission.description),
          const SizedBox(height: 7),
          Text(
            'پاداش: ${persianDigits(mission.coinReward)} کوین | ${money(mission.capitalReward)} سرمایه | ${persianDigits(mission.experienceReward)} XP',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: (mission.current / mission.target).clamp(0.0, 1.0),
            minHeight: 7,
            borderRadius: BorderRadius.circular(4),
            color: mission.complete ? appGreen : appGold,
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${persianDigits(mission.current)} / ${persianDigits(mission.target)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (!mission.claimed)
                FilledButton.icon(
                  onPressed: mission.complete && !working ? onClaim : null,
                  icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                  label: const Text('دریافت'),
                )
              else
                const Text('دریافت شد', style: TextStyle(color: appGreen)),
            ],
          ),
        ],
      ),
    ),
  );
}

class _BuildingTile extends StatelessWidget {
  const _BuildingTile({
    required this.building,
    required this.working,
    required this.onBuild,
  });

  final BusinessBuildingOption building;
  final bool working;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(_buildingIcon(building.type), color: appNavy),
      title: Text(building.title),
      subtitle: Text(
        'تعداد: ${persianDigits(building.count)} | هزینه: ${money(building.cost)}',
      ),
      trailing: IconButton(
        tooltip: 'ساخت ${building.title}',
        onPressed: building.affordable && !working ? onBuild : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ),
  );
}

class _ProductionPanel extends StatelessWidget {
  const _ProductionPanel({
    required this.business,
    required this.working,
    required this.onMaterials,
    required this.onProduce,
    required this.onSell,
  });

  final BusinessProgress business;
  final bool working;
  final VoidCallback onMaterials;
  final VoidCallback onProduce;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'مواد اولیه: ${persianDigits(business.rawMaterials)} | محصول آماده: ${persianDigits(business.producedGoods)}',
          ),
          const SizedBox(height: 4),
          Text(
            'قیمت خرید فعلی: ${money(business.materialUnitPrice)} هر واحد | ${money(business.materialBatchCost)} هر نوبت',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: working ? null : onMaterials,
                icon: const Icon(Icons.shopping_basket_outlined),
                label: const Text('مواد اولیه'),
              ),
              OutlinedButton.icon(
                onPressed: working ? null : onProduce,
                icon: const Icon(Icons.precision_manufacturing_outlined),
                label: const Text('تولید'),
              ),
              FilledButton.icon(
                onPressed: working ? null : onSell,
                icon: const Icon(Icons.sell_outlined),
                label: const Text('فروش محصول'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _InternationalPanel extends StatelessWidget {
  const _InternationalPanel({
    required this.business,
    required this.working,
    required this.onStart,
    required this.onComplete,
  });

  final BusinessProgress business;
  final bool working;
  final VoidCallback onStart;
  final ValueChanged<BusinessContract> onComplete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: working ? null : onStart,
            icon: const Icon(Icons.add_road_outlined),
            label: const Text('ثبت قرارداد خارجی'),
          ),
          if (business.contracts.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...business.contracts.reversed.map(
              (contract) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  contract.status == 'completed'
                      ? Icons.check_circle
                      : Icons.local_shipping_outlined,
                  color: contract.status == 'completed' ? appGreen : appNavy,
                ),
                title: Text(contract.title),
                subtitle: Text(
                  contract.status == 'completed'
                      ? 'تکمیل‌شده'
                      : _availabilityText(contract.availableAt),
                ),
                trailing:
                    contract.status == 'in_progress' &&
                        _isAvailable(contract.availableAt)
                    ? IconButton(
                        tooltip: 'تکمیل قرارداد',
                        onPressed: working ? null : () => onComplete(contract),
                        icon: const Icon(Icons.task_alt, color: appGreen),
                      )
                    : null,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _InvestmentPanel extends StatelessWidget {
  const _InvestmentPanel({
    required this.business,
    required this.working,
    required this.onStart,
    required this.onClaim,
  });

  final BusinessProgress business;
  final bool working;
  final VoidCallback onStart;
  final ValueChanged<BusinessInvestment> onClaim;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: working ? null : onStart,
            icon: const Icon(Icons.add_chart_outlined),
            label: const Text('سرمایه‌گذاری جدید'),
          ),
          if (business.investments.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...business.investments.reversed.map(
              (investment) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  investment.status == 'claimed'
                      ? Icons.verified
                      : Icons.account_balance_outlined,
                  color: investment.status == 'claimed' ? appGreen : appNavy,
                ),
                title: Text(investment.title),
                subtitle: Text(
                  investment.status == 'claimed'
                      ? 'بازده دریافت شد'
                      : _availabilityText(investment.availableAt),
                ),
                trailing:
                    investment.status == 'active' &&
                        _isAvailable(investment.availableAt)
                    ? IconButton(
                        tooltip: 'دریافت بازده',
                        onPressed: working ? null : () => onClaim(investment),
                        icon: const Icon(
                          Icons.download_done_outlined,
                          color: appGreen,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: appNavy),
      const SizedBox(width: 7),
      Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
    ],
  );
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white)),
      const SizedBox(height: 5),
      LinearProgressIndicator(
        value: value,
        minHeight: 8,
        borderRadius: BorderRadius.circular(4),
        backgroundColor: Colors.white24,
        color: color,
      ),
    ],
  );
}

double _requirementProgress(List<BusinessRequirement> requirements) {
  if (requirements.isEmpty) return 1;
  final total = requirements.fold<double>(
    0,
    (sum, item) => sum + (item.current / item.required).clamp(0.0, 1.0),
  );
  return total / requirements.length;
}

bool _isAvailable(DateTime? date) =>
    date != null && !DateTime.now().isBefore(date);

String _availabilityText(DateTime? date) {
  if (date == null) return 'در حال بررسی';
  final remaining = date.difference(DateTime.now());
  if (remaining <= Duration.zero) {
    return 'آماده دریافت';
  }
  return 'آماده‌سازی: ${persianDigits(remaining.inSeconds)} ثانیه';
}

String _requirementValue(BusinessRequirement item, {bool required = false}) {
  final value = required ? item.required : item.current;
  return item.id == 'capital' ? money(value) : persianDigits(value);
}

IconData _stageIcon(String key) => switch (key) {
  'storefront' => Icons.storefront,
  'store' => Icons.store,
  'warehouse' => Icons.warehouse,
  'business' => Icons.business,
  'factory' => Icons.factory,
  'precision_manufacturing' => Icons.precision_manufacturing,
  'public' => Icons.public,
  'account_balance' => Icons.account_balance,
  _ => Icons.storefront,
};

IconData _buildingIcon(String key) => switch (key) {
  'branch' => Icons.store_mall_directory_outlined,
  'warehouse' => Icons.warehouse_outlined,
  'company' => Icons.business_outlined,
  'factory' => Icons.factory_outlined,
  'industrialCompany' => Icons.precision_manufacturing_outlined,
  'internationalOffice' => Icons.public_outlined,
  'logistics' => Icons.local_shipping_outlined,
  'holding' => Icons.account_balance_outlined,
  _ => Icons.domain_outlined,
};
