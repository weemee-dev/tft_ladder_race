import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../data/ladder_data_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.onSignOutPressed,
    required this.ladderDataService,
  });

  final User user;
  final Future<void> Function() onSignOutPressed;
  final LadderDataService ladderDataService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('web/favicon.png', width: 28, height: 28),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'RezQ TFT LADDER RACE',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Abmelden',
            onPressed: onSignOutPressed,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<LadderDataSnapshot>(
        stream: ladderDataService.watchLadderData(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Die Ladder-Daten konnten nicht geladen werden.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFA07A)),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ladderData = snapshot.data;
          if (ladderData == null || ladderData.players.isEmpty) {
            return const Center(
              child: Text('Noch keine Ladder-Daten synchronisiert.'),
            );
          }
          return DashboardBody(
            ladderDataService: ladderDataService,
            livePlayers: ladderData.players,
            lastUpdated: ladderData.updatedAt,
          );
        },
      ),
    );
  }
}

class DashboardBody extends StatelessWidget {
  const DashboardBody({
    super.key,
    required this.ladderDataService,
    this.livePlayers,
    this.lastUpdated,
  });

  final LadderDataService ladderDataService;
  final List<LadderPlayer>? livePlayers;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final players = livePlayers ?? const <LadderPlayer>[];
    final scoutingPlayers = [...players]
      ..sort((a, b) => rankScore(b).compareTo(rankScore(a)));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: RaceCountdown()),
                  const SizedBox(width: 10),
                  _RefreshButton(
                    ladderDataService: ladderDataService,
                    lastUpdated: lastUpdated,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 26),
              Text(
                'DIE RACE-ÜBERSICHT',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 760 ? 2 : 1;
                  final panels = [
                    RankingPanel(
                      players: players,
                      title: 'HÖCHSTE ELO',
                      accent: const Color(0xFFFFC857),
                      valueKey: 'elo',
                    ),
                    RankingPanel(
                      players: players,
                      title: 'MEISTE LP GAIN',
                      accent: const Color(0xFF20C9FF),
                      valueKey: 'gain',
                    ),
                  ];
                  if (columns == 1) {
                    return Column(
                      children: [
                        panels[0],
                        const SizedBox(height: 14),
                        panels[1],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: panels[0]),
                      const SizedBox(width: 14),
                      Expanded(child: panels[1]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 26),
              Text(
                'ELO-VERLAUF',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              EloTimelineGraph(players: players),
              const SizedBox(height: 26),
              Text(
                'DAILY PROGRESS',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              DailyProgressSection(players: players),
              const SizedBox(height: 26),
              Text(
                'RACE AWARDS',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              RaceAwardsPanel(players: players),
              const SizedBox(height: 26),
              Text(
                'SPIELER IM SCOUTING',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900
                      ? 4
                      : constraints.maxWidth > 560
                      ? 2
                      : 1;
                  final gap = 14.0;
                  final itemWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: scoutingPlayers
                        .map(
                          (player) => SizedBox(
                            width: itemWidth,
                            child: PlayerCard(player: player),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 26),
              Text(
                'PLAYER INTELLIGENCE',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900 ? 2 : 1;
                  final gap = 14.0;
                  final itemWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: players
                        .map(
                          (player) => SizedBox(
                            width: itemWidth,
                            child: PlayerInsightPanel(player: player),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              if (livePlayers == null)
                const Text(
                  'Firestore wird synchronisiert ...',
                  style: TextStyle(color: Colors.white54),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyProgressSection extends StatelessWidget {
  const DailyProgressSection({super.key, required this.players});

  final List<LadderPlayer> players;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 560
            ? 2
            : 1;
        final gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: players
              .map(
                (player) => SizedBox(
                  width: width,
                  child: _DailyProgressCard(
                    player: player,
                    playerIndex: players.indexOf(player),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DailyProgressCard extends StatelessWidget {
  const _DailyProgressCard({required this.player, required this.playerIndex});

  final LadderPlayer player;
  final int playerIndex;

  @override
  Widget build(BuildContext context) {
    final progress = _DailyPlayerProgress.fromPlayer(player, playerIndex);
    final maxMatches = progress.days.fold<int>(
      0,
      (max, day) => day.matches > max ? day.matches : max,
    );
    final accent = _raceColors[progress.playerIndex % _raceColors.length];
    return _Panel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(player: player, small: true),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                progress.todaySummary,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: progress.days.map((day) {
              final barHeight = maxMatches == 0
                  ? 16.0
                  : 14 + (day.matches / maxMatches) * 40;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 50,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: barHeight,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: day.matches == 0
                                  ? Colors.white10
                                  : accent.withValues(alpha: .75),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${day.matches}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        day.label,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _DailyValue(label: 'MATCHES', value: '${progress.totalMatches}'),
              const SizedBox(width: 14),
              _DailyValue(label: 'AVG', value: progress.averagePlacement),
              const SizedBox(width: 14),
              _DailyValue(label: 'BEST DAY', value: progress.bestDay),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyValue extends StatelessWidget {
  const _DailyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 8, color: Colors.white54)),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ],
  );
}

class _DailyDay {
  const _DailyDay({
    required this.date,
    required this.matches,
    required this.averagePlacement,
  });

  final DateTime date;
  final int matches;
  final double averagePlacement;

  String get label => '${date.day}.${date.month}';
}

class _DailyPlayerProgress {
  const _DailyPlayerProgress({
    required this.playerIndex,
    required this.days,
    required this.totalMatches,
    required this.averagePlacement,
    required this.bestDay,
    required this.todaySummary,
  });

  factory _DailyPlayerProgress.fromPlayer(
    LadderPlayer player,
    int playerIndex,
  ) {
    final today = _day(DateTime.now());
    final days = <_DailyDay>[];
    final allMatches = player.matchHistory
        .where((match) => match.gameStartTimestamp != null)
        .toList();
    for (var offset = 6; offset >= 0; offset--) {
      final date = today.subtract(Duration(days: offset));
      final matches = allMatches
          .where(
            (match) =>
                _day(
                  DateTime.fromMillisecondsSinceEpoch(
                    match.gameStartTimestamp!,
                  ),
                ) ==
                date,
          )
          .toList();
      final average = matches.isEmpty
          ? 0.0
          : matches.fold<int>(0, (sum, match) => sum + match.placement) /
                matches.length;
      days.add(
        _DailyDay(
          date: date,
          matches: matches.length,
          averagePlacement: average,
        ),
      );
    }
    final played = allMatches.length;
    final average = played == 0
        ? '-'
        : (allMatches.fold<int>(0, (sum, match) => sum + match.placement) /
                  played)
              .toStringAsFixed(1);
    final best = days
        .where((day) => day.matches > 0)
        .fold<_DailyDay?>(
          null,
          (best, day) =>
              best == null || day.averagePlacement < best.averagePlacement
              ? day
              : best,
        );
    final current = days.last;
    return _DailyPlayerProgress(
      playerIndex: playerIndex,
      days: days,
      totalMatches: played,
      averagePlacement: average,
      bestDay: best == null
          ? '-'
          : '${best.averagePlacement.toStringAsFixed(1)} · ${best.label}',
      todaySummary: current.matches == 0
          ? 'RUHETAG'
          : '${current.matches} MATCH${current.matches == 1 ? '' : 'ES'}',
    );
  }

  final int playerIndex;
  final List<_DailyDay> days;
  final int totalMatches;
  final String averagePlacement;
  final String bestDay;
  final String todaySummary;
}

class RaceAwardsPanel extends StatelessWidget {
  const RaceAwardsPanel({super.key, required this.players});

  final List<LadderPlayer> players;

  @override
  Widget build(BuildContext context) {
    final awards = _RaceAwards.fromPlayers(players);
    return _Panel(
      accent: const Color(0xFFFFC857),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 760 ? 3 : 1;
          final gap = 18.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: 16,
            children: awards
                .map(
                  (award) => SizedBox(
                    width: width,
                    child: _AwardRow(award: award),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _Award {
  const _Award({
    required this.title,
    required this.icon,
    required this.player,
    required this.value,
    required this.color,
  });

  final String title;
  final IconData icon;
  final LadderPlayer? player;
  final String value;
  final Color color;
}

class _AwardRow extends StatelessWidget {
  const _AwardRow({required this.award});

  final _Award award;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(award.icon, color: award.color, size: 22),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              award.title,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white54,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              award.player?.name ?? 'Noch offen',
              style: TextStyle(color: award.color, fontWeight: FontWeight.bold),
            ),
            Text(
              award.value,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
      ),
    ],
  );
}

class _RaceAwards {
  static List<_Award> fromPlayers(List<LadderPlayer> players) {
    LadderPlayer? longestStreak;
    var longest = 0;
    LadderPlayer? bestAverage;
    var bestAverageValue = double.infinity;
    LadderPlayer? bestLpDay;
    var bestLpDayValue = 0;
    LadderPlayer? mostMatches;
    var mostMatchesValue = 0;
    for (final player in players) {
      final placements = [...player.matchHistory]
        ..sort(
          (a, b) =>
              (a.gameStartTimestamp ?? 0).compareTo(b.gameStartTimestamp ?? 0),
        );
      var streak = 0;
      var bestStreak = 0;
      for (final match in placements) {
        streak = match.placement == 1 ? streak + 1 : 0;
        if (streak > bestStreak) bestStreak = streak;
      }
      if (bestStreak > longest) {
        longest = bestStreak;
        longestStreak = player;
      }
      if (player.matchesPlayed > mostMatchesValue) {
        mostMatchesValue = player.matchesPlayed;
        mostMatches = player;
      }
      if (player.matchesPlayed > 0 && player.average < bestAverageValue) {
        bestAverageValue = player.average;
        bestAverage = player;
      }
      final tierPoints = [...player.tierHistory]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (var index = 1; index < tierPoints.length; index++) {
        final gain =
            tierPointScore(
              tierPoints[index].tier,
              tierPoints[index].division,
              tierPoints[index].leaguePoints,
            ) -
            tierPointScore(
              tierPoints[index - 1].tier,
              tierPoints[index - 1].division,
              tierPoints[index - 1].leaguePoints,
            );
        if (gain > bestLpDayValue) {
          bestLpDayValue = gain.round();
          bestLpDay = player;
        }
      }
    }
    return [
      _Award(
        title: 'LÄNGSTE WINSTREAK',
        icon: Icons.local_fire_department,
        player: longestStreak,
        value: longest == 0 ? '-' : '$longest Siege in Folge',
        color: const Color(0xFFFF7043),
      ),
      _Award(
        title: 'MEISTE LP AN EINEM TAG',
        icon: Icons.trending_up,
        player: bestLpDay,
        value: bestLpDay == null ? '-' : '+$bestLpDay LP',
        color: const Color(0xFF7CF7C5),
      ),
      _Award(
        title: 'MEISTE GESPIELTE MATCHES',
        icon: Icons.sports_esports,
        player: mostMatches,
        value: mostMatches == null ? '-' : '$mostMatchesValue Matches',
        color: const Color(0xFF20C9FF),
      ),
      _Award(
        title: 'BESTER RACE-SCHNITT',
        icon: Icons.workspace_premium,
        player: bestAverage,
        value: bestAverage == null
            ? '-'
            : 'Ø ${bestAverage.average.toStringAsFixed(1)} Platzierung',
        color: const Color(0xFFFFC857),
      ),
    ];
  }
}

class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.ladderDataService, this.lastUpdated});

  final LadderDataService ladderDataService;
  final DateTime? lastUpdated;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _loading = false;

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.ladderDataService.refreshNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daten werden aktualisiert.')),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refresh fehlgeschlagen: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final updatedAt = widget.lastUpdated;
    final timeLabel = updatedAt == null ? '--:--' : _formatTime(updatedAt);
    final tooltip = updatedAt == null
        ? 'Noch kein Update ausgeführt'
        : 'Zuletzt aktualisiert am ${_formatUpdatedAt(updatedAt)}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Daten aktualisieren',
          onPressed: _loading ? null : _refresh,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
        Tooltip(
          message: tooltip,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 11,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 2),
              Text(
                timeLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  String _formatUpdatedAt(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}.${twoDigits(value.month)}. '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

class RaceCountdown extends StatefulWidget {
  const RaceCountdown({super.key});

  @override
  State<RaceCountdown> createState() => _RaceCountdownState();
}

class _RaceCountdownState extends State<RaceCountdown> {
  static final _deadline = DateTime(2026, 9, 10, 23, 59);
  late Timer _timer;
  Duration _remaining = _deadline.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _remaining = _deadline.difference(DateTime.now()));
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining.isNegative ? Duration.zero : _remaining;
    final value =
        '${remaining.inDays}T ${remaining.inHours % 24}h ${remaining.inMinutes % 60}m ${remaining.inSeconds % 60}s';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF202833),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFF7043),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FINALE  ·  10.09.2026  ·  23:59 MESZ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFC857),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DeadlineBanner extends StatefulWidget {
  const DeadlineBanner({super.key});

  @override
  State<DeadlineBanner> createState() => _DeadlineBannerState();
}

class _DeadlineBannerState extends State<DeadlineBanner> {
  Timer? _timer;
  Duration _remaining = const Duration(days: 25, hours: 8, minutes: 42);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _remaining -= const Duration(minutes: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts =
        '${_remaining.inDays.toString().padLeft(2, '0')} : '
        '${(_remaining.inHours % 24).toString().padLeft(2, '0')} : '
        '${(_remaining.inMinutes % 60).toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF202833),
        border: Border.all(
          color: const Color(0xFFFF7043).withValues(alpha: .7),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 12,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAS FINALE',
                style: TextStyle(
                  color: Color(0xFFFF7043),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '10.09.2026 · 23:59 MESZ',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Text(
            parts,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFC857),
            ),
          ),
        ],
      ),
    );
  }
}

class RankingPanel extends StatelessWidget {
  const RankingPanel({
    super.key,
    required this.players,
    required this.title,
    required this.accent,
    required this.valueKey,
  });

  final List<LadderPlayer> players;
  final String title;
  final Color accent;
  final String valueKey;

  @override
  Widget build(BuildContext context) {
    final ranking = [...players]
      ..sort(
        (a, b) => valueKey == 'elo'
            ? rankScore(b).compareTo(rankScore(a))
            : b.gain.compareTo(a.gain),
      );
    return _Panel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...ranking
              .take(4)
              .map(
                (player) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Text(
                        '${ranking.indexOf(player) + 1}',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      PlayerAvatar(player: player, small: true),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          player.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (valueKey == 'elo')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${player.rank} ${player.division}'.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '${player.elo} LP',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        )
                      else
                        Flexible(
                          child: Text(
                            formatGain(player),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class PlayerCard extends StatelessWidget {
  const PlayerCard({super.key, required this.player});

  final LadderPlayer player;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      accent: player.gain >= 0
          ? const Color(0xFF20C9FF)
          : const Color(0xFFFF7043),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(player: player),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      player.error == null
                          ? '${player.rank} ${player.division}'.trim()
                          : 'SYNC ERROR',
                      style: TextStyle(
                        color: player.error == null
                            ? Colors.white60
                            : const Color(0xFFFF7043),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${player.elo} LP',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${player.rank} ${player.division}'.trim(),
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (player.error != null)
            Text(
              player.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFFFA07A), fontSize: 11),
            )
          else ...[
            TierGraph(history: player.tierHistory),
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: PlacementSparkline(placements: player.lastPlaces),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Metric(
                  label: 'LP GAIN',
                  value: formatGain(player),
                  color: player.gain >= 0
                      ? const Color(0xFF7CF7C5)
                      : const Color(0xFFFF7043),
                ),
                _Metric(
                  label: 'AVG PLACE',
                  value: player.matchesPlayed == 0
                      ? '-'
                      : player.average.toStringAsFixed(1),
                  color: Colors.white,
                ),
                _Metric(
                  label: 'TOP 4',
                  value: player.matchesPlayed == 0
                      ? '-'
                      : '${(player.topFourRate * 100).round()}%',
                  color: const Color(0xFFFFC857),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${player.matchesPlayed} MATCHES',
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
              const Spacer(),
              Text(
                player.title,
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EloTimelineGraph extends StatelessWidget {
  const EloTimelineGraph({super.key, required this.players});

  final List<LadderPlayer> players;

  @override
  Widget build(BuildContext context) {
    final graph = _EloGraphData.fromPlayers(players);
    return _Panel(
      accent: const Color(0xFFFFC857),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 280,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _DailyEloPainter(graph)),
                    ),
                    ...graph.series.expand(
                      (series) => series.points.map((point) {
                        final x = graph.x(point, constraints.maxWidth);
                        final y = graph.y(point, 280);
                        return Positioned(
                          left: (x - 6).clamp(
                            36.0,
                            constraints.maxWidth - 20.0,
                          ),
                          top: (y - 6).clamp(4.0, 254.0),
                          child: Tooltip(
                            message: point.label,
                            triggerMode: TooltipTriggerMode.tap,
                            waitDuration: const Duration(milliseconds: 150),
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color:
                                    _raceColors[graph.series.indexOf(series) %
                                        _raceColors.length],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white70,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    ...graph.series.asMap().entries.map((entry) {
                      final point = entry.value.points.last;
                      final x = graph.x(point, constraints.maxWidth);
                      final y = graph.y(point, 280);
                      return Positioned(
                        left: (x - 18).clamp(34.0, constraints.maxWidth - 38.0),
                        top: (y - 18).clamp(0.0, 244.0),
                        child: Tooltip(
                          message: point.label,
                          triggerMode: TooltipTriggerMode.tap,
                          child: PlayerAvatar(
                            player: entry.value.player,
                            small: true,
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: graph.series.asMap().entries.map((entry) {
              final color = _raceColors[entry.key % _raceColors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${entry.value.player.name} · ${entry.value.player.rank} ${entry.value.player.division}'
                        .trim(),
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

const _raceColors = <Color>[
  Color(0xFF20C9FF),
  Color(0xFFFF7043),
  Color(0xFF7CF7C5),
  Color(0xFFFFC857),
];

class _DailyEloPoint {
  const _DailyEloPoint({
    required this.date,
    required this.value,
    required this.tier,
    required this.division,
    required this.leaguePoints,
  });

  final DateTime date;
  final double value;
  final String tier;
  final String division;
  final int leaguePoints;

  String get label =>
      '${tier[0]}${tier.substring(1).toLowerCase()} $division - $leaguePoints LP';

  _DailyEloPoint onDate(DateTime value) => _DailyEloPoint(
    date: value,
    value: this.value,
    tier: tier,
    division: division,
    leaguePoints: leaguePoints,
  );
}

class _EloSeries {
  const _EloSeries({required this.player, required this.points});

  final LadderPlayer player;
  final List<_DailyEloPoint> points;
}

class _EloGraphData {
  _EloGraphData({
    required this.series,
    required this.startDate,
    required this.endDate,
    required this.minValue,
    required this.maxValue,
  });

  factory _EloGraphData.fromPlayers(List<LadderPlayer> players) {
    final rankedPlayers = players.where((player) {
      final rank = player.rank.toUpperCase();
      return rank != 'UNRANKED' &&
          rank != 'ERROR' &&
          _tierValues.containsKey(rank);
    }).toList();
    final configuredStart = rankedPlayers
        .map(
          (player) =>
              DateTime.tryParse(player.raceStartAt) ?? DateTime(2026, 8, 12),
        )
        .map(
          (date) => date.isBefore(DateTime(2026, 8, 12))
              ? DateTime(2026, 8, 12)
              : date,
        )
        .fold<DateTime?>(
          null,
          (current, value) =>
              current == null || value.isBefore(current) ? value : current,
        );
    final startDate = _day(configuredStart ?? DateTime(2026, 8, 12));
    final today = _day(DateTime.now());
    final series = <_EloSeries>[];
    for (final player in rankedPlayers) {
      final byDay = <DateTime, _DailyEloPoint>{};
      final startTier = player.startTier.toUpperCase();
      if (_tierValues.containsKey(startTier)) {
        byDay[startDate] = _DailyEloPoint(
          date: startDate,
          value: tierPointScore(
            startTier,
            player.startDivision,
            player.startLeaguePoints,
          ),
          tier: startTier,
          division: player.startDivision,
          leaguePoints: player.startLeaguePoints,
        );
      }
      for (final point in player.tierHistory) {
        final timestamp = DateTime.tryParse(point.timestamp);
        final tier = point.tier.toUpperCase();
        if (timestamp == null ||
            timestamp.isBefore(startDate) ||
            !_tierValues.containsKey(tier)) {
          continue;
        }
        final date = _day(timestamp);
        byDay[date] = _DailyEloPoint(
          date: date,
          value: tierPointScore(tier, point.division, point.leaguePoints),
          tier: tier,
          division: point.division,
          leaguePoints: point.leaguePoints,
        );
      }
      if (byDay.isEmpty && !player.rank.toUpperCase().contains('UNRANKED')) {
        byDay[today] = _DailyEloPoint(
          date: today,
          value: tierPointScore(player.rank, player.division, player.elo),
          tier: player.rank,
          division: player.division,
          leaguePoints: player.elo,
        );
      }
      if (byDay.isNotEmpty) {
        final firstDate = byDay.keys.reduce(
          (left, right) => left.isBefore(right) ? left : right,
        );
        var lastKnown = byDay[firstDate]!;
        final points = <_DailyEloPoint>[];
        for (
          var date = startDate;
          !date.isAfter(today);
          date = date.add(const Duration(days: 1))
        ) {
          lastKnown = byDay[date] ?? lastKnown;
          points.add(lastKnown.onDate(date));
        }
        series.add(_EloSeries(player: player, points: points));
      }
    }
    final allPoints = series.expand((item) => item.points).toList();
    final endDate = allPoints.isEmpty
        ? today
        : allPoints
              .map((point) => point.date)
              .reduce((left, right) => left.isAfter(right) ? left : right);
    final values = allPoints.map((point) => point.value).toList();
    final rawMin = values.isEmpty
        ? 0.0
        : values.reduce((left, right) => left < right ? left : right);
    final rawMax = values.isEmpty
        ? 3600.0
        : values.reduce((left, right) => left > right ? left : right);
    return _EloGraphData(
      series: series,
      startDate: startDate,
      endDate: endDate.isBefore(startDate) ? startDate : endDate,
      minValue: (rawMin - 100).clamp(0.0, double.infinity),
      maxValue: rawMax + 100,
    );
  }

  final List<_EloSeries> series;
  final DateTime startDate;
  final DateTime endDate;
  final double minValue;
  final double maxValue;

  double x(_DailyEloPoint point, double width) {
    final range = endDate.difference(startDate).inDays;
    return 42 +
        (width - 58) *
            (range == 0 ? 1 : point.date.difference(startDate).inDays / range);
  }

  double y(_DailyEloPoint point, double height) {
    final range = maxValue - minValue;
    return height -
        16 -
        ((point.value - minValue) / range).clamp(0.0, 1.0) * (height - 26);
  }
}

const _tierValues = <String, int>{
  'IRON': 0,
  'BRONZE': 1,
  'SILVER': 2,
  'GOLD': 3,
  'PLATINUM': 4,
  'EMERALD': 5,
  'DIAMOND': 6,
  'MASTER': 7,
  'GRANDMASTER': 8,
  'CHALLENGER': 9,
};

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

class _DailyEloPainter extends CustomPainter {
  _DailyEloPainter(this.graph);

  final _EloGraphData graph;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const right = 16.0;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .14)
      ..strokeWidth = 1;
    final dayCount = graph.endDate.difference(graph.startDate).inDays;
    for (var day = 0; day <= dayCount; day++) {
      final x =
          left +
          (size.width - left - right) * (dayCount == 0 ? 1 : day / dayCount);
      canvas.drawLine(Offset(x, 10), Offset(x, size.height - 16), gridPaint);
      if (dayCount <= 10 || day % 2 == 0 || day == dayCount) {
        _paintText(
          canvas,
          _formatDate(graph.startDate.add(Duration(days: day))),
          Offset(x - 15, size.height - 12),
          Colors.white54,
        );
      }
    }
    final tierLabels = _tierValues.keys.toList();
    for (final tier in tierLabels) {
      final value = tierPointScore(tier, 'IV', 0);
      if (value < graph.minValue || value > graph.maxValue) continue;
      final point = _DailyEloPoint(
        date: graph.startDate,
        value: value,
        tier: tier,
        division: 'IV',
        leaguePoints: 0,
      );
      final y = graph.y(point, size.height);
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
      _paintText(canvas, tier, Offset(0, y - 6), Colors.white54);
    }
    for (var index = 0; index < graph.series.length; index++) {
      final series = graph.series[index];
      final path = Path();
      for (
        var pointIndex = 0;
        pointIndex < series.points.length;
        pointIndex++
      ) {
        final point = series.points[pointIndex];
        final offset = Offset(
          graph.x(point, size.width),
          graph.y(point, size.height),
        );
        if (pointIndex == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _raceColors[index % _raceColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';

  void _paintText(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DailyEloPainter oldDelegate) =>
      oldDelegate.graph != graph;
}

double tierPointScore(String tier, String division, int leaguePoints) {
  const tiers = <String, int>{
    'IRON': 0,
    'BRONZE': 1,
    'SILVER': 2,
    'GOLD': 3,
    'PLATINUM': 4,
    'EMERALD': 5,
    'DIAMOND': 6,
    'MASTER': 7,
    'GRANDMASTER': 8,
    'CHALLENGER': 9,
  };
  const divisions = <String, int>{'IV': 0, 'III': 1, 'II': 2, 'I': 3};
  final tierValue = tiers[tier.toUpperCase()] ?? 0;
  final divisionValue = divisions[division.toUpperCase()] ?? 0;
  return (tierValue * 400 + divisionValue * 100 + leaguePoints).toDouble();
}

int rankScore(LadderPlayer player) {
  const tierOrder = <String, int>{
    'UNRANKED': -1,
    'IRON': 0,
    'BRONZE': 1,
    'SILVER': 2,
    'GOLD': 3,
    'PLATINUM': 4,
    'EMERALD': 5,
    'DIAMOND': 6,
    'MASTER': 7,
    'GRANDMASTER': 8,
    'CHALLENGER': 9,
  };
  const divisionOrder = <String, int>{'IV': 0, 'III': 1, 'II': 2, 'I': 3};
  final tier = tierOrder[player.rank.toUpperCase()] ?? -1;
  final division =
      divisionOrder[player.division.toUpperCase()] ??
      int.tryParse(player.division) ??
      0;
  return tier * 100000 + division * 1000 + player.elo;
}

String formatGain(LadderPlayer player) {
  if (player.startTier.isEmpty) {
    return player.gain >= 0 ? '+${player.gain} LP' : '${player.gain} LP';
  }
  final start = '${player.startTier} ${player.startDivision}'.trim();
  final current = '${player.rank} ${player.division}'.trim();
  final gain = player.gain >= 0 ? '+${player.gain}' : '${player.gain}';
  return '$start ${player.startLeaguePoints} LP -> $current ${player.elo} LP | $gain LP';
}

class RankBadge extends StatelessWidget {
  const RankBadge({
    super.key,
    required this.tier,
    required this.division,
    this.compact = false,
  });

  final String tier;
  final String division;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);
    return Container(
      width: compact ? 34 : 58,
      height: compact ? 34 : 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .14),
        border: Border.all(
          color: color.withValues(alpha: .8),
          width: compact ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .18),
            blurRadius: compact ? 6 : 14,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            rankEmblemUrl(tier),
            width: compact ? 18 : 30,
            height: compact ? 18 : 30,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.shield, size: compact ? 14 : 24, color: color),
          ),
          if (!compact)
            Text(
              division.isEmpty ? tier : division,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Color _tierColor(String value) {
    switch (value) {
      case 'IRON':
        return const Color(0xFF8A8F98);
      case 'BRONZE':
        return const Color(0xFFB8794A);
      case 'SILVER':
        return const Color(0xFFC7D0DA);
      case 'GOLD':
        return const Color(0xFFFFC857);
      case 'PLATINUM':
        return const Color(0xFF66D6C3);
      case 'EMERALD':
        return const Color(0xFF7CF7C5);
      case 'DIAMOND':
        return const Color(0xFF6FC7FF);
      case 'MASTER':
        return const Color(0xFFB58CFF);
      default:
        return const Color(0xFF9BA3B5);
    }
  }
}

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.player, this.small = false});

  final LadderPlayer player;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final fallback = player.name.isEmpty ? '?' : player.name[0].toUpperCase();
    if (player.profileIconId == null) {
      return CircleAvatar(
        radius: small ? 16 : 20,
        backgroundColor: Colors.white10,
        child: Text(fallback),
      );
    }
    return CircleAvatar(
      backgroundColor: Colors.white10,
      child: ClipOval(
        child: Image.network(
          profileIconUrl(player.profileIconId!),
          width: small ? 32 : 40,
          height: small ? 32 : 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Text(fallback),
        ),
      ),
    );
  }
}

String profileIconUrl(int profileIconId) =>
    'https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/profile-icons/$profileIconId.jpg';

String rankEmblemUrl(String tier) =>
    'https://raw.communitydragon.org/latest/plugins/rcp-fe-lol-static-assets/global/default/ranked-emblem/emblem-${tier.toLowerCase()}.png';

class PlayerInsightPanel extends StatelessWidget {
  const PlayerInsightPanel({super.key, required this.player});

  final LadderPlayer player;

  @override
  Widget build(BuildContext context) {
    final synergies = player.synergies.take(4).toList();
    final recentMatches = player.matchHistory.take(20).toList();
    final recentStats = _PlacementStats(
      recentMatches.map((match) => match.placement).toList(),
    );
    final overallStats = _PlacementStats(
      player.matchHistory.map((match) => match.placement).toList(),
    );
    final recentStandings = recentMatches
        .map((match) => match.placement)
        .toList();
    return _Panel(
      accent: const Color(0xFF9B8CFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(player: player, small: true),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  player.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MOST SYNERGIES',
                      style: TextStyle(
                        color: Color(0xFF9B8CFF),
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (synergies.isEmpty)
                      const Text(
                        'Noch keine Trait-Daten',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      )
                    else
                      ...synergies.map(
                        (synergy) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _traitName(synergy.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Text(
                                '${synergy.matches}x',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '#${synergy.averagePlacement.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Color(0xFF7CF7C5),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LETZTE 20 STANDINGS',
                      style: TextStyle(
                        color: Color(0xFF9B8CFF),
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (recentStandings.isEmpty)
                      const Text('-', style: TextStyle(color: Colors.white54))
                    else
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: recentStandings
                            .map((place) => _StandingDot(place: place))
                            .toList(),
                      ),
                    const SizedBox(height: 12),
                    _StatsSection(title: 'LETZTE 20', stats: recentStats),
                    const SizedBox(height: 12),
                    _StatsSection(
                      title: 'GESAMT SEIT RENNSTART',
                      stats: overallStats,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _traitName(String rawName) {
    final name = rawName.split('_').last;
    return name.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
  }
}

class _PlacementStats {
  _PlacementStats(this.placements);

  final List<int> placements;

  int get wins => placements.where((place) => place == 1).length;
  int get losses => placements.where((place) => place > 4).length;
  double get winRate => placements.isEmpty ? 0 : wins / placements.length;
  double get average => placements.isEmpty
      ? 0
      : placements.reduce((left, right) => left + right) / placements.length;
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.title, required this.stats});

  final String title;
  final _PlacementStats stats;

  @override
  Widget build(BuildContext context) {
    final value = stats.placements.isEmpty
        ? '-'
        : '${stats.wins}W ${stats.losses}L';
    final ratio = stats.placements.isEmpty
        ? '-'
        : '${(stats.winRate * 100).round()}%';
    final average = stats.placements.isEmpty
        ? '-'
        : stats.average.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF9B8CFF),
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 12,
          runSpacing: 3,
          children: [
            Text(
              '${stats.placements.length} MATCHES',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF7CF7C5),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$ratio WIN RATE',
              style: const TextStyle(
                color: Color(0xFFFFC857),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'AVG $average',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _StandingDot extends StatelessWidget {
  const _StandingDot({required this.place});

  final int place;

  @override
  Widget build(BuildContext context) {
    final color = place == 1
        ? const Color(0xFFFFC857)
        : place <= 4
        ? const Color(0xFF7CF7C5)
        : const Color(0xFFFF7043);
    return Container(
      width: 25,
      height: 25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        border: Border.all(color: color.withValues(alpha: .7)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$place',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54)),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ],
  );
}

class PlacementSparkline extends StatelessWidget {
  const PlacementSparkline({super.key, required this.placements});

  final List<int> placements;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SparklinePainter(placements),
    child: const SizedBox.expand(),
  );
}

class TierGraph extends StatelessWidget {
  const TierGraph({super.key, required this.history});

  final List<TierPoint> history;

  @override
  Widget build(BuildContext context) {
    final current = history.isEmpty
        ? 'NO TIER HISTORY'
        : '${history.last.tier} ${history.last.division}'.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'TIER GRAPH',
              style: TextStyle(
                fontSize: 9,
                color: Color(0xFF9B8CFF),
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Text(
              current,
              style: const TextStyle(fontSize: 9, color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: CustomPaint(
            painter: _TierGraphPainter(history),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.placements);
  final List<int> placements;

  @override
  void paint(Canvas canvas, Size size) {
    if (placements.length < 2) return;
    final line = Paint()
      ..color = const Color(0xFF20C9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final points = <Offset>[];
    for (var index = 0; index < placements.length; index++) {
      final x = size.width * index / (placements.length - 1);
      final y = size.height * (placements[index] - 1) / 7;
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = const Color(0xFFFFC857));
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.placements != placements;
}

class _TierGraphPainter extends CustomPainter {
  _TierGraphPainter(this.history);
  final List<TierPoint> history;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    final values = history.map(_tierValue).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 1
        ? 1
        : (maxValue - minValue).abs();
    final line = Paint()
      ..color = const Color(0xFF9B8CFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y =
          size.height -
          ((values[index] - minValue) / range * (size.height - 6)) -
          3;
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
    canvas.drawCircle(
      points.last,
      3.5,
      Paint()..color = const Color(0xFFFFC857),
    );
  }

  double _tierValue(TierPoint point) {
    const tiers = <String, int>{
      'IRON': 0,
      'BRONZE': 1,
      'SILVER': 2,
      'GOLD': 3,
      'PLATINUM': 4,
      'EMERALD': 5,
      'DIAMOND': 6,
      'MASTER': 7,
      'GRANDMASTER': 8,
      'CHALLENGER': 9,
    };
    final tier = tiers[point.tier] ?? -1;
    final division = int.tryParse(point.division) ?? 0;
    return (tier * 1000 + (4 - division) * 100 + point.leaguePoints).toDouble();
  }

  @override
  bool shouldRepaint(covariant _TierGraphPainter oldDelegate) =>
      oldDelegate.history != history;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.accent, required this.child});
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF202833),
      borderRadius: BorderRadius.circular(16),
      border: Border(left: BorderSide(color: accent, width: 3)),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6)),
      ],
    ),
    child: child,
  );
}
