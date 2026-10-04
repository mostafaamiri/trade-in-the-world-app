import 'dart:async';

import 'package:flutter/material.dart';

import 'life_stages.dart';
import 'services/game_api.dart';
import 'ui.dart';

class LifeStagesPage extends StatefulWidget {
  const LifeStagesPage({super.key, required this.api, this.initialTab = 0});

  final GameApi api;
  final int initialTab;

  @override
  State<LifeStagesPage> createState() => _LifeStagesPageState();
}

class _LifeStagesPageState extends State<LifeStagesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<LifeStagesRoom> _rooms = const [];
  LifeStagesRoom? _myRoom;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final results = await Future.wait([
        widget.api.lifeStagesRooms(),
        widget.api.myLifeStagesRoom(),
      ]);
      if (!mounted) return;
      setState(() {
        _rooms = results[0] as List<LifeStagesRoom>;
        _myRoom = results[1] as LifeStagesRoom?;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openRoom(LifeStagesRoom room) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            LifeStagesRoomPage(api: widget.api, roomId: room.roomId),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _createRoom() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _RoomNameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final room = await widget.api.createLifeStagesRoom(name.trim());
      if (mounted) await _openRoom(room);
    } catch (error) {
      if (mounted) await showFailure(context, error);
    }
  }

  Future<void> _joinByCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _RoomCodeDialog(),
    );
    if (code == null || code.trim().isEmpty) return;
    try {
      final room = await widget.api.joinLifeStagesRoom(code);
      if (mounted) await _openRoom(room);
    } catch (error) {
      if (mounted) await showFailure(context, error);
    }
  }

  Future<void> _joinRoom(LifeStagesRoom room) async {
    try {
      final joined = await widget.api.joinLifeStagesRoom(room.roomCode);
      if (mounted) await _openRoom(joined);
    } catch (error) {
      if (mounted) await showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('مراحل زندگی'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'ساخت اتاق'),
          Tab(text: 'مسابقات'),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'بروزرسانی',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: ScreenBackground(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _CreateRoomTab(
                  myRoom: _myRoom,
                  onCreate: _createRoom,
                  onOpen: _openRoom,
                ),
                _ContestRoomsTab(
                  rooms: _rooms,
                  onOpen: _openRoom,
                  onJoin: _joinRoom,
                  onJoinByCode: _joinByCode,
                  onRefresh: _reload,
                ),
              ],
            ),
    ),
  );
}

class _CreateRoomTab extends StatelessWidget {
  const _CreateRoomTab({
    required this.myRoom,
    required this.onCreate,
    required this.onOpen,
  });

  final LifeStagesRoom? myRoom;
  final VoidCallback onCreate;
  final ValueChanged<LifeStagesRoom> onOpen;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const _LifeStagesIntro(),
      const SizedBox(height: 14),
      if (myRoom != null) ...[
        const Text(
          'اتاق فعال شما',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        _RoomTile(room: myRoom!, onTap: () => onOpen(myRoom!)),
        const SizedBox(height: 14),
      ],
      FilledButton.icon(
        onPressed: myRoom == null ? onCreate : null,
        icon: const Icon(Icons.add_home_work_outlined),
        label: const Text('ساخت اتاق مراحل زندگی'),
      ),
      const SizedBox(height: 12),
      const Text(
        'اتاق با کد شش‌نویسه ساخته می‌شود. بازی فقط وقتی شروع می‌شود که پنج بازیکن، پنج نقش متفاوت را انتخاب کرده باشند.',
        style: TextStyle(color: Color(0xff425466), height: 1.5),
      ),
    ],
  );
}

class _ContestRoomsTab extends StatelessWidget {
  const _ContestRoomsTab({
    required this.rooms,
    required this.onOpen,
    required this.onJoin,
    required this.onJoinByCode,
    required this.onRefresh,
  });

  final List<LifeStagesRoom> rooms;
  final ValueChanged<LifeStagesRoom> onOpen;
  final ValueChanged<LifeStagesRoom> onJoin;
  final VoidCallback onJoinByCode;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: rooms.isEmpty ? 2 : rooms.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return OutlinedButton.icon(
            onPressed: onJoinByCode,
            icon: const Icon(Icons.key_rounded),
            label: const Text('ورود به مسابقه با کد اتاق'),
          );
        }
        if (rooms.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 36),
            child: Center(child: Text('فعلاً اتاق بازی در دسترس نیست.')),
          );
        }
        final room = rooms[index - 1];
        final isMember = room.players.any((player) => player.isMe);
        return _RoomTile(
          room: room,
          onTap: isMember ? () => onOpen(room) : null,
          trailing: isMember
              ? const Icon(Icons.arrow_back_ios_new_rounded, size: 18)
              : room.status == 'lobby'
              ? FilledButton(
                  onPressed: () => onJoin(room),
                  child: const Text('پیوستن'),
                )
              : const Text('در حال بازی'),
        );
      },
    ),
  );
}

class _LifeStagesIntro extends StatelessWidget {
  const _LifeStagesIntro();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xeefeffff),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xffd6e2ec)),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: appGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.diversity_3_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'یک شهر، پنج نقش، یک آینده',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 4),
              Text(
                'در هر مرحله از قدرت نقش خود برای ساختن زندگی گروه استفاده کن.',
                style: TextStyle(height: 1.45),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, this.onTap, this.trailing});

  final LifeStagesRoom room;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      leading: CircleAvatar(
        backgroundColor: room.status == 'active' ? appGreen : appGold,
        child: Icon(
          room.status == 'active'
              ? Icons.play_arrow_rounded
              : Icons.groups_rounded,
          color: Colors.white,
        ),
      ),
      title: Text(
        room.name,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${lifeStagesStatusTitle(room.status)} | ${persianDigits(room.playerCount)} از ${persianDigits(room.maxPlayers)} نفر | کد ${room.roomCode}',
      ),
      trailing: trailing,
    ),
  );
}

class LifeStagesRoomPage extends StatefulWidget {
  const LifeStagesRoomPage({
    super.key,
    required this.api,
    required this.roomId,
  });

  final GameApi api;
  final String roomId;

  @override
  State<LifeStagesRoomPage> createState() => _LifeStagesRoomPageState();
}

class _LifeStagesRoomPageState extends State<LifeStagesRoomPage> {
  LifeStagesRoom? _room;
  Timer? _refreshTimer;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    try {
      final room = await widget.api.lifeStagesRoom(widget.roomId);
      if (mounted) {
        setState(() {
          _room = room;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted || silent) return;
      setState(() => _loading = false);
      await showFailure(context, error);
    }
  }

  Future<void> _run(Future<LifeStagesRoom> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final room = await action();
      if (mounted) setState(() => _room = room);
    } catch (error) {
      if (mounted) await showFailure(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _chooseRole() async {
    final room = _room;
    if (room == null) return;
    final selected = await showModalBottomSheet<LifeStagesRole>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _RolePicker(room: room),
    );
    if (selected != null) {
      await _run(
        () => widget.api.selectLifeStagesRole(room.roomId, selected.id),
      );
    }
  }

  Future<void> _leave() async {
    final room = _room;
    if (room == null) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خروج از اتاق'),
        content: const Text('پیش از شروع بازی، از اتاق خارج می‌شوی.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (leave != true) return;
    try {
      await widget.api.leaveLifeStagesRoom(room.roomId);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) await showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    return Scaffold(
      appBar: AppBar(
        title: const Text('اتاق مراحل زندگی'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'بروزرسانی',
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (room?.status == 'lobby')
            IconButton(
              onPressed: _leave,
              tooltip: 'خروج از اتاق',
              icon: const Icon(Icons.exit_to_app_rounded),
            ),
        ],
      ),
      body: ScreenBackground(
        child: _loading || room == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                  children: [
                    _RoomHeader(room: room),
                    const SizedBox(height: 14),
                    if (room.status == 'lobby') ...[
                      _LobbyPanel(
                        room: room,
                        working: _working,
                        onChooseRole: _chooseRole,
                        onStart: () => _run(
                          () => widget.api.startLifeStagesRoom(room.roomId),
                        ),
                      ),
                    ] else ...[
                      _ActiveStagePanel(
                        room: room,
                        working: _working,
                        onUsePower: (power) => _run(
                          () => widget.api.useLifeStagesPower(
                            room.roomId,
                            power.id,
                          ),
                        ),
                        onNextStage: () => _run(
                          () => widget.api.nextLifeStagesStage(room.roomId),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _PlayersPanel(room: room),
                    const SizedBox(height: 14),
                    _EventsPanel(events: room.events),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.room});

  final LifeStagesRoom room;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xfefeffff),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xffcedfe9)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_tree_outlined, color: appGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                room.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _StatusChip(status: room.status),
          ],
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(icon: Icons.key_rounded, label: 'کد ${room.roomCode}'),
            _InfoChip(
              icon: Icons.people_alt_outlined,
              label:
                  '${persianDigits(room.playerCount)} / ${persianDigits(room.maxPlayers)} نفر',
            ),
            _InfoChip(
              icon: Icons.stars_outlined,
              label: '${persianDigits(room.teamPoints)} امتیاز',
            ),
          ],
        ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: status == 'active'
          ? const Color(0xffd9f3e8)
          : const Color(0xffffefc4),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      lifeStagesStatusTitle(status),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xffedf4f7),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: appNavy),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _LobbyPanel extends StatelessWidget {
  const _LobbyPanel({
    required this.room,
    required this.working,
    required this.onChooseRole,
    required this.onStart,
  });

  final LifeStagesRoom room;
  final bool working;
  final VoidCallback onChooseRole;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final me = room.me;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'آماده‌سازی گروه',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            const Text('نقش‌ها تکراری نیستند و هر نقش سه قدرت دارد.'),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: working ? null : onChooseRole,
              icon: const Icon(Icons.badge_outlined),
              label: Text(
                me?.role == null
                    ? 'انتخاب نقش من'
                    : 'نقش من: ${me!.role!.title}',
              ),
            ),
            const SizedBox(height: 12),
            if (room.isOwner)
              FilledButton.icon(
                onPressed: room.canStart && !working ? onStart : null,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('شروع بازی برای پنج نفر'),
              )
            else
              const Text(
                'پس از کامل‌شدن گروه، سازندهٔ اتاق بازی را شروع می‌کند.',
                style: TextStyle(color: Color(0xff425466)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveStagePanel extends StatelessWidget {
  const _ActiveStagePanel({
    required this.room,
    required this.working,
    required this.onUsePower,
    required this.onNextStage,
  });

  final LifeStagesRoom room;
  final bool working;
  final ValueChanged<LifeStagesPower> onUsePower;
  final VoidCallback onNextStage;

  @override
  Widget build(BuildContext context) {
    final me = room.me;
    final finished = room.status == 'completed';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              finished
                  ? 'نتیجهٔ مراحل زندگی'
                  : 'مرحلهٔ ${persianDigits(room.currentStageIndex + 1)}: ${room.currentStage.title}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              finished
                  ? 'گروه این مسابقه را با ${persianDigits(room.teamPoints)} امتیاز به پایان رساند.'
                  : room.currentStage.description,
            ),
            if (!finished) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (room.currentStageIndex + 1) / room.stages.length,
                color: appGreen,
                backgroundColor: const Color(0xffd9e7ec),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
              if (me?.role != null) ...[
                Text(
                  'قدرت‌های ${me!.role!.title}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (final power in me.role!.powers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: working || me.usedPowerIds.contains(power.id)
                            ? null
                            : () => onUsePower(power),
                        icon: Icon(
                          me.usedPowerIds.contains(power.id)
                              ? Icons.check_circle_outline
                              : Icons.bolt_outlined,
                        ),
                        label: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(power.title),
                            Text(
                              power.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              if (room.isOwner) ...[
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: working ? null : onNextStage,
                  icon: Icon(
                    room.currentStageIndex == room.stages.length - 1
                        ? Icons.flag_outlined
                        : Icons.arrow_back_rounded,
                  ),
                  label: Text(
                    room.currentStageIndex == room.stages.length - 1
                        ? 'پایان مسابقه'
                        : 'مرحلهٔ بعدی',
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayersPanel extends StatelessWidget {
  const _PlayersPanel({required this.room});

  final LifeStagesRoom room;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'گروه پنج‌نفره',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < room.maxPlayers; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: index < room.players.length
                  ? _PlayerRow(player: room.players[index])
                  : const _EmptySeat(),
            ),
        ],
      ),
    ),
  );
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player});

  final LifeStagesPlayer player;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: BoxDecoration(
      color: player.isMe ? const Color(0xffe3f5ed) : const Color(0xfff3f6f7),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        AvatarCircle(
          avatarId: player.avatarId,
          size: 34,
          borderColor: player.isMe ? appGreen : appGold,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            player.displayName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          player.role?.title ?? 'در انتظار نقش',
          style: TextStyle(
            color: player.role == null ? const Color(0xff7a5c00) : appNavy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat();

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(
        color: const Color(0xffc5d2d8),
        style: BorderStyle.solid,
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text('جای خالی برای بازیکن'),
  );
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({required this.events});

  final List<LifeStagesEvent> events;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'رویدادهای گروه',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Text('هنوز رویدادی ثبت نشده است.')
          else
            for (final event in events.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      event.type == 'power' ? Icons.bolt_rounded : Icons.circle,
                      size: event.type == 'power' ? 19 : 10,
                      color: event.type == 'power' ? appGold : appGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            event.message,
                            style: const TextStyle(fontSize: 12, height: 1.35),
                          ),
                        ],
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

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.room});

  final LifeStagesRoom room;

  @override
  Widget build(BuildContext context) {
    final usedRoleIds = room.players
        .where((player) => !player.isMe && player.roleId != null)
        .map((player) => player.roleId!)
        .toSet();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
          children: [
            const Text(
              'انتخاب نقش',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'هر نقش فقط یک‌بار قابل انتخاب است و سه قدرت ویژه دارد.',
            ),
            const SizedBox(height: 12),
            for (final role in room.roles)
              ListTile(
                enabled: !usedRoleIds.contains(role.id),
                onTap: usedRoleIds.contains(role.id)
                    ? null
                    : () => Navigator.pop(context, role),
                leading: CircleAvatar(
                  backgroundColor: usedRoleIds.contains(role.id)
                      ? Colors.grey.shade300
                      : const Color(0xffe3f1ed),
                  child: const Icon(Icons.badge_outlined, color: appGreen),
                ),
                title: Text(
                  role.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  role.powers.map((power) => power.title).join(' | '),
                ),
                trailing: usedRoleIds.contains(role.id)
                    ? const Text('انتخاب شده')
                    : const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoomNameDialog extends StatefulWidget {
  const _RoomNameDialog();

  @override
  State<_RoomNameDialog> createState() => _RoomNameDialogState();
}

class _RoomNameDialogState extends State<_RoomNameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ساخت اتاق مراحل زندگی'),
    content: TextField(
      controller: _name,
      autofocus: true,
      maxLength: 60,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => Navigator.pop(context, _name.text.trim()),
      decoration: const InputDecoration(labelText: 'نام گروه یا اتاق'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _name.text.trim()),
        child: const Text('ساخت اتاق'),
      ),
    ],
  );
}

class _RoomCodeDialog extends StatefulWidget {
  const _RoomCodeDialog();

  @override
  State<_RoomCodeDialog> createState() => _RoomCodeDialogState();
}

class _RoomCodeDialogState extends State<_RoomCodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ورود با کد اتاق'),
    content: TextField(
      controller: _code,
      autofocus: true,
      maxLength: 6,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => Navigator.pop(context, _code.text.trim()),
      decoration: const InputDecoration(labelText: 'کد شش‌نویسهٔ اتاق'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _code.text.trim()),
        child: const Text('پیوستن'),
      ),
    ],
  );
}
