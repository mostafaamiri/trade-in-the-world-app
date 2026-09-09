import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'business_progress_page.dart';
import 'game_page.dart';
import 'models.dart';
import 'services/game_api.dart';
import 'services/jalali_date.dart';
import 'services/notification_service.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  final api = await GameApi.create();
  runApp(TradeInTheWorldApp(api: api));
}

class TradeInTheWorldApp extends StatelessWidget {
  const TradeInTheWorldApp({super.key, required this.api});

  final GameApi api;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'تجارت در جهان',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: appGreen),
      scaffoldBackgroundColor: const Color(0xfff3f6f5),
      appBarTheme: const AppBarTheme(
        backgroundColor: appNavy,
        foregroundColor: Colors.white,
      ),
      cardTheme: const CardThemeData(elevation: 2, margin: EdgeInsets.zero),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: AppRoot(api: api),
    ),
  );
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.api});

  final GameApi api;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  PlayerProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final startedAt = DateTime.now();
    if (!widget.api.hasSession) {
      await _finishSplash(startedAt);
      return;
    }
    try {
      _profile = await widget.api.profile();
      unawaited(NotificationService.sync(widget.api));
    } catch (_) {
      await widget.api.clearSession();
    }
    await _finishSplash(startedAt);
  }

  Future<void> _finishSplash(DateTime startedAt) async {
    final remaining =
        const Duration(seconds: 30) - DateTime.now().difference(startedAt);
    if (!remaining.isNegative) await Future<void>.delayed(remaining);
    if (mounted) setState(() => _loading = false);
  }

  void _onProfile(PlayerProfile profile) {
    setState(() => _profile = profile);
    unawaited(NotificationService.sync(widget.api));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SplashPage(loading: true);
    if (_profile == null)
      return ProfilePage(api: widget.api, onSaved: _onProfile);
    return HomePage(
      api: widget.api,
      profile: _profile!,
      onProfileChanged: _onProfile,
      onAccountDeleted: () => setState(() => _profile = null),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.loading = false});

  final bool loading;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/business-game-background.png',
          fit: BoxFit.cover,
        ),
        const ColoredBox(color: Color(0x33000000)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  size: 74,
                  color: appGold,
                ),
                const SizedBox(height: 18),
                const Text(
                  'تجارت در جهان',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 26),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) =>
                      _SplashProgressPanel(progress: _controller.value),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _SplashProgressPanel extends StatelessWidget {
  const _SplashProgressPanel({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      height: 196,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _SplashHandshakeArtwork(),
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x24071226)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: Column(
              children: [
                const Spacer(),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  color: appGold,
                  backgroundColor: const Color(0xb2FFFFFF),
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 9),
                Text(
                  '${persianDigits((progress * 100).floor())}٪',
                  style: const TextStyle(
                    color: appGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
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

class _SplashHandshakeArtwork extends StatelessWidget {
  const _SplashHandshakeArtwork();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff16839a), Color(0xff07556a), Color(0xff122550)],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -58,
          right: -20,
          child: Transform.rotate(
            angle: -.28,
            child: Container(
              width: 148,
              height: 132,
              decoration: BoxDecoration(
                color: const Color(0xfff0d77f).withValues(alpha: .72),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ),
        Positioned(
          top: 5,
          left: -24,
          child: Transform.rotate(
            angle: -.38,
            child: Container(
              width: 116,
              height: 104,
              decoration: BoxDecoration(
                color: const Color(0xff1b6582),
                border: Border.all(color: const Color(0x99FFFFFF), width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: -22,
          child: Transform.rotate(
            angle: .42,
            child: Container(
              width: 116,
              height: 104,
              decoration: BoxDecoration(
                color: const Color(0xff1b6582),
                border: Border.all(color: const Color(0x99FFFFFF), width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const Center(
          child: Icon(
            Icons.handshake_rounded,
            color: Color(0xffffdf87),
            size: 112,
            shadows: [Shadow(color: Color(0xa8001028), blurRadius: 12)],
          ),
        ),
      ],
    ),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.api,
    required this.onSaved,
    this.initial,
  });

  final GameApi api;
  final ValueChanged<PlayerProfile> onSaved;
  final PlayerProfile? initial;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _name;
  String _avatar = 'merchant_purple';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _avatar = widget.initial?.avatarId ?? _avatar;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 3) {
      await showFailure(context, 'نام و نام خانوادگی را کامل وارد کن.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final profile = widget.initial == null
          ? await widget.api.createGuest(_name.text.trim(), _avatar)
          : await widget.api.updateProfile(_name.text.trim(), _avatar);
      widget.onSaved(profile);
      if (mounted && widget.initial != null) Navigator.pop(context);
    } catch (error) {
      if (mounted) await showFailure(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.initial == null
        ? null
        : AppBar(title: const Text('ویرایش حساب کاربری')),
    body: ScreenBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'حساب بازرگان',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'نام و نام خانوادگی و تصویر بازرگان خود را انتخاب کن.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _name,
                        maxLength: 80,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'نام و نام خانوادگی',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'تصویر بازرگان',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: avatars.keys
                            .map(
                              (id) => InkWell(
                                borderRadius: BorderRadius.circular(40),
                                onTap: () => setState(() => _avatar = id),
                                child: AvatarCircle(
                                  avatarId: id,
                                  size: 64,
                                  borderColor: _avatar == id
                                      ? appRed
                                      : Colors.transparent,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _save,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          _submitting
                              ? 'در حال ذخیره...'
                              : widget.initial == null
                              ? 'ورود به بازی'
                              : 'ذخیره تغییرات',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.profile,
    required this.onProfileChanged,
    required this.onAccountDeleted,
  });

  final GameApi api;
  final PlayerProfile profile;
  final ValueChanged<PlayerProfile> onProfileChanged;
  final VoidCallback onAccountDeleted;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _hasUpdate = false;
  String _version = '۰.۴.۰';
  BusinessProgress? _business;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    try {
      final business = await widget.api.business();
      if (mounted) setState(() => _business = business);
    } catch (_) {}
  }

  Future<void> _openLevel() async {
    if (_business == null) await _loadBusiness();
    if (!mounted) return;
    final business = _business;
    if (business == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('دریافت سطح و کوین ناموفق بود.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BusinessProgressPage(
          api: widget.api,
          initialBusiness: business,
          compact: true,
        ),
      ),
    );
    if (mounted) _loadBusiness();
  }

  Future<void> _openMissions() async {
    if (_business == null) await _loadBusiness();
    if (!mounted) {
      return;
    }
    final business = _business;
    if (business == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('دریافت ماموریت‌ها ناموفق بود.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BusinessProgressPage(
          api: widget.api,
          initialBusiness: business,
          compact: true,
          missionFocus: true,
        ),
      ),
    );
    if (mounted) {
      _loadBusiness();
    }
  }

  Future<void> _checkUpdate() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/public/downloads/trade-in-the-world/metadata'),
      );
      if (response.statusCode != 200) return;
      final data = (jsonDecode(response.body) as Map).cast<String, dynamic>();
      if (mounted)
        setState(() {
          _version = persianDigits(package.version);
          _hasUpdate =
              jsonInt(data['versionCode']) > int.tryParse(package.buildNumber)!;
        });
    } catch (_) {}
  }

  Future<void> _openMatch(String matchId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamePage(api: widget.api, matchId: matchId),
      ),
    );
    if (mounted) {
      _checkUpdate();
      _loadBusiness();
    }
  }

  Future<void> _editProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          api: widget.api,
          initial: widget.profile,
          onSaved: widget.onProfileChanged,
        ),
      ),
    );
  }

  Future<void> _deleteProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف حساب'),
        content: const Text(
          'حساب و خروج از مسابقه‌های فعال حذف می‌شود. ادامه می‌دهی؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: appRed),
            child: const Text('حذف حساب'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.api.deleteProfile();
      widget.onAccountDeleted();
    } catch (error) {
      if (mounted) await showFailure(context, error);
    }
  }

  Future<void> _showCategories() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          children: [
            const ListTile(
              title: Text(
                'دسته‌بندی',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline_rounded),
              title: const Text('نمایش اعضا'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MembersPage(api: widget.api),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('تقویم'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const CalendarPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('لیگ امتیاز و رتبه'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LeaguePage(api: widget.api),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.military_tech_outlined),
              title: const Text('سطح'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openLevel();
              },
            ),
            ListTile(
              leading: const Icon(Icons.task_alt_outlined),
              title: const Text('ماموریت‌های روزانه و مرحله‌ای'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openMissions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: const Text('مسابقات'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        MatchesPage(api: widget.api, onOpen: _openMatch),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_business_rounded),
              title: const Text('ساخت اتاق'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final id = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => CreateMatchPage(api: widget.api),
                  ),
                );
                if (id != null && mounted) _openMatch(id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('وارد کردن کد اتاق'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final id = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => JoinMatchPage(api: widget.api),
                  ),
                );
                if (id != null && mounted) _openMatch(id);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('ویرایش حساب کاربری'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.new_releases_outlined),
              title: Text('نسخه: $_version'),
              onTap: () {
                Navigator.pop(sheetContext);
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('نسخه برنامه'),
                    content: Text('شما از نسخه $_version استفاده می‌کنید.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('بستن'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: Badge(
                isLabelVisible: _hasUpdate,
                child: const Icon(Icons.system_update_alt_rounded),
              ),
              title: const Text('بروزرسانی'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UpdatePage(
                      hasUpdate: _hasUpdate,
                      onChecked: _checkUpdate,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: appRed),
              title: const Text('حذف حساب', style: TextStyle(color: appRed)),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteProfile();
              },
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ScreenBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                children: [
                  Row(
                    children: [
                      AvatarCircle(avatarId: widget.profile.avatarId, size: 52),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.profile.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: appGold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_outlined),
                        const SizedBox(width: 6),
                        Text(
                          _business == null
                              ? 'کوین: ...'
                              : 'کوین: ${persianDigits(_business!.coins)}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'تجارت در جهان',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 31,
                      color: appNavy,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _HomeAction(
                    color: appNavy,
                    icon: Icons.category_outlined,
                    label: 'دسته‌بندی',
                    onTap: _showCategories,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class MembersPage extends StatefulWidget {
  const MembersPage({super.key, required this.api});

  final GameApi api;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late Future<List<GameMember>> _members;

  @override
  void initState() {
    super.initState();
    _members = widget.api.members();
  }

  Future<void> _reload() async {
    setState(() => _members = widget.api.members());
    await _members;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('اعضا')),
    body: ScreenBackground(
      child: FutureBuilder<List<GameMember>>(
        future: _members,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('تلاش دوباره'),
                ),
              ),
            );
          }
          final members = snapshot.data ?? const <GameMember>[];
          if (members.isEmpty) {
            return const Center(child: Text('هنوز عضوی ثبت‌نام نکرده است.'));
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: members.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    '${persianDigits(members.length)} عضو',
                    style: const TextStyle(
                      color: appNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                }
                final member = members[index - 1];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: AvatarCircle(avatarId: member.avatarId),
                    title: Text(
                      member.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    ),
  );
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _weekdays = [
    '',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنج‌شنبه',
    'جمعه',
    'شنبه',
    'یک‌شنبه',
  ];
  static const _months = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];
  static const _dayWords = [
    'یکم',
    'دوم',
    'سوم',
    'چهارم',
    'پنجم',
    'ششم',
    'هفتم',
    'هشتم',
    'نهم',
    'دهم',
    'یازدهم',
    'دوازدهم',
    'سیزدهم',
    'چهاردهم',
    'پانزدهم',
    'شانزدهم',
    'هفدهم',
    'هجدهم',
    'نوزدهم',
    'بیستم',
    'بیست‌ویکم',
    'بیست‌ودوم',
    'بیست‌وسوم',
    'بیست‌وچهارم',
    'بیست‌وپنجم',
    'بیست‌وششم',
    'بیست‌وهفتم',
    'بیست‌وهشتم',
    'بیست‌ونهم',
    'سی‌ام',
    'سی‌ویکم',
  ];

  late final DateTime _openedAt;
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _openedAt = _now;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _time(DateTime value, {bool milliseconds = false}) {
    final base =
        '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}:${_twoDigits(value.second)}';
    return milliseconds
        ? '$base.${value.millisecond.toString().padLeft(3, '0')}'
        : base;
  }

  _CalendarInfo _calendarInfo(DateTime value) {
    final jalali = jalaliDateFor(value);
    final day = _dayWords[jalali.day - 1];
    final weekday = _weekdays[value.weekday];
    final month = _months[jalali.month - 1];
    return _CalendarInfo(
      day: day,
      weekday: weekday,
      month: month,
      year: jalali.year,
      century: jalali.year ~/ 100 + 1,
      full: '$weekday، $day $month سال ${jalali.year}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _calendarInfo(_now);
    final openedInfo = _calendarInfo(_openedAt);
    return Scaffold(
      appBar: AppBar(title: const Text('تقویم')),
      body: Container(
        width: double.infinity,
        color: const Color(0xfff3f6f5),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: appNavy,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffd8e3e0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _time(_now, milliseconds: true),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      info.full,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xffe2e8f0),
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth >= 360;
                        return GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: twoColumns ? 2 : 1,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: twoColumns ? 2.2 : 4.2,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _CalendarDetail(label: 'روز ماه', value: info.day),
                            _CalendarDetail(
                              label: 'روز هفته',
                              value: info.weekday,
                            ),
                            _CalendarDetail(
                              label: 'ماه سال',
                              value: info.month,
                            ),
                            _CalendarDetail(
                              label: 'سال خورشیدی',
                              value: persianDigits(info.year),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _CalendarDetail(
                      label: 'قرن',
                      value: 'قرن ${persianDigits(info.century)}',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(color: Color(0x55FFFFFF)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.push_pin_outlined,
                          color: Color(0xff38bdf8),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'تاریخ و ساعت باز شدن تقویم',
                          style: TextStyle(
                            color: Color(0xffcbd5e1),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${openedInfo.full} - ساعت ${_time(_openedAt)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xff7dd3fc)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarInfo {
  const _CalendarInfo({
    required this.day,
    required this.weekday,
    required this.month,
    required this.year,
    required this.century,
    required this.full,
  });

  final String day;
  final String weekday;
  final String month;
  final int year;
  final int century;
  final String full;
}

class _CalendarDetail extends StatelessWidget {
  const _CalendarDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0x22FFFFFF)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(color: Color(0xffcbd5e1), fontSize: 13),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 62,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key, required this.api, required this.onOpen});
  final GameApi api;
  final ValueChanged<String> onOpen;
  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  late Future<List<MatchInfo>> _matches;
  @override
  void initState() {
    super.initState();
    _matches = widget.api.publicMatches();
  }

  void _refresh() => setState(() => _matches = widget.api.publicMatches());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مسابقات')),
    body: ScreenBackground(
      child: FutureBuilder<List<MatchInfo>>(
        future: _matches,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('دریافت مسابقات ناموفق بود'),
              ),
            );
          final matches = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: matches.isEmpty ? 1 : matches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (matches.isEmpty)
                  return const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('مسابقه عمومی در انتظار شروع نیست.'),
                    ),
                  );
                final item = matches[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: appGold,
                      child: Icon(Icons.public, color: Colors.black),
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.section}  |  کد: ${persianDigits(item.roomCode)}',
                    ),
                    trailing: FilledButton(
                      onPressed: () async {
                        try {
                          final info = await PackageInfo.fromPlatform();
                          final id = await widget.api.joinMatch(
                            item.roomCode,
                            info.version,
                            info.buildNumber,
                          );
                          widget.onOpen(id);
                        } catch (error) {
                          if (context.mounted) showFailure(context, error);
                        }
                      },
                      child: const Text('پیوستن'),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    ),
  );
}

class CreateMatchPage extends StatefulWidget {
  const CreateMatchPage({super.key, required this.api});
  final GameApi api;
  @override
  State<CreateMatchPage> createState() => _CreateMatchPageState();
}

class _CreateMatchPageState extends State<CreateMatchPage> {
  final _name = TextEditingController(text: 'مسابقه تجارت جهانی');
  String _section = 'تجارت جهانی';
  bool _private = true;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final info = await PackageInfo.fromPlatform();
      final id = await widget.api.createMatch(
        name: _name.text.trim(),
        section: _section,
        isPrivate: _private,
        appVersion: info.version,
        appBuild: info.buildNumber,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      if (mounted) await showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ساخت اتاق')),
    body: ScreenBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'نام مسابقه و بخش آن را مشخص کن. کد اتاق هشت رقمی به‌صورت خودکار ساخته می‌شود.',
                style: TextStyle(height: 1.8),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'نام مسابقه'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _section,
                decoration: const InputDecoration(labelText: 'بخش مسابقه'),
                items: const ['تجارت جهانی', 'بازار آزاد', 'چالش حرفه‌ای']
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _section = value!),
              ),
              SwitchListTile(
                value: _private,
                onChanged: (value) => setState(() => _private = value),
                title: const Text('اتاق خصوصی'),
                subtitle: Text(
                  _private
                      ? 'ورود فقط با کد هشت رقمی'
                      : 'در فهرست مسابقات هم دیده می‌شود',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: appRed),
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.add_business),
                label: Text(_busy ? 'در حال ساخت...' : 'ساخت اتاق'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class JoinMatchPage extends StatefulWidget {
  const JoinMatchPage({super.key, required this.api});
  final GameApi api;
  @override
  State<JoinMatchPage> createState() => _JoinMatchPageState();
}

class _JoinMatchPageState extends State<JoinMatchPage> {
  final _code = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!RegExp(r'^\d{8}$').hasMatch(_code.text.trim())) {
      await showFailure(context, 'کد اتاق باید دقیقاً ۸ رقم باشد.');
      return;
    }
    setState(() => _busy = true);
    try {
      final info = await PackageInfo.fromPlatform();
      final id = await widget.api.joinMatch(
        _code.text.trim(),
        info.version,
        info.buildNumber,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      if (mounted) await showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('وارد کردن کد اتاق')),
    body: ScreenBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.pin_outlined,
                  size: 58,
                  color: Color(0xff2674bd),
                ),
                const SizedBox(height: 16),
                const Text(
                  'کد هشت رقمی اتاق را وارد کن.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _code,
                  maxLength: 8,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, letterSpacing: 3),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '۱۲۳۴۵۶۷۸',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff2674bd),
                  ),
                  onPressed: _busy ? null : _join,
                  icon: const Icon(Icons.login),
                  label: Text(_busy ? 'در حال ورود...' : 'پیوستن'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class LeaguePage extends StatelessWidget {
  const LeaguePage({super.key, required this.api});
  final GameApi api;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('لیگ امتیاز و رتبه')),
    body: ScreenBackground(
      child: FutureBuilder<List<Json>>(
        future: api.league(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return const Center(child: Text('دریافت جدول لیگ ناموفق بود.'));
          final items = snapshot.data!;
          if (items.isEmpty)
            return const Center(
              child: Text('هنوز نتیجه‌ای در لیگ ثبت نشده است.'),
            );
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final item = items[index];
              final name = jsonString(item['displayName']).trim();
              final points =
                  item['totalPoints'] ?? item['score'] ?? item['points'];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: index < 3 ? appGold : appNavy,
                  child: Text(
                    persianDigits(jsonInt(item['rank'], index + 1)),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  name.isEmpty || name == 'بازرگان'
                      ? 'نام و نام خانوادگی ثبت نشده'
                      : name,
                ),
                subtitle: Text('برد: ${persianDigits(jsonInt(item['wins']))}'),
                trailing: Text('${money(jsonInt(points))} امتیاز'),
              );
            },
          );
        },
      ),
    ),
  );
}

class UpdatePage extends StatefulWidget {
  const UpdatePage({
    super.key,
    required this.hasUpdate,
    required this.onChecked,
  });
  final bool hasUpdate;
  final Future<void> Function() onChecked;
  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  bool _checking = false;
  Future<void> _download() async {
    final metadata = Uri.parse(
      '$apiBaseUrl/public/downloads/trade-in-the-world/metadata',
    );
    try {
      final response = await http.get(metadata);
      final data = (jsonDecode(response.body) as Map).cast<String, dynamic>();
      final uri = Uri.parse(jsonString(data['apkUrl']));
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
        throw Exception('باز کردن لینک دانلود ممکن نشد.');
    } catch (error) {
      if (mounted) await showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بروزرسانی')),
    body: ScreenBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.hasUpdate
                          ? Icons.system_update_alt_rounded
                          : Icons.verified_outlined,
                      size: 58,
                      color: widget.hasUpdate ? appGold : appGreen,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.hasUpdate
                          ? 'نسخه جدید آماده نصب است.'
                          : 'نسخه نصب‌شده به‌روز است.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: appNavy),
                      onPressed: _download,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('دانلود و نصب نسخه جدید'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _checking
                          ? null
                          : () async {
                              setState(() => _checking = true);
                              await widget.onChecked();
                              if (mounted) setState(() => _checking = false);
                            },
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        _checking ? 'در حال بررسی...' : 'بررسی دوباره',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
