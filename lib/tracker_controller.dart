import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_models.dart';
import 'live_service.dart';
import 'notification_service.dart';
import 'team_branding.dart';
import 'team_logo_service.dart';

const resultBuckets = <String>[
  'Pending',
  '4-0',
  '4-1',
  'Elimination Winner',
  'Elimination Loser',
  '1-4',
  '0-4',
];

const predictionDataVersion = 3;
const predictionPatch = '7.41d';
const predictionDataUpdatedAt = '2026-08-03';

const _storageKey = 'ti_tracker_state_v4';
const _legacyStorageKey = 'ti_tracker_state_v3';
const _teamLogoCacheKey = 'ti_team_logo_cache_v1';

class TeamEntry {
  TeamEntry({
    required this.name,
    required this.clientName,
    required this.pick,
    this.logoUrl,
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
  String? logoUrl;
  int wins;
  int losses;
  int mapWins;
  int mapLosses;
  String actual;
  bool live;
  DateTime? lastMatchAt;

  bool get isExact => actual != 'Pending' && actual == pick;
  bool get isMiss => actual != 'Pending' && actual != pick;

  String get initials =>
      teamBrandFor(name, alternateName: clientName).code;

  Map<String, dynamic> toJson() => {
        'name': name,
        'clientName': clientName,
        'pick': pick,
        'logoUrl': logoUrl,
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
        pick:
            json['pick'] as String? ?? json['predicted'] as String? ?? 'Pending',
        logoUrl: _cleanUrl(json['logoUrl'] as String?),
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        mapWins: (json['mapWins'] as num?)?.toInt() ?? 0,
        mapLosses: (json['mapLosses'] as num?)?.toInt() ?? 0,
        actual: json['actual'] as String? ?? 'Pending',
        live: json['live'] as bool? ?? false,
        lastMatchAt:
            DateTime.tryParse(json['lastMatchAt'] as String? ?? ''),
      );

  static List<TeamEntry> defaults() => [
        TeamEntry(
          name: 'PARIVISION',
          clientName: 'TEAM VISION',
          pick: '4-0',
        ),
        TeamEntry(
          name: 'Team Yandex',
          clientName: 'TEAM YANDEX',
          pick: '4-1',
        ),
        TeamEntry(
          name: 'BetBoom Team',
          clientName: 'BOOMBOYS',
          pick: '4-1',
        ),
        TeamEntry(
          name: 'Team Falcons',
          clientName: 'TEAM FALCONS',
          pick: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Team Spirit',
          clientName: 'TEAM SPIRIT',
          pick: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Nigma Galaxy',
          clientName: 'NIGMA GALAXY',
          pick: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'Vici Gaming',
          clientName: 'VICI GAMING',
          pick: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'Aurora Gaming',
          clientName: 'AURORA GAMING',
          pick: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'Team Liquid',
          clientName: 'TEAM LIQUID',
          pick: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'LGD Gaming',
          clientName: 'LGD GAMING',
          pick: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'IRON WING',
          clientName: 'IRON WING',
          pick: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'Xtreme Gaming',
          clientName: 'XTREME GAMING',
          pick: '1-4',
        ),
        TeamEntry(
          name: 'OG',
          clientName: 'OG',
          pick: 'Elimination Loser',
        ),
        TeamEntry(
          name: 'GamerLegion',
          clientName: 'GAMERLEGION',
          pick: '1-4',
        ),
        TeamEntry(
          name: 'Team Resilience',
          clientName: 'TEAM RESILIENCE',
          pick: 'Elimination Winner',
        ),
        TeamEntry(
          name: 'HULIGANI',
          clientName: 'HULIGANI',
          pick: '0-4',
        ),
      ];
}

class TrackerController extends ChangeNotifier {
  TrackerController(
    this.teams, {
    SharedPreferences? preferences,
    LiveResultsService? service,
    NotificationService? notifications,
    TeamLogoService? logoService,
  })  : _preferences = preferences,
        _service = service ?? LiveResultsService(),
        _notifications = notifications ?? NotificationService(),
        _logoService = logoService ?? TeamLogoService();

  List<TeamEntry> teams;
  final SharedPreferences? _preferences;
  final LiveResultsService _service;
  final NotificationService _notifications;
  final TeamLogoService _logoService;

  List<LiveSeries> series = const [];
  bool isSyncing = false;
  bool isRefreshingLogos = false;
  bool notificationsEnabled = false;
  bool notificationPermissionDenied = false;
  String syncStatus = 'offline';
  String syncMessage = 'Using saved data.';
  String logoMessage = 'Team logos not checked.';
  String source = 'OpenDota';
  DateTime? lastChecked;
  DateTime? feedUpdatedAt;
  DateTime? lastLogoUpdated;
  int? leagueId;
  String? leagueName;
  int newSeriesCount = 0;

  DateTime? get lastUpdated => lastChecked;

  factory TrackerController.memory({
    LiveResultsService? service,
    NotificationService? notifications,
    TeamLogoService? logoService,
  }) =>
      TrackerController(
        TeamEntry.defaults(),
        service: service,
        notifications: notifications,
        logoService: logoService,
      );

  static Future<TrackerController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString(_storageKey) ?? prefs.getString(_legacyStorageKey);
    final controller = TrackerController(
      TeamEntry.defaults(),
      preferences: prefs,
    );
    controller.notificationsEnabled =
        prefs.getBool(notificationsEnabledKey) ?? false;

    var migratedPredictions = false;
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final savedTeams = (data['teams'] as List<dynamic>)
            .map(
              (item) => TeamEntry.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        final savedPredictionVersion =
            (data['predictionDataVersion'] as num?)?.toInt() ?? 1;
        if (savedPredictionVersion < predictionDataVersion) {
          controller.teams = _mergeCurrentPredictions(savedTeams);
          migratedPredictions = true;
        } else {
          controller.teams = savedTeams;
        }
        controller.syncStatus = data['syncStatus'] as String? ?? 'offline';
        controller.syncMessage =
            data['syncMessage'] as String? ?? 'Using saved data.';
        controller.logoMessage =
            data['logoMessage'] as String? ?? 'Using cached team branding.';
        controller.source = data['source'] as String? ?? 'OpenDota';
        controller.lastChecked = DateTime.tryParse(
          data['lastChecked'] as String? ??
              data['lastUpdated'] as String? ??
              '',
        );
        controller.feedUpdatedAt =
            DateTime.tryParse(data['feedUpdatedAt'] as String? ?? '');
        controller.lastLogoUpdated =
            DateTime.tryParse(data['lastLogoUpdated'] as String? ?? '');
        controller.leagueId = (data['leagueId'] as num?)?.toInt();
        controller.leagueName = data['leagueName'] as String?;
        controller.series =
            ((data['series'] as List<dynamic>?) ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(LiveSeries.fromJson)
                .toList();
      } catch (_) {
        controller.teams = TeamEntry.defaults();
        migratedPredictions = true;
      }
    } else {
      migratedPredictions = true;
    }

    controller._restoreLogoCache();
    if (migratedPredictions) {
      controller.syncMessage =
          'Prediction board refreshed for patch $predictionPatch form.';
      await controller._save();
    }
    return controller;
  }

  int get settled =>
      teams.where((team) => team.actual != 'Pending').length;
  int get hits => teams.where((team) => team.isExact).length;
  int get misses => teams.where((team) => team.isMiss).length;
  double get accuracy => settled == 0 ? 0 : hits / settled;
  int get active =>
      teams.where((team) => team.wins + team.losses > 0).length;
  int get completedSeries =>
      series.where((item) => item.completed).length;
  int get unresolvedLogos => teams
      .where((team) => team.logoUrl == null || team.logoUrl!.isEmpty)
      .length;
  bool get hasLiveData => syncStatus == 'live' || syncStatus == 'ready';

  List<LiveSeries> get recentCompletedSeries {
    final items = series.where((item) => item.completed).toList()
      ..sort(
        (a, b) => (b.startedAt ?? DateTime(1970))
            .compareTo(a.startedAt ?? DateTime(1970)),
      );
    return items;
  }

  TeamEntry? teamByName(String value) {
    final key = _normalize(value);
    for (final team in teams) {
      final brand = teamBrandFor(
        team.name,
        alternateName: team.clientName,
      );
      if (_normalize(team.name) == key ||
          _normalize(team.clientName) == key ||
          brand.matches(value)) {
        return team;
      }
    }
    return null;
  }

  Future<void> initializeNotifications() => _notifications.initialize();

  Future<bool> setNotificationsEnabled(bool enabled) async {
    notificationPermissionDenied = false;
    if (enabled) {
      final granted = await _notifications.requestPermission();
      if (!granted) {
        notificationPermissionDenied = true;
        notificationsEnabled = false;
        await _notifications.setEnabled(false);
        notifyListeners();
        return false;
      }
      await _notifications.setEnabled(
        true,
        currentSeriesIds:
            series.where((item) => item.completed).map((item) => item.id),
      );
      notificationsEnabled = true;
    } else {
      await _notifications.setEnabled(false);
      notificationsEnabled = false;
    }
    notifyListeners();
    return true;
  }

  Future<void> sendTestNotification() =>
      _notifications.showTestNotification();

  Future<void> synchronize() async {
    if (isSyncing) return;
    isSyncing = true;
    newSeriesCount = 0;
    notifyListeners();

    try {
      final before = series
          .where((item) => item.completed)
          .map((item) => item.id)
          .toSet();
      final feed = await _service.fetch();
      syncStatus = feed.status;
      syncMessage = feed.message;
      source = feed.source;
      lastChecked = DateTime.now().toUtc();
      feedUpdatedAt = feed.generatedAt;
      leagueId = feed.leagueId;
      leagueName = feed.leagueName;
      series = feed.series;

      final after = series
          .where((item) => item.completed)
          .map((item) => item.id)
          .toSet();
      newSeriesCount = after.difference(before).length;
      _applyFeed(feed);
      await _notifications.notifyForNewSeries(feed.series);
      await _save();
      await hydrateTeamLogos();
    } catch (_) {
      syncStatus = 'offline';
      syncMessage =
          'Refresh failed. Showing the last saved tournament data.';
      await _save();
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> hydrateTeamLogos({bool force = false}) async {
    if (isRefreshingLogos) return;
    if (!force && unresolvedLogos == 0) return;

    isRefreshingLogos = true;
    logoMessage = 'Resolving team identities…';
    notifyListeners();

    try {
      final discovered = await _logoService.discoverLogos();
      var updated = 0;
      for (final team in teams) {
        final brand = teamBrandFor(
          team.name,
          alternateName: team.clientName,
        );
        final url = discovered[brand.canonicalName];
        if (url != null && url.isNotEmpty && team.logoUrl != url) {
          team.logoUrl = url;
          updated += 1;
        }
      }
      lastLogoUpdated = DateTime.now().toUtc();
      logoMessage = unresolvedLogos == 0
          ? 'All team identities resolved.'
          : '${teams.length - unresolvedLogos}/${teams.length} team logos resolved.';
      await _persistLogoCache();
      if (updated > 0) await _save();
    } catch (_) {
      logoMessage = unresolvedLogos == teams.length
          ? 'Logo service unavailable. Using branded fallbacks.'
          : 'Some logos are cached; unresolved teams use branded fallbacks.';
    } finally {
      isRefreshingLogos = false;
      notifyListeners();
    }
  }

  Future<void> clearLogoCache() async {
    for (final team in teams) {
      team.logoUrl = null;
    }
    lastLogoUpdated = null;
    logoMessage = 'Team logo cache cleared.';
    await _preferences?.remove(_teamLogoCacheKey);
    await _save();
  }

  void _restoreLogoCache() {
    final raw = _preferences?.getString(_teamLogoCacheKey);
    if (raw == null) return;
    try {
      final cached = Map<String, dynamic>.from(jsonDecode(raw));
      for (final team in teams) {
        final brand = teamBrandFor(
          team.name,
          alternateName: team.clientName,
        );
        final url = _cleanUrl(cached[brand.canonicalName] as String?);
        if (url != null && team.logoUrl == null) team.logoUrl = url;
      }
    } catch (_) {
      // Invalid visual cache is ignored.
    }
  }

  Future<void> _persistLogoCache() async {
    final cache = <String, String>{};
    for (final team in teams) {
      final url = _cleanUrl(team.logoUrl);
      if (url == null) continue;
      final brand = teamBrandFor(
        team.name,
        alternateName: team.clientName,
      );
      cache[brand.canonicalName] = url;
    }
    await _preferences?.setString(_teamLogoCacheKey, jsonEncode(cache));
  }

  void _applyFeed(LiveFeed feed) {
    if (feed.teams.isEmpty) return;
    for (final incoming in feed.teams) {
      final local =
          teamByName(incoming.name) ?? teamByName(incoming.clientName);
      if (local == null) continue;
      local
        ..wins = incoming.seriesWins
        ..losses = incoming.seriesLosses
        ..mapWins = incoming.mapWins
        ..mapLosses = incoming.mapLosses
        ..actual = incoming.actual
        ..lastMatchAt = incoming.lastMatchAt
        ..live = true;
      if (incoming.logoUrl != null) local.logoUrl = incoming.logoUrl;
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
        'schemaVersion': 5,
        'predictionDataVersion': predictionDataVersion,
        'predictionPatch': predictionPatch,
        'predictionDataUpdatedAt': predictionDataUpdatedAt,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'teams': teams.map((team) => team.toJson()).toList(),
        'series': series.map((item) => item.toJson()).toList(),
      });

  bool importJson(String sourceText) {
    try {
      final data = jsonDecode(sourceText) as Map<String, dynamic>;
      final imported = (data['teams'] as List<dynamic>)
          .map(
            (item) => TeamEntry.fromJson(item as Map<String, dynamic>),
          )
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
    syncMessage =
        'Using patch $predictionPatch selections updated $predictionDataUpdatedAt.';
    lastChecked = null;
    feedUpdatedAt = null;
    leagueId = null;
    leagueName = null;
    _restoreLogoCache();
    _save();
  }

  Future<void> _save() async {
    notifyListeners();
    await _preferences?.setString(
      _storageKey,
      jsonEncode({
        'predictionDataVersion': predictionDataVersion,
        'predictionPatch': predictionPatch,
        'predictionDataUpdatedAt': predictionDataUpdatedAt,
        'teams': teams.map((team) => team.toJson()).toList(),
        'series': series.map((item) => item.toJson()).toList(),
        'syncStatus': syncStatus,
        'syncMessage': syncMessage,
        'logoMessage': logoMessage,
        'source': source,
        'lastChecked': lastChecked?.toUtc().toIso8601String(),
        'feedUpdatedAt': feedUpdatedAt?.toUtc().toIso8601String(),
        'lastLogoUpdated': lastLogoUpdated?.toUtc().toIso8601String(),
        'leagueId': leagueId,
        'leagueName': leagueName,
      }),
    );
  }

  @override
  void dispose() {
    _logoService.close();
    _service.close();
    super.dispose();
  }
}

List<TeamEntry> _mergeCurrentPredictions(List<TeamEntry> savedTeams) {
  final byName = <String, TeamEntry>{};
  for (final team in savedTeams) {
    byName[_normalize(team.name)] = team;
    byName[_normalize(team.clientName)] = team;
  }

  return TeamEntry.defaults().map((current) {
    final saved = byName[_normalize(current.name)] ??
        byName[_normalize(current.clientName)];
    if (saved == null) return current;

    return TeamEntry(
      name: current.name,
      clientName: current.clientName,
      pick: current.pick,
      logoUrl: saved.logoUrl,
      wins: saved.wins,
      losses: saved.losses,
      mapWins: saved.mapWins,
      mapLosses: saved.mapLosses,
      actual: saved.actual,
      live: saved.live,
      lastMatchAt: saved.lastMatchAt,
    );
  }).toList();
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String? _cleanUrl(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
