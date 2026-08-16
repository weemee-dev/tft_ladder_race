import 'package:cloud_firestore/cloud_firestore.dart';

class LadderDataService {
  LadderDataService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<LadderPlayer>> watchPlayers() {
    return _firestore.doc('ladder_data/current').snapshots().map((snapshot) {
      final data = snapshot.data();
      final players = data?['players'];
      if (players is! List) {
        return <LadderPlayer>[];
      }
      return players
          .whereType<Map<String, dynamic>>()
          .map(LadderPlayer.fromMap)
          .toList();
    });
  }
}

class LadderPlayer {
  const LadderPlayer({
    required this.name,
    required this.title,
    required this.elo,
    required this.gain,
    required this.streak,
    required this.average,
    required this.lastPlaces,
  });

  factory LadderPlayer.fromMap(Map<String, dynamic> data) {
    final placements = (data['placements'] as List<dynamic>? ?? [])
        .whereType<num>()
        .map((value) => value.toInt())
        .toList();
    final average = placements.isEmpty
        ? 0.0
        : placements.reduce((left, right) => left + right) / placements.length;
    var streak = 0;
    for (final place in placements.reversed) {
      if (place <= 4) {
        streak++;
      } else {
        break;
      }
    }
    return LadderPlayer(
      name: data['name'] as String? ?? data['gameName'] as String? ?? 'Unknown',
      title: _titleFor(data['firstOrEighth'] as num? ?? 0),
      elo: (data['leaguePoints'] as num? ?? 0).toInt(),
      gain: (data['lpGain'] as num? ?? 0).toInt(),
      streak: streak,
      average: average,
      lastPlaces: placements.take(5).toList(),
    );
  }

  final String name;
  final String title;
  final int elo;
  final int gain;
  final int streak;
  final double average;
  final List<int> lastPlaces;

  static String _titleFor(num firstOrEighth) {
    if (firstOrEighth >= 4) return 'Fast 8th Enjoyer';
    return 'Race Challenger';
  }
}