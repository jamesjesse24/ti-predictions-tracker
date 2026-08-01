import 'dart:convert';

import 'package:http/http.dart' as http;

import 'team_branding.dart';

/// Resolves actual team logos from OpenDota when the event feed has not yet
/// attached a logo_url. The caller should persist the returned map so this
/// endpoint is not requested on every app launch.
class TeamLogoService {
  TeamLogoService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri teamsEndpoint =
      Uri.parse('https://api.opendota.com/api/teams');

  final http.Client _client;

  Future<Map<String, String>> discoverLogos() async {
    final response = await _client.get(
      teamsEndpoint.replace(
        queryParameters: {
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ),
      headers: const {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError('Team logo request returned HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw const FormatException('OpenDota teams response is not a list.');
    }

    final resolved = <String, String>{};
    for (final item in decoded.whereType<Map<String, dynamic>>()) {
      final name = (item['name'] as String? ?? '').trim();
      final tag = (item['tag'] as String? ?? '').trim();
      final logo = _normalizeLogoUrl(item['logo_url'] as String?);
      if (logo == null) continue;

      for (final brand in teamBrands) {
        if (brand.matches(name) || brand.matches(tag)) {
          resolved.putIfAbsent(brand.canonicalName, () => logo);
          break;
        }
      }
    }

    return resolved;
  }

  void close() => _client.close();
}

String? _normalizeLogoUrl(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  if (trimmed.startsWith('/')) return 'https://www.opendota.com$trimmed';
  return trimmed;
}
