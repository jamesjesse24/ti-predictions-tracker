import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'tracker_controller.dart';

const _stageGold = Color(0xFFD9AA4F);
const _stageGoldLight = Color(0xFFFFE0A0);
const _stagePanel = Color(0xFF11141A);
const _stagePanelRaised = Color(0xFF181C24);
const _stageMuted = Color(0xFF97A0AF);
const _stageLine = Color(0xFF272D38);
const _stageSuccess = Color(0xFF4ADE80);
const _stageDanger = Color(0xFFFB7185);
const _stageBlue = Color(0xFF60A5FA);
const _stageAmber = Color(0xFFF59E0B);

class GroupStageStatusPanel extends StatefulWidget {
  const GroupStageStatusPanel({super.key, required this.controller});

  final TrackerController controller;

  @override
  State<GroupStageStatusPanel> createState() => _GroupStageStatusPanelState();
}

class _GroupStageStatusPanelState extends State<GroupStageStatusPanel> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final teams = [...widget.controller.teams]..sort(_compareTeams);
    final directQualified = teams.where(_isDirectQualified).toList();
    final eliminationWinners = teams
        .where((team) => team.actual == 'Elimination Winner')
        .toList();
    final eliminated = teams.where(_isEliminated).toList();
    final active = teams
        .where(
          (team) => team.actual == 'Pending' && team.wins + team.losses > 0,
        )
        .toList();
    final settled = teams.where((team) => team.actual != 'Pending').length;
    final completedSwiss = widget.controller.series
        .where(
          (series) =>
              series.completed &&
              series.stage.toLowerCase().contains('swiss'),
        )
        .length;
    final progress = teams.isEmpty ? 0.0 : settled / teams.length;
    final complete = teams.isNotEmpty && settled == teams.length;
    final started = completedSwiss > 0 || active.isNotEmpty || settled > 0;
    final visibleTeams = expanded ? teams : teams.take(6).toList();

    final statusLabel = complete
        ? 'COMPLETE'
        : started
            ? 'IN PROGRESS'
            : 'WAITING';
    final statusColor = complete
        ? _stageSuccess
        : started
            ? _stageBlue
            : _stageAmber;

    return Container(
      decoration: BoxDecoration(
        color: _stagePanel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: statusColor.withAlpha(70)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF302410), Color(0xFF171B24)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(24),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: statusColor.withAlpha(80)),
                        ),
                        child: Icon(
                          Icons.account_tree_rounded,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Group Stage Status',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Live advancement and elimination picture',
                              style: TextStyle(
                                color: _stageMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(label: statusLabel, color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          complete
                              ? 'All ${teams.length} teams have a final group-stage outcome.'
                              : started
                                  ? '$settled of ${teams.length} teams are settled across $completedSwiss completed Swiss series.'
                                  : 'Waiting for the first official group-stage series.',
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: Colors.white10,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _StageMetric(
                      label: 'DIRECT',
                      value: '${directQualified.length}',
                      icon: Icons.rocket_launch_rounded,
                      color: _stageSuccess,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StageMetric(
                      label: 'PLAY-IN W',
                      value: '${eliminationWinners.length}',
                      icon: Icons.emoji_events_rounded,
                      color: _stageGold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StageMetric(
                      label: 'ACTIVE',
                      value: '${active.length}',
                      icon: Icons.bolt_rounded,
                      color: _stageBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StageMetric(
                      label: 'OUT',
                      value: '${eliminated.length}',
                      icon: Icons.close_rounded,
                      color: _stageDanger,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _stageLine),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'CURRENT TABLE',
                      style: TextStyle(
                        color: _stageMuted,
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '$completedSwiss SERIES',
                    style: const TextStyle(
                      color: _stageGold,
                      fontSize: 10,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (!started)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _WaitingState(),
              )
            else ...[
              ...visibleTeams.indexed.map(
                (entry) => _StandingRow(
                  rank: entry.$1 + 1,
                  team: entry.$2,
                ),
              ),
              if (teams.length > 6)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 5, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => setState(() => expanded = !expanded),
                      icon: Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                      label: Text(
                        expanded
                            ? 'SHOW TOP 6'
                            : 'VIEW ALL ${teams.length} TEAMS',
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageMetric extends StatelessWidget {
  const _StageMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
      decoration: BoxDecoration(
        color: _stagePanelRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(42)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(
              color: _stageMuted,
              fontSize: 8,
              letterSpacing: 0.6,
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
    final mapDiff = team.mapWins - team.mapLosses;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1015),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _stageLine),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _stageMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StageTeamLogo(team: team, size: 36),
          const SizedBox(width: 10),
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
                  'Maps ${team.mapWins}-${team.mapLosses}  •  ${mapDiff >= 0 ? '+' : ''}$mapDiff',
                  style: const TextStyle(color: _stageMuted, fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${team.wins}-${team.losses}',
            style: const TextStyle(
              color: _stageGoldLight,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 68,
            child: _StatusBadge(label: status, color: statusColor),
          ),
        ],
      ),
    );
  }
}

class _WaitingState extends StatelessWidget {
  const _WaitingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1015),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _stageLine),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: _stageGold),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Standings will appear after the first synchronized series.',
              style: TextStyle(color: _stageMuted, height: 1.35),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 8,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StageTeamLogo extends StatelessWidget {
  const _StageTeamLogo({required this.team, required this.size});

  final TeamEntry team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3515), Color(0xFF1A1F28)],
        ),
        border: Border.all(color: const Color(0x66D9AA4F)),
      ),
      child: Text(
        team.initials,
        style: TextStyle(
          color: _stageGoldLight,
          fontSize: size * 0.27,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    final logo = team.logoUrl;
    if (logo == null || logo.isEmpty) return fallback;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white.withAlpha(24)),
      ),
      child: CachedNetworkImage(
        imageUrl: logo,
        fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

bool _isDirectQualified(TeamEntry team) =>
    team.actual == '4-0' || team.actual == '4-1';

bool _isEliminated(TeamEntry team) =>
    team.actual == '0-4' ||
    team.actual == '1-4' ||
    team.actual == 'Elimination Loser';

int _compareTeams(TeamEntry a, TeamEntry b) {
  final outcomeCompare = _outcomeWeight(b).compareTo(_outcomeWeight(a));
  if (outcomeCompare != 0) return outcomeCompare;
  final winsCompare = b.wins.compareTo(a.wins);
  if (winsCompare != 0) return winsCompare;
  final lossesCompare = a.losses.compareTo(b.losses);
  if (lossesCompare != 0) return lossesCompare;
  final mapDiffA = a.mapWins - a.mapLosses;
  final mapDiffB = b.mapWins - b.mapLosses;
  final mapCompare = mapDiffB.compareTo(mapDiffA);
  if (mapCompare != 0) return mapCompare;
  return a.clientName.compareTo(b.clientName);
}

int _outcomeWeight(TeamEntry team) {
  if (_isDirectQualified(team)) return 4;
  if (team.actual == 'Elimination Winner') return 3;
  if (team.actual == 'Pending') return 2;
  return 1;
}

String _teamStatus(TeamEntry team) {
  if (_isDirectQualified(team)) return 'DIRECT';
  if (team.actual == 'Elimination Winner') return 'ADVANCED';
  if (_isEliminated(team)) return 'OUT';
  if (team.wins + team.losses > 0) return 'IN PLAY';
  return 'WAITING';
}

Color _teamStatusColor(TeamEntry team) {
  if (_isDirectQualified(team)) return _stageSuccess;
  if (team.actual == 'Elimination Winner') return _stageGold;
  if (_isEliminated(team)) return _stageDanger;
  if (team.wins + team.losses > 0) return _stageBlue;
  return _stageMuted;
}
