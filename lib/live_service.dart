import 'dart:convert';

import 'package:http/http.dart' as http;

import 'live_models.dart';

class LiveResultsService {
  LiveResultsService({http.Client? client}) : _client = client ?? http.Client();

  static const feedUrl =
      'https://raw.githubusercontent.com/jamesjesse24/ti-predictions-tracker/main/data/live.json';

  final http.Client _client;

  Future<LiveFeed> fetch() async {
    final checkedAt = DateTime.now().toUtc();
    final uri = Uri.parse(feedUrl).replace(
      queryParameters: {'t': checkedAt.millisecondsSinceEpoch.toString()},
    );
    final response = await _client.get(
      uri,
      headers: const {'Cache-Control': 'no-cache'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw StateError('Live feed returned HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Live feed is not a JSON object.');
    }

    final remoteFeed = LiveFeed.fromJson(decoded);
    final remoteUpdatedAt = remoteFeed.generatedAt;
    final message = remoteUpdatedAt == null
        ? remoteFeed.message
        : '${remoteFeed.message} Tournament data changed '
            '${_formatLocalTimestamp(remoteUpdatedAt)}.';

    // `generatedAt` is consumed by the UI as the successful synchronization
    // time. The repository feed timestamp is preserved in the status message,
    // so users can distinguish a fresh check from a new match-data publication.
    return LiveFeed(
      status: remoteFeed.status,
      source: remoteFeed.source,
      message: message,
      generatedAt: checkedAt,
      leagueName: remoteFeed.leagueName,
      leagueId: remoteFeed.leagueId,
      teams: remoteFeed.teams,
      series: remoteFeed.series,
    );
  }

  void close() => _client.close();
}

String _formatLocalTimestamp(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day} $hour:$minute $suffix';
}
