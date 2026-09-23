import { describe, expect, it } from "vitest"
import { addMonths, dateKey, monthGrid, weekdayHeaders } from "./calendar"
import { decorate, type Match, type RawMatch } from "./matches"

function match(date: string, overrides: Partial<RawMatch> = {}): Match {
  return decorate({
    code: `X${date}`,
    poule: "2MB",
    competitionKey: "2MB",
    competition: "Nationale 2 Masculine · Poule B",
    ffvbUrl: "",
    entity: "ABCCS",
    round: "01",
    date,
    time: "16:00",
    team: "VIE AU GRAND AIR DE ST MAUR",
    opponent: "PARIS VOLLEY CLUB",
    atHome: true,
    venue: "BROSSOLETTE",
    sets: "",
    score: "",
    referees: [],
    ...overrides,
  })
}

describe("monthGrid", () => {
  it("opens the week on Monday and closes it on Sunday", () => {
    const [first] = monthGrid(new Date(2026, 8, 1), [])
    expect(first[0].date.getDay()).toBe(1)
    expect(first[6].date.getDay()).toBe(0)
    expect(weekdayHeaders[0]).toBe("lun")
    expect(weekdayHeaders[6]).toBe("dim")
  })

  it("marks the last two columns as the weekend", () => {
    const [first] = monthGrid(new Date(2026, 8, 1), [])
    expect(first.map((day) => day.weekend)).toEqual([false, false, false, false, false, true, true])
  })

  it("pads the rows with the neighbouring months and flags them as outside", () => {
    // 2026-09-01 is a Tuesday, so August 31 opens the grid.
    const weeks = monthGrid(new Date(2026, 8, 1), [])
    expect(weeks[0][0].key).toBe("2026-08-31")
    expect(weeks[0][0].outside).toBe(true)
    expect(weeks[0][1].outside).toBe(false)
    expect(weeks.flat()).toHaveLength(weeks.length * 7)
  })

  it("covers every day of the month exactly once", () => {
    const inside = monthGrid(new Date(2026, 8, 1), [])
      .flat()
      .filter((day) => !day.outside)
    expect(inside).toHaveLength(30)
  })

  it("files each match under its own day", () => {
    const weeks = monthGrid(new Date(2026, 8, 1), [match("2026-09-27"), match("2026-09-27")])
    const day = weeks.flat().find((d) => d.key === "2026-09-27")!
    expect(day.matches).toHaveLength(2)
    expect(weeks.flat().filter((d) => d.matches.length)).toHaveLength(1)
  })

  it("ignores a match that falls outside the month on show", () => {
    const weeks = monthGrid(new Date(2026, 8, 1), [match("2026-12-05")])
    expect(weeks.flat().some((day) => day.matches.length)).toBe(false)
  })

  it("highlights exactly one day, today", () => {
    const weeks = monthGrid(new Date(2026, 8, 1), [], new Date(2026, 8, 4))
    const today = weeks.flat().filter((day) => day.today)
    expect(today).toHaveLength(1)
    expect(today[0].key).toBe("2026-09-04")
  })

  it("highlights nothing when today is in another month", () => {
    const weeks = monthGrid(new Date(2026, 11, 1), [], new Date(2026, 8, 4))
    expect(weeks.flat().some((day) => day.today)).toBe(false)
  })
})

describe("dateKey", () => {
  it("pads to the FFVB format so it matches a raw match date", () => {
    expect(dateKey(new Date(2026, 8, 4))).toBe("2026-09-04")
  })
})

describe("addMonths", () => {
  it("rolls over the year in both directions", () => {
    expect(dateKey(addMonths(new Date(2026, 11, 1), 1))).toBe("2027-01-01")
    expect(dateKey(addMonths(new Date(2026, 0, 1), -1))).toBe("2025-12-01")
  })
})
