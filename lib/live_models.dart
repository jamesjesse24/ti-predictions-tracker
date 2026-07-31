class LiveTeamResult {
  const LiveTeamResult({
    required this.name,
    required this.clientName,
    required this.seriesWins,
    required this.seriesLosses,
    required this.mapWins,
    required this.mapLosses,
    required this.actual,
    this.lastMatchAt,
  });

  final String name;
  final String clientName;
  final int seriesWins;
  final int seriesLosses;
  final int mapWins;
  final int mapLosses;
  final String actual;
  final DateTime? lastMatchAt;

  factory LiveTeamResult.fromJson(Map<String, dynamic> json) => LiveTeamResult(
        name: json['name'] as String? ?? '',
        clientName: json['clientName'] as String? ?? '',
        seriesWins: (json['seriesWins'] as num?)?.toInt() ?? 0,
        seriesLosses: (json['seriesLosses'] as num?)?.toInt() ?? 0,
        mapWins: (json['mapWins'] as num?)?.toInt() ?? 0,
        mapLosses: (json['mapLosses'] as num?)?.toInt() ?? 0,
        actual: json['actual'] as String? ?? 'Pending',
        lastMatchAt: DateTime.tryParse(json['lastMatchAt'] as String? ?? ''),
      );
}

class LiveSeries {
  const LiveSeries({
    required this.id,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.winner,
    required this.stage,
    required this.completed,
    this.startedAt,
  });

  final String id;
  final String teamA;
  final String teamB;
  final int scoreA;
  final int scoreB;
  final String winner;
  final String stage;
  final bool completed;
  final DateTime? startedAt;

  factory LiveSeries.fromJson(Map<String, dynamic> json) => LiveSeries(
        id: json['id'].toString(),
        teamA: json['teamA'] as String? ?? 'Unknown',
        teamB: json['teamB'] as String? ?? 'Unknown',
        scoreA: (json['scoreA'] as num?)?.toInt() ?? 0,
        scoreB: (json['scoreB'] as num?)?.toInt() ?? 0,
        winner: json['winner'] as String? ?? '',
        stage: json['stage'] as String? ?? 'Swiss',
        completed: json['completed'] as bool? ?? false,
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'teamA': teamA,
        'teamB': teamB,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'winner': winner,
        'stage': stage,
        'completed': completed,
        'startedAt': startedAt?.toUtc().toIso8601String(),
      };
}

class LiveFeed {
  const LiveFeed({
    required this.status,
    required this.source,
    required this.message,
    required this.teams,
    required this.series,
    this.generatedAt,
    this.leagueName,
    this.leagueId,
  });

  final String status;
  final String source;
  final String message;
  final DateTime? generatedAt;
  final String? leagueName;
  final int? leagueId;
  final List<LiveTeamResult> teams;
  final List<LiveSeries> series;

  bool get hasLiveData => status == 'live' || status == 'ready';

  factory LiveFeed.fromJson(Map<String, dynamic> json) => LiveFeed(
        status: json['status'] as String? ?? 'waiting',
        source: json['source'] as String? ?? 'OpenDota',
        message: json['message'] as String? ?? '',
        generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? ''),
        leagueName: json['leagueName'] as String?,
        leagueId: (json['leagueId'] as num?)?.toInt(),
        teams: ((json['teams'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LiveTeamResult.fromJson)
            .toList(),
        series: ((json['series'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LiveSeries.fromJson)
            .toList(),
      );
}
