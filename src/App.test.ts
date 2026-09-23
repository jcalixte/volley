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

type Wrapper = Awaited<ReturnType<typeof render>>

function teamOptions(wrapper: Wrapper) {
  return wrapper.findAll("select option").map((o) => o.text())
}

async function pickRegional(wrapper: Wrapper) {
  await wrapper.find("select").setValue("1MA")
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
    expect(teamOptions(wrapper).filter((f) => f.includes("Île-de-France"))).toHaveLength(1)
  })

  it("offers a Google subscription, the only route that works on Android", async () => {
    const wrapper = await render()
    const feed = encodeURIComponent(`${location.origin}/api/calendar.ics`)
    const links = wrapper.findAll("a").map((a) => a.attributes("href"))
    expect(links).toContain(`https://calendar.google.com/calendar/r?cid=${feed}`)
    expect(links).toContain(`webcal://${location.host}/api/calendar.ics`)
  })

  it("copies the feed address for clients that open neither scheme", async () => {
    const writeText = vi.fn(() => Promise.resolve())
    vi.stubGlobal("navigator", { ...navigator, clipboard: { writeText } })
    const wrapper = await render()
    const copy = wrapper.findAll("button").find((b) => b.text().includes("Copier le lien"))!
    await copy.trigger("click")
    await flushPromises()
    expect(writeText).toHaveBeenCalledWith(`${location.origin}/api/calendar.ics`)
    expect(wrapper.text()).toContain("Lien copié")
  })

  it("narrows the list to one championship when a filter is picked", async () => {
    const wrapper = await render()
    await pickRegional(wrapper)
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
    await pickRegional(first)

    const second = await render()
    expect(second.findAll("section li")).toHaveLength(1)
    expect(second.text()).toContain("ASV")
  })

  it("puts the championship in the URL so a link can be shared", async () => {
    const wrapper = await render()
    await pickRegional(wrapper)
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
    await pickRegional(wrapper)
    expect(wrapper.find('a[href^="webcal://"]').attributes("href")).toContain("equipe=1MA")
  })

  it("names the championship being subscribed to", async () => {
    const wrapper = await render()
    await pickRegional(wrapper)
    expect(wrapper.find(".menu-title").text()).toBe("Île-de-France Masculine · 1MA")
  })

  it("also offers a one-off download", async () => {
    const wrapper = await render()
    const download = wrapper.find("a[download]")
    expect(download.exists()).toBe(true)
    expect(download.attributes("href")).toContain("/api/calendar.ics")
  })
})

describe("the calendar view", () => {
  async function openCalendar(wrapper: Wrapper) {
    const tab = wrapper.findAll("button").find((b) => b.text() === "Calendrier")!
    await tab.trigger("click")
    return wrapper
  }

  it("opens on the current month with today highlighted", async () => {
    const wrapper = await openCalendar(await render())
    expect(wrapper.text()).toContain("septembre 2026")
    const today = wrapper.findAll(".bg-primary.rounded-full")
    expect(today).toHaveLength(1)
    expect(today[0].text()).toBe("4")
  })

  it("gives the weekend columns more room than the weekdays", async () => {
    const wrapper = await openCalendar(await render())
    expect(wrapper.html()).toContain("grid-cols-[repeat(5,minmax(0,1fr))_1.6fr_1.6fr]")
  })

  it("places a match on its own day and leaves the other months out", async () => {
    const wrapper = await openCalendar(await render())
    expect(wrapper.text()).toContain("16:00PARIS VOLLEY CLUB")
    expect(wrapper.text()).not.toContain("ASV")
  })

  it("walks to the month that holds the next match", async () => {
    const wrapper = await openCalendar(await render())
    await wrapper.find('[aria-label="Mois suivant"]').trigger("click")
    expect(wrapper.text()).toContain("octobre 2026")
    expect(wrapper.text()).toContain("PUC VOLLEY-BALL 3")
    expect(wrapper.text()).toContain("3–1")
  })

  it("offers a way back once the month on show is not the current one", async () => {
    const wrapper = await openCalendar(await render())
    expect(wrapper.text()).not.toContain("Aujourd'hui")
    await wrapper.find('[aria-label="Mois précédent"]').trigger("click")
    const back = wrapper.findAll("button").find((b) => b.text() === "Aujourd'hui")!
    await back.trigger("click")
    expect(wrapper.text()).toContain("septembre 2026")
  })

  it("keeps the team filter", async () => {
    const wrapper = await render()
    await pickRegional(wrapper)
    await openCalendar(wrapper)
    await wrapper.find('[aria-label="Mois suivant"]').trigger("click")
    expect(wrapper.text()).toContain("VOLLEY 6")
    expect(wrapper.text()).not.toContain("PUC VOLLEY-BALL 3")
  })
})
