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
};

type RiotRank = {
  tier: string;
  rank: string;
  leaguePoints: number;
  wins: number;
  losses: number;
};

type CachedMatch = {
  matchId: string;
  placement: number;
  units: unknown[];
  traits: unknown[];
  goldLeft?: number;
};

type CachedPlayer = RacePlayer & {
  matchHistory?: CachedMatch[];
};

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

async function loadPlayer(player: RacePlayer, cachedMatches: CachedMatch[] = []) {
  const hashIndex = player.gameName.lastIndexOf("#");
  const gameName = hashIndex >= 0 ? player.gameName.slice(0, hashIndex) : player.gameName;
  const tagLine = hashIndex >= 0 ? player.gameName.slice(hashIndex + 1) : player.tagLine;
  const account = await riotGet<{ puuid: string }>(
    regionalRoute,
    `/riot/account/v1/accounts/by-riot-id/${encodeURIComponent(gameName)}/${encodeURIComponent(tagLine)}`,
  );
  const summoner = await riotGet<{ id?: string; summonerId?: string }>(
    platformRoute,
    `/tft/summoner/v1/summoners/by-puuid/${encodeURIComponent(account.puuid)}`,
  );
  const summonerId = summoner.id ?? summoner.summonerId;
  const ranks = summonerId
    ? await riotGet<RiotRank[]>(
        platformRoute,
        `/tft/league/v1/entries/by-summoner/${encodeURIComponent(summonerId)}`,
      )
    : [];
  const rank = ranks[0] ?? {
    tier: "UNRANKED",
    rank: "",
    leaguePoints: 0,
    wins: 0,
    losses: 0,
  };
  const matchIds = await riotGet<string[]>(
    regionalRoute,
    `/tft/match/v1/matches/by-puuid/${encodeURIComponent(account.puuid)}/ids?count=20`,
  );
  const recentMatchIds = matchIds.slice(0, 20);
  const matchHistoryById = new Map(
    cachedMatches.map((match) => [match.matchId, match]),
  );
  const newMatchIds = recentMatchIds.filter(
    (matchId) => !matchHistoryById.has(matchId),
  );

  for (const matchId of newMatchIds) {
    const match = await riotGet<{
      info: {
        participants: Array<{
          puuid: string;
          placement: number;
          units: unknown[];
          traits: unknown[];
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
        units: participant.units,
        traits: participant.traits,
        goldLeft: participant.gold_left,
      });
    }
  }

  const matchHistory = recentMatchIds
    .map((matchId) => matchHistoryById.get(matchId))
    .filter((match): match is CachedMatch => match !== undefined);
  const placements = matchHistory.map((match) => match.placement);
  const firstPlacement = placements.at(-1) ?? null;
  const topFour = placements.filter((placement) => placement <= 4).length;

  return {
    ...player,
    puuid: account.puuid,
    rank: rank.tier,
    division: rank.rank,
    leaguePoints: rank.leaguePoints,
    lpGain: rank.leaguePoints - (player.startLeaguePoints ?? rank.leaguePoints),
    wins: rank.wins,
    losses: rank.losses,
    placements,
    matchHistory,
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
) {
  try {
    return await loadPlayer(player, cachedMatches);
  } catch (error) {
    logger.error("Failed to load player", {
      playerId: player.id,
      name: player.name,
      error: error instanceof Error ? error.message : String(error),
    });
    const placements = cachedMatches.map((match) => match.placement);
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
