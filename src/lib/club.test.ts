import { afterEach, describe, expect, it } from "vitest"
import { HOME_CLUB, clubQuery, clubUrl, isHomeClub, viewedClub } from "./club"

function visit(search: string) {
  history.replaceState(null, "", `/${search}`)
}

describe("viewedClub", () => {
  afterEach(() => visit(""))

  it("is ours without a club in the link", () => {
    visit("")
    expect(viewedClub()).toBe(HOME_CLUB)
    expect(isHomeClub()).toBe(true)
    expect(clubQuery()).toBe("")
  })

  it("reads another club from the link", () => {
    visit("?club=0885362&onglet=results")
    expect(viewedClub()).toBe("0885362")
    expect(isHomeClub()).toBe(false)
    expect(clubQuery()).toBe("?club=0885362")
  })

  it("falls back to ours on a malformed code", () => {
    visit("?club=../api")
    expect(viewedClub()).toBe(HOME_CLUB)
  })
})

describe("clubUrl", () => {
  it("links another club through the club parameter", () => {
    expect(clubUrl("0885362")).toBe("/?club=0885362")
  })

  it("links our own club to the plain page", () => {
    expect(clubUrl(HOME_CLUB)).toBe("/")
  })

  it("gives a bye no link", () => {
    expect(clubUrl("")).toBeUndefined()
  })
})
