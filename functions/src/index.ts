import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";

initializeApp();

const db = getFirestore();
const riotApiKey = defineSecret("RIOT_API_KEY");
const regionalRoute = "europe";
const platformRoute = "euw1";

type RacePlayer = {
  id: string;
  name: string;
  gameName: string;
  tagLine: string;
  startLeaguePoints?: number;
  startTier?: string;
  startDivision?: string;
  raceStartAt?: string;
};

type RiotRank = {
  tier: string;
  rank: string;
  leaguePoints: number;
  wins: number;
  losses: number;
};

type CachedTrait = {
  name: string;
};

type CachedMatch = {
  matchId: string;
  placement: number;
  gameStartTimestamp?: number;
  units: unknown[];
  traits: CachedTrait[];
  goldLeft?: number;
};

type CachedPlayer = RacePlayer & {
  matchHistory?: CachedMatch[];
  tierHistory?: TierPoint[];
};

type TierPoint = {
  timestamp: string;
  tier: string;
  division: string;
  leaguePoints: number;
};

const tierOrder: Record<string, number> = {
  IRON: 0,
  BRONZE: 1,
  SILVER: 2,
  GOLD: 3,
  PLATINUM: 4,
  EMERALD: 5,
  DIAMOND: 6,
  MASTER: 7,
  GRANDMASTER: 8,
  CHALLENGER: 9,
};

function rankPoints(tier: string, division: string, leaguePoints: number) {
  const tierValue = tierOrder[tier] ?? 0;
  const normalizedDivision = division.toUpperCase().trim();
  const romanDivision: Record<string, number> = { I: 1, II: 2, III: 3, IV: 4 };
  const divisionValue = romanDivision[normalizedDivision] ?? Number.parseInt(normalizedDivision, 10);
  const divisionPoints = Number.isFinite(divisionValue)
    ? Math.max(0, 4 - divisionValue) * 100
    : 0;
  return tierValue * 400 + divisionPoints + leaguePoints;
}

async function riotGet<T>(host: string, path: string): Promise<T> {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const response = await fetch(`https://${host}.api.riotgames.com${path}`, {
      headers: { "X-Riot-Token": riotApiKey.value() },
    });
    if (response.ok) {
      return response.json() as Promise<T>;
    }
    if (response.status !== 429 || attempt === 2) {
      throw new Error(`Riot API ${response.status} for ${path}`);
    }
    const retryAfter = Number(response.headers.get("retry-after") ?? "2");
    const delaySeconds = Number.isFinite(retryAfter) ? Math.max(1, retryAfter) : 2;
    await new Promise((resolve) => setTimeout(resolve, delaySeconds * 1000));
  }
  throw new Error(`Riot API request failed for ${path}`);
}

async function loadPlayer(
  player: RacePlayer,
  cachedMatches: CachedMatch[] = [],
  cachedTierHistory: TierPoint[] = [],
) {
  const hashIndex = player.gameName.lastIndexOf("#");
  const gameName = hashIndex >= 0 ? player.gameName.slice(0, hashIndex) : player.gameName;
  const tagLine = hashIndex >= 0 ? player.gameName.slice(hashIndex + 1) : player.tagLine;
  const account = await riotGet<{ puuid: string }>(
    regionalRoute,
    `/riot/account/v1/accounts/by-riot-id/${encodeURIComponent(gameName)}/${encodeURIComponent(tagLine)}`,
  );
  const summoner = await riotGet<{ puuid: string; profileIconId?: number }>(
    platformRoute,
    `/tft/summoner/v1/summoners/by-puuid/${encodeURIComponent(account.puuid)}`,
  );
  const ranks = await riotGet<RiotRank[]>(
    platformRoute,
    `/tft/league/v1/by-puuid/${encodeURIComponent(account.puuid)}`,
  );
  const rank = ranks[0] ?? {
    tier: "UNRANKED",
    rank: "",
    leaguePoints: 0,
    wins: 0,
    losses: 0,
  };
  const matchIds: string[] = [];
  for (let page = 0; page < 10; page += 1) {
    const pageIds = await riotGet<string[]>(
      regionalRoute,
      `/tft/match/v1/matches/by-puuid/${encodeURIComponent(account.puuid)}/ids?start=${page * 100}&count=100`,
    );
    matchIds.push(...pageIds);
    if (pageIds.length < 100) break;
  }
  const recentMatchIds = [...new Set(matchIds)];
  const matchHistoryById = new Map(
    cachedMatches.map((match) => [match.matchId, match]),
  );
  const newMatchIds = recentMatchIds.filter((matchId) => {
    const cached = matchHistoryById.get(matchId);
    return !cached || cached.gameStartTimestamp === undefined;
  });

  for (const matchId of newMatchIds) {
    const match = await riotGet<{
      info: {
        game_datetime?: number;
        participants: Array<{
          puuid: string;
          placement: number;
          units: unknown[];
          traits: Array<{ name?: string; style?: number }>;
          gold_left?: number;
        }>;
      };
    }>(
      regionalRoute,
      `/tft/match/v1/matches/${encodeURIComponent(matchId)}`,
    );
    const participant = match.info.participants.find(
      (entry) => entry.puuid === account.puuid,
    );
    if (participant) {
      matchHistoryById.set(matchId, {
        matchId,
        placement: participant.placement,
        gameStartTimestamp: match.info.game_datetime,
        units: participant.units,
        traits: participant.traits
          .filter((trait) => Boolean(trait.name) && (trait.style ?? 0) > 0)
          .map((trait) => ({name: trait.name!})),
        goldLeft: participant.gold_left,
      });
    }
  }

  const raceStartTimestamp = player.raceStartAt
    ? Date.parse(player.raceStartAt)
    : Number.NEGATIVE_INFINITY;
  const matchHistory = recentMatchIds
    .map((matchId) => matchHistoryById.get(matchId))
    .filter((match): match is CachedMatch => match !== undefined)
    .filter((match) => (match.gameStartTimestamp ?? Number.POSITIVE_INFINITY) >= raceStartTimestamp);
  const placements = matchHistory.map((match) => match.placement);
  const firstPlacement = placements.at(-1) ?? null;
  const topFour = placements.filter((placement) => placement <= 4).length;
  const synergyTotals = new Map<string, {matches: number; placementTotal: number}>();
  for (const match of matchHistory) {
    for (const trait of match.traits) {
      const current = synergyTotals.get(trait.name) ?? {matches: 0, placementTotal: 0};
      synergyTotals.set(trait.name, {
        matches: current.matches + 1,
        placementTotal: current.placementTotal + match.placement,
      });
    }
  }
  const synergies = [...synergyTotals.entries()]
    .map(([name, value]) => ({
      name,
      matches: value.matches,
      averagePlacement: value.placementTotal / value.matches,
    }))
    .sort((left, right) => right.matches - left.matches)
    .slice(0, 8);
  const matchWins = placements.filter((placement) => placement === 1).length;
  const matchLosses = placements.filter((placement) => placement > 4).length;
  const tierHistory = [
    ...cachedTierHistory,
    {
      timestamp: new Date().toISOString(),
      tier: rank.tier,
      division: rank.rank,
      leaguePoints: rank.leaguePoints,
    },
  ].slice(-30);
  const hasStartRank = Boolean(player.startTier);
  const lpGain = hasStartRank
    ? rankPoints(rank.tier, rank.rank, rank.leaguePoints) - rankPoints(
        player.startTier!,
        player.startDivision ?? "",
        player.startLeaguePoints ?? 0,
      )
    : rank.leaguePoints - (player.startLeaguePoints ?? rank.leaguePoints);

  return {
    ...player,
    puuid: account.puuid,
    profileIconId: summoner.profileIconId ?? null,
    rank: rank.tier,
    division: rank.rank,
    leaguePoints: rank.leaguePoints,
    lpGain,
    startTier: player.startTier ?? "",
    startDivision: player.startDivision ?? "",
    raceStartAt: player.raceStartAt ?? "",
    wins: rank.wins,
    losses: rank.losses,
    placements,
    matchHistory,
    synergies,
    matchWins,
    matchLosses,
    winRate: placements.length === 0 ? 0 : matchWins / placements.length,
    recentStandings: placements.slice(0, 10),
    tierHistory,
    firstPlacement,
    matchesPlayed: placements.length,
    topFourRate: placements.length === 0 ? 0 : topFour / placements.length,
    firstOrEighth: placements.filter((placement) => placement === 1 || placement === 8).length,
    lastUpdated: new Date().toISOString(),
  };
}

async function loadPlayerSafely(
  player: RacePlayer,
  cachedMatches: CachedMatch[] = [],
  cachedTierHistory: TierPoint[] = [],
) {
  try {
    return await loadPlayer(player, cachedMatches, cachedTierHistory);
  } catch (error) {
    logger.error("Failed to load player", {
      playerId: player.id,
      name: player.name,
      error: error instanceof Error ? error.message : String(error),
    });
    const placements = cachedMatches.map((match) => match.placement);
    const matchWins = placements.filter((placement) => placement === 1).length;
    const matchLosses = placements.filter((placement) => placement > 4).length;
    return {
      ...player,
      rank: "ERROR",
      division: "",
      leaguePoints: 0,
      lpGain: 0,
      wins: 0,
      losses: 0,
      placements,
      matchHistory: cachedMatches,
      synergies: [],
      matchWins,
      matchLosses,
      winRate: placements.length === 0 ? 0 : matchWins / placements.length,
      recentStandings: placements.slice(0, 10),
      tierHistory: cachedTierHistory,
      firstPlacement: placements.at(-1) ?? null,
      matchesPlayed: placements.length,
      topFourRate: placements.length === 0
        ? 0
        : placements.filter((placement) => placement <= 4).length / placements.length,
      firstOrEighth: placements.filter((placement) => placement === 1 || placement === 8).length,
      error: "Riot-Daten konnten nicht geladen werden",
      lastUpdated: new Date().toISOString(),
    };
  }
}

export const refreshLadderData = onSchedule(
  {
    region: "europe-west1",
    schedule: "every 60 minutes",
    timeZone: "Europe/Berlin",
    secrets: [riotApiKey],
  },
  async () => {
    const config = await db.doc("race_config/players").get();
    const players = (config.data()?.players ?? []) as RacePlayer[];
    if (players.length !== 4) {
      throw new Error("race_config/players must contain exactly four players");
    }

    const previousData = await db.doc("ladder_data/current").get();
    const previousPlayers = (previousData.data()?.players ?? []) as CachedPlayer[];
    const previousById = new Map(
      previousPlayers.map((player) => [player.id, player]),
    );
    const results = [];
    for (const player of players) {
      results.push(
        await loadPlayerSafely(
          player,
          previousById.get(player.id)?.matchHistory ?? [],
          previousById.get(player.id)?.tierHistory ?? [],
        ),
      );
    }
    await db.doc("ladder_data/current").set({
      players: results,
      updatedAt: new Date().toISOString(),
    });
    logger.info("Updated ladder data", { playerCount: results.length });
  },
);
