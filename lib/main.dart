import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'background_worker.dart';
import 'group_stage_status_panel.dart';
import 'live_models.dart';
import 'tracker_controller.dart';

export 'tracker_controller.dart';

const _gold = Color(0xFFD9AA4F);
const _goldLight = Color(0xFFFFE0A0);
const _amber = Color(0xFFF59E0B);
const _bg = Color(0xFF07080B);
const _panel = Color(0xFF11141A);
const _panelRaised = Color(0xFF181C24);
const _muted = Color(0xFF97A0AF);
const _line = Color(0xFF272D38);
const _success = Color(0xFF4ADE80);
const _danger = Color(0xFFFB7185);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await TrackerController.load();
  await controller.initializeNotifications();
  if (!kIsWeb && Platform.isAndroid) {
    await configureBackgroundResultChecks();
  }
  runApp(TrackerApp(controller: controller));
}

class TrackerApp extends StatelessWidget {
  const TrackerApp({super.key, required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _gold,
      brightness: Brightness.dark,
      surface: _panel,
    );
    return MaterialApp(
      title: 'TI Predictions Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: _bg,
        useMaterial3: true,
        splashFactory: InkSparkle.splashFactory,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(color: _line, thickness: 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _panelRaised,
          hintStyle: const TextStyle(color: _muted),
          prefixIconColor: _muted,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _gold),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF101319),
          indicatorColor: Color(0xFF493717),
          elevation: 0,
          height: 68,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _panelRaised,
          contentTextStyle: const TextStyle(color: Colors.white),
          actionTextColor: _goldLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: HomeShell(controller: controller),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final TrackerController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  Timer? timer;

  static const titles = [
    ('Command Center', 'Live tournament overview'),
    ('Prediction Board', 'Selections versus results'),
    ('Fantasy Roster', 'Players, banners, and title'),
    ('Control Room', 'Sync, alerts, and backups'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    timer = Timer.periodic(const Duration(minutes: 5), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final before = widget.controller.completedSeries;
    await widget.controller.synchronize();
    if (!mounted) return;
    final added = widget.controller.completedSeries - before;
    if (added > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$added new completed ${added == 1 ? 'series' : 'series'} synced.'),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () => setState(() => index = 0),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = titles[index];
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          extendBody: true,
          appBar: AppBar(
            toolbarHeight: 76,
            titleSpacing: 16,
            title: Row(
              children: [
                const _BrandMark(size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.$1,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title.$2,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              _HeaderIcon(
                tooltip: widget.controller.notificationsEnabled
                    ? 'Result alerts enabled'
                    : 'Enable result alerts',
                icon: widget.controller.notificationsEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                active: widget.controller.notificationsEnabled,
                onPressed: () => setState(() => index = 3),
              ),
              const SizedBox(width: 4),
              _HeaderIcon(
                tooltip: 'Refresh live results',
                icon: Icons.sync_rounded,
                spinning: widget.controller.isSyncing,
                onPressed: widget.controller.isSyncing ? null : _refresh,
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: _AppBackdrop(
            child: SafeArea(
              top: false,
              child: IndexedStack(
                index: index,
                children: [
                  DashboardPage(
                    controller: widget.controller,
                    onRefresh: _refresh,
                    onOpenSettings: () => setState(() => index = 3),
                  ),
                  PredictionsPage(
                    controller: widget.controller,
                    onRefresh: _refresh,
                  ),
                  FantasyPage(controller: widget.controller),
                  SettingsPage(
                    controller: widget.controller,
                    onRefresh: _refresh,
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (value) => setState(() => index = value),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: 'Overview',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.shield_outlined),
                    selectedIcon: Icon(Icons.shield_rounded),
                    label: 'Picks',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome_rounded),
                    label: 'Fantasy',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.tune_outlined),
                    selectedIcon: Icon(Icons.tune_rounded),
                    label: 'Control',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.controller,
    required this.onRefresh,
    this.onOpenSettings,
  });

  final TrackerController controller;
  final Future<void> Function() onRefresh;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final percentage = (controller.accuracy * 100).round();
    final recent = controller.recentCompletedSeries;
    final activeTeams = controller.teams.where((team) => team.live).length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _gold,
      backgroundColor: _panelRaised,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
        children: [
          _CommandHero(controller: controller),
          const SizedBox(height: 14),
          if (!controller.notificationsEnabled)
            _AlertInvitation(
              permissionDenied: controller.notificationPermissionDenied,
              onPressed: onOpenSettings,
            ),
          if (!controller.notificationsEnabled) const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.track_changes_rounded,
                  value: controller.settled == 0 ? '—' : '$percentage%',
                  label: 'Accuracy',
                  accent: _gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.verified_rounded,
                  value: '${controller.hits}',
                  label: 'Exact hits',
                  accent: _success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.sports_esports_rounded,
                  value: '${controller.completedSeries}',
                  label: 'Series',
                  accent: const Color(0xFF60A5FA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AccuracyPanel(
            percentage: percentage,
            settled: controller.settled,
            hits: controller.hits,
            misses: controller.misses,
            activeTeams: activeTeams,
          ),
          const SizedBox(height: 24),
          GroupStageStatusPanel(controller: controller),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Latest completed series',
            subtitle: recent.isEmpty
                ? 'Waiting for the first official result'
                : '${recent.length} completed series in the feed',
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            const _EmptyPanel(
              icon: Icons.hourglass_top_rounded,
              title: 'The arena is quiet',
              body:
                  'The app checks the live feed on launch, every five minutes while open, and in the background when alerts are enabled.',
            )
          else
            ...recent.take(6).map(
                  (series) => _SeriesCard(
                    series: series,
                    controller: controller,
                  ),
                ),
          const SizedBox(height: 22),
          const _SectionHeader(
            title: 'Prediction pulse',
            subtitle: 'Current series records for your selected field',
            icon: Icons.monitor_heart_rounded,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.teams.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _PulseTeamCard(
                team: controller.teams[index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandHero extends StatelessWidget {
  const _CommandHero({required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final live = controller.hasLiveData;
    final statusColor = live
        ? _success
        : controller.syncStatus == 'waiting'
            ? _amber
            : _danger;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2B12), Color(0xFF151922), Color(0xFF0C0F15)],
          stops: [0, 0.58, 1],
        ),
        border: Border.all(color: const Color(0x66D9AA4F)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2ED9AA4F),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -12,
            top: -18,
            child: Opacity(opacity: 0.12, child: _BrandMark(size: 132)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusDot(color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    live ? 'LIVE DATA LINK' : controller.syncStatus.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'THE INTERNATIONAL\nPREDICTION COMMAND',
                style: TextStyle(
                  height: 0.98,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 290,
                child: Text(
                  controller.syncMessage,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.public_rounded,
                    label: controller.source,
                  ),
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: controller.lastUpdated == null
                        ? 'Not synced yet'
                        : _formatDate(controller.lastUpdated!),
                  ),
                  if (controller.leagueId != null)
                    _InfoChip(
                      icon: Icons.tag_rounded,
                      label: 'League ${controller.leagueId}',
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccuracyPanel extends StatelessWidget {
  const _AccuracyPanel({
    required this.percentage,
    required this.settled,
    required this.hits,
    required this.misses,
    required this.activeTeams,
  });

  final int percentage;
  final int settled;
  final int hits;
  final int misses;
  final int activeTeams;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: settled == 0 ? 0 : percentage / 100,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white10,
                  color: _gold,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      settled == 0 ? '—' : '$percentage%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'MODEL SCORE',
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.1,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prediction performance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(
                  settled == 0
                      ? 'Final categories will be scored automatically as teams qualify or are eliminated.'
                      : '$hits exact picks, $misses misses, and $activeTeams teams currently carrying live records.',
                  style: const TextStyle(color: _muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                _Pill(
                  label: settled == 0
                      ? 'AWAITING OUTCOMES'
                      : percentage >= 80
                          ? 'ELITE READ'
                          : percentage >= 60
                              ? 'COMPETITIVE READ'
                              : 'REVISION NEEDED',
                  color: settled == 0
                      ? _gold
                      : percentage >= 80
                          ? _success
                          : percentage >= 60
                              ? _amber
                              : _danger,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PredictionsPage extends StatefulWidget {
  const PredictionsPage({
    super.key,
    required this.controller,
    required this.onRefresh,
  });

  final TrackerController controller;
  final Future<void> Function() onRefresh;

  @override
  State<PredictionsPage> createState() => _PredictionsPageState();
}

class _PredictionsPageState extends State<PredictionsPage> {
  String query = '';
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final teams = widget.controller.teams.where((team) {
      final matchesQuery = normalizedQuery.isEmpty ||
          team.clientName.toLowerCase().contains(normalizedQuery) ||
          team.name.toLowerCase().contains(normalizedQuery);
      final matchesFilter =
          filter == 'All' || team.pick == filter || team.actual == filter;
      return matchesQuery && matchesFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: _gold,
      backgroundColor: _panelRaised,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
        children: [
          _BoardSummary(controller: widget.controller),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search teams',
              suffixIcon: Icon(Icons.tune_rounded, size: 19),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', ...resultBuckets.skip(1)].map((item) {
                final selected = filter == item;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(item),
                    onSelected: (_) => setState(() => filter = item),
                    selectedColor: const Color(0xFF493717),
                    side: BorderSide(color: selected ? _gold : _line),
                    labelStyle: TextStyle(
                      color: selected ? _goldLight : Colors.white70,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          if (teams.isEmpty)
            const _EmptyPanel(
              icon: Icons.search_off_rounded,
              title: 'No teams match',
              body: 'Try another search term or result category.',
            )
          else
            ...teams.map(
              (team) => _TeamPredictionCard(
                controller: widget.controller,
                team: team,
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardSummary extends StatelessWidget {
  const _BoardSummary({required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const _BrandMark(size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '16-team prediction board',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${controller.settled} settled • ${controller.hits} exact • ${controller.misses} missed',
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
          _Pill(
            label: controller.hasLiveData ? 'AUTO' : 'OFFLINE',
            color: controller.hasLiveData ? _success : _amber,
          ),
        ],
      ),
    );
  }
}

class _TeamPredictionCard extends StatelessWidget {
  const _TeamPredictionCard({required this.controller, required this.team});

  final TrackerController controller;
  final TeamEntry team;

  @override
  Widget build(BuildContext context) {
    final stateColor = team.isExact
        ? _success
        : team.isMiss
            ? _danger
            : _gold;
    final played = team.wins + team.losses;
    final progress = (played / 5).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: team.isExact || team.isMiss ? stateColor.withAlpha(95) : _line),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _TeamLogo(team: team, size: 54),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.clientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          team.name,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (team.live)
                    const _Pill(label: 'LIVE', color: _success)
                  else
                    _Pill(label: 'PENDING', color: _muted),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1015),
                border: Border(top: BorderSide(color: _line)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _LabelValue(
                          label: 'YOUR PICK',
                          value: team.pick,
                          color: _goldLight,
                        ),
                      ),
                      Expanded(
                        child: _LabelValue(
                          label: 'SERIES',
                          value: '${team.wins}-${team.losses}',
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: _LabelValue(
                          label: 'MAPS',
                          value: '${team.mapWins}-${team.mapLosses}',
                          color: Colors.white70,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _LabelValue(
                          label: 'ACTUAL',
                          value: team.actual,
                          color: stateColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: Colors.white10,
                      color: stateColor,
                    ),
                  ),
                  if (!controller.hasLiveData) ...[
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Manual fallback',
                            style: TextStyle(color: _muted, fontSize: 11),
                          ),
                        ),
                        _CounterControl(
                          label: 'W',
                          value: team.wins,
                          onMinus: () => controller.changeWins(team, -1),
                          onPlus: () => controller.changeWins(team, 1),
                        ),
                        const SizedBox(width: 10),
                        _CounterControl(
                          label: 'L',
                          value: team.losses,
                          onMinus: () => controller.changeLosses(team, -1),
                          onPlus: () => controller.changeLosses(team, 1),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FantasyPage extends StatelessWidget {
  const FantasyPage({super.key, required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final core = controller.teamByName('TEAM VISION');
    final mid = controller.teamByName('TEAM LIQUID');
    final support = controller.teamByName('LGD GAMING');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      children: [
        const _FantasyHero(),
        const SizedBox(height: 14),
        _FantasyRoleCard(
          role: 'CORE',
          team: core,
          fallbackTeam: 'TEAM VISION',
          players: 'Noticed + Satanic',
          accent: const Color(0xFFFB7185),
          stats: const [
            ('Deaths', '150%', Icons.favorite_border_rounded),
            ('Tormentor Kills', '200%', Icons.whatshot_rounded),
            ('Creep Score', '180%', Icons.grass_rounded),
          ],
        ),
        _FantasyRoleCard(
          role: 'MID',
          team: mid,
          fallbackTeam: 'TEAM LIQUID',
          players: 'Nisha',
          accent: const Color(0xFF60A5FA),
          stats: const [
            ('Creep Score', '220%', Icons.grass_rounded),
            ('Lotuses Gained', '190%', Icons.local_florist_rounded),
            ('Stuns', '250%', Icons.flash_on_rounded),
          ],
        ),
        _FantasyRoleCard(
          role: 'SUPPORT',
          team: support,
          fallbackTeam: 'LGD GAMING',
          players: 'KingJungles + Thiolicor',
          accent: const Color(0xFF4ADE80),
          stats: const [
            ('Camps Stacked', '220%', Icons.forest_rounded),
            ('Stuns', '260%', Icons.flash_on_rounded),
            ('Watchers Taken', '250%', Icons.visibility_rounded),
          ],
        ),
        const SizedBox(height: 8),
        const _EmptyPanel(
          icon: Icons.lightbulb_rounded,
          title: 'Fantasy status',
          body:
              'Team performance affects opportunity, but emblem scoring still depends on the selected player statistics in each game.',
        ),
      ],
    );
  }
}

class _FantasyHero extends StatelessWidget {
  const _FantasyHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A3413), Color(0xFF171B24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x66D9AA4F)),
      ),
      child: const Row(
        children: [
          _BrandMark(size: 66),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HEROIC LET HIM COOK',
                  style: TextStyle(
                    color: _goldLight,
                    fontSize: 11,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '[LTGS] the Clutch',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 5),
                Text(
                  'Group-stage fantasy lineup',
                  style: TextStyle(color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FantasyRoleCard extends StatelessWidget {
  const _FantasyRoleCard({
    required this.role,
    required this.team,
    required this.fallbackTeam,
    required this.players,
    required this.accent,
    required this.stats,
  });

  final String role;
  final TeamEntry? team;
  final String fallbackTeam;
  final String players;
  final Color accent;
  final List<(String, String, IconData)> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withAlpha(70)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _TeamLogo(team: team, fallbackName: fallbackTeam, size: 52),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Pill(label: role, color: accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              team?.clientName ?? fallbackTeam,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(players, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                if (team != null)
                  Text(
                    '${team!.wins}-${team!.losses}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1015),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(23)),
              border: Border(top: BorderSide(color: _line)),
            ),
            child: Row(
              children: stats
                  .map(
                    (stat) => Expanded(
                      child: _FantasyStat(
                        label: stat.$1,
                        value: stat.$2,
                        icon: stat.$3,
                        color: accent,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.onRefresh,
  });

  final TrackerController controller;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      children: [
        _NotificationControl(controller: controller),
        const SizedBox(height: 20),
        const _SectionHeader(
          title: 'Data synchronization',
          subtitle: 'Automatic OpenDota feed and offline cache',
          icon: Icons.cloud_sync_rounded,
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.sync_rounded,
          title: 'Sync results now',
          subtitle: controller.isSyncing
              ? 'Fetching the latest tournament feed…'
              : 'Last update: ${controller.lastUpdated == null ? 'never' : _formatDate(controller.lastUpdated!)}',
          onTap: controller.isSyncing ? null : onRefresh,
        ),
        _SettingsTile(
          icon: Icons.public_rounded,
          title: controller.leagueName ?? 'The International 2026',
          subtitle: controller.leagueId == null
              ? 'League discovery is automatic.'
              : '${controller.source} league ID ${controller.leagueId}',
        ),
        const SizedBox(height: 20),
        const _SectionHeader(
          title: 'Backup and recovery',
          subtitle: 'Keep your selections and cached records portable',
          icon: Icons.inventory_2_rounded,
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.copy_all_rounded,
          title: 'Copy JSON backup',
          subtitle: 'Copy selections, records, logos, and completed series.',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: controller.exportJson()));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup copied to clipboard.')),
              );
            }
          },
        ),
        _SettingsTile(
          icon: Icons.download_rounded,
          title: 'Import JSON backup',
          subtitle: 'Restore a previously exported tracker state.',
          onTap: () => _showImport(context, controller),
        ),
        _SettingsTile(
          icon: Icons.restart_alt_rounded,
          title: 'Reset local results',
          subtitle: 'Clear the cache and restore the original selection board.',
          danger: true,
          onTap: () => _confirmReset(context, controller),
        ),
        const SizedBox(height: 18),
        const _EmptyPanel(
          icon: Icons.info_rounded,
          title: 'Automatic architecture',
          body:
              'GitHub Actions updates data/live.json from OpenDota. The APK reads that feed directly, caches it locally, and checks in the background when result alerts are enabled.',
        ),
      ],
    );
  }

  static Future<void> _showImport(
    BuildContext context,
    TrackerController controller,
  ) async {
    final text = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panelRaised,
        title: const Text('Import JSON backup'),
        content: TextField(
          controller: text,
          maxLines: 10,
          decoration: const InputDecoration(hintText: 'Paste backup JSON here'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final ok = controller.importJson(text.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? 'Backup imported.' : 'Invalid backup.')),
              );
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
    text.dispose();
  }

  static Future<void> _confirmReset(
    BuildContext context,
    TrackerController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panelRaised,
        title: const Text('Reset local results?'),
        content: const Text(
          'This clears cached results. Automatic synchronization can download them again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.reset();
  }
}

class _NotificationControl extends StatelessWidget {
  const _NotificationControl({required this.controller});

  final TrackerController controller;

  Future<void> _toggle(BuildContext context, bool enabled) async {
    final success = await controller.setNotificationsEnabled(enabled);
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification permission was not granted.'),
        ),
      );
      return;
    }
    if (enabled) {
      await controller.sendTestNotification();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background result alerts enabled.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = controller.notificationsEnabled;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: enabled
              ? const [Color(0xFF173822), Color(0xFF151A20)]
              : const [Color(0xFF3C2B12), Color(0xFF151A20)],
        ),
        border: Border.all(color: enabled ? _success.withAlpha(90) : _gold.withAlpha(90)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: (enabled ? _success : _gold).withAlpha(24),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: (enabled ? _success : _gold).withAlpha(70)),
                ),
                child: Icon(
                  enabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: enabled ? _success : _gold,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Result notifier',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Background checks approximately every 15 minutes',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: _success,
                onChanged: (value) => _toggle(context, value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              enabled
                  ? 'Alerts are active. Android may delay background work to preserve battery, but new completed series will be detected automatically.'
                  : 'Enable alerts to receive a native notification after a newly completed series appears in the synchronized feed.',
              style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 12),
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: controller.sendTestNotification,
                icon: const Icon(Icons.send_rounded),
                label: const Text('SEND TEST NOTIFICATION'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.series, required this.controller});

  final LiveSeries series;
  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final teamA = controller.teamByName(series.teamA);
    final teamB = controller.teamByName(series.teamB);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Pill(label: series.stage.toUpperCase(), color: _gold),
              const Spacer(),
              if (series.startedAt != null)
                Text(
                  _shortDate(series.startedAt!),
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SeriesTeam(
                  team: teamA,
                  fallbackName: series.teamA,
                  score: series.scoreA,
                  winner: series.winner == series.teamA,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Expanded(
                child: _SeriesTeam(
                  team: teamB,
                  fallbackName: series.teamB,
                  score: series.scoreB,
                  winner: series.winner == series.teamB,
                  reverse: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeriesTeam extends StatelessWidget {
  const _SeriesTeam({
    required this.team,
    required this.fallbackName,
    required this.score,
    required this.winner,
    this.reverse = false,
  });

  final TeamEntry? team;
  final String fallbackName;
  final int score;
  final bool winner;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final content = [
      _TeamLogo(team: team, fallbackName: fallbackName, size: 42),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment:
              reverse ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              team?.clientName ?? fallbackName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: reverse ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: winner ? _goldLight : Colors.white,
              ),
            ),
            Text(
              winner ? 'WINNER' : 'FINAL',
              style: TextStyle(
                color: winner ? _success : _muted,
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '$score',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: winner ? _goldLight : Colors.white70,
        ),
      ),
    ];
    return Row(children: reverse ? content.reversed.toList() : content);
  }
}

class _PulseTeamCard extends StatelessWidget {
  const _PulseTeamCard({required this.team});

  final TeamEntry team;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TeamLogo(team: team, size: 42),
          const SizedBox(height: 8),
          Text(
            team.clientName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${team.wins}-${team.losses}',
            style: const TextStyle(color: _gold, fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({
    this.team,
    this.fallbackName,
    this.size = 48,
  });

  final TeamEntry? team;
  final String? fallbackName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = team?.logoUrl;
    final name = team?.clientName ?? fallbackName ?? 'TI';
    final initials = team?.initials ?? _initials(name);
    final fallback = _LogoFallback(initials: initials, size: size);

    if (logo == null || logo.isEmpty) return fallback;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: Colors.white.withAlpha(24)),
      ),
      child: CachedNetworkImage(
        imageUrl: logo,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 220),
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: _gold),
          ),
        ),
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3515), Color(0xFF1A1F28)],
        ),
        border: Border.all(color: const Color(0x66D9AA4F)),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: _goldLight,
          fontSize: size * 0.28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CounterControl extends StatelessWidget {
  const _CounterControl({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onMinus,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(Icons.remove_rounded, size: 15),
            ),
          ),
          Text(
            '$label$value',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          InkWell(
            onTap: onPlus,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(Icons.add_rounded, size: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _FantasyStat extends StatelessWidget {
  const _FantasyStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(color: _muted, fontSize: 9, height: 1.15),
        ),
      ],
    );
  }
}

class _AlertInvitation extends StatelessWidget {
  const _AlertInvitation({required this.permissionDenied, this.onPressed});

  final bool permissionDenied;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF201A10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x66D9AA4F)),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: _gold),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      permissionDenied ? 'Notification permission blocked' : 'Enable result alerts',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      permissionDenied
                          ? 'Open Control Room and try enabling alerts again.'
                          : 'Get notified after a newly completed series is synchronized.',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _gold),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBackdrop extends StatelessWidget {
  const _AppBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1016), _bg, _bg],
              ),
            ),
          ),
        ),
        Positioned(
          right: -90,
          top: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0x2ED9AA4F), Colors.transparent]),
            ),
          ),
        ),
        Positioned(
          left: -120,
          bottom: 30,
          child: Container(
            width: 260,
            height: 260,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0x1A3B82F6), Colors.transparent]),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BrandMarkPainter()),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final diamond = Path()
      ..moveTo(center.dx, size.height * 0.04)
      ..lineTo(size.width * 0.96, center.dy)
      ..lineTo(center.dx, size.height * 0.96)
      ..lineTo(size.width * 0.04, center.dy)
      ..close();
    final inner = Path()
      ..moveTo(center.dx, size.height * 0.18)
      ..lineTo(size.width * 0.82, center.dy)
      ..lineTo(center.dx, size.height * 0.82)
      ..lineTo(size.width * 0.18, center.dy)
      ..close();

    canvas.drawPath(
      diamond,
      Paint()
        ..shader = const LinearGradient(
          colors: [_goldLight, _gold, Color(0xFF8A5E1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(inner, Paint()..color = const Color(0xFF101319));

    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.28, size.height * 0.30, size.width * 0.44, size.height * 0.12),
      Radius.circular(size.width * 0.025),
    );
    final stem = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.44, size.height * 0.38, size.width * 0.12, size.height * 0.36),
      Radius.circular(size.width * 0.025),
    );
    final glyph = Paint()..color = _goldLight;
    canvas.drawRRect(bar, glyph);
    canvas.drawRRect(stem, glyph);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeaderIcon extends StatefulWidget {
  const _HeaderIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.spinning = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  final bool spinning;

  @override
  State<_HeaderIcon> createState() => _HeaderIconState();
}

class _HeaderIconState extends State<_HeaderIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.spinning) controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _HeaderIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !controller.isAnimating) {
      controller.repeat();
    } else if (!widget.spinning && controller.isAnimating) {
      controller.stop();
      controller.value = 0;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.icon,
      color: widget.active ? _goldLight : Colors.white70,
      size: 21,
    );
    return Tooltip(
      message: widget.tooltip,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.active ? const Color(0xFF3A2B13) : _panel,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: widget.active ? const Color(0x66D9AA4F) : _line),
          ),
          child: widget.spinning
              ? RotationTransition(turns: controller, child: icon)
              : icon,
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _panel.withAlpha(238),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(52)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? _danger : _gold;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: danger ? _danger.withAlpha(55) : _line),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withAlpha(22),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: danger ? _danger : Colors.white,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: _muted),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF332610),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _gold, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: _muted, fontSize: 8, letterSpacing: 1.1),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(86)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.3),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _goldLight),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withAlpha(150), blurRadius: 9)],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF302410),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _gold),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: _muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return 'TI';
  if (words.length == 1) {
    return words.first.substring(0, words.first.length.clamp(1, 2)).toUpperCase();
  }
  return words.take(2).map((word) => word[0]).join().toUpperCase();
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day} $hour:$minute $suffix';
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}';
}
