export interface RawMatch {
  code: string
  poule: string
  competitionKey: string
  competition: string
  ffvbUrl: string
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
  played: boolean
  ourSets: number | null
  theirSets: number | null
  won: boolean | null
}

// FFVB gives the hall's name but not its address — that only exists inside the
// per-match PDF. A search query carries enough to land on it: the hall name is
// ambiguous alone ("PALAIS DES SPORTS", "GYMNASE MUNICIPAL"), but the host club
// names its town, and every home game is played in Saint-Maur.
export function mapsUrl(match: Pick<RawMatch, "venue" | "opponent" | "atHome">): string {
  const host = match.atHome ? HOME_TOWN : hostTown(match.opponent)
  const query = new URLSearchParams({ api: "1", query: `${match.venue} ${host}` })
  return `https://www.google.com/maps/search/?${query}`
}

const HOME_TOWN = "Saint-Maur-des-Fossés"

// A trailing single digit is the club's team number, not part of its name.
function hostTown(club: string): string {
  return club.replace(/\s\d$/, "")
}

// A subscription rather than a download: FFVB moves fixtures mid-season, and a
// subscribed calendar picks that up where an imported file stays wrong.
export function calendarUrl(competition: string, subscribe: boolean): string {
  const path =
    "/api/calendar.ics" +
    (competition === "all" ? "" : `?equipe=${encodeURIComponent(competition)}`)
  return subscribe ? `webcal://${location.host}${path}` : path
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
    played,
    ourSets,
    theirSets,
    won: played ? ourSets! > theirSets! : null,
  }
}

export function byKickoff(a: Match, b: Match): number {
  return a.kickoff.getTime() - b.kickoff.getTime()
}
