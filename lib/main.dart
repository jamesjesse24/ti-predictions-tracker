import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'live_models.dart';
import 'tracker_controller.dart';

export 'tracker_controller.dart';

const _gold = Color(0xFFD6A84B);
const _bg = Color(0xFF090A0C);
const _panel = Color(0xFF15171C);
const _muted = Color(0xFF9CA3AF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await TrackerController.load();
  runApp(TrackerApp(controller: controller));
}

class TrackerApp extends StatelessWidget {
  const TrackerApp({super.key, required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TI Predictions Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _gold,
          brightness: Brightness.dark,
          surface: _panel,
        ),
        scaffoldBackgroundColor: _bg,
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B1E24),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF101216),
          indicatorColor: Color(0xFF5B431D),
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
    'Command Center',
    'Prediction Board',
    'Fantasy Roster',
    'Data & Settings',
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
          content: Text('$added new completed series ${added == 1 ? 'was' : 'were'} synced.'),
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
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF0E0F12),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w900)),
                const Text(
                  'THE INTERNATIONAL 2026',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 10,
                    letterSpacing: 1.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh live results',
                onPressed: widget.controller.isSyncing ? null : _refresh,
                icon: widget.controller.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
            ],
          ),
          body: SafeArea(
            child: IndexedStack(
              index: index,
              children: [
                DashboardPage(controller: widget.controller, onRefresh: _refresh),
                PredictionsPage(controller: widget.controller, onRefresh: _refresh),
                const FantasyPage(),
                SettingsPage(controller: widget.controller, onRefresh: _refresh),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
              NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Predictions'),
              NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Fantasy'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller, required this.onRefresh});

  final TrackerController controller;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final percentage = (controller.accuracy * 100).round();
    final recent = controller.series.where((item) => item.completed).toList()
      ..sort((a, b) => (b.startedAt ?? DateTime(1970)).compareTo(a.startedAt ?? DateTime(1970)));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        children: [
          _SyncCard(controller: controller, onRefresh: onRefresh),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3C2A10), Color(0xFF17191F)],
              ),
              border: Border.all(color: const Color(0x66D6A84B)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 108,
                  height: 108,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: controller.settled == 0 ? 0 : controller.accuracy,
                        strokeWidth: 11,
                        backgroundColor: Colors.white10,
                        color: _gold,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$percentage%', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                          const Text('ACCURACY', style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: _muted)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Prediction performance', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 7),
                      Text(
                        controller.settled == 0
                            ? 'Results will be compared automatically as teams reach final categories.'
                            : '${controller.hits} exact hits from ${controller.settled} settled teams.',
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      _Pill(
                        label: controller.settled == 0
                            ? 'Awaiting outcomes'
                            : percentage >= 80
                                ? 'Elite read'
                                : percentage >= 60
                                    ? 'Competitive read'
                                    : 'Model needs revision',
                        color: percentage >= 80
                            ? Colors.greenAccent
                            : percentage >= 60
                                ? Colors.amberAccent
                                : Colors.redAccent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Metric(icon: Icons.check_circle_outline, value: '${controller.hits}', label: 'Exact hits')),
              const SizedBox(width: 10),
              Expanded(child: _Metric(icon: Icons.cancel_outlined, value: '${controller.misses}', label: 'Misses')),
              const SizedBox(width: 10),
              Expanded(child: _Metric(icon: Icons.sports_esports_outlined, value: '${controller.completedSeries}', label: 'Series')),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Latest completed series', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            const _EmptyPanel(
              icon: Icons.hourglass_empty,
              title: 'No completed series yet',
              body: 'The app checks the remote feed on launch, every five minutes while open, and whenever you pull to refresh.',
            )
          else
            ...recent.take(6).map(_SeriesTile.new),
        ],
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.controller, required this.onRefresh});

  final TrackerController controller;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final live = controller.hasLiveData;
    final color = live
        ? Colors.greenAccent
        : controller.syncStatus == 'waiting'
            ? Colors.amberAccent
            : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(14)),
            child: Icon(live ? Icons.cloud_done_outlined : Icons.cloud_sync_outlined, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  live ? 'Automatic live results active' : 'Automatic feed: ${controller.syncStatus}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(controller.syncMessage, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                if (controller.lastUpdated != null)
                  Text('Updated ${_formatDate(controller.lastUpdated!)} • ${controller.source}', style: const TextStyle(color: _muted, fontSize: 11)),
              ],
            ),
          ),
          IconButton(onPressed: controller.isSyncing ? null : onRefresh, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }
}

class PredictionsPage extends StatefulWidget {
  const PredictionsPage({super.key, required this.controller, required this.onRefresh});

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
    final teams = widget.controller.teams.where((team) {
      final matchesQuery = team.clientName.toLowerCase().contains(query.toLowerCase()) || team.name.toLowerCase().contains(query.toLowerCase());
      final matchesFilter = filter == 'All' || team.pick == filter || team.actual == filter;
      return matchesQuery && matchesFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        children: [
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search team'),
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
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          ...teams.map((team) => _TeamCard(controller: widget.controller, team: team)),
        ],
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.controller, required this.team});

  final TrackerController controller;
  final TeamEntry team;

  @override
  Widget build(BuildContext context) {
    final stateColor = team.isExact
        ? Colors.greenAccent
        : team.isMiss
            ? Colors.redAccent
            : _gold;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: _panel,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF3B2B13),
                  foregroundColor: _gold,
                  child: Text(team.initials, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(team.clientName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      if (team.name != team.clientName)
                        Text(team.name, style: const TextStyle(color: _muted, fontSize: 11)),
                    ],
                  ),
                ),
                if (team.live) const _Pill(label: 'LIVE', color: Colors.greenAccent),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _LabelValue(label: 'PICK', value: team.pick, color: _gold)),
                Expanded(child: _LabelValue(label: 'SERIES', value: '${team.wins}-${team.losses}', color: Colors.white)),
                Expanded(child: _LabelValue(label: 'MAPS', value: '${team.mapWins}-${team.mapLosses}', color: Colors.white70)),
                Expanded(child: _LabelValue(label: 'ACTUAL', value: team.actual, color: stateColor)),
              ],
            ),
            if (!controller.hasLiveData) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('Manual fallback', style: TextStyle(color: _muted, fontSize: 12))),
                  IconButton(onPressed: () => controller.changeWins(team, -1), icon: const Icon(Icons.remove_circle_outline)),
                  Text('${team.wins}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  IconButton(onPressed: () => controller.changeWins(team, 1), icon: const Icon(Icons.add_circle_outline)),
                  const SizedBox(width: 10),
                  IconButton(onPressed: () => controller.changeLosses(team, -1), icon: const Icon(Icons.remove_circle_outline)),
                  Text('${team.losses}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  IconButton(onPressed: () => controller.changeLosses(team, 1), icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FantasyPage extends StatelessWidget {
  const FantasyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: const [
        _FantasyHeader(),
        SizedBox(height: 14),
        _FantasyCard(
          role: 'CORE',
          team: 'TEAM VISION',
          players: 'Noticed + Satanic',
          stats: [
            ('Deaths', '150%'),
            ('Tormentor Kills', '200%'),
            ('Creep Score', '180%'),
          ],
        ),
        _FantasyCard(
          role: 'MID',
          team: 'TEAM LIQUID',
          players: 'Nisha',
          stats: [
            ('Creep Score', '220%'),
            ('Lotuses Gained', '190%'),
            ('Stuns', '250%'),
          ],
        ),
        _FantasyCard(
          role: 'SUPPORT',
          team: 'LGD GAMING',
          players: 'KingJungles + Thiolicor',
          stats: [
            ('Camps Stacked', '220%'),
            ('Stuns', '260%'),
            ('Watchers Taken', '250%'),
          ],
        ),
      ],
    );
  }
}

class _FantasyHeader extends StatelessWidget {
  const _FantasyHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFF352710), Color(0xFF17191F)]),
        border: Border.all(color: const Color(0x66D6A84B)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Heroic LET HIM COOK [LTGS] the Clutch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 5),
          Text('Current group-stage fantasy configuration', style: TextStyle(color: _muted)),
        ],
      ),
    );
  }
}

class _FantasyCard extends StatelessWidget {
  const _FantasyCard({required this.role, required this.team, required this.players, required this.stats});

  final String role;
  final String team;
  final String players;
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _panel,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Pill(label: role, color: _gold),
                const SizedBox(width: 10),
                Expanded(child: Text(team, style: const TextStyle(fontWeight: FontWeight.w900))),
              ],
            ),
            const SizedBox(height: 7),
            Text(players, style: const TextStyle(color: Colors.white70)),
            const Divider(height: 24),
            ...stats.map((stat) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(stat.$1, style: const TextStyle(color: _muted))),
                      Text(stat.$2, style: const TextStyle(fontWeight: FontWeight.w900, color: _gold)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller, required this.onRefresh});

  final TrackerController controller;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: [
        const Text('Automatic synchronization', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.cloud_sync_outlined,
          title: 'Sync now',
          subtitle: 'Fetch the latest generated event feed from GitHub.',
          onTap: controller.isSyncing ? null : onRefresh,
        ),
        _SettingsTile(
          icon: Icons.public,
          title: controller.leagueName ?? 'The International 2026',
          subtitle: controller.leagueId == null
              ? 'OpenDota league discovery is automatic.'
              : 'OpenDota league ID ${controller.leagueId}',
        ),
        const SizedBox(height: 18),
        const Text('Backup', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.copy_all_outlined,
          title: 'Copy JSON backup',
          subtitle: 'Copy selections, cached records, and completed series.',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: controller.exportJson()));
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup copied.')));
          },
        ),
        _SettingsTile(
          icon: Icons.download_outlined,
          title: 'Import JSON backup',
          subtitle: 'Restore an exported tracker state.',
          onTap: () => _showImport(context, controller),
        ),
        _SettingsTile(
          icon: Icons.restart_alt,
          title: 'Reset local state',
          subtitle: 'Restore the original selections and clear cached results.',
          danger: true,
          onTap: () => _confirmReset(context, controller),
        ),
        const SizedBox(height: 18),
        const _EmptyPanel(
          icon: Icons.info_outline,
          title: 'How automatic updates work',
          body: 'GitHub Actions checks OpenDota, generates data/live.json, and the installed APK reads that file. Match-data updates do not require rebuilding the APK.',
        ),
      ],
    );
  }

  static Future<void> _showImport(BuildContext context, TrackerController controller) async {
    final text = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import JSON'),
        content: TextField(controller: text, maxLines: 10, decoration: const InputDecoration(hintText: 'Paste backup JSON here')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final ok = controller.importJson(text.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Backup imported.' : 'Invalid backup.')));
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  static Future<void> _confirmReset(BuildContext context, TrackerController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset tracker?'),
        content: const Text('This clears local cached results. Automatic synchronization can download them again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed == true) controller.reset();
  }
}

class _SeriesTile extends StatelessWidget {
  const _SeriesTile(this.series);

  final LiveSeries series;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _panel,
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: const Icon(Icons.emoji_events_outlined, color: _gold),
        title: Text('${series.teamA} ${series.scoreA}–${series.scoreB} ${series.teamB}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${series.stage} • Winner: ${series.winner}', style: const TextStyle(color: _muted)),
        trailing: series.startedAt == null ? null : Text(_shortDate(series.startedAt!), style: const TextStyle(fontSize: 11, color: _muted)),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, this.onTap, this.danger = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : _gold;
    return Card(
      color: _panel,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: danger ? Colors.redAccent : null)),
        subtitle: Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Icon(icon, color: _gold),
          const SizedBox(height: 7),
          Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
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
        Text(label, style: const TextStyle(color: _muted, fontSize: 9, letterSpacing: 1.1)),
        const SizedBox(height: 4),
        Text(value, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
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
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
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
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _gold),
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
