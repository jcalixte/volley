import { flushPromises, mount } from "@vue/test-utils"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import App from "./App.vue"
import type { Calendar, RawMatch } from "./lib/matches"

function match(overrides: Partial<RawMatch> = {}): RawMatch {
  return {
    code: "2MB004",
    poule: "2MB",
    competitionKey: "2MB",
    competition: "Nationale 2 Masculine · Poule B",
    ffvbUrl: "https://www.ffvbbeach.org/ffvbapp/resu/vbspo_calendrier.php?poule=2MB",
    entity: "ABCCS",
    round: "01",
    date: "2026-09-27",
    time: "16:00",
    team: "VIE AU GRAND AIR DE ST MAUR",
    opponent: "PARIS VOLLEY CLUB",
    atHome: true,
    venue: "BROSSOLETTE",
    sets: "",
    score: "",
    referees: [],
    ...overrides,
  }
}

const calendar: Calendar = {
  club: "VIE AU GRAND AIR DE ST MAUR",
  season: "2026/2027",
  fetchedAt: Math.floor(Date.now() / 1000),
  stale: false,
  matches: [
    match(),
    match({ code: "2MB009", date: "2026-10-04", opponent: "PUC VOLLEY-BALL 3", atHome: false }),
    match({
      code: "1MAA012",
      poule: "1MAA",
      competitionKey: "1MA",
      competition: "Île-de-France Masculine · 1MA",
      entity: "LIIDF",
      date: "2026-10-11",
      opponent: "VOLLEY 6",
      sets: "3-1",
      score: "25-20,25-18,22-25,25-19",
    }),
    match({
      code: "1MAR040",
      poule: "1MAR",
      competitionKey: "1MA",
      competition: "Île-de-France Masculine · 1MA",
      entity: "LIIDF",
      date: "2027-02-06",
      opponent: "ASV",
    }),
  ],
}

function stubFetch(body: Calendar, ok = true) {
  vi.stubGlobal(
    "fetch",
    vi.fn(() => Promise.resolve({ ok, status: ok ? 200 : 502, json: () => Promise.resolve(body) })),
  )
}

beforeEach(() => {
  vi.useFakeTimers()
  vi.setSystemTime(new Date(2026, 8, 4))
  localStorage.clear()
  history.replaceState(null, "", "/")
})

afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

async function render() {
  stubFetch(calendar)
  const wrapper = mount(App)
  await flushPromises()
  return wrapper
}

describe("App", () => {
  it("lists the upcoming matches of every team by default", async () => {
    const wrapper = await render()
    // The played 1MAA match is excluded from "À venir".
    expect(wrapper.findAll("section li")).toHaveLength(3)
    expect(wrapper.text()).toContain("PARIS VOLLEY CLUB")
    expect(wrapper.text()).toContain("ASV")
  })

  it("announces the next match at the top", async () => {
    const wrapper = await render()
    expect(wrapper.text()).toContain("Prochain match")
    expect(wrapper.text()).toContain("Réception de PARIS VOLLEY CLUB")
  })

  it("marks home and away", async () => {
    const wrapper = await render()
    expect(wrapper.text()).toContain("Domicile")
    expect(wrapper.text()).toContain("Extérieur")
  })

  it("groups the aller and retour phases under one filter", async () => {
    const wrapper = await render()
    const filters = wrapper.findAll("button").map((b) => b.text())
    expect(filters.filter((f) => f.includes("Île-de-France"))).toHaveLength(1)
  })

  it("narrows the list to one championship when a filter is picked", async () => {
    const wrapper = await render()
    const regional = wrapper.findAll("button").find((b) => b.text().includes("Île-de-France"))!
    await regional.trigger("click")
    expect(wrapper.findAll("section li")).toHaveLength(1)
    expect(wrapper.text()).toContain("ASV")
    expect(wrapper.text()).not.toContain("PARIS VOLLEY CLUB")
  })

  it("shows played matches with their score under Résultats", async () => {
    const wrapper = await render()
    const results = wrapper.findAll("button").find((b) => b.text().startsWith("Résultats"))!
    await results.trigger("click")
    expect(wrapper.findAll("section li")).toHaveLength(1)
    expect(wrapper.text()).toContain("3–1")
    expect(wrapper.text()).toContain("25-20 · 25-18 · 22-25 · 25-19")
  })

  it("warns when the calendar being shown is a stale fallback", async () => {
    stubFetch({ ...calendar, stale: true })
    const wrapper = mount(App)
    await flushPromises()
    expect(wrapper.text()).toContain("La FFVB ne répond pas")
  })

  it("surfaces an error instead of an empty page when the API is down", async () => {
    stubFetch(calendar, false)
    const wrapper = mount(App)
    await flushPromises()
    expect(wrapper.text()).toContain("injoignable")
  })
})

describe("remembering a team", () => {
  it("keeps the picked championship for the next visit", async () => {
    const first = await render()
    const regional = first.findAll("button").find((b) => b.text().includes("Île-de-France"))!
    await regional.trigger("click")

    const second = await render()
    expect(second.findAll("section li")).toHaveLength(1)
    expect(second.text()).toContain("ASV")
  })

  it("puts the championship in the URL so a link can be shared", async () => {
    const wrapper = await render()
    const regional = wrapper.findAll("button").find((b) => b.text().includes("Île-de-France"))!
    await regional.trigger("click")
    expect(new URL(location.href).searchParams.get("equipe")).toBe("1MA")
  })

  it("opens on the championship named in the link", async () => {
    history.replaceState(null, "", "/?equipe=1MA")
    const wrapper = await render()
    expect(wrapper.findAll("section li")).toHaveLength(1)
    expect(wrapper.text()).toContain("ASV")
  })

  // Poule codes change between seasons; a remembered one that no longer exists
  // must not leave the page looking empty.
  it("falls back to every team when the remembered championship is gone", async () => {
    localStorage.setItem("equipe", "9XX")
    const wrapper = await render()
    expect(wrapper.findAll("section li")).toHaveLength(3)
  })
})

describe("adding to a calendar", () => {
  it("offers a subscription for the whole club by default", async () => {
    const wrapper = await render()
    const subscribe = wrapper.find('a[href^="webcal://"]')
    expect(subscribe.exists()).toBe(true)
    expect(subscribe.attributes("href")).not.toContain("equipe=")
  })

  it("scopes the subscription to the picked championship", async () => {
    const wrapper = await render()
    const regional = wrapper.findAll("button").find((b) => b.text().includes("Île-de-France"))!
    await regional.trigger("click")
    expect(wrapper.find('a[href^="webcal://"]').attributes("href")).toContain("equipe=1MA")
  })

  it("names the championship being subscribed to", async () => {
    const wrapper = await render()
    const regional = wrapper.findAll("button").find((b) => b.text().includes("Île-de-France"))!
    await regional.trigger("click")
    expect(wrapper.text()).toContain("Île-de-France Masculine · 1MA")
  })

  it("also offers a one-off download", async () => {
    const wrapper = await render()
    const download = wrapper.find("a[download]")
    expect(download.exists()).toBe(true)
    expect(download.attributes("href")).toContain("/api/calendar.ics")
  })
})
