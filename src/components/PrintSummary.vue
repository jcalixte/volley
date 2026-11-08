<script setup lang="ts">
import { computed } from "vue"
import type { Match } from "@/lib/matches"
import { absenceOn } from "@/lib/absences"
import { monthLabel, weekdayLabel } from "@/lib/format"

const props = defineProps<{
  club: string
  season: string
  teams: { key: string; label: string; color: string }[]
  matches: Match[]
}>()

const printedOn = new Intl.DateTimeFormat("fr-FR", { dateStyle: "long" }).format(new Date())
const SHORT = new Intl.DateTimeFormat("fr-FR", { day: "2-digit", month: "2-digit" })

interface Day {
  date: string
  kickoff: Date
  /** Set on the first day of each month, which opens with a divider row. */
  month?: string
  byTeam: Record<string, Match[]>
}

// A youth plateau can hold several matches per team on one day.
const rows = computed(() => {
  const days = new Map<string, Day>()
  for (const match of props.matches) {
    let day = days.get(match.date)
    if (!day) {
      day = { date: match.date, kickoff: match.kickoff, byTeam: {} }
      days.set(match.date, day)
    }
    ;(day.byTeam[match.competitionKey] ??= []).push(match)
  }
  let previous = ""
  for (const day of days.values()) {
    const month = monthLabel(day.kickoff)
    if (month !== previous) day.month = month
    previous = month
  }
  return [...days.values()]
})

function print() {
  window.print()
}
</script>

<template>
  <!-- Forced light: on paper a dark theme would print near-white text on an
       unprinted background. -->
  <article
    data-theme="light"
    class="rounded-box bg-base-100 p-6 text-base-content shadow-sm ring-1 ring-base-300/60 print:rounded-none print:p-0 print:shadow-none print:ring-0"
  >
    <header class="mb-4 flex items-start justify-between gap-4 border-b border-base-300 pb-3">
      <div class="min-w-0">
        <h2 class="font-display text-2xl font-bold uppercase leading-tight">{{ club }}</h2>
        <p class="text-xs text-base-content/70">
          Saison {{ season }} · synthèse au {{ printedOn }}
        </p>
      </div>
      <button class="btn shrink-0 btn-primary print:hidden" @click="print">
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
            d="M17 17h2a2 2 0 0 0 2 -2v-4a2 2 0 0 0 -2 -2h-14a2 2 0 0 0 -2 2v4a2 2 0 0 0 2 2h2"
          />
          <path d="M17 9v-4a2 2 0 0 0 -2 -2h-6a2 2 0 0 0 -2 2v4" />
          <path d="M7 15a2 2 0 0 1 2 -2h6a2 2 0 0 1 2 2v4a2 2 0 0 1 -2 2h-6a2 2 0 0 1 -2 -2z" />
        </svg>
        Imprimer
      </button>
    </header>

    <p v-if="!teams.length" class="py-8 text-center text-base-content/70">
      Aucun match à afficher ici.
    </p>

    <!-- Borders, not fills, carry the team colour: browsers drop backgrounds
         when printing unless asked. -->
    <table v-if="teams.length" class="table table-xs" data-testid="summary-grid">
      <thead>
        <tr>
          <th class="w-16">Date</th>
          <template v-for="team in teams" :key="team.key">
            <th class="w-12 border-t-4 align-bottom" :style="{ borderTopColor: team.color }">
              Heure
            </th>
            <th
              class="border-t-4 align-bottom font-display text-sm font-bold uppercase leading-tight text-base-content"
              :style="{ borderTopColor: team.color }"
            >
              {{ team.label }}
            </th>
          </template>
        </tr>
      </thead>
      <tbody>
        <template v-for="row in rows" :key="row.date">
          <tr v-if="row.month" class="break-after-avoid" data-testid="summary-month">
            <td
              :colspan="1 + teams.length * 2"
              class="bg-base-200 pt-3 font-display text-sm font-bold uppercase tracking-wide print:bg-transparent"
            >
              {{ row.month }}
            </td>
          </tr>
          <tr class="break-inside-avoid align-top" data-testid="summary-row">
            <td class="whitespace-nowrap font-medium tabular-nums">
              <span class="flex gap-1">
                <span>{{ weekdayLabel(row.kickoff) }}</span>
                <span>{{ SHORT.format(row.kickoff) }}</span>
                <span
                  v-if="absenceOn(row.date)"
                  role="img"
                  :title="absenceOn(row.date)!.reason"
                  :aria-label="absenceOn(row.date)!.reason"
                  >{{ absenceOn(row.date)!.flag }}</span
                >
              </span>
            </td>
            <template v-for="team in teams" :key="team.key">
              <td class="tabular-nums">
                <!-- Same min height on both cells keeps a team's times level with
                   its matches when a day holds more than one. -->
                <div v-for="match in row.byTeam[team.key] ?? []" :key="match.code" class="min-h-8">
                  {{ match.time }}
                </div>
              </td>
              <td>
                <div v-for="match in row.byTeam[team.key] ?? []" :key="match.code" class="min-h-8">
                  <div class="font-medium">
                    {{ match.opponent }}
                    <span
                      v-if="match.played"
                      class="tabular-nums"
                      :class="match.won ? 'font-bold' : 'font-normal text-base-content/70'"
                    >
                      {{ match.ourSets }}–{{ match.theirSets }}
                    </span>
                  </div>
                  <div class="text-[0.65rem] text-base-content/70">
                    {{ match.atHome ? "Dom." : "Ext."
                    }}<template v-if="match.venue"> · {{ match.venue }}</template>
                  </div>
                </div>
              </td>
            </template>
          </tr>
        </template>
      </tbody>
    </table>
  </article>
</template>
