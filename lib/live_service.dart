import 'dart:convert';

import 'package:http/http.dart' as http;

import 'live_models.dart';

class LiveResultsService {
  LiveResultsService({http.Client? client}) : _client = client ?? http.Client();

  static const feedUrl =
      'https://raw.githubusercontent.com/jamesjesse24/ti-predictions-tracker/main/data/live.json';

  final http.Client _client;

  Future<LiveFeed> fetch() async {
    final uri = Uri.parse(feedUrl).replace(
      queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
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
    return LiveFeed.fromJson(decoded);
  }

  void close() => _client.close();
}
