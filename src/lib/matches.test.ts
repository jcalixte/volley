import { describe, expect, it } from "vitest"
import { calendarUrl, decorate, mapsUrl, type RawMatch } from "./matches"

function raw(overrides: Partial<RawMatch> = {}): RawMatch {
  return {
    code: "2FC004",
    poule: "2FC",
    competitionKey: "2FC",
    competition: "Nationale 2 Féminine · Poule C",
    ffvbUrl: "https://www.ffvbbeach.org/ffvbapp/resu/vbspo_calendrier.php?poule=2FC",
    entity: "ABCCS",
    round: "01",
    date: "2026-09-27",
    time: "13:30",
    team: "VIE AU GRAND AIR DE ST MAUR",
    opponent: "PLESSIS-ROBINSON VOLLEY-BALL",
    atHome: true,
    venue: "BROSSOLETTE",
    sets: "",
    score: "",
    referees: [],
    ...overrides,
  }
}

describe("decorate", () => {
  it("reads the kickoff in local time, not UTC", () => {
    const match = decorate(raw())
    expect(match.kickoff.getFullYear()).toBe(2026)
    expect(match.kickoff.getMonth()).toBe(8)
    expect(match.kickoff.getDate()).toBe(27)
    expect(match.kickoff.getHours()).toBe(13)
  })

  it("treats a match with no set score as not yet played", () => {
    const match = decorate(raw())
    expect(match.played).toBe(false)
    expect(match.won).toBeNull()
  })

  it("reads a home win from the set score", () => {
    const match = decorate(raw({ sets: "3-1" }))
    expect(match.played).toBe(true)
    expect(match.ourSets).toBe(3)
    expect(match.theirSets).toBe(1)
    expect(match.won).toBe(true)
  })

  it("flips the set score when the club is the away side", () => {
    const match = decorate(raw({ atHome: false, sets: "3-1" }))
    expect(match.ourSets).toBe(1)
    expect(match.theirSets).toBe(3)
    expect(match.won).toBe(false)
  })
})

describe("mapsUrl", () => {
  function query(match: Parameters<typeof mapsUrl>[0]) {
    return new URL(mapsUrl(match)).searchParams.get("query")
  }

  it("searches the hall together with the club's town for a home game", () => {
    expect(query(raw({ venue: "BROSSOLETTE", atHome: true }))).toBe(
      "BROSSOLETTE Saint-Maur-des-Fossés",
    )
  })

  // "PALAIS DES SPORTS" alone is worthless; the host club names the town.
  it("searches the hall together with the host club when away", () => {
    expect(
      query(raw({ venue: "PALAIS DES SPORTS", atHome: false, opponent: "BESANCON VOLLEY-BALL" })),
    ).toBe("PALAIS DES SPORTS BESANCON VOLLEY-BALL")
  })

  it("drops the host club's team number, which is not part of its name", () => {
    expect(query(raw({ venue: "HUNEBELLE", atHome: false, opponent: "C S M CLAMART 2" }))).toBe(
      "HUNEBELLE C S M CLAMART",
    )
  })

  it("keeps a number that belongs to the club's name", () => {
    expect(query(raw({ venue: "GYMNASE ELISABETH", atHome: false, opponent: "V.B. 14" }))).toBe(
      "GYMNASE ELISABETH V.B. 14",
    )
  })
})

describe("calendarUrl", () => {
  it("subscribes over webcal so the client keeps re-reading it", () => {
    expect(calendarUrl("2MB", true)).toBe(`webcal://${location.host}/api/calendar.ics?equipe=2MB`)
  })

  it("downloads over plain http", () => {
    expect(calendarUrl("2MB", false)).toBe("/api/calendar.ics?equipe=2MB")
  })

  it("omits the filter for the whole club", () => {
    expect(calendarUrl("all", false)).toBe("/api/calendar.ics")
  })
})
