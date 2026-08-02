import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ti_predictions_tracker/team_branding.dart';
import 'package:ti_predictions_tracker/team_logo_service.dart';

void main() {
  test('client aliases resolve to canonical team brands', () {
    expect(teamBrandFor('TEAM VISION').canonicalName, 'PARIVISION');
    expect(teamBrandFor('BOOMBOYS').canonicalName, 'BetBoom Team');
    expect(teamBrandFor('L1ga Team').displayName, 'HULIGANI');
    expect(teamBrandFor('1win').displayName, 'IRON WING');
  });

  test('unknown teams receive a stable fallback code', () {
    expect(teamBrandFor('Alpha Squad').code, 'AS');
    expect(teamBrandFor('Z').code, 'Z');
  });

  test('logo service maps OpenDota names and tags to configured brands', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/teams');
      return http.Response(
        jsonEncode([
          {
            'name': 'PARIVISION',
            'tag': 'PARI',
            'logo_url': '//cdn.example/parivision.png',
          },
          {
            'name': 'BetBoom Team',
            'tag': 'BB',
            'logo_url': 'https://cdn.example/betboom.png',
          },
          {
            'name': 'Unrelated Team',
            'tag': 'OTHER',
            'logo_url': 'https://cdn.example/other.png',
          },
        ]),
        200,
      );
    });
    final service = TeamLogoService(client: client);

    final logos = await service.discoverLogos();

    expect(logos['PARIVISION'], 'https://cdn.example/parivision.png');
    expect(logos['BetBoom Team'], 'https://cdn.example/betboom.png');
    expect(logos.containsValue('https://cdn.example/other.png'), isFalse);
    service.close();
  });
}
