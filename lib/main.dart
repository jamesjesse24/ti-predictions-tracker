import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'ti_predictions_tracker_state_v1';

const predictionBuckets = <String>[
  'Pending',
  '4-0',
  '4-1',
  'Elimination Winner',
  'Elimination Loser',
  '1-4',
  '0-4',
];

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
    const seed = Color(0xFFD6A84B);
    return MaterialApp(
      title: 'TI Predictions Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF121316),
        ),
        scaffoldBackgroundColor: const Color(0xFF090A0C),
        useMaterial3: true,
        dividerColor: Colors.white12,
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF111318),
          indicatorColor: Color(0xFF5A431D),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF17191F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
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

  static const _titles = <String>[
    'Command Center',
    'Prediction Board',
    'Fantasy Roster',
    'Data & Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_index],
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const Text(
              'THE INTERNATIONAL 2026',
              style: TextStyle(
                color: Color(0xFFD6A84B),
                fontSize: 10,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0E0F12),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            return IndexedStack(
              index: _index,
              children: [
                DashboardPage(controller: widget.controller),
                PredictionsPage(controller: widget.controller),
                const FantasyPage(),
                SettingsPage(controller: widget.controller),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Predictions',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Fantasy',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class TrackerController extends ChangeNotifier {
  TrackerController({required this.teams, SharedPreferences? preferences})
      : _preferences = preferences;

  final SharedPreferences? _preferences;
  List<TeamEntry> teams;

  static Future<TrackerController> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null) {
      return TrackerController(
        teams: TeamEntry.defaults(),
        preferences: preferences,
      );
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final storedTeams = (decoded['teams'] as List<dynamic>)
          .map((item) => TeamEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      return TrackerController(teams: storedTeams, preferences: preferences);
    } catch (_) {
      return TrackerController(
        teams: TeamEntry.defaults(),
        preferences: preferences,
      );
    }
  }

  factory TrackerController.memory() {
    return TrackerController(teams: TeamEntry.defaults());
  }

  int get settledCount =>
      teams.where((team) => team.actualBucket != 'Pending').length;

  int get exactHits => teams
      .where(
        (team) =>
            team.actualBucket != 'Pending' &&
            team.actualBucket == team.predictedBucket,
      )
      .length;

  double get accuracy => settledCount == 0 ? 0 : exactHits / settledCount;

  int get teamsInProgress => teams
      .where((team) => team.wins > 0 || team.losses > 0)
      .length;

  void changeWins(TeamEntry team, int delta) {
    team.wins = (team.wins + delta).clamp(0, 4);
    _inferTerminalBucket(team);
    _commit();
  }

  void changeLosses(TeamEntry team, int delta) {
    team.losses = (team.losses + delta).clamp(0, 4);
    _inferTerminalBucket(team);
    _commit();
  }

  void setActualBucket(TeamEntry team, String bucket) {
    team.actualBucket = bucket;
    _commit();
  }

  void _inferTerminalBucket(TeamEntry team) {
    if (team.wins == 4) {
      team.actualBucket = team.losses == 0 ? '4-0' : '4-1';
    } else if (team.losses == 4) {
      team.actualBucket = team.wins == 0 ? '0-4' : '1-4';
    }
  }

  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'teams': teams.map((team) => team.toJson()).toList(),
    });
  }

  bool importJson(String source) {
    try {
      final decoded = jsonDecode(source) as Map<String, dynamic>;
      final imported = (decoded['teams'] as List<dynamic>)
          .map((item) => TeamEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      if (imported.length != 16) {
        return false;
      }
      teams = imported;
      _commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  void reset() {
    teams = TeamEntry.defaults();
    _commit();
  }

  void _commit() {
    notifyListeners();
    final data = jsonEncode({
      'schemaVersion': 1,
      'teams': teams.map((team) => team.toJson()).toList(),
    });
    _preferences?.setString(_storageKey, data);
  }
}

class TeamEntry {
  TeamEntry({
    required this.name,
    required this.clientName,
    required this.predictedBucket,
    this.wins = 0,
    this.losses = 0,
    this.actualBucket = 'Pending',
  });

  final String name;
  final String clientName;
  final String predictedBucket;
  int wins;
  int losses;
  String actualBucket;

  String get initials {
    final words = clientName.split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
    }
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }

  bool get isExact =>
      actualBucket != 'Pending' && actualBucket == predictedBucket;

  bool get isMiss =>
      actualBucket != 'Pending' && actualBucket != predictedBucket;

  Map<String, dynamic> toJson() => {
        'name': name,
        'clientName': clientName,
        'predictedBucket': predictedBucket,
        'wins': wins,
        'losses': losses,
        'actualBucket': actualBucket,
      };

  factory TeamEntry.fromJson(Map<String, dynamic> json) {
    return TeamEntry(
      name: json['name'] as String,
      clientName: json['clientName'] as String,
      predictedBucket: json['predictedBucket'] as String,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      actualBucket: json['actualBucket'] as String? ?? 'Pending',
    );
  }

  static List<TeamEntry> defaults() => [
        TeamEntry(
          name: 'PARIVISION',
          clientName: 'TEAM VISION',
          predictedBucket: '4-0',
        ),
        TeamEntry(
          name: 'Team Yandex',
          clientName: 'TEAM YANDEX',
          predictedBucket: '4-1',
        ),
        TeamEntry(
          name: 'BetBoom Team',
          clientName: 'BOOMBOYS',
          predictedBucket: '4-1',
        ),
        TeamEntry(
          name: 'Team Falcons',
          clientName: 'TEAM FALCONS',
          predictedBucket: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Team Spirit',
          clientName: 'TEAM SPIRIT',
          predictedBucket: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Nigma Galaxy',
          clientName: 'NIGMA GALAXY',
          predictedBucket: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Vici Gaming',
          clientName: 'VICI GAMING',
          predictedBucket: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Aurora Gaming',
          clientName: 'AURORA GAMING',
          predictedBucket: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Team Liquid',
          clientName: 'TEAM LIQUID',
          predictedBucket: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'LGD Gaming',
          clientName: 'LGD GAMING',
          predictedBucket: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'IRON WING',
          clientName: 'IRON WING',
          predictedBucket: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'Xtreme Gaming',
          clientName: 'XTREME GAMING',
          predictedBucket: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'OG',
          clientName: 'OG',
          predictedBucket: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'GamerLegion',
          clientName: 'GAMERLEGION',
          predictedBucket: '1-4',
        ),
        TeamEntry(
          name: 'Team Resilience',
          clientName: 'TEAM RESILIENCE',
          predictedBucket: '1-4',
        ),
        TeamEntry(
          name: 'HULIGANI',
          clientName: 'HULIGANI',
          predictedBucket: '0-4',
        ),
      ];
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final percentage = (controller.accuracy * 100).round();
    final misses = controller.teams.where((team) => team.isMiss).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: [
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
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: controller.settledCount == 0
                          ? 0
                          : controller.accuracy,
                      strokeWidth: 11,
                      backgroundColor: Colors.white10,
                      color: const Color(0xFFD6A84B),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percentage%',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'ACCURACY',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: Colors.white60,
                          ),
                        ),
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
                    const Text(
                      'Prediction performance',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      controller.settledCount == 0
                          ? 'Enter completed results to start measuring the prediction board.'
                          : '${controller.exactHits} exact hits from ${controller.settledCount} settled teams.',
                      style: const TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    _StatusPill(
                      label: controller.settledCount == 0
                          ? 'Awaiting group stage'
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
            Expanded(
              child: _MetricCard(
                icon: Icons.check_circle_outline,
                value: '${controller.exactHits}',
                label: 'Exact hits',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.flag_outlined,
                value: '${controller.settledCount}/16',
                label: 'Settled',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.ssid_chart,
                value: '${controller.teamsInProgress}',
                label: 'In progress',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Original prediction board',
          subtitle: 'The locked forecast used for accuracy comparison.',
        ),
        const SizedBox(height: 12),
        ...predictionBuckets.where((bucket) => bucket != 'Pending').map(
          (bucket) {
            final teams = controller.teams
                .where((team) => team.predictedBucket == bucket)
                .toList();
            return _BucketStrip(bucket: bucket, teams: teams);
          },
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Prediction misses',
          subtitle: misses.isEmpty
              ? 'No confirmed misses yet.'
              : '${misses.length} team${misses.length == 1 ? '' : 's'} currently differ from the forecast.',
        ),
        const SizedBox(height: 10),
        if (misses.isEmpty)
          const _EmptyPanel(
            icon: Icons.auto_awesome,
            title: 'Clean board',
            message: 'Settled teams that miss their predicted category will appear here.',
          )
        else
          ...misses.map(
            (team) => Card(
              child: ListTile(
                leading: _TeamAvatar(team: team),
                title: Text(team.clientName),
                subtitle: Text(
                  'Predicted ${team.predictedBucket} • Actual ${team.actualBucket}',
                ),
                trailing: const Icon(Icons.close, color: Colors.redAccent),
              ),
            ),
          ),
      ],
    );
  }
}

class PredictionsPage extends StatefulWidget {
  const PredictionsPage({super.key, required this.controller});

  final TrackerController controller;

  @override
  State<PredictionsPage> createState() => _PredictionsPageState();
}

class _PredictionsPageState extends State<PredictionsPage> {
  String _query = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.controller.teams.where((team) {
      final matchesSearch = team.clientName.toLowerCase().contains(
            _query.toLowerCase(),
          ) ||
          team.name.toLowerCase().contains(_query.toLowerCase());
      final matchesFilter =
          _filter == 'All' || team.predictedBucket == _filter;
      return matchesSearch && matchesFilter;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search teams',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    'All',
                    ...predictionBuckets.where((bucket) => bucket != 'Pending'),
                  ].map((bucket) {
                    final selected = _filter == bucket;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(bucket),
                        selected: selected,
                        onSelected: (_) => setState(() => _filter = bucket),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 30),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final team = filtered[index];
              return TeamTrackerCard(
                team: team,
                controller: widget.controller,
              );
            },
          ),
        ),
      ],
    );
  }
}

class TeamTrackerCard extends StatelessWidget {
  const TeamTrackerCard({
    super.key,
    required this.team,
    required this.controller,
  });

  final TeamEntry team;
  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final bucketColor = colorForBucket(team.predictedBucket);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: bucketColor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                children: [
                  _TeamAvatar(team: team),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.clientName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (team.name != team.clientName)
                          Text(
                            team.name,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: team.predictedBucket,
                    color: bucketColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _RecordControl(
                      label: 'WINS',
                      value: team.wins,
                      color: Colors.greenAccent,
                      onDecrease: () => controller.changeWins(team, -1),
                      onIncrease: () => controller.changeWins(team, 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RecordControl(
                      label: 'LOSSES',
                      value: team.losses,
                      color: Colors.redAccent,
                      onDecrease: () => controller.changeLosses(team, -1),
                      onIncrease: () => controller.changeLosses(team, 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF17191F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      team.isExact
                          ? Icons.check_circle
                          : team.isMiss
                              ? Icons.cancel
                              : Icons.hourglass_empty,
                      color: team.isExact
                          ? Colors.greenAccent
                          : team.isMiss
                              ? Colors.redAccent
                              : Colors.white38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Actual result: ${team.actualBucket}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Set actual result',
                      onSelected: (value) =>
                          controller.setActualBucket(team, value),
                      itemBuilder: (context) => predictionBuckets
                          .map(
                            (bucket) => PopupMenuItem(
                              value: bucket,
                              child: Text(bucket),
                            ),
                          )
                          .toList(),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        _FantasyTitleCard(),
        SizedBox(height: 14),
        _FantasyRoleCard(
          role: 'CORE',
          team: 'TEAM VISION',
          players: 'Noticed & Satanic',
          icon: Icons.sports_mma,
          stats: [
            BannerStat('Deaths', 150, 'Tier III • Benevolent'),
            BannerStat('Tormentor Kills', 200, 'Tier II • Vampiric'),
            BannerStat('Creep Score', 180, 'Tier III • Unique'),
          ],
        ),
        SizedBox(height: 12),
        _FantasyRoleCard(
          role: 'MID',
          team: 'TEAM LIQUID',
          players: 'Nisha',
          icon: Icons.bolt,
          stats: [
            BannerStat('Creep Score', 220, 'Tier III • Fractal'),
            BannerStat('Lotuses Gained', 190, 'Tier I • Fractal'),
            BannerStat('Stuns', 250, 'Tier V • Benevolent'),
          ],
        ),
        SizedBox(height: 12),
        _FantasyRoleCard(
          role: 'SUPPORT',
          team: 'LGD GAMING',
          players: 'KingJungles & Thiolicor',
          icon: Icons.volunteer_activism,
          stats: [
            BannerStat('Camps Stacked', 220, 'Tier III • Fractal'),
            BannerStat('Stuns', 260, 'Tier IV • Fractal'),
            BannerStat('Watchers Taken', 250, 'Tier V • Friendly'),
          ],
        ),
        SizedBox(height: 16),
        _EmptyPanel(
          icon: Icons.insights,
          title: 'Optimization note',
          message:
              'The roster is stored as the current reference build. A later version can add editable fantasy cards and automatic match-level scoring.',
        ),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: [
        const _SectionTitle(
          title: 'Back up your tracker',
          subtitle: 'Export or restore the full 16-team prediction state.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: const Text('Copy JSON backup'),
                subtitle: const Text('Copies all records and actual outcomes.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: controller.exportJson()),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backup copied to clipboard.')),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.input_outlined),
                title: const Text('Import JSON backup'),
                subtitle: const Text('Restores a previously exported state.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showImportDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Tracker controls',
          subtitle: 'Reset only when you want to discard all entered results.',
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restart_alt, color: Colors.redAccent),
            title: const Text('Reset prediction results'),
            subtitle: const Text('Returns all records and actual outcomes to pending.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _confirmReset(context),
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Build information',
          subtitle: 'Designed for automatic Android delivery through GitHub Actions.',
        ),
        const SizedBox(height: 12),
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.android),
                title: Text('TI Predictions Tracker'),
                subtitle: Text('Version 1.0.0 • Offline-first Flutter app'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.cloud_done_outlined),
                title: Text('CI release pipeline'),
                subtitle: Text('Push a v* tag to build and attach the APK to GitHub Releases.'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final textController = TextEditingController();
    final imported = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import tracker backup'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: textController,
            minLines: 7,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Paste exported JSON here',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final success = controller.importJson(textController.text);
              Navigator.pop(dialogContext, success);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (context.mounted && imported != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            imported
                ? 'Tracker backup restored.'
                : 'Import failed. Use a valid 16-team tracker backup.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset all results?'),
        content: const Text(
          'This clears entered records and actual outcomes. The original prediction board remains unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.reset();
    }
  }
}

class BannerStat {
  const BannerStat(this.name, this.multiplier, this.detail);

  final String name;
  final int multiplier;
  final String detail;
}

class _FantasyTitleCard extends StatelessWidget {
  const _FantasyTitleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF473113), Color(0xFF191A20)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x66D6A84B)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COACHING TITLE',
            style: TextStyle(
              color: Color(0xFFD6A84B),
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Heroic LET HIM COOK [LTGS] the Clutch',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 7),
          Text(
            'Heroic rewards capped or masked heroes. The Clutch rewards the last possible match of a series.',
            style: TextStyle(color: Colors.white70, height: 1.4),
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
    required this.players,
    required this.icon,
    required this.stats,
  });

  final String role;
  final String team;
  final String players;
  final IconData icon;
  final List<BannerStat> stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF5A431D),
                  child: Icon(icon, color: const Color(0xFFFFD985)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$role • $team',
                        style: const TextStyle(
                          color: Color(0xFFD6A84B),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        players,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...stats.map(
              (stat) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF17191F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            stat.detail,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${stat.multiplier}%',
                      style: const TextStyle(
                        color: Color(0xFFFFD985),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordControl extends StatelessWidget {
  const _RecordControl({
    required this.label,
    required this.value,
    required this.color,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final int value;
  final Color color;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF17191F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: value > 0 ? onDecrease : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: value < 4 ? onIncrease : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFD6A84B)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _BucketStrip extends StatelessWidget {
  const _BucketStrip({required this.bucket, required this.teams});

  final String bucket;
  final List<TeamEntry> teams;

  @override
  Widget build(BuildContext context) {
    final color = colorForBucket(bucket);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14161B),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              bucket,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: teams
                  .map(
                    (team) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(team.clientName),
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

class _TeamAvatar extends StatelessWidget {
  const _TeamAvatar({required this.team});

  final TeamEntry team;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 23,
      backgroundColor: colorForBucket(team.predictedBucket).withValues(alpha: 0.2),
      foregroundColor: colorForBucket(team.predictedBucket),
      child: Text(
        team.initials,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: Colors.white54)),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14161B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD6A84B), size: 31),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white60, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color colorForBucket(String bucket) {
  return switch (bucket) {
    '4-0' => const Color(0xFFFFD166),
    '4-1' => const Color(0xFF7BDFF2),
    'Elimination Winner' => const Color(0xFF80ED99),
    'Elimination Loser' => const Color(0xFFFF9F80),
    '1-4' => const Color(0xFFCDB4DB),
    '0-4' => const Color(0xFFFF6B6B),
    _ => Colors.white54,
  };
}
