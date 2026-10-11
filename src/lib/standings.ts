export interface StandingRow {
  rank: number
  team: string
  /** FFVB stamps each line with its club, so our own teams are known, not guessed. */
  ours: boolean
  points: number
  played: number
  won: number
  lost: number
  forfeits: number
  setsWon: number
  setsLost: number
  /** A string, not a number: FFVB prints "MAX" when no set has been conceded. */
  setRatio: string
  pointsWon: number
  pointsLost: number
  pointRatio: string
}

export interface Ranking {
  /** The poule code, the same key the matches carry. */
  key: string
  title: string
  level: string
  entity: string
  ffvbUrl: string
  rows: StandingRow[]
}

export interface Standings {
  club: string
  season: string
  fetchedAt: number
  stale: boolean
  tables: Ranking[]
}

export async function fetchStandings(): Promise<Standings> {
  const response = await fetch("/api/standings")
  if (!response.ok) throw new Error(`Le classement FFVB est injoignable (${response.status})`)
  return response.json()
}
