import { describe, expect, it } from "vitest"
import { absenceOn, type Absence } from "./absences"

const japan: Absence[] = [
  { flag: "🇯🇵", reason: "Passeur au Japon", from: "2026-11-17", to: "2027-02-15" },
]

describe("absenceOn", () => {
  it("flags a match inside the window", () => {
    expect(absenceOn("2026-12-13", japan)?.flag).toBe("🇯🇵")
  })

  it("counts both ends of the window as away", () => {
    expect(absenceOn("2026-11-17", japan)).toBeDefined()
    expect(absenceOn("2027-02-15", japan)).toBeDefined()
  })

  it("leaves the day before and the day after alone", () => {
    expect(absenceOn("2026-11-16", japan)).toBeUndefined()
    expect(absenceOn("2027-02-16", japan)).toBeUndefined()
  })
})
