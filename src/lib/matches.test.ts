import { describe, expect, it } from "vitest"
import { calendarLinks, decorate, directionsUrl, mapsUrl, type RawMatch } from "./matches"

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
    opponentCode: "0929372",
    atHome: true,
    venue: "BROSSOLETTE",
    address: null,
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

describe("hall links", () => {
  const address = "COUCHOT, 2 RUE COUCHOT, 92100 BOULOGNE BILLANCOURT"

  it("searches Google Maps for the address directly", () => {
    const url = new URL(mapsUrl(address))
    expect(url.origin + url.pathname).toBe("https://www.google.com/maps/search/")
    expect(url.searchParams.get("query")).toBe(address)
  })

  it("routes to the address directly, leaving no redirect tab behind", () => {
    const url = new URL(directionsUrl(address))
    expect(url.origin + url.pathname).toBe("https://www.google.com/maps/dir/")
    expect(url.searchParams.get("api")).toBe("1")
    expect(url.searchParams.get("destination")).toBe(address)
  })
})

describe("calendarLinks", () => {
  it("subscribes over webcal so the client keeps re-reading it", () => {
    expect(calendarLinks(["2MB"]).webcal).toBe(
      `webcal://${location.host}/api/calendar.ics?equipe=2MB`,
    )
  })

  it("hands the https feed to Google, the only route Android offers", () => {
    const feed = encodeURIComponent(`${location.origin}/api/calendar.ics?equipe=2MB`)
    expect(calendarLinks(["2MB"]).google).toBe(`https://calendar.google.com/calendar/r?cid=${feed}`)
  })

  it("downloads over plain http", () => {
    expect(calendarLinks(["2MB"]).file).toBe("/api/calendar.ics?equipe=2MB")
  })

  it("omits the filter for the whole club", () => {
    expect(calendarLinks([]).file).toBe("/api/calendar.ics")
  })

  it("lists several championships in one feed", () => {
    expect(calendarLinks(["2MB", "2FA"]).file).toBe("/api/calendar.ics?equipe=2MB,2FA")
  })
})
