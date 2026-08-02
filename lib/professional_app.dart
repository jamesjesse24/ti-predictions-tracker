import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'group_stage_status_panel.dart';
import 'live_models.dart';
import 'team_branding.dart';
import 'tracker_controller.dart';

const _gold = Color(0xFFD8A84E);
const _goldSoft = Color(0xFFFFD98A);
const _background = Color(0xFF080A0E);
const _surface = Color(0xFF11141A);
const _surfaceRaised = Color(0xFF171B22);
const _border = Color(0xFF282E38);
const _textPrimary = Color(0xFFF6F3EE);
const _muted = Color(0xFF929AA8);
const _success = Color(0xFF4ADE80);
const _danger = Color(0xFFFB7185);
const _blue = Color(0xFF60A5FA);

class TrackerApp extends StatelessWidget {
  const TrackerApp({super.key, required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _gold,
      brightness: Brightness.dark,
      surface: _surface,
    );

    return MaterialApp(
      title: 'TI Predictions Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: _background,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: _border,
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surface,
          hintStyle: const TextStyle(color: _muted),
          prefixIconColor: _muted,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _gold),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF101319),
          indicatorColor: Color(0xFF4B3717),
          elevation: 0,
          height: 66,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _surfaceRaised,
          actionTextColor: _goldSoft,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
  int _index = 0;
  Timer? _timer;

  static const _titles = [
    'Overview',
    'Predictions',
    'Fantasy',
    'Control',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refresh(),
    );
  }

  Future<void> _refresh() async {
    final before = widget.controller.completedSeries;
    await widget.controller.synchronize();
    if (!mounted) return;

    final added = widget.controller.completedSeries - before;
    if (added > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$added new ${added == 1 ? 'series' : 'series'} synced',
          ),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () => setState(() => _index = 0),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          extendBody: true,
          appBar: AppBar(
            toolbarHeight: 70,
            titleSpacing: 18,
            title: Row(
              children: [
                const _AppMark(size: 38),
                const SizedBox(width: 12),
                Text(
                  _titles[_index],
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            actions: [
              _HeaderButton(
                tooltip: 'Result alerts',
                icon: widget.controller.notificationsEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                active: widget.controller.notificationsEnabled,
                onPressed: () => setState(() => _index = 3),
              ),
              const SizedBox(width: 6),
              _HeaderButton(
                tooltip: 'Refresh results',
                icon: Icons.sync_rounded,
                spinning: widget.controller.isSyncing,
                onPressed:
                    widget.controller.isSyncing ? null : _refresh,
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: _Backdrop(
            child: SafeArea(
              top: false,
              child: IndexedStack(
                index: _index,
                children: [
                  DashboardPage(
                    controller: widget.controller,
                    onRefresh: _refresh,
                    onOpenSettings: () => setState(() => _index = 3),
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
              borderRadius: BorderRadius.circular(22),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) {
                  setState(() => _index = value);
                },
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
    final accuracy = (controller.accuracy * 100).round();
    final recent = controller.recentCompletedSeries;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _gold,
      backgroundColor: _surfaceRaised,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _ConnectionStrip(controller: controller),
          if (!controller.notificationsEnabled) ...[
            const SizedBox(height: 10),
            _NotificationPrompt(
              denied: controller.notificationPermissionDenied,
              onTap: onOpenSettings,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Accuracy',
                  value: controller.settled == 0 ? '—' : '$accuracy%',
                  icon: Icons.track_changes_rounded,
                  color: _gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Exact hits',
                  value: '${controller.hits}',
                  icon: Icons.check_circle_rounded,
                  color: _success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Series',
                  value: '${controller.completedSeries}',
                  icon: Icons.sports_esports_rounded,
                  color: _blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GroupStageStatusPanel(controller: controller),
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'Latest results',
            trailing: recent.isEmpty ? null : '${recent.length}',
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            const _EmptyState(
              icon: Icons.hourglass_empty_rounded,
              title: 'No completed series yet',
              detail: 'Waiting for the first synced result',
            )
          else
            ...recent.take(5).map(
                  (series) => _ResultCard(
                    series: series,
                    controller: controller,
                  ),
                ),
          const SizedBox(height: 20),
          const _SectionTitle(title: 'Field snapshot'),
          const SizedBox(height: 8),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.teams.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _TeamSnapshotCard(
                team: controller.teams[index],
              ),
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
  String _query = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final teams = widget.controller.teams.where((team) {
      final query = _query.toLowerCase();
      final matchesQuery =
          team.clientName.toLowerCase().contains(query) ||
              team.name.toLowerCase().contains(query);
      final matchesFilter = _filter == 'All' ||
          team.pick == _filter ||
          team.actual == _filter;
      return matchesQuery && matchesFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: _gold,
      backgroundColor: _surfaceRaised,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search teams',
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', ...resultBuckets.skip(1)].map((item) {
                final selected = _filter == item;
                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(_shortBucket(item)),
                    onSelected: (_) => setState(() => _filter = item),
                    side: const BorderSide(color: _border),
                    selectedColor: const Color(0xFF4B3717),
                    backgroundColor: _surface,
                    labelStyle: TextStyle(
                      color: selected ? _goldSoft : _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (teams.isEmpty)
            const _EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching teams',
              detail: 'Change the search or filter',
            )
          else
            ...teams.map(
              (team) => _PredictionCard(
                controller: widget.controller,
                team: team,
              ),
            ),
        ],
      ),
    );
  }
}

class FantasyPage extends StatelessWidget {
  const FantasyPage({super.key, required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const _FantasyTitleCard(),
        const SizedBox(height: 12),
        _FantasyRosterCard(
          role: 'CORE',
          team: controller.teamByName('PARIVISION') ?? controller.teams.first,
          displayTeam: 'TEAM VISION',
          players: 'Noticed + Satanic',
          roleColor: _danger,
          stats: const [
            _FantasyStat(
              Icons.favorite_border_rounded,
              '150%',
              'Deaths',
            ),
            _FantasyStat(
              Icons.local_fire_department_rounded,
              '200%',
              'Tormentor',
            ),
            _FantasyStat(Icons.grass_rounded, '180%', 'Creeps'),
          ],
        ),
        const SizedBox(height: 10),
        _FantasyRosterCard(
          role: 'MID',
          team: controller.teamByName('Team Liquid') ?? controller.teams[8],
          displayTeam: 'TEAM LIQUID',
          players: 'Nisha',
          roleColor: _blue,
          stats: const [
            _FantasyStat(Icons.grass_rounded, '220%', 'Creeps'),
            _FantasyStat(
              Icons.local_florist_rounded,
              '190%',
              'Lotuses',
            ),
            _FantasyStat(Icons.bolt_rounded, '250%', 'Stuns'),
          ],
        ),
        const SizedBox(height: 10),
        _FantasyRosterCard(
          role: 'SUPPORT',
          team: controller.teamByName('LGD Gaming') ?? controller.teams[9],
          displayTeam: 'LGD GAMING',
          players: 'KingJungles + Thiolicor',
          roleColor: _success,
          stats: const [
            _FantasyStat(Icons.park_rounded, '220%', 'Stacks'),
            _FantasyStat(Icons.bolt_rounded, '260%', 'Stuns'),
            _FantasyStat(Icons.visibility_rounded, '250%', 'Watchers'),
          ],
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _NotifierCard(controller: controller),
        if (controller.notificationPermissionDenied) ...[
          const SizedBox(height: 8),
          const _InlineWarning(
            text: 'Notification permission is disabled in Android settings.',
          ),
        ],
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Synchronization'),
        const SizedBox(height: 8),
        _SettingTile(
          icon: Icons.sync_rounded,
          title: 'Sync results',
          subtitle: controller.lastChecked == null
              ? 'Not checked yet'
              : 'Last checked ${_formatDate(controller.lastChecked!)}',
          onTap: controller.isSyncing ? null : onRefresh,
          trailing: controller.isSyncing
              ? const _SmallSpinner()
              : null,
        ),
        _SettingTile(
          icon: Icons.cloud_outlined,
          title: 'Feed status',
          subtitle: _feedSubtitle(controller),
        ),
        _SettingTile(
          icon: Icons.image_search_rounded,
          title: 'Refresh team logos',
          subtitle: controller.isRefreshingLogos
              ? 'Resolving team identities'
              : controller.logoMessage,
          onTap: controller.isRefreshingLogos
              ? null
              : () async {
                  await controller.hydrateTeamLogos(force: true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(controller.logoMessage)),
                    );
                  }
                },
          trailing: controller.isRefreshingLogos
              ? const _SmallSpinner()
              : null,
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Backup'),
        const SizedBox(height: 8),
        _SettingTile(
          icon: Icons.copy_rounded,
          title: 'Copy backup',
          subtitle: 'Copy tracker data as JSON',
          onTap: () async {
            await Clipboard.setData(
              ClipboardData(text: controller.exportJson()),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup copied')),
              );
            }
          },
        ),
        _SettingTile(
          icon: Icons.file_download_outlined,
          title: 'Import backup',
          subtitle: 'Restore a previous JSON backup',
          onTap: () => _showImportDialog(context, controller),
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Local data'),
        const SizedBox(height: 8),
        _SettingTile(
          icon: Icons.hide_image_outlined,
          title: 'Clear logo cache',
          subtitle: 'Return to branded fallbacks until refreshed',
          danger: true,
          onTap: () => _confirmLogoClear(context, controller),
        ),
        _SettingTile(
          icon: Icons.restart_alt_rounded,
          title: 'Reset tracker',
          subtitle: 'Clear cached results and restore picks',
          danger: true,
          onTap: () => _showResetDialog(context, controller),
        ),
      ],
    );
  }

  Future<void> _showImportDialog(
    BuildContext context,
    TrackerController controller,
  ) async {
    final textController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceRaised,
        title: const Text('Import backup'),
        content: TextField(
          controller: textController,
          maxLines: 9,
          decoration: const InputDecoration(
            hintText: 'Paste JSON backup',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final valid = controller.importJson(textController.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    valid ? 'Backup imported' : 'Invalid backup',
                  ),
                ),
              );
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
    textController.dispose();
  }

  Future<void> _confirmLogoClear(
    BuildContext context,
    TrackerController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceRaised,
        title: const Text('Clear logo cache?'),
        content: const Text(
          'Team-coloured fallbacks will be used until logos are refreshed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearLogoCache();
  }

  Future<void> _showResetDialog(
    BuildContext context,
    TrackerController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceRaised,
        title: const Text('Reset tracker?'),
        content: const Text(
          'Cached results and local changes will be cleared.',
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

class _ConnectionStrip extends StatelessWidget {
  const _ConnectionStrip({required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final connected = controller.hasLiveData;
    final color = connected
        ? _success
        : controller.syncStatus == 'waiting'
            ? _gold
            : _danger;
    final state = connected
        ? 'CONNECTED'
        : controller.syncStatus == 'waiting'
            ? 'WAITING'
            : 'OFFLINE';

    return _Panel(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              connected
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_sync_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      state,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      controller.source,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  controller.lastChecked == null
                      ? 'Not checked yet'
                      : 'Last checked ${_formatDate(controller.lastChecked!)}',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (controller.leagueId != null)
            _SmallBadge(
              label: '#${controller.leagueId}',
              color: _gold,
            ),
        ],
      ),
    );
  }
}

class _NotificationPrompt extends StatelessWidget {
  const _NotificationPrompt({required this.denied, this.onTap});

  final bool denied;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF17140D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x554B3717)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: _gold,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                denied
                    ? 'Notification permission denied'
                    : 'Enable result alerts',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
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
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.series, required this.controller});

  final LiveSeries series;
  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final first = controller.teamByName(series.teamA);
    final second = controller.teamByName(series.teamB);
    final firstWon = series.winner == series.teamA;
    final secondWon = series.winner == series.teamB;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Panel(
        padding: const EdgeInsets.all(13),
        child: Column(
          children: [
            Row(
              children: [
                TeamLogo(
                  name: first?.name ?? series.teamA,
                  alternateName: first?.clientName,
                  logoUrl: first?.logoUrl,
                  size: 42,
                  showGlow: false,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    first?.clientName ?? series.teamA,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: firstWon ? _textPrimary : Colors.white70,
                      fontWeight: firstWon
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${series.scoreA}–${series.scoreB}',
                    style: const TextStyle(
                      color: _goldSoft,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    second?.clientName ?? series.teamB,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondWon ? _textPrimary : Colors.white70,
                      fontWeight: secondWon
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TeamLogo(
                  name: second?.name ?? series.teamB,
                  alternateName: second?.clientName,
                  logoUrl: second?.logoUrl,
                  size: 42,
                  showGlow: false,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              '${series.stage} • Winner: ${series.winner}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSnapshotCard extends StatelessWidget {
  const _TeamSnapshotCard({required this.team});

  final TeamEntry team;

  @override
  Widget build(BuildContext context) {
    final brand = teamBrandFor(
      team.name,
      alternateName: team.clientName,
    );

    return Container(
      width: 120,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brand.primary.withAlpha(72)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand.primary.withAlpha(20), _surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TeamLogo(
                name: team.name,
                alternateName: team.clientName,
                logoUrl: team.logoUrl,
                size: 40,
                showGlow: false,
              ),
              const Spacer(),
              if (team.live) const _StatusDot(color: _success),
            ],
          ),
          const Spacer(),
          Text(
            team.clientName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${team.wins}-${team.losses}',
            style: TextStyle(
              color: brand.primary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.controller, required this.team});

  final TrackerController controller;
  final TeamEntry team;

  @override
  Widget build(BuildContext context) {
    final resultColor = team.isExact
        ? _success
        : team.isMiss
            ? _danger
            : _gold;
    final settled = team.actual != 'Pending';
    final status = settled
        ? 'SETTLED'
        : team.live
            ? 'LIVE'
            : 'WAITING';

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TeamAccentCard(
        name: team.name,
        alternateName: team.clientName,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
              child: Row(
                children: [
                  TeamLogo(
                    name: team.name,
                    alternateName: team.clientName,
                    logoUrl: team.logoUrl,
                    size: 52,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (team.name != team.clientName) ...[
                          const SizedBox(height: 2),
                          Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TeamStatusChip(
                    name: team.name,
                    alternateName: team.clientName,
                    label: status,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _DataCell(
                      label: 'PICK',
                      value: _shortBucket(team.pick),
                      color: _goldSoft,
                    ),
                  ),
                  Expanded(
                    child: _DataCell(
                      label: 'SERIES',
                      value: '${team.wins}-${team.losses}',
                    ),
                  ),
                  Expanded(
                    child: _DataCell(
                      label: 'MAPS',
                      value: '${team.mapWins}-${team.mapLosses}',
                    ),
                  ),
                  Expanded(
                    child: _DataCell(
                      label: 'RESULT',
                      value: _shortBucket(team.actual),
                      color: resultColor,
                    ),
                  ),
                ],
              ),
            ),
            if (!controller.hasLiveData) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Manual record',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                    const Spacer(),
                    _Stepper(
                      label: 'W',
                      value: team.wins,
                      onMinus: () => controller.changeWins(team, -1),
                      onPlus: () => controller.changeWins(team, 1),
                    ),
                    const SizedBox(width: 12),
                    _Stepper(
                      label: 'L',
                      value: team.losses,
                      onMinus: () => controller.changeLosses(team, -1),
                      onPlus: () => controller.changeLosses(team, 1),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FantasyTitleCard extends StatelessWidget {
  const _FantasyTitleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x66D8A84E)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF392A12), Color(0xFF151922)],
        ),
      ),
      child: const Row(
        children: [
          _AppMark(size: 58),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LET HIM COOK',
                  style: TextStyle(
                    color: _goldSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '[LTGS] the Clutch',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Group Stage Lineup',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FantasyRosterCard extends StatelessWidget {
  const _FantasyRosterCard({
    required this.role,
    required this.team,
    required this.displayTeam,
    required this.players,
    required this.roleColor,
    required this.stats,
  });

  final String role;
  final TeamEntry team;
  final String displayTeam;
  final String players;
  final Color roleColor;
  final List<_FantasyStat> stats;

  @override
  Widget build(BuildContext context) {
    final brand = teamBrandFor(
      team.name,
      alternateName: displayTeam,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brand.primary.withAlpha(92)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand.primary.withAlpha(18), _surface],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                TeamLogo(
                  name: team.name,
                  alternateName: displayTeam,
                  logoUrl: team.logoUrl,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _SmallBadge(label: role, color: roleColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayTeam,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        players,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${team.wins}-${team.losses}',
                  style: TextStyle(
                    color: brand.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            child: Row(
              children: stats.map((stat) {
                return Expanded(
                  child: Column(
                    children: [
                      Icon(stat.icon, color: roleColor, size: 20),
                      const SizedBox(height: 5),
                      Text(
                        stat.value,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stat.label,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FantasyStat {
  const _FantasyStat(this.icon, this.value, this.label);

  final IconData icon;
  final String value;
  final String label;
}

class _NotifierCard extends StatelessWidget {
  const _NotifierCard({required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x66D8A84E)),
        gradient: const LinearGradient(
          colors: [Color(0xFF35280F), Color(0xFF151922)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0x223D2D10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: _gold,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Result alerts',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Checks every 15 min',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: controller.notificationsEnabled,
            activeTrackColor: _gold,
            onChanged: (enabled) async {
              final success =
                  await controller.setNotificationsEnabled(enabled);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? enabled
                            ? 'Result alerts enabled'
                            : 'Result alerts disabled'
                        : 'Notification permission denied',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? _danger : _gold;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: danger ? _danger.withAlpha(70) : _border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: danger ? _danger : _textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    (onTap == null
                        ? const SizedBox.shrink()
                        : const Icon(
                            Icons.chevron_right_rounded,
                            color: _muted,
                          )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _danger.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _danger.withAlpha(70)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _danger, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell({
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 8,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
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
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: onMinus,
          icon: const Icon(Icons.remove_rounded, size: 17),
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: onPlus,
          icon: const Icon(Icons.add_rounded, size: 17),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
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
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SmallSpinner extends StatelessWidget {
  const _SmallSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AppMarkPainter()),
    );
  }
}

class _AppMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = Path()
      ..moveTo(center.dx, 0)
      ..lineTo(size.width, center.dy)
      ..lineTo(center.dx, size.height)
      ..lineTo(0, center.dy)
      ..close();
    canvas.drawPath(outer, Paint()..color = _gold);

    final inset = size.width * 0.18;
    final inner = Path()
      ..moveTo(center.dx, inset)
      ..lineTo(size.width - inset, center.dy)
      ..lineTo(center.dx, size.height - inset)
      ..lineTo(inset, center.dy)
      ..close();
    canvas.drawPath(inner, Paint()..color = _surface);

    final stroke = Paint()
      ..color = _goldSoft
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(size.width * 0.30, size.height * 0.35),
      Offset(size.width * 0.70, size.height * 0.35),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.35),
      Offset(size.width * 0.50, size.height * 0.70),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeaderButton extends StatefulWidget {
  const _HeaderButton({
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
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.spinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _HeaderButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spinning && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.icon,
      color: widget.active ? _goldSoft : _muted,
      size: 21,
    );

    return Tooltip(
      message: widget.tooltip,
      child: Material(
        color: widget.active ? const Color(0xFF2F2514) : _surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: widget.active
                    ? const Color(0x88D8A84E)
                    : _border,
              ),
            ),
            child: widget.spinning
                ? RotationTransition(turns: _controller, child: icon)
                : icon,
          ),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_background, Color(0xFF090B10), _background],
        ),
      ),
      child: child,
    );
  }
}

String _shortBucket(String value) {
  switch (value) {
    case 'Elimination Winner':
      return 'Play-in W';
    case 'Elimination Loser':
      return 'Play-in L';
    case 'Pending':
      return 'Pending';
    default:
      return value;
  }
}

String _feedSubtitle(TrackerController controller) {
  final league = controller.leagueId == null
      ? controller.source
      : '${controller.source} • League ${controller.leagueId}';
  final updated = controller.feedUpdatedAt == null
      ? 'Feed update unknown'
      : 'Feed updated ${_formatDate(controller.feedUpdatedAt!)}';
  return '$league • $updated';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day} $hour:$minute $suffix';
}
