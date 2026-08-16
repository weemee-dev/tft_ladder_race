import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
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
            const Flexible(child: Text('TFT LADDER RACE', overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            const _DeadlineChip(),
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
      body: StreamBuilder<List<LadderPlayer>>(
        stream: ladderDataService.watchPlayers(),
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
          if (snapshot.data == null || snapshot.data!.isEmpty) {
            return const Center(child: Text('Noch keine Ladder-Daten synchronisiert.'));
          }
          return DashboardBody(user: user, livePlayers: snapshot.data);
        },
      ),
    );
  }
}

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key, required this.user, this.livePlayers});

  final User user;
  final List<LadderPlayer>? livePlayers;

  @override
  Widget build(BuildContext context) {
    final players = livePlayers ?? const <LadderPlayer>[];
    final totalMatches = players.fold(0, (sum, player) => sum + player.matchesPlayed);
    final averagePlacement = players
        .where((player) => player.matchesPlayed > 0)
        .fold<double>(0, (sum, player) => sum + player.average);
    final rankedPlayers = [...players]..sort((a, b) => b.elo.compareTo(a.elo));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeHeader(email: user.email),
              const SizedBox(height: 20),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('LIVE RACE STATUS', style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  Text('${players.length}/4 PLAYERS · $totalMatches MATCHES TRACKED', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
                  const SizedBox(height: 5),
                  const Text('Wie oft landet jeder Spieler auf Platz 1 bis 8? Grün = Top 4, Orange = Bottom 4.', style: TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth > 760 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: columns == 4 ? 1.55 : 1.9,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StatTile(label: 'MATCHES LOGGED', value: '$totalMatches', icon: Icons.sports_esports, accent: const Color(0xFF20C9FF)),
                    _StatTile(label: 'BEST LP', value: rankedPlayers.isEmpty ? '-' : '${rankedPlayers.first.elo}', icon: Icons.workspace_premium, accent: const Color(0xFFFFC857)),
                    _StatTile(label: 'AVG PLACEMENT', value: averagePlacement == 0 ? '-' : (averagePlacement / players.where((player) => player.matchesPlayed > 0).length).toStringAsFixed(1), icon: Icons.insights, accent: const Color(0xFF7CF7C5)),
                    _StatTile(label: 'TOP 4 RATE', value: _groupTopFourRate(players), icon: Icons.bolt, accent: const Color(0xFFFF7043)),
                  ],
                );
              }),
              const SizedBox(height: 26),
              Text('DIE RACE-ÜBERSICHT', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 760 ? 2 : 1;
                  final panels = [
                    RankingPanel(players: players, title: 'HÖCHSTE ELO', accent: const Color(0xFFFFC857), valueKey: 'elo'),
                    RankingPanel(players: players, title: 'MEISTE LP GAIN', accent: const Color(0xFF20C9FF), valueKey: 'gain'),
                  ];
                  if (columns == 1) {
                    return Column(children: [
                      panels[0],
                      const SizedBox(height: 14),
                      panels[1],
                    ]);
                  }
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: panels[0]),
                    const SizedBox(width: 14),
                    Expanded(child: panels[1]),
                  ]);
                },
              ),
              const SizedBox(height: 26),
              PlacementChart(players: players),
              const SizedBox(height: 26),
              Text('SPIELER IM SCOUTING', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900
                      ? 4
                      : constraints.maxWidth > 560
                          ? 2
                          : 1;
                  final gap = 14.0;
                  final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: players.map((player) => SizedBox(
                      width: itemWidth,
                      child: PlayerCard(player: player),
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 26),
              Text('PLAYER INTELLIGENCE', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900 ? 2 : 1;
                  final gap = 14.0;
                  final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: players.map((player) => SizedBox(
                      width: itemWidth,
                      child: PlayerInsightPanel(player: player),
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              if (livePlayers == null)
                const Text('Firestore wird synchronisiert ...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }

  String _groupTopFourRate(List<LadderPlayer> players) {
    final active = players.where((player) => player.matchesPlayed > 0).toList();
    if (active.isEmpty) return '-';
    final rate = active.fold<double>(0, (sum, player) => sum + player.topFourRate) / active.length;
    return '${(rate * 100).round()}%';
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bolt, color: Color(0xFFFFC857), size: 30),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Willkommen zurück', style: Theme.of(context).textTheme.headlineSmall),
              Text(email ?? 'Race member', style: TextStyle(color: Colors.white.withValues(alpha: .62))),
            ],
          ),
        ),
        const Chip(avatar: Icon(Icons.circle, size: 10, color: Colors.greenAccent), label: Text('LIVE')),
      ],
    );
  }
}

class _DeadlineChip extends StatelessWidget {
  const _DeadlineChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7043).withValues(alpha: .14),
        border: Border.all(color: const Color(0xFFFF7043).withValues(alpha: .65)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Text('FINALE · 10.09 · 23:59', style: TextStyle(color: Color(0xFFFFA07A), fontSize: 10, fontWeight: FontWeight.bold)),
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
    final parts = '${_remaining.inDays.toString().padLeft(2, '0')} : '
        '${(_remaining.inHours % 24).toString().padLeft(2, '0')} : '
        '${(_remaining.inMinutes % 60).toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF202833),
        border: Border.all(color: const Color(0xFFFF7043).withValues(alpha: .7)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 12,
        children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DAS FINALE', style: TextStyle(color: Color(0xFFFF7043), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            SizedBox(height: 4),
            Text('10.09.2026 · 23:59 MESZ', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          ]),
          Text(parts, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFFFFC857))),
        ],
      ),
    );
  }
}

class RankingPanel extends StatelessWidget {
  const RankingPanel({super.key, required this.players, required this.title, required this.accent, required this.valueKey});

  final List<LadderPlayer> players;
  final String title;
  final Color accent;
  final String valueKey;

  @override
  Widget build(BuildContext context) {
    final ranking = [...players]
      ..sort((a, b) => (valueKey == 'elo' ? b.elo : b.gain).compareTo(valueKey == 'elo' ? a.elo : a.gain));
    return _Panel(
      accent: accent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: accent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ...ranking.take(4).map((player) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            Text('${ranking.indexOf(player) + 1}', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            RankBadge(tier: player.rank, division: player.division, compact: true),
            const SizedBox(width: 9),
            Expanded(child: Text(player.name, style: const TextStyle(fontWeight: FontWeight.w600))),
            Flexible(child: Text(valueKey == 'elo' ? '${player.elo} LP' : formatGain(player), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
          ]),
        )),
      ]),
    );
  }
}

class PlayerCard extends StatelessWidget {
  const PlayerCard({super.key, required this.player});

  final LadderPlayer player;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      accent: player.gain >= 0 ? const Color(0xFF20C9FF) : const Color(0xFFFF7043),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PlayerAvatar(player: player),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(player.error == null ? '${player.rank} ${player.division}'.trim() : 'SYNC ERROR', style: TextStyle(color: player.error == null ? Colors.white60 : const Color(0xFFFF7043), fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${player.elo} LP', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${player.rank} ${player.division}'.trim(), style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ]),
        ]),
        const SizedBox(height: 10),
        if (player.error != null)
          Text(player.error!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFFFA07A), fontSize: 11))
        else ...[
          TierGraph(history: player.tierHistory),
          const SizedBox(height: 8),
          SizedBox(height: 56, child: PlacementSparkline(placements: player.lastPlaces)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _Metric(label: 'LP GAIN', value: formatGain(player), color: player.gain >= 0 ? const Color(0xFF7CF7C5) : const Color(0xFFFF7043)),
            _Metric(label: 'AVG PLACE', value: player.matchesPlayed == 0 ? '-' : player.average.toStringAsFixed(1), color: Colors.white),
            _Metric(label: 'TOP 4', value: player.matchesPlayed == 0 ? '-' : '${(player.topFourRate * 100).round()}%', color: const Color(0xFFFFC857)),
          ]),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Text('${player.matchesPlayed} MATCHES', style: const TextStyle(fontSize: 10, color: Colors.white54)),
          const Spacer(),
          Text(player.title, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ]),
      ]),
    );
  }

}

String formatGain(LadderPlayer player) {
  if (player.startTier.isEmpty) return player.gain >= 0 ? '+${player.gain} LP' : '${player.gain} LP';
  final start = '${player.startTier} ${player.startDivision}'.trim();
  final current = '${player.rank} ${player.division}'.trim();
  final gain = player.gain >= 0 ? '+${player.gain}' : '${player.gain}';
  return '$start ${player.startLeaguePoints} LP -> $current ${player.elo} LP | $gain LP';
}

class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.tier, required this.division, this.compact = false});

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
        border: Border.all(color: color.withValues(alpha: .8), width: compact ? 1 : 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: .18), blurRadius: compact ? 6 : 14)],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.network(
          rankEmblemUrl(tier),
          width: compact ? 18 : 30,
          height: compact ? 18 : 30,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(Icons.shield, size: compact ? 14 : 24, color: color),
        ),
        if (!compact) Text(division.isEmpty ? tier : division, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Color _tierColor(String value) {
    switch (value) {
      case 'IRON': return const Color(0xFF8A8F98);
      case 'BRONZE': return const Color(0xFFB8794A);
      case 'SILVER': return const Color(0xFFC7D0DA);
      case 'GOLD': return const Color(0xFFFFC857);
      case 'PLATINUM': return const Color(0xFF66D6C3);
      case 'EMERALD': return const Color(0xFF7CF7C5);
      case 'DIAMOND': return const Color(0xFF6FC7FF);
      case 'MASTER': return const Color(0xFFB58CFF);
      default: return const Color(0xFF9BA3B5);
    }
  }
}

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.player});

  final LadderPlayer player;

  @override
  Widget build(BuildContext context) {
    final fallback = player.name.isEmpty ? '?' : player.name[0].toUpperCase();
    if (player.profileIconId == null) {
      return CircleAvatar(backgroundColor: Colors.white10, child: Text(fallback));
    }
    return CircleAvatar(
      backgroundColor: Colors.white10,
      child: ClipOval(
        child: Image.network(
          profileIconUrl(player.profileIconId!),
          width: 40,
          height: 40,
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
    return _Panel(
      accent: const Color(0xFF9B8CFF),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(player.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          Text('${player.matchWins}W  ${player.matchLosses}L', style: const TextStyle(color: Color(0xFF7CF7C5), fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Text('${(player.winRate * 100).round()}%', style: const TextStyle(color: Color(0xFFFFC857), fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MOST SYNERGIES', style: TextStyle(color: Color(0xFF9B8CFF), fontSize: 9, letterSpacing: 1)),
            const SizedBox(height: 6),
            if (synergies.isEmpty)
              const Text('Noch keine Trait-Daten', style: TextStyle(color: Colors.white54, fontSize: 11))
            else
              ...synergies.map((synergy) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Expanded(child: Text(_traitName(synergy.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                      Text('${synergy.matches}x', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      const SizedBox(width: 8),
                      Text('#${synergy.averagePlacement.toStringAsFixed(1)}', style: const TextStyle(color: Color(0xFF7CF7C5), fontSize: 10)),
                    ]),
                  )),
          ])),
          const SizedBox(width: 18),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('RECENT STANDINGS', style: TextStyle(color: Color(0xFF9B8CFF), fontSize: 9, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(spacing: 5, runSpacing: 5, children: player.recentStandings.map((place) => _StandingDot(place: place)).toList()),
            const SizedBox(height: 10),
            Text('${player.matchesPlayed} matches · avg ${player.average == 0 ? '-' : player.average.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ])),
        ]),
      ]),
    );
  }

  String _traitName(String rawName) {
    final name = rawName.split('_').last;
    return name.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}');
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
      decoration: BoxDecoration(color: color.withValues(alpha: .18), border: Border.all(color: color.withValues(alpha: .7)), borderRadius: BorderRadius.circular(6)),
      child: Text('$place', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ]);
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon, required this.accent});

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      accent: accent,
      child: Row(children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54, letterSpacing: .8)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: accent)),
        ])),
      ]),
    );
  }
}

class PlacementChart extends StatelessWidget {
  const PlacementChart({super.key, required this.players});

  final List<LadderPlayer> players;

  @override
  Widget build(BuildContext context) {
    final counts = List<int>.filled(8, 0);
    for (final player in players) {
      for (final match in player.matchHistory) {
        if (match.placement >= 1 && match.placement <= 8) counts[match.placement - 1]++;
      }
    }
    final total = counts.fold(0, (sum, count) => sum + count);
    return _Panel(
      accent: const Color(0xFF7CF7C5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('PLACEMENT RADAR', style: TextStyle(color: Color(0xFF7CF7C5), fontWeight: FontWeight.bold, letterSpacing: 1.2))),
          Text('$total MATCHES', style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
        const SizedBox(height: 16),
        SizedBox(height: 118, child: CustomPaint(painter: _PlacementChartPainter(counts: counts), child: const SizedBox.expand())),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(8, (index) => Text('${index + 1}', style: TextStyle(color: index < 4 ? const Color(0xFF7CF7C5) : Colors.white54, fontSize: 10)))),
      ]),
    );
  }
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
    final current = history.isEmpty ? 'NO TIER HISTORY' : '${history.last.tier} ${history.last.division}'.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('TIER GRAPH', style: TextStyle(fontSize: 9, color: Color(0xFF9B8CFF), letterSpacing: 1)),
        const Spacer(),
        Text(current, style: const TextStyle(fontSize: 9, color: Colors.white54)),
      ]),
      const SizedBox(height: 4),
      SizedBox(height: 40, child: CustomPaint(painter: _TierGraphPainter(history), child: const SizedBox.expand())),
    ]);
  }
}

class _PlacementChartPainter extends CustomPainter {
  _PlacementChartPainter({required this.counts});
  final List<int> counts;

  @override
  void paint(Canvas canvas, Size size) {
    final maxCount = counts.fold<int>(1, (max, value) => value > max ? value : max);
    final width = size.width / counts.length;
    for (var index = 0; index < counts.length; index++) {
      final barHeight = size.height * counts[index] / maxCount;
      final rect = Rect.fromLTWH(index * width + width * .2, size.height - barHeight, width * .6, barHeight);
      final paint = Paint()..color = index < 4 ? const Color(0xFF7CF7C5) : const Color(0xFFFF7043);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlacementChartPainter oldDelegate) => oldDelegate.counts != counts;
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.placements);
  final List<int> placements;

  @override
  void paint(Canvas canvas, Size size) {
    if (placements.length < 2) return;
    final line = Paint()..color = const Color(0xFF20C9FF)..style = PaintingStyle.stroke..strokeWidth = 2;
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
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.placements != placements;
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
    final range = (maxValue - minValue).abs() < 1 ? 1 : (maxValue - minValue).abs();
    final line = Paint()..color = const Color(0xFF9B8CFF)..style = PaintingStyle.stroke..strokeWidth = 2;
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y = size.height - ((values[index] - minValue) / range * (size.height - 6)) - 3;
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
    canvas.drawCircle(points.last, 3.5, Paint()..color = const Color(0xFFFFC857));
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
  bool shouldRepaint(covariant _TierGraphPainter oldDelegate) => oldDelegate.history != history;
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
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: child,
      );
}

