<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from "vue"
import MatchRow from "@/components/MatchRow.vue"
import { fullDate, monthLabel, relativeTime } from "@/lib/format"
import {
  byKickoff,
  competitionKey,
  competitionLabel,
  decorate,
  fetchCalendar,
  type Calendar,
  type Match,
} from "@/lib/matches"

type View = "upcoming" | "results" | "all"

const calendar = ref<Calendar | null>(null)
const error = ref<string | null>(null)
const loading = ref(true)
const competition = ref("all")
const view = ref<View>("upcoming")
const now = ref(Date.now())

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

// The FFVB calendar changes when results are entered, so a tab left open all
// weekend should not keep showing Saturday morning's version.
function refreshWhenVisible() {
  if (document.visibilityState === "visible") load()
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
  const seen = new Map<string, { key: string; label: string; count: number }>()
  for (const match of matches.value) {
    const key = competitionKey(match.poule)
    const entry = seen.get(key)
    if (entry) entry.count += 1
    else seen.set(key, { key, label: competitionLabel(match.poule, match.entity), count: 1 })
  }
  return [...seen.values()]
})

const inCompetition = computed(() =>
  competition.value === "all"
    ? matches.value
    : matches.value.filter((match) => competitionKey(match.poule) === competition.value),
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

const playedCount = computed(() => matches.value.filter((m) => m.played).length)
</script>

<template>
  <div class="min-h-dvh bg-base-200">
    <header class="bg-primary text-primary-content">
      <div class="mx-auto max-w-3xl px-4 py-8">
        <p class="text-xs uppercase tracking-widest opacity-80">
          Saison {{ calendar?.season ?? "" }}
        </p>
        <h1 class="mt-1 text-2xl font-bold sm:text-3xl">
          {{ calendar?.club ?? "Vie au Grand Air de Saint-Maur" }}
        </h1>
        <p class="mt-1 text-sm opacity-80">Tous les matchs du club, toutes équipes confondues.</p>

        <div v-if="nextMatch" class="mt-6 rounded-box bg-primary-content/15 p-4 backdrop-blur-sm">
          <p class="text-xs uppercase tracking-wider opacity-80">Prochain match</p>
          <p class="mt-1 text-lg font-semibold">
            {{ nextMatch.atHome ? "Réception de" : "Déplacement à" }} {{ nextMatch.opponent }}
          </p>
          <p class="mt-0.5 text-sm opacity-90">
            {{ fullDate(nextMatch.kickoff) }} à {{ nextMatch.time }}
            <template v-if="nextMatch.venue"> · {{ nextMatch.venue }}</template>
          </p>
          <p class="mt-1 text-xs opacity-75">{{ nextMatch.competition }}</p>
        </div>
      </div>
    </header>

    <main class="mx-auto max-w-3xl px-4 py-6">
      <div v-if="error" class="alert alert-error">
        <span>{{ error }}</span>
        <button class="btn btn-sm" @click="load">Réessayer</button>
      </div>

      <div v-else-if="loading && !calendar" class="flex justify-center py-16">
        <span class="loading loading-lg loading-dots text-primary" />
      </div>

      <template v-else>
        <div v-if="calendar?.stale" class="alert alert-warning mb-4" role="status">
          <span>
            La FFVB ne répond pas. Calendrier affiché tel qu'il était
            {{ relativeTime(calendar.fetchedAt) }}.
          </span>
        </div>

        <div class="mb-4 flex flex-wrap gap-2">
          <button
            class="btn btn-sm"
            :class="competition === 'all' ? 'btn-primary' : 'btn-ghost'"
            @click="competition = 'all'"
          >
            Toutes les équipes
          </button>
          <button
            v-for="entry in competitions"
            :key="entry.key"
            class="btn btn-sm"
            :class="competition === entry.key ? 'btn-primary' : 'btn-ghost'"
            @click="competition = entry.key"
          >
            {{ entry.label }}
            <span class="badge badge-sm badge-neutral">{{ entry.count }}</span>
          </button>
        </div>

        <div role="tablist" class="tabs-box tabs mb-4">
          <button
            v-for="tab in [
              { id: 'upcoming' as View, label: 'À venir' },
              { id: 'results' as View, label: `Résultats (${playedCount})` },
              { id: 'all' as View, label: 'Toute la saison' },
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

        <p v-if="!visible.length" class="py-12 text-center text-base-content/60">
          Aucun match à afficher ici.
        </p>

        <section v-for="month in months" :key="month.label" class="mb-6">
          <h2 class="mb-2 text-sm font-semibold uppercase tracking-wide text-base-content/60">
            {{ month.label }}
          </h2>
          <ul class="flex flex-col gap-2">
            <MatchRow
              v-for="match in month.matches"
              :key="match.code"
              :match="match"
              :season="calendar?.season ?? ''"
            />
          </ul>
        </section>
      </template>
    </main>

    <footer class="mx-auto max-w-3xl px-4 pb-10 text-center text-xs text-base-content/50">
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
