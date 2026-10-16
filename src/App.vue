<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from "vue"
import MatchRow from "@/components/MatchRow.vue"
import MatchCalendar from "@/components/MatchCalendar.vue"
import RankingTable from "@/components/RankingTable.vue"
import PrintSummary from "@/components/PrintSummary.vue"
import { fullDate, monthLabel, relativeTime } from "@/lib/format"
import { absenceOn } from "@/lib/absences"
import {
  byKickoff,
  calendarLinks,
  decorate,
  fetchCalendar,
  teamColor,
  type Calendar,
  type Match,
} from "@/lib/matches"
import { fetchStandings, type Standings } from "@/lib/standings"

type View = "upcoming" | "results" | "all" | "calendar" | "standings" | "summary"

const FILTER_PARAM = "equipe"

const calendar = ref<Calendar | null>(null)
const error = ref<string | null>(null)
const loading = ref(true)
const picked = ref(rememberedCompetitions())
const view = ref<View>("upcoming")
const now = ref(Date.now())
const standings = ref<Standings | null>(null)
const standingsError = ref<string | null>(null)

// Most people open this page for one or two teams. `?equipe=2MB,2FA` makes that
// shareable, and the last choice is remembered so the regulars land on their own
// list. No pick at all means every team.
function rememberedCompetitions(): string[] {
  const fromLink = new URLSearchParams(location.search).get(FILTER_PARAM)
  const stored = fromLink ?? localStorage.getItem(FILTER_PARAM) ?? ""
  return stored.split(",").filter(Boolean)
}

watch(picked, (keys) => {
  localStorage.setItem(FILTER_PARAM, keys.join(","))
  const url = new URL(location.href)
  if (keys.length) url.searchParams.set(FILTER_PARAM, keys.join(","))
  else url.searchParams.delete(FILTER_PARAM)
  history.replaceState(null, "", url)
})

async function load() {
  loading.value = true
  try {
    calendar.value = await fetchCalendar()
    error.value = null
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : String(cause)
  } finally {
    loading.value = false
    now.value = Date.now()
  }
}

// The ranking sits behind its own upstream page, which is a far bigger document
// than the calendar export, so it is only fetched once someone asks for it.
async function loadStandings() {
  try {
    standings.value = await fetchStandings()
    standingsError.value = null
  } catch (cause) {
    standingsError.value = cause instanceof Error ? cause.message : String(cause)
  }
}

watch(view, (tab) => {
  if ((tab === "standings" || tab === "summary") && !standings.value) loadStandings()
})

// The FFVB calendar changes when results are entered, so a tab left open all
// weekend should not keep showing Saturday morning's version.
function refreshWhenVisible() {
  if (document.visibilityState !== "visible") return
  load()
  if (standings.value) loadStandings()
}

onMounted(() => {
  load()
  document.addEventListener("visibilitychange", refreshWhenVisible)
})
onUnmounted(() => document.removeEventListener("visibilitychange", refreshWhenVisible))

const matches = computed<Match[]>(() =>
  (calendar.value?.matches ?? []).map(decorate).sort(byKickoff),
)

const competitions = computed(() => {
  const seen = new Map<string, { key: string; label: string; count: number; color: string }>()
  for (const match of matches.value) {
    const entry = seen.get(match.competitionKey)
    if (entry) entry.count += 1
    else
      seen.set(match.competitionKey, {
        key: match.competitionKey,
        label: match.competition,
        count: 1,
        color: teamColor(seen.size),
      })
  }
  return [...seen.values()]
})

// Poule codes change between seasons, so a remembered one that has disappeared
// is ignored rather than leaving the page empty.
const activeCompetitions = computed(() =>
  competitions.value.filter((entry) => picked.value.includes(entry.key)).map((entry) => entry.key),
)

function toggle(key: string) {
  const keys = activeCompetitions.value
  picked.value = keys.includes(key) ? keys.filter((k) => k !== key) : [...keys, key]
}

const shownTeams = computed(() =>
  activeCompetitions.value.length
    ? competitions.value.filter((entry) => activeCompetitions.value.includes(entry.key))
    : competitions.value,
)

const teamColors = computed(() =>
  Object.fromEntries(competitions.value.map((entry) => [entry.key, entry.color])),
)

const inCompetition = computed(() =>
  activeCompetitions.value.length
    ? matches.value.filter((match) => activeCompetitions.value.includes(match.competitionKey))
    : matches.value,
)

const nextMatch = computed(() =>
  inCompetition.value.find((match) => !match.played && match.kickoff.getTime() >= now.value),
)

const visible = computed(() => {
  if (view.value === "results") return inCompetition.value.filter((m) => m.played).reverse()
  if (view.value === "upcoming") return inCompetition.value.filter((m) => !m.played)
  return inCompetition.value
})

const months = computed(() => {
  const groups: { label: string; matches: Match[] }[] = []
  for (const match of visible.value) {
    const label = monthLabel(match.kickoff)
    const last = groups.at(-1)
    if (last && last.label === label) last.matches.push(match)
    else groups.push({ label, matches: [match] })
  }
  return groups
})

const agenda = computed(() => calendarLinks(activeCompetitions.value))

const copied = ref(false)

// Firefox on Android opens neither webcal: nor Google's importer for everyone,
// so the raw feed address stays reachable by hand.
async function copyFeed() {
  await navigator.clipboard.writeText(agenda.value.url)
  copied.value = true
  setTimeout(() => (copied.value = false), 3000)
}

const pickedLabels = computed(() =>
  competitions.value
    .filter((entry) => activeCompetitions.value.includes(entry.key))
    .map((entry) => entry.label),
)

const agendaLabel = computed(() => pickedLabels.value.join(" + ") || "Toutes les équipes")

const pickerLabel = computed(() => {
  const labels = pickedLabels.value
  if (labels.length === 0) return "Toutes les équipes"
  if (labels.length === 1) return labels[0]
  return `${labels.length} équipes`
})

const nextAbsence = computed(() => (nextMatch.value ? absenceOn(nextMatch.value.date) : undefined))

const playedCount = computed(() => inCompetition.value.filter((m) => m.played).length)

// FFVB ranks a poule under its own code, which is the key the matches already
// carry — so one championship lines up with one table, and a youth poule FFVB
// publishes no table for simply has none.
const rankings = computed(() => {
  const tables = standings.value?.tables ?? []
  if (!activeCompetitions.value.length) return tables
  return tables.filter((table) => activeCompetitions.value.includes(table.key))
})

// The app's own wording wherever it has one; FFVB's all-caps title otherwise.
function rankingLabel(key: string, fallback: string): string {
  return competitions.value.find((entry) => entry.key === key)?.label ?? fallback
}
</script>

<template>
  <div class="min-h-dvh bg-base-200 print:bg-white">
    <header class="bg-primary text-primary-content print:hidden">
      <div class="mx-auto max-w-3xl px-4 py-8">
        <p class="text-xs uppercase tracking-widest opacity-80">
          Saison {{ calendar?.season ?? "" }}
        </p>
        <h1 class="mt-1 text-2xl font-bold sm:text-3xl">
          {{ calendar?.club ?? "Vie au Grand Air de Saint-Maur" }}
        </h1>
        <div v-if="nextMatch" class="mt-6 rounded-box bg-primary-content/15 p-4 backdrop-blur-sm">
          <p class="text-xs uppercase tracking-wider opacity-80">Prochain match</p>
          <p class="mt-1 text-lg font-semibold">
            {{ nextMatch.atHome ? "Réception de" : "Déplacement à" }} {{ nextMatch.opponent }}
          </p>
          <p class="mt-0.5 text-sm opacity-90">
            {{ fullDate(nextMatch.kickoff) }} à {{ nextMatch.time }}
            <template v-if="nextMatch.venue"> · {{ nextMatch.venue }}</template>
          </p>
          <p class="mt-1 text-xs opacity-75">
            {{ nextMatch.competition }}
            <template v-if="nextAbsence">
              · {{ nextAbsence.flag }} {{ nextAbsence.reason }}</template
            >
          </p>
        </div>
      </div>
    </header>

    <main class="mx-auto max-w-3xl px-4 py-6 print:max-w-none print:p-0">
      <div v-if="error" class="alert alert-error">
        <span>{{ error }}</span>
        <button class="btn btn-sm" @click="load">Réessayer</button>
      </div>

      <div v-else-if="loading && !calendar" class="flex justify-center py-16">
        <span class="loading loading-lg loading-dots text-primary" />
      </div>

      <template v-else>
        <div v-if="calendar?.stale" class="alert alert-warning mb-4 print:hidden" role="status">
          <span>
            La FFVB ne répond pas. Calendrier affiché tel qu'il était
            {{ relativeTime(calendar.fetchedAt) }}.
          </span>
        </div>

        <div class="mb-4 flex flex-wrap items-center gap-2 print:hidden">
          <div class="dropdown min-w-56 flex-1">
            <div
              tabindex="0"
              role="button"
              class="select select-bordered w-full"
              aria-label="Équipes"
              data-testid="team-picker"
            >
              <span class="flex min-w-0 items-center gap-1.5">
                <span
                  v-for="key in activeCompetitions"
                  :key="key"
                  class="size-2.5 shrink-0 rounded-full"
                  :style="{ backgroundColor: teamColors[key] }"
                />
                <span class="truncate">{{ pickerLabel }}</span>
              </span>
            </div>
            <ul
              tabindex="0"
              class="dropdown-content menu z-10 w-full min-w-72 rounded-box bg-base-100 p-2 shadow-lg ring-1 ring-base-300"
            >
              <li>
                <button
                  type="button"
                  :class="{ 'menu-active': !activeCompetitions.length }"
                  @click="picked = []"
                >
                  Toutes les équipes
                </button>
              </li>
              <li v-for="entry in competitions" :key="entry.key">
                <label>
                  <input
                    type="checkbox"
                    class="checkbox checkbox-sm"
                    :style="{ '--input-color': entry.color, color: '#ffffff' }"
                    :value="entry.key"
                    :checked="activeCompetitions.includes(entry.key)"
                    @change="toggle(entry.key)"
                  />
                  <span class="flex-1">{{ entry.label }}</span>
                  <span class="text-xs opacity-60">{{ entry.count }}</span>
                </label>
              </li>
            </ul>
          </div>

          <div class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-outline">
              <svg
                class="size-4"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <path
                  d="M4 7a2 2 0 0 1 2 -2h12a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2z"
                />
                <path d="M16 3v4M8 3v4M4 11h16M8 15h2v2h-2z" />
              </svg>
              Ajouter à mon agenda
            </div>
            <ul
              tabindex="0"
              class="dropdown-content menu z-10 w-80 rounded-box bg-base-100 p-2 shadow-lg ring-1 ring-base-300"
            >
              <li class="menu-title text-xs">{{ agendaLabel }}</li>
              <li>
                <a :href="agenda.google" target="_blank" rel="noopener">
                  <span>
                    S'abonner avec Google Agenda
                    <span class="block text-xs font-normal opacity-60">
                      Android et web · se met à jour quand la FFVB change une date
                    </span>
                  </span>
                </a>
              </li>
              <li>
                <a :href="agenda.webcal">
                  <span>
                    S'abonner avec Apple Agenda
                    <span class="block text-xs font-normal opacity-60">
                      iPhone, iPad, Mac et Outlook
                    </span>
                  </span>
                </a>
              </li>
              <li>
                <button type="button" @click="copyFeed">
                  <span>
                    {{ copied ? "Lien copié" : "Copier le lien du calendrier" }}
                    <span class="block text-xs font-normal opacity-60">
                      À coller dans « ajouter par URL » de n'importe quelle app
                    </span>
                  </span>
                </button>
              </li>
              <li>
                <a :href="agenda.file" download="volley-st-maur.ics">
                  <span>
                    Télécharger le fichier .ics
                    <span class="block text-xs font-normal opacity-60">
                      Copie figée, à réimporter après chaque changement
                    </span>
                  </span>
                </a>
              </li>
            </ul>
          </div>
        </div>

        <div role="tablist" class="tabs-box tabs mb-4 print:hidden">
          <button
            v-for="tab in [
              { id: 'upcoming' as View, label: 'À venir' },
              { id: 'results' as View, label: `Résultats (${playedCount})` },
              { id: 'all' as View, label: 'Toute la saison' },
              { id: 'calendar' as View, label: 'Calendrier' },
              { id: 'standings' as View, label: 'Classement' },
              { id: 'summary' as View, label: 'Synthèse' },
            ]"
            :key="tab.id"
            role="tab"
            class="tab"
            :class="{ 'tab-active': view === tab.id }"
            @click="view = tab.id"
          >
            {{ tab.label }}
          </button>
        </div>

        <MatchCalendar
          v-if="view === 'calendar'"
          :matches="inCompetition"
          :colors="teamColors"
          :teams="shownTeams"
        />

        <PrintSummary
          v-else-if="view === 'summary'"
          :club="calendar?.club ?? ''"
          :season="calendar?.season ?? ''"
          :teams="shownTeams"
          :matches="inCompetition"
          :rankings="rankings"
        />

        <template v-else-if="view === 'standings'">
          <div v-if="standingsError" class="alert alert-error">
            <span>{{ standingsError }}</span>
            <button class="btn btn-sm" @click="loadStandings">Réessayer</button>
          </div>

          <div v-else-if="!standings" class="flex justify-center py-16">
            <span class="loading loading-lg loading-dots text-primary" />
          </div>

          <p v-else-if="!rankings.length" class="py-12 text-center text-base-content/60">
            La FFVB ne publie pas de classement pour cette compétition.
          </p>

          <template v-else>
            <RankingTable
              v-for="ranking in rankings"
              :key="ranking.key"
              :ranking="ranking"
              :label="rankingLabel(ranking.key, ranking.title)"
            />
          </template>
        </template>

        <template v-else>
          <p v-if="!visible.length" class="py-12 text-center text-base-content/60">
            Aucun match à afficher ici.
          </p>

          <section v-for="month in months" :key="month.label" class="mb-6">
            <h2 class="mb-2 text-sm font-semibold uppercase tracking-wide text-base-content/60">
              {{ month.label }}
            </h2>
            <ul class="flex flex-col gap-2">
              <MatchRow v-for="match in month.matches" :key="match.code" :match="match" />
            </ul>
          </section>
        </template>
      </template>
    </main>

    <footer
      class="mx-auto max-w-3xl px-4 pb-10 text-center text-xs text-base-content/50 print:hidden"
    >
      <p v-if="calendar">
        Données FFVB, mises à jour {{ relativeTime(calendar.fetchedAt) }}.
        <button class="link" @click="load">Actualiser</button>
      </p>
      <p class="mt-1">
        Source :
        <a
          class="link"
          href="https://www.ffvbbeach.org/ffvbapp/resu/"
          target="_blank"
          rel="noopener"
          >ffvbbeach.org</a
        >
      </p>
    </footer>
  </div>
</template>
