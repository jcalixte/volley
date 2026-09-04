export interface RawMatch {
  code: string
  poule: string
  entity: string
  round: string
  date: string
  time: string
  team: string
  opponent: string
  atHome: boolean
  venue: string
  sets: string
  score: string
  referees: string[]
}

export interface Calendar {
  club: string
  season: string
  fetchedAt: number
  stale: boolean
  matches: RawMatch[]
}

export interface Match extends RawMatch {
  kickoff: Date
  competition: string
  played: boolean
  ourSets: number | null
  theirSets: number | null
  won: boolean | null
}

// FFVB poule codes are positional: level, gender, group, and — in the regional
// championships only — a phase letter, A for aller and R for retour. The two
// phases are one championship, so they share a competition key.
export function competitionKey(poule: string): string {
  return poule.length > 3 ? poule.slice(0, 3) : poule
}

export function competitionLabel(poule: string, entity: string): string {
  const gender = poule[1] === "M" ? "Masculine" : "Féminine"
  return entity === "ABCCS"
    ? `Nationale ${poule[0]} ${gender} · Poule ${poule[2]}`
    : `Île-de-France ${gender} · ${competitionKey(poule)}`
}

export function ffvbUrl(poule: string, entity: string, season: string): string {
  const params = new URLSearchParams({ saison: season, codent: entity, poule })
  return `https://www.ffvbbeach.org/ffvbapp/resu/vbspo_calendrier.php?${params}`
}

export async function fetchCalendar(): Promise<Calendar> {
  const response = await fetch("/api/matches")
  if (!response.ok) throw new Error(`Le calendrier FFVB est injoignable (${response.status})`)
  return response.json()
}

export function decorate(raw: RawMatch): Match {
  const [year, month, day] = raw.date.split("-").map(Number)
  const [hours, minutes] = raw.time.split(":").map(Number)
  const kickoff = new Date(year, month - 1, day, hours || 0, minutes || 0)

  const [homeSets, awaySets] = raw.sets.split("-").map(Number)
  const played = Number.isFinite(homeSets) && Number.isFinite(awaySets)
  const ourSets = played ? (raw.atHome ? homeSets : awaySets) : null
  const theirSets = played ? (raw.atHome ? awaySets : homeSets) : null

  return {
    ...raw,
    kickoff,
    competition: competitionLabel(raw.poule, raw.entity),
    played,
    ourSets,
    theirSets,
    won: played ? ourSets! > theirSets! : null,
  }
}

export function byKickoff(a: Match, b: Match): number {
  return a.kickoff.getTime() - b.kickoff.getTime()
}
