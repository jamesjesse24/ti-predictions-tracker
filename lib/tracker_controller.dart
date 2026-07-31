import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_models.dart';
import 'live_service.dart';

const resultBuckets = <String>[
  'Pending',
  '4-0',
  '4-1',
  'Elimination Winner',
  'Elimination Loser',
  '1-4',
  '0-4',
];

const _storageKey = 'ti_tracker_state_v2';

class TeamEntry {
  TeamEntry({
    required this.name,
    required this.clientName,
    required this.pick,
    this.wins = 0,
    this.losses = 0,
    this.mapWins = 0,
    this.mapLosses = 0,
    this.actual = 'Pending',
    this.live = false,
    this.lastMatchAt,
  });

  final String name;
  final String clientName;
  final String pick;
  int wins;
  int losses;
  int mapWins;
  int mapLosses;
  String actual;
  bool live;
  DateTime? lastMatchAt;

  bool get isExact => actual != 'Pending' && actual == pick;
  bool get isMiss => actual != 'Pending' && actual != pick;

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
        'pick': pick,
        'wins': wins,
        'losses': losses,
        'mapWins': mapWins,
        'mapLosses': mapLosses,
        'actual': actual,
        'live': live,
        'lastMatchAt': lastMatchAt?.toUtc().toIso8601String(),
      };

  factory TeamEntry.fromJson(Map<String, dynamic> json) => TeamEntry(
        name: json['name'] as String,
        clientName: json['clientName'] as String,
        pick: json['pick'] as String? ?? json['predicted'] as String? ?? 'Pending',
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        mapWins: (json['mapWins'] as num?)?.toInt() ?? 0,
        mapLosses: (json['mapLosses'] as num?)?.toInt() ?? 0,
        actual: json['actual'] as String? ?? 'Pending',
        live: json['live'] as bool? ?? false,
        lastMatchAt: DateTime.tryParse(json['lastMatchAt'] as String? ?? ''),
      );

  static List<TeamEntry> defaults() => [
        TeamEntry(name: 'PARIVISION', clientName: 'TEAM VISION', pick: '4-0'),
        TeamEntry(name: 'Team Yandex', clientName: 'TEAM YANDEX', pick: '4-1'),
        TeamEntry(name: 'BetBoom Team', clientName: 'BOOMBOYS', pick: '4-1'),
        TeamEntry(name: 'Team Falcons', clientName: 'TEAM FALCONS', pick: 'Elimination Winner'),
        TeamEntry(name: 'Team Spirit', clientName: 'TEAM SPIRIT', pick: 'Elimination Winner'),
        TeamEntry(name: 'Nigma Galaxy', clientName: 'NIGMA GALAXY', pick: 'Elimination Winner'),
        TeamEntry(name: 'Vici Gaming', clientName: 'VICI GAMING', pick: 'Elimination Winner'),
        TeamEntry(name: 'Aurora Gaming', clientName: 'AURORA GAMING', pick: 'Elimination Winner'),
        TeamEntry(name: 'Team Liquid', clientName: 'TEAM LIQUID', pick: 'Elimination Loser'),
        TeamEntry(name: 'LGD Gaming', clientName: 'LGD GAMING', pick: 'Elimination Loser'),
        TeamEntry(name: 'IRON WING', clientName: 'IRON WING', pick: 'Elimination Loser'),
        TeamEntry(name: 'Xtreme Gaming', clientName: 'XTREME GAMING', pick: 'Elimination Loser'),
        TeamEntry(name: 'OG', clientName: 'OG', pick: 'Elimination Loser'),
        TeamEntry(name: 'GamerLegion', clientName: 'GAMERLEGION', pick: '1-4'),
        TeamEntry(name: 'Team Resilience', clientName: 'TEAM RESILIENCE', pick: '1-4'),
        TeamEntry(name: 'HULIGANI', clientName: 'HULIGANI', pick: '0-4'),
      ];
}

class TrackerController extends ChangeNotifier {
  TrackerController(
    this.teams, {
    SharedPreferences? preferences,
    LiveResultsService? service,
  })  : _preferences = preferences,
        _service = service ?? LiveResultsService();

  List<TeamEntry> teams;
  final SharedPreferences? _preferences;
  final LiveResultsService _service;

  List<LiveSeries> series = const [];
  bool isSyncing = false;
  String syncStatus = 'offline';
  String syncMessage = 'Using saved data.';
  String source = 'OpenDota';
  DateTime? lastUpdated;
  int? leagueId;
  String? leagueName;
  int newSeriesCount = 0;

  factory TrackerController.memory({LiveResultsService? service}) =>
      TrackerController(TeamEntry.defaults(), service: service);

  static Future<TrackerController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      return TrackerController(TeamEntry.defaults(), preferences: prefs);
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final teams = (data['teams'] as List<dynamic>)
          .map((item) => TeamEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      final controller = TrackerController(teams, preferences: prefs);
      controller.syncStatus = data['syncStatus'] as String? ?? 'offline';
      controller.syncMessage = data['syncMessage'] as String? ?? 'Using saved data.';
      controller.source = data['source'] as String? ?? 'OpenDota';
      controller.lastUpdated = DateTime.tryParse(data['lastUpdated'] as String? ?? '');
      controller.leagueId = (data['leagueId'] as num?)?.toInt();
      controller.leagueName = data['leagueName'] as String?;
      controller.series = ((data['series'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LiveSeries.fromJson)
          .toList();
      return controller;
    } catch (_) {
      return TrackerController(TeamEntry.defaults(), preferences: prefs);
    }
  }

  int get settled => teams.where((team) => team.actual != 'Pending').length;
  int get hits => teams.where((team) => team.isExact).length;
  int get misses => teams.where((team) => team.isMiss).length;
  double get accuracy => settled == 0 ? 0 : hits / settled;
  int get active => teams.where((team) => team.wins + team.losses > 0).length;
  int get completedSeries => series.where((item) => item.completed).length;
  bool get hasLiveData => syncStatus == 'live' || syncStatus == 'ready';

  Future<void> synchronize() async {
    if (isSyncing) return;
    isSyncing = true;
    newSeriesCount = 0;
    notifyListeners();

    try {
      final before = series.where((item) => item.completed).map((item) => item.id).toSet();
      final feed = await _service.fetch();
      syncStatus = feed.status;
      syncMessage = feed.message;
      source = feed.source;
      lastUpdated = feed.generatedAt ?? DateTime.now().toUtc();
      leagueId = feed.leagueId;
      leagueName = feed.leagueName;
      series = feed.series;

      final after = series.where((item) => item.completed).map((item) => item.id).toSet();
      newSeriesCount = after.difference(before).length;
      _applyFeed(feed);
      await _save();
    } catch (error) {
      syncStatus = 'offline';
      syncMessage = 'Automatic refresh failed. Showing the last saved results.';
      await _save();
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  void _applyFeed(LiveFeed feed) {
    if (feed.teams.isEmpty) return;
    for (final incoming in feed.teams) {
      final key = _normalize(incoming.name);
      TeamEntry? local;
      for (final candidate in teams) {
        if (_normalize(candidate.name) == key ||
            _normalize(candidate.clientName) == key ||
            _normalize(candidate.clientName) == _normalize(incoming.clientName)) {
          local = candidate;
          break;
        }
      }
      if (local == null) continue;
      local
        ..wins = incoming.seriesWins
        ..losses = incoming.seriesLosses
        ..mapWins = incoming.mapWins
        ..mapLosses = incoming.mapLosses
        ..actual = incoming.actual
        ..lastMatchAt = incoming.lastMatchAt
        ..live = true;
    }
  }

  void changeWins(TeamEntry team, int amount) {
    team.wins = (team.wins + amount).clamp(0, 5).toInt();
    _inferTerminalResult(team);
    _save();
  }

  void changeLosses(TeamEntry team, int amount) {
    team.losses = (team.losses + amount).clamp(0, 5).toInt();
    _inferTerminalResult(team);
    _save();
  }

  void setActual(TeamEntry team, String actual) {
    team.actual = actual;
    _save();
  }

  void _inferTerminalResult(TeamEntry team) {
    if (team.wins == 4 && team.losses <= 1) {
      team.actual = team.losses == 0 ? '4-0' : '4-1';
    } else if (team.losses == 4 && team.wins <= 1) {
      team.actual = team.wins == 0 ? '0-4' : '1-4';
    }
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 2,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'teams': teams.map((team) => team.toJson()).toList(),
        'series': series.map((item) => item.toJson()).toList(),
      });

  bool importJson(String sourceText) {
    try {
      final data = jsonDecode(sourceText) as Map<String, dynamic>;
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
    series = const [];
    syncStatus = 'offline';
    syncMessage = 'Using default selections.';
    lastUpdated = null;
    leagueId = null;
    leagueName = null;
    _save();
  }

  Future<void> _save() async {
    notifyListeners();
    await _preferences?.setString(
      _storageKey,
      jsonEncode({
        'teams': teams.map((team) => team.toJson()).toList(),
        'series': series.map((item) => item.toJson()).toList(),
        'syncStatus': syncStatus,
        'syncMessage': syncMessage,
        'source': source,
        'lastUpdated': lastUpdated?.toUtc().toIso8601String(),
        'leagueId': leagueId,
        'leagueName': leagueName,
      }),
    );
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '');
