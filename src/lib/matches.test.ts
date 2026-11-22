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
    return new URL(mapsUrl(match), location.origin).searchParams.get("q")
  }

  it("asks the backend for the match's hall", () => {
    expect(new URL(mapsUrl(raw()), location.origin).pathname).toBe("/api/salle/ABCCS/2FC004")
  })

  it("guesses the hall together with the club's town for a home game", () => {
    expect(query(raw({ venue: "BROSSOLETTE", atHome: true }))).toBe(
      "BROSSOLETTE Saint-Maur-des-Fossés",
    )
  })

  it("guesses the hall together with the host club when away", () => {
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

describe("directionsUrl", () => {
  it("asks the backend to route to the match's hall, with a fallback guess", () => {
    const url = new URL(
      directionsUrl(
        raw({
          entity: "ABCCS",
          code: "2MB042",
          venue: "COUCHOT",
          atHome: false,
          opponent: "ACBB 2",
        }),
      ),
      location.origin,
    )
    expect(url.pathname).toBe("/api/salle/ABCCS/2MB042/itineraire")
    expect(url.searchParams.get("q")).toBe("COUCHOT ACBB")
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
