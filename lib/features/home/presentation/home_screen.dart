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
        title: const Text('TFT LADDER RACE'),
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
            return const Center(child: Text('Die Ladder-Daten konnten nicht geladen werden.'));
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

  static const fallbackPlayers = <Player>[
    Player('Mango', 'The Climber', 742, 980, 3, 4.1, <int>[2, 1, 4, 3, 2]),
    Player('Kira', 'LP Goblin', 680, 860, 2, 4.8, <int>[4, 3, 2, 5, 1]),
    Player('Rex', 'The Grinder', 615, 790, 5, 5.2, <int>[6, 4, 7, 2, 6]),
    Player('Nova', 'Fast 8th Enjoyer', 540, 720, 1, 6.0, <int>[8, 1, 7, 8, 5]),
  ];

  @override
  Widget build(BuildContext context) {
    final players = livePlayers
        ?.map((player) => Player(
            player.name,
            player.title,
            player.elo,
            player.gain,
            player.streak,
            player.average,
            player.lastPlaces,
          ))
        .toList() ??
      fallbackPlayers;
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
              const DeadlineBanner(),
              const SizedBox(height: 24),
              Text('DIE RACE-ÜBERSICHT', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 760 ? 2 : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: columns == 2 ? 1.75 : 2.25,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      RankingPanel(players: players, title: 'HÖCHSTE ELO', accent: const Color(0xFFFFC857), valueKey: 'elo'),
                      RankingPanel(players: players, title: 'MEISTE LP GAIN', accent: const Color(0xFF20C9FF), valueKey: 'gain'),
                    ],
                  );
                },
              ),
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
                  return GridView.builder(
                    itemCount: players.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: columns == 1 ? 1.75 : .78,
                    ),
                    itemBuilder: (context, index) => PlayerCard(player: players[index]),
                  );
                },
              ),
              const SizedBox(height: 20),
              if (livePlayers == null)
                const Text('Demo-Daten: Firestore ist noch nicht synchronisiert.'),
            ],
          ),
        ),
      ),
    );
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

  final List<Player> players;
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
        ...ranking.take(3).map((player) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            Text('${ranking.indexOf(player) + 1}', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Expanded(child: Text(player.name, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(valueKey == 'elo' ? '${player.elo} LP' : '+${player.gain} LP'),
          ]),
        )),
      ]),
    );
  }
}

class PlayerCard extends StatelessWidget {
  const PlayerCard({super.key, required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      accent: player.name == 'Mango' ? const Color(0xFFFFC857) : const Color(0xFF20C9FF),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: Colors.white10, child: Text(player.name[0])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(player.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(player.title, style: TextStyle(color: Colors.white.withValues(alpha: .6), fontSize: 12)),
          ])),
          Text('${player.elo} LP', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _Metric(label: 'LP GAIN', value: '+${player.gain}', color: Colors.greenAccent),
          _Metric(label: 'AVG PLACE', value: player.average.toStringAsFixed(1), color: Colors.white),
          _Metric(label: 'STREAK', value: '${player.streak}x', color: const Color(0xFFFF7043)),
        ]),
        const Spacer(),
        Row(children: [
          const Text('LAST 5', style: TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(width: 8),
          ...player.lastPlaces.map((place) => Padding(
            padding: const EdgeInsets.only(right: 5),
            child: CircleAvatar(radius: 11, backgroundColor: place <= 4 ? Colors.green.shade700 : Colors.red.shade800, child: Text('$place', style: const TextStyle(fontSize: 11))),
          )),
        ]),
      ]),
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

class Player {
  const Player(this.name, this.title, this.elo, this.gain, this.streak, this.average, this.lastPlaces);
  final String name;
  final String title;
  final int elo;
  final int gain;
  final int streak;
  final double average;
  final List<int> lastPlaces;
}
