import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ti_predictions_tracker/live_service.dart';

void main() {
  test('successful fetch reports the current check time', () async {
    final remoteTimestamp = DateTime.utc(2026, 8, 1, 0, 15);
    final client = MockClient((request) async {
      expect(request.queryParameters['t'], isNotEmpty);
      expect(request.headers['Cache-Control'], 'no-cache');
      return http.Response(
        jsonEncode({
          'status': 'ready',
          'source': 'OpenDota',
          'message': 'No new completed series.',
          'generatedAt': remoteTimestamp.toIso8601String(),
          'leagueName': 'The International 2026',
          'leagueId': 19719,
          'teams': <Object>[],
          'series': <Object>[],
        }),
        200,
      );
    });
    final service = LiveResultsService(client: client);
    final before = DateTime.now().toUtc();

    final feed = await service.fetch();

    final after = DateTime.now().toUtc();
    expect(feed.generatedAt, isNotNull);
    expect(
      feed.generatedAt!.isBefore(before),
      isFalse,
      reason: 'The UI timestamp must represent this refresh, not the feed commit.',
    );
    expect(feed.generatedAt!.isAfter(after), isFalse);
    expect(feed.message, contains('Tournament data changed'));
    expect(feed.message, contains('No new completed series.'));
    service.close();
  });
}
