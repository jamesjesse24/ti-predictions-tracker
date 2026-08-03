import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ti_predictions_tracker/tracker_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('final post-7.41d board preserves the required prediction buckets', () {
    final teams = TeamEntry.defaults();
    final counts = <String, int>{};
    for (final team in teams) {
      counts.update(team.pick, (value) => value + 1, ifAbsent: () => 1);
    }

    expect(teams, hasLength(16));
    expect(counts['4-0'], 1);
    expect(counts['4-1'], 2);
    expect(counts['Elimination Winner'], 5);
    expect(counts['Elimination Loser'], 5);
    expect(counts['1-4'], 2);
    expect(counts['0-4'], 1);

    final byName = {for (final team in teams) team.name: team.pick};
    expect(byName['PARIVISION'], '4-0');
    expect(byName['Team Yandex'], '4-1');
    expect(byName['BetBoom Team'], '4-1');
    expect(byName['Team Liquid'], 'Elimination Winner');
    expect(byName['Team Resilience'], 'Elimination Winner');
    expect(byName['Nigma Galaxy'], 'Elimination Loser');
    expect(byName['IRON WING'], 'Elimination Loser');
    expect(byName['OG'], 'Elimination Loser');
    expect(byName['Xtreme Gaming'], '1-4');
    expect(byName['HULIGANI'], '0-4');
  });

  test('load migrates version 2 picks while retaining live records', () async {
    final oldTeams = TeamEntry.defaults()
        .map((team) => Map<String, dynamic>.from(team.toJson()))
        .toList();

    void changePick(String name, String pick) {
      final team = oldTeams.firstWhere((item) => item['name'] == name);
      team['pick'] = pick;
    }

    changePick('Nigma Galaxy', 'Elimination Winner');
    changePick('Team Liquid', 'Elimination Loser');
    changePick('IRON WING', 'Elimination Winner');
    changePick('Xtreme Gaming', 'Elimination Loser');
    changePick('OG', '1-4');
    changePick('Team Resilience', 'Elimination Loser');

    final ironWing =
        oldTeams.firstWhere((item) => item['name'] == 'IRON WING');
    ironWing
      ..['wins'] = 2
      ..['losses'] = 1
      ..['mapWins'] = 5
      ..['mapLosses'] = 3
      ..['actual'] = 'Pending'
      ..['live'] = true
      ..['logoUrl'] = 'https://example.com/iron-wing.png';

    SharedPreferences.setMockInitialValues({
      'ti_tracker_state_v4': jsonEncode({
        'predictionDataVersion': 2,
        'predictionPatch': '7.41d',
        'teams': oldTeams,
        'series': <Object>[],
        'syncStatus': 'ready',
        'syncMessage': 'Saved before the final prediction refresh.',
      }),
    });

    final controller = await TrackerController.load();
    final migratedIronWing = controller.teamByName('IRON WING');

    expect(predictionDataVersion, 3);
    expect(predictionPatch, '7.41d');
    expect(migratedIronWing?.pick, 'Elimination Loser');
    expect(migratedIronWing?.wins, 2);
    expect(migratedIronWing?.losses, 1);
    expect(migratedIronWing?.mapWins, 5);
    expect(migratedIronWing?.mapLosses, 3);
    expect(migratedIronWing?.live, isTrue);
    expect(
      migratedIronWing?.logoUrl,
      'https://example.com/iron-wing.png',
    );
    expect(controller.teamByName('Team Liquid')?.pick, 'Elimination Winner');
    expect(
      controller.teamByName('Team Resilience')?.pick,
      'Elimination Winner',
    );
    expect(controller.teamByName('Nigma Galaxy')?.pick, 'Elimination Loser');
    expect(controller.teamByName('OG')?.pick, 'Elimination Loser');
    expect(controller.teamByName('Xtreme Gaming')?.pick, '1-4');

    final preferences = await SharedPreferences.getInstance();
    final stored = jsonDecode(
      preferences.getString('ti_tracker_state_v4')!,
    ) as Map<String, dynamic>;
    expect(stored['predictionDataVersion'], predictionDataVersion);
    expect(stored['predictionPatch'], predictionPatch);

    controller.dispose();
  });
}
