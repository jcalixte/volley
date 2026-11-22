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

// FFVB's CSV names the hall but not its address. The backend reads the address
// from FFVB's match sheet and redirects to Google Maps; `q` is the fallback
// when the sheet has none: the hall's name plus the host club's town.
type Place = Pick<RawMatch, "entity" | "code" | "venue" | "opponent" | "atHome">

export function mapsUrl(match: Place): string {
  return `${hallPath(match)}?${new URLSearchParams({ q: venueQuery(match) })}`
}

// Google Maps routes from the user's current position.
export function directionsUrl(match: Place): string {
  return `${hallPath(match)}/itineraire?${new URLSearchParams({ q: venueQuery(match) })}`
}

function hallPath(match: Place): string {
  return `/api/salle/${encodeURIComponent(match.entity)}/${encodeURIComponent(match.code)}`
}

function venueQuery(match: Place): string {
  const host = match.atHome ? HOME_TOWN : hostTown(match.opponent)
  return `${match.venue} ${host}`
}

const HOME_TOWN = "Saint-Maur-des-Fossés"

// A trailing single digit is the club's team number, not part of its name.
function hostTown(club: string): string {
  return club.replace(/\s\d$/, "")
}

export interface CalendarLinks {
  file: string
  url: string
  webcal: string
  /** Android has no webcal handler at all, so hand the feed to Google's importer. */
  google: string
}

export function calendarLinks(competitions: string[]): CalendarLinks {
  const file =
    "/api/calendar.ics" +
    (competitions.length ? `?equipe=${competitions.map(encodeURIComponent).join(",")}` : "")
  const url = `${location.origin}${file}`
  return {
    file,
    url,
    webcal: `webcal://${location.host}${file}`,
    google: `https://calendar.google.com/calendar/r?cid=${encodeURIComponent(url)}`,
  }
}

// Each colour carries white text at 4.9:1 or more, in both themes.
const TEAM_COLORS = [
  "#1d4ed8",
  "#be185d",
  "#047857",
  "#c2410c",
  "#7e22ce",
  "#0e7490",
  "#b91c1c",
  "#a16207",
]

export function teamColor(index: number): string {
  return TEAM_COLORS[index % TEAM_COLORS.length]
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
