import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'ti_tracker_state_v1';
const _gold = Color(0xFFD6A84B);
const _bg = Color(0xFF090A0C);
const _panel = Color(0xFF15171C);

const resultBuckets = <String>[
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
    return MaterialApp(
      title: 'TI Predictions Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _gold,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: _bg,
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _panel,
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
  int index = 0;

  static const titles = [
    'Command Center',
    'Prediction Board',
    'Fantasy Roster',
    'Data & Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0F12),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[index],
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
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
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => IndexedStack(
            index: index,
            children: [
              DashboardPage(controller: widget.controller),
              PredictionsPage(controller: widget.controller),
              const FantasyPage(),
              SettingsPage(controller: widget.controller),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            label: 'Predictions',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            label: 'Fantasy',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class TrackerController extends ChangeNotifier {
  TrackerController(this.teams, [this.preferences]);

  List<TeamEntry> teams;
  final SharedPreferences? preferences;

  factory TrackerController.memory() => TrackerController(TeamEntry.defaults());

  static Future<TrackerController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return TrackerController(TeamEntry.defaults(), prefs);

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final teams = (data['teams'] as List<dynamic>)
          .map((item) => TeamEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      return TrackerController(teams, prefs);
    } catch (_) {
      return TrackerController(TeamEntry.defaults(), prefs);
    }
  }

  int get settled => teams.where((team) => team.actual != 'Pending').length;
  int get hits => teams.where((team) => team.actual == team.predicted).length;
  int get misses => teams.where((team) => team.isMiss).length;
  double get accuracy => settled == 0 ? 0 : hits / settled;
  int get active => teams.where((team) => team.wins + team.losses > 0).length;

  void changeWins(TeamEntry team, int amount) {
    team.wins = (team.wins + amount).clamp(0, 4).toInt();
    _inferTerminalResult(team);
    _save();
  }

  void changeLosses(TeamEntry team, int amount) {
    team.losses = (team.losses + amount).clamp(0, 4).toInt();
    _inferTerminalResult(team);
    _save();
  }

  void setActual(TeamEntry team, String actual) {
    team.actual = actual;
    _save();
  }

  void _inferTerminalResult(TeamEntry team) {
    if (team.wins == 4) {
      team.actual = team.losses == 0 ? '4-0' : '4-1';
    } else if (team.losses == 4) {
      team.actual = team.wins == 0 ? '0-4' : '1-4';
    }
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'teams': teams.map((team) => team.toJson()).toList(),
      });

  bool importJson(String source) {
    try {
      final data = jsonDecode(source) as Map<String, dynamic>;
      final imported = (data['teams'] as List<dynamic>)
          .map((item) => TeamEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      if (imported.length != 16) return false;
      teams = imported;
      _save();
      return true;
    } catch (_) {
      return false;
    }
  }

  void reset() {
    teams = TeamEntry.defaults();
    _save();
  }

  void _save() {
    notifyListeners();
    preferences?.setString(
      _storageKey,
      jsonEncode({'teams': teams.map((team) => team.toJson()).toList()}),
    );
  }
}

class TeamEntry {
  TeamEntry({
    required this.name,
    required this.clientName,
    required this.predicted,
    this.wins = 0,
    this.losses = 0,
    this.actual = 'Pending',
  });

  final String name;
  final String clientName;
  final String predicted;
  int wins;
  int losses;
  String actual;

  bool get isExact => actual != 'Pending' && actual == predicted;
  bool get isMiss => actual != 'Pending' && actual != predicted;

  String get initials {
    final words = clientName.split(RegExp(r'\s+'));
    if (words.length == 1) {
      final length = words.first.length < 2 ? words.first.length : 2;
      return words.first.substring(0, length).toUpperCase();
    }
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'clientName': clientName,
        'predicted': predicted,
        'wins': wins,
        'losses': losses,
        'actual': actual,
      };

  factory TeamEntry.fromJson(Map<String, dynamic> json) => TeamEntry(
        name: json['name'] as String,
        clientName: json['clientName'] as String,
        predicted: json['predicted'] as String,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        actual: json['actual'] as String? ?? 'Pending',
      );

  static List<TeamEntry> defaults() => [
        TeamEntry(
          name: 'PARIVISION',
          clientName: 'TEAM VISION',
          predicted: '4-0',
        ),
        TeamEntry(
          name: 'Team Yandex',
          clientName: 'TEAM YANDEX',
          predicted: '4-1',
        ),
        TeamEntry(
          name: 'BetBoom Team',
          clientName: 'BOOMBOYS',
          predicted: '4-1',
        ),
        TeamEntry(
          name: 'Team Falcons',
          clientName: 'TEAM FALCONS',
          predicted: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Team Spirit',
          clientName: 'TEAM SPIRIT',
          predicted: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Nigma Galaxy',
          clientName: 'NIGMA GALAXY',
          predicted: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Vici Gaming',
          clientName: 'VICI GAMING',
          predicted: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Aurora Gaming',
          clientName: 'AURORA GAMING',
          predicted: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Team Liquid',
          clientName: 'TEAM LIQUID',
          predicted: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'LGD Gaming',
          clientName: 'LGD GAMING',
          predicted: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'IRON WING',
          clientName: 'IRON WING',
          predicted: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'Xtreme Gaming',
          clientName: 'XTREME GAMING',
          predicted: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'OG',
          clientName: 'OG',
          predicted: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'GamerLegion',
          clientName: 'GAMERLEGION',
          predicted: '1-4',
        ),
        TeamEntry(
          name: 'Team Resilience',
          clientName: 'TEAM RESILIENCE',
          predicted: '1-4',
        ),
        TeamEntry(
          name: 'HULIGANI',
          clientName: 'HULIGANI',
          predicted: '0-4',
        ),
      ];
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final percent = (controller.accuracy * 100).round();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3C2A10), _panel],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _gold.withOpacity(.45)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 106,
                height: 106,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: controller.accuracy,
                      strokeWidth: 10,
                      backgroundColor: Colors.white10,
                      color: _gold,
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
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
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.settled == 0
                          ? 'Enter completed results to begin the comparison.'
                          : '${controller.hits} exact hits from ${controller.settled} settled teams.',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StatusPill(
                      text: controller.settled == 0
                          ? 'Awaiting group stage'
                          : percent >= 80
                              ? 'Elite read'
                              : percent >= 60
                                  ? 'Competitive read'
                                  : 'Model needs revision',
                      color: percent >= 80
                          ? Colors.greenAccent
                          : percent >= 60
                              ? Colors.amberAccent
                              : Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                value: '${controller.hits}',
                label: 'Exact hits',
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                value: '${controller.settled}/16',
                label: 'Settled',
                icon: Icons.flag_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                value: '${controller.active}',
                label: 'Active',
                icon: Icons.ssid_chart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionTitle(
          title: 'Original prediction board',
          subtitle: 'The locked forecast used for accuracy scoring.',
        ),
        const SizedBox(height: 10),
        ...resultBuckets.where((bucket) => bucket != 'Pending').map((bucket) {
          final teams = controller.teams
              .where((team) => team.predicted == bucket)
              .toList();
          return BucketStrip(bucket: bucket, teams: teams);
        }),
        const SizedBox(height: 18),
        SectionTitle(
          title: 'Current misses',
          subtitle: controller.misses == 0
              ? 'No confirmed misses yet.'
              : '${controller.misses} predictions differ from the final category.',
        ),
        const SizedBox(height: 10),
        if (controller.misses == 0)
          const InfoPanel(
            icon: Icons.auto_awesome,
            title: 'Clean board',
            message: 'Confirmed misses will appear here.',
          )
        else
          ...controller.teams.where((team) => team.isMiss).map(
                (team) => Card(
                  child: ListTile(
                    leading: TeamAvatar(team: team),
                    title: Text(team.clientName),
                    subtitle: Text(
                      'Predicted ${team.predicted} • Actual ${team.actual}',
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
  String query = '';
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final teams = widget.controller.teams.where((team) {
      final text = '${team.clientName} ${team.name}'.toLowerCase();
      return text.contains(query.toLowerCase()) &&
          (filter == 'All' || team.predicted == filter);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search teams',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    'All',
                    ...resultBuckets.where((bucket) => bucket != 'Pending'),
                  ]
                      .map(
                        (bucket) => Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: FilterChip(
                            label: Text(bucket),
                            selected: filter == bucket,
                            onSelected: (_) => setState(() => filter = bucket),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: teams.length,
            itemBuilder: (context, index) => TeamCard(
              team: teams[index],
              controller: widget.controller,
            ),
          ),
        ),
      ],
    );
  }
}

class TeamCard extends StatelessWidget {
  const TeamCard({
    super.key,
    required this.team,
    required this.controller,
  });

  final TeamEntry team;
  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final color = bucketColor(team.predicted);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                TeamAvatar(team: team),
                const SizedBox(width: 11),
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
                StatusPill(text: team.predicted, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RecordControl(
                    label: 'WINS',
                    value: team.wins,
                    color: Colors.greenAccent,
                    onMinus: () => controller.changeWins(team, -1),
                    onPlus: () => controller.changeWins(team, 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RecordControl(
                    label: 'LOSSES',
                    value: team.losses,
                    color: Colors.redAccent,
                    onMinus: () => controller.changeLosses(team, -1),
                    onPlus: () => controller.changeLosses(team, 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(13),
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
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Actual result: ${team.actual}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.edit_outlined),
                    onSelected: (value) => controller.setActual(team, value),
                    itemBuilder: (context) => resultBuckets
                        .map(
                          (bucket) => PopupMenuItem(
                            value: bucket,
                            child: Text(bucket),
                          ),
                        )
                        .toList(),
                  ),
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
  const FantasyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        FantasyTitleCard(),
        SizedBox(height: 12),
        FantasyRoleCard(
          role: 'CORE',
          team: 'TEAM VISION',
          players: 'Noticed & Satanic',
          stats: [
            FantasyStat('Deaths', 150, 'Tier III • Benevolent'),
            FantasyStat('Tormentor Kills', 200, 'Tier II • Vampiric'),
            FantasyStat('Creep Score', 180, 'Tier III • Unique'),
          ],
        ),
        SizedBox(height: 10),
        FantasyRoleCard(
          role: 'MID',
          team: 'TEAM LIQUID',
          players: 'Nisha',
          stats: [
            FantasyStat('Creep Score', 220, 'Tier III • Fractal'),
            FantasyStat('Lotuses Gained', 190, 'Tier I • Fractal'),
            FantasyStat('Stuns', 250, 'Tier V • Benevolent'),
          ],
        ),
        SizedBox(height: 10),
        FantasyRoleCard(
          role: 'SUPPORT',
          team: 'LGD GAMING',
          players: 'KingJungles & Thiolicor',
          stats: [
            FantasyStat('Camps Stacked', 220, 'Tier III • Fractal'),
            FantasyStat('Stuns', 260, 'Tier IV • Fractal'),
            FantasyStat('Watchers Taken', 250, 'Tier V • Friendly'),
          ],
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
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle(
          title: 'Backup',
          subtitle: 'Copy or restore all team records and outcomes.',
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: const Text('Copy JSON backup'),
                subtitle: const Text(
                  'Save the full tracker state to the clipboard.',
                ),
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: controller.exportJson()),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backup copied.')),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.input_outlined),
                title: const Text('Import JSON backup'),
                subtitle: const Text('Restore a previously exported state.'),
                onTap: () => showImportDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restart_alt, color: Colors.redAccent),
            title: const Text('Reset results'),
            subtitle: const Text(
              'Clear records while keeping the original predictions.',
            ),
            onTap: () => confirmReset(context),
          ),
        ),
        const SizedBox(height: 18),
        const InfoPanel(
          icon: Icons.android,
          title: 'Automatic APK delivery',
          message:
              'Every CI run uploads an APK artifact. A v* tag creates a GitHub Release and attaches the APK automatically.',
        ),
      ],
    );
  }

  Future<void> showImportDialog(BuildContext context) async {
    final input = TextEditingController();
    final success = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import backup'),
        content: TextField(
          controller: input,
          minLines: 7,
          maxLines: 12,
          decoration: const InputDecoration(hintText: 'Paste JSON here'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.importJson(input.text),
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Backup restored.' : 'Invalid backup.')),
      );
    }
  }

  Future<void> confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset all results?'),
        content: const Text(
          'Entered wins, losses, and actual categories will be cleared.',
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
    if (confirmed == true) controller.reset();
  }
}

class FantasyStat {
  const FantasyStat(this.name, this.multiplier, this.detail);

  final String name;
  final int multiplier;
  final String detail;
}

class FantasyTitleCard extends StatelessWidget {
  const FantasyTitleCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF473113), _panel],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withOpacity(.45)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COACHING TITLE',
            style: TextStyle(
              color: _gold,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Heroic LET HIM COOK [LTGS] the Clutch',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Current high-percentile fantasy reference build.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class FantasyRoleCard extends StatelessWidget {
  const FantasyRoleCard({
    super.key,
    required this.role,
    required this.team,
    required this.players,
    required this.stats,
  });

  final String role;
  final String team;
  final String players;
  final List<FantasyStat> stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$role • $team',
              style: const TextStyle(
                color: _gold,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              players,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 11),
            ...stats.map(
              (stat) => Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(12),
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
                        fontSize: 18,
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

class RecordControl extends StatelessWidget {
  const RecordControl({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final int value;
  final Color color;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: value > 0 ? onMinus : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                onPressed: value < 4 ? onPlus : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          children: [
            Icon(icon, color: _gold),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class BucketStrip extends StatelessWidget {
  const BucketStrip({
    super.key,
    required this.bucket,
    required this.teams,
  });

  final String bucket;
  final List<TeamEntry> teams;

  @override
  Widget build(BuildContext context) {
    final color = bucketColor(bucket);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bucket,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: teams
                .map((team) => Chip(label: Text(team.clientName)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class TeamAvatar extends StatelessWidget {
  const TeamAvatar({super.key, required this.team});

  final TeamEntry team;

  @override
  Widget build(BuildContext context) {
    final color = bucketColor(team.predicted);
    return CircleAvatar(
      backgroundColor: color.withOpacity(.18),
      foregroundColor: color,
      child: Text(
        team.initials,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(subtitle, style: const TextStyle(color: Colors.white54)),
      ],
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 29),
          const SizedBox(width: 12),
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
                  style: const TextStyle(
                    color: Colors.white60,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color bucketColor(String bucket) {
  switch (bucket) {
    case '4-0':
      return const Color(0xFFFFD166);
    case '4-1':
      return const Color(0xFF7BDFF2);
    case 'Elimination Winner':
      return const Color(0xFF80ED99);
    case 'Elimination Loser':
      return const Color(0xFFFF9F80);
    case '1-4':
      return const Color(0xFFCDB4DB);
    case '0-4':
      return const Color(0xFFFF6B6B);
    default:
      return Colors.white54;
  }
}
