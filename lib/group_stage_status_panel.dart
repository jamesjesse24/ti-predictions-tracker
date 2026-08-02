import 'package:flutter/material.dart';

import 'team_branding.dart';
import 'tracker_controller.dart';

const _gold = Color(0xFFD8A84E);
const _goldSoft = Color(0xFFFFD98A);
const _surface = Color(0xFF11141A);
const _surfaceRaised = Color(0xFF171B22);
const _border = Color(0xFF282E38);
const _muted = Color(0xFF929AA8);
const _success = Color(0xFF4ADE80);
const _danger = Color(0xFFFB7185);
const _blue = Color(0xFF60A5FA);

class GroupStageStatusPanel extends StatelessWidget {
  const GroupStageStatusPanel({super.key, required this.controller});

  final TrackerController controller;

  @override
  Widget build(BuildContext context) {
    final teams = [...controller.teams]..sort(_compareTeams);
    final settled = teams.where((team) => team.actual != 'Pending').length;
    final direct = teams.where(_isDirect).length;
    final playInWinners = teams
        .where((team) => team.actual == 'Elimination Winner')
        .length;
    final eliminated = teams.where(_isOut).length;
    final active = teams
        .where(
          (team) =>
              team.actual == 'Pending' && team.wins + team.losses > 0,
        )
        .length;
    final completedSwiss = controller.series
        .where(
          (series) =>
              series.completed &&
              series.stage.toLowerCase().contains('swiss'),
        )
        .length;
    final started = completedSwiss > 0 || settled > 0 || active > 0;
    final complete = teams.isNotEmpty && settled == teams.length;
    final status = complete
        ? 'COMPLETE'
        : started
            ? 'IN PROGRESS'
            : 'WAITING';
    final statusColor = complete
        ? _success
        : started
            ? _blue
            : _gold;
    final progress = teams.isEmpty ? 0.0 : settled / teams.length;
    final visible = teams
        .where(
          (team) =>
              team.wins + team.losses > 0 || team.actual != 'Pending',
        )
        .take(8)
        .toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF18140C), _surface],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Group stage',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(label: status, color: statusColor),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '$settled/${teams.length} settled',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      '$completedSwiss Swiss series',
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.white10,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final metrics = [
                  _Metric(
                    label: 'DIRECT',
                    value: direct,
                    color: _success,
                  ),
                  _Metric(
                    label: 'PLAY-IN W',
                    value: playInWinners,
                    color: _gold,
                  ),
                  _Metric(label: 'ACTIVE', value: active, color: _blue),
                  _Metric(label: 'OUT', value: eliminated, color: _danger),
                ];

                if (constraints.maxWidth < 330) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: metrics[0]),
                          const SizedBox(width: 7),
                          Expanded(child: metrics[1]),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(child: metrics[2]),
                          const SizedBox(width: 7),
                          Expanded(child: metrics[3]),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: metrics[0]),
                    const SizedBox(width: 7),
                    Expanded(child: metrics[1]),
                    const SizedBox(width: 7),
                    Expanded(child: metrics[2]),
                    const SizedBox(width: 7),
                    Expanded(child: metrics[3]),
                  ],
                );
              },
            ),
          ),
          if (!started)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _EmptyTable(),
            )
          else ...[
            const Divider(height: 1),
            ...visible.indexed.map(
              (entry) => _StandingRow(
                rank: entry.$1 + 1,
                team: entry.$2,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(
        color: _surfaceRaised,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withAlpha(34)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: _muted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.rank, required this.team});

  final int rank;
  final TeamEntry team;

  @override
  Widget build(BuildContext context) {
    final status = _teamStatus(team);
    final statusColor = _teamStatusColor(team);
    final brand = teamBrandFor(
      team.name,
      alternateName: team.clientName,
    );
    final mapDiff = team.mapWins - team.mapLosses;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: brand.primary.withAlpha(48)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [brand.primary.withAlpha(15), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ),
          const SizedBox(width: 7),
          TeamLogo(
            name: team.name,
            alternateName: team.clientName,
            logoUrl: team.logoUrl,
            size: 38,
            showGlow: false,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Maps ${team.mapWins}-${team.mapLosses} • ${mapDiff >= 0 ? '+' : ''}$mapDiff',
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
              ],
            ),
          ),
          Text(
            '${team.wins}-${team.losses}',
            style: TextStyle(
              color: brand.primary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: _StatusBadge(label: status, color: statusColor),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyTable extends StatelessWidget {
  const _EmptyTable();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_empty_rounded, color: _gold, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Standings unavailable',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  'Unlocks after the first official series',
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isDirect(TeamEntry team) =>
    team.actual == '4-0' || team.actual == '4-1';

bool _isOut(TeamEntry team) =>
    team.actual == '0-4' ||
    team.actual == '1-4' ||
    team.actual == 'Elimination Loser';

int _compareTeams(TeamEntry a, TeamEntry b) {
  final aGroup = _sortGroup(a);
  final bGroup = _sortGroup(b);
  if (aGroup != bGroup) return aGroup.compareTo(bGroup);
  if (a.wins != b.wins) return b.wins.compareTo(a.wins);
  if (a.losses != b.losses) return a.losses.compareTo(b.losses);
  final aDiff = a.mapWins - a.mapLosses;
  final bDiff = b.mapWins - b.mapLosses;
  if (aDiff != bDiff) return bDiff.compareTo(aDiff);
  return a.clientName.compareTo(b.clientName);
}

int _sortGroup(TeamEntry team) {
  if (_isDirect(team)) return 0;
  if (team.actual == 'Elimination Winner') return 1;
  if (team.actual == 'Pending' && team.wins + team.losses > 0) return 2;
  if (_isOut(team)) return 3;
  return 4;
}

String _teamStatus(TeamEntry team) {
  if (_isDirect(team)) return 'DIRECT';
  if (team.actual == 'Elimination Winner') return 'PLAY-IN W';
  if (_isOut(team)) return 'OUT';
  return team.wins + team.losses > 0 ? 'ACTIVE' : 'WAITING';
}

Color _teamStatusColor(TeamEntry team) {
  if (_isDirect(team)) return _success;
  if (team.actual == 'Elimination Winner') return _gold;
  if (_isOut(team)) return _danger;
  return team.wins + team.losses > 0 ? _blue : _muted;
}
