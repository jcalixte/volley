import { describe, expect, it } from "vitest"
import { countdown } from "./format"

describe("countdown", () => {
  it("counts calendar days, not hours", () => {
    const friday = new Date(2026, 10, 13, 23, 30)
    expect(countdown(new Date(2026, 10, 14, 10, 0), friday)).toBe("Demain")
    expect(countdown(new Date(2026, 10, 13, 23, 45), friday)).toBe("Aujourd'hui")
    expect(countdown(new Date(2026, 10, 21, 16, 0), friday)).toBe("Dans 8 jours")
  })

  it("is not thrown off by the clocks going back", () => {
    const beforeChange = new Date(2026, 9, 24, 12, 0)
    expect(countdown(new Date(2026, 9, 26, 9, 0), beforeChange)).toBe("Dans 2 jours")
  })
})
