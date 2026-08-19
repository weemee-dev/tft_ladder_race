import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class LadderDataService {
  LadderDataService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> refreshNow() async {
    await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('refreshLadderDataNow')
        .call();
  }

  Stream<List<LadderPlayer>> watchPlayers() {
    return _firestore.doc('ladder_data/current').snapshots().map((snapshot) {
      final data = snapshot.data();
      final players = data?['players'];
      if (players is! List) {
        return <LadderPlayer>[];
      }
        return players
          .whereType<Map>()
          .map((player) => LadderPlayer.fromMap(Map<String, dynamic>.from(player)))
          .toList();
    });
  }
}

class LadderPlayer {
  const LadderPlayer({
    required this.name,
    required this.gameName,
    required this.profileIconId,
    required this.title,
    required this.elo,
    required this.rank,
    required this.division,
    required this.startTier,
    required this.startDivision,
    required this.startLeaguePoints,
    required this.raceStartAt,
    required this.gain,
    required this.streak,
    required this.average,
    required this.matchesPlayed,
    required this.topFourRate,
    required this.firstOrEighth,
    required this.lastPlaces,
    required this.matchHistory,
    required this.synergies,
    required this.matchWins,
    required this.matchLosses,
    required this.winRate,
    required this.recentStandings,
    required this.tierHistory,
    required this.error,
  });

  factory LadderPlayer.fromMap(Map<String, dynamic> data) {
    final placements = (data['placements'] as List<dynamic>? ?? [])
        .whereType<num>()
        .map((value) => value.toInt())
        .toList();
      final history = (data['matchHistory'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((match) => LadderMatch.fromMap(Map<String, dynamic>.from(match)))
        .toList();
      final synergies = (data['synergies'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((synergy) => LadderSynergy.fromMap(Map<String, dynamic>.from(synergy)))
        .toList();
      final recentStandings = (data['recentStandings'] as List<dynamic>? ?? [])
        .whereType<num>()
        .map((value) => value.toInt())
        .toList();
      final tierHistory = (data['tierHistory'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((point) => TierPoint.fromMap(Map<String, dynamic>.from(point)))
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
      gameName: data['gameName'] as String? ?? '',
      profileIconId: (data['profileIconId'] as num?)?.toInt(),
      title: _titleFor(data['firstOrEighth'] as num? ?? 0),
      elo: (data['leaguePoints'] as num? ?? 0).toInt(),
      rank: data['rank'] as String? ?? 'UNRANKED',
      division: data['division'] as String? ?? '',
      startTier: data['startTier'] as String? ?? '',
      startDivision: data['startDivision'] as String? ?? '',
      startLeaguePoints: (data['startLeaguePoints'] as num? ?? 0).toInt(),
      raceStartAt: data['raceStartAt'] as String? ?? '',
      gain: (data['lpGain'] as num? ?? 0).toInt(),
      streak: streak,
      average: average,
      matchesPlayed: (data['matchesPlayed'] as num? ?? placements.length).toInt(),
      topFourRate: (data['topFourRate'] as num? ?? 0).toDouble(),
      firstOrEighth: (data['firstOrEighth'] as num? ?? 0).toInt(),
      lastPlaces: placements.take(5).toList(),
      matchHistory: history,
      synergies: synergies,
      matchWins: (data['matchWins'] as num? ?? 0).toInt(),
      matchLosses: (data['matchLosses'] as num? ?? 0).toInt(),
      winRate: (data['winRate'] as num? ?? 0).toDouble(),
      recentStandings: recentStandings.isEmpty ? placements.take(10).toList() : recentStandings,
      tierHistory: tierHistory,
      error: data['error'] as String?,
    );
  }

  final String name;
  final String gameName;
  final int? profileIconId;
  final String title;
  final int elo;
  final String rank;
  final String division;
  final String startTier;
  final String startDivision;
  final int startLeaguePoints;
  final String raceStartAt;
  final int gain;
  final int streak;
  final double average;
  final int matchesPlayed;
  final double topFourRate;
  final int firstOrEighth;
  final List<int> lastPlaces;
  final List<LadderMatch> matchHistory;
  final List<LadderSynergy> synergies;
  final int matchWins;
  final int matchLosses;
  final double winRate;
  final List<int> recentStandings;
  final List<TierPoint> tierHistory;
  final String? error;

  bool get hasData => error == null && matchesPlayed > 0;

  static String _titleFor(num firstOrEighth) {
    if (firstOrEighth >= 4) return 'Fast 8th Enjoyer';
    return 'Race Challenger';
  }
}

class LadderMatch {
  const LadderMatch({
    required this.matchId,
    required this.placement,
    this.gameStartTimestamp,
    required this.units,
    required this.traits,
    this.goldLeft,
  });

  factory LadderMatch.fromMap(Map<String, dynamic> data) {
    return LadderMatch(
      matchId: data['matchId'] as String? ?? '',
      placement: (data['placement'] as num? ?? 0).toInt(),
      gameStartTimestamp: (data['gameStartTimestamp'] as num?)?.toInt(),
      units: (data['units'] as List<dynamic>? ?? []).length,
      traits: (data['traits'] as List<dynamic>? ?? []).length,
      goldLeft: (data['goldLeft'] as num?)?.toDouble(),
    );
  }

  final String matchId;
  final int placement;
  final int? gameStartTimestamp;
  final int units;
  final int traits;
  final double? goldLeft;
}

class LadderSynergy {
  const LadderSynergy({required this.name, required this.matches, required this.averagePlacement});

  factory LadderSynergy.fromMap(Map<String, dynamic> data) {
    return LadderSynergy(
      name: data['name'] as String? ?? 'Unknown',
      matches: (data['matches'] as num? ?? 0).toInt(),
      averagePlacement: (data['averagePlacement'] as num? ?? 0).toDouble(),
    );
  }

  final String name;
  final int matches;
  final double averagePlacement;
}

class TierPoint {
  const TierPoint({required this.timestamp, required this.tier, required this.division, required this.leaguePoints});

  factory TierPoint.fromMap(Map<String, dynamic> data) {
    return TierPoint(
      timestamp: data['timestamp'] as String? ?? '',
      tier: data['tier'] as String? ?? 'UNRANKED',
      division: data['division'] as String? ?? '',
      leaguePoints: (data['leaguePoints'] as num? ?? 0).toInt(),
    );
  }

  final String timestamp;
  final String tier;
  final String division;
  final int leaguePoints;
}