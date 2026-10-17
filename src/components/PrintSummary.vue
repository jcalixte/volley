<script setup lang="ts">
import { computed } from "vue"
import type { Match } from "@/lib/matches"
import { absenceOn } from "@/lib/absences"
import { weekdayLabel } from "@/lib/format"

const props = defineProps<{
  club: string
  season: string
  teams: { key: string; label: string; color: string }[]
  matches: Match[]
}>()

const printedOn = new Intl.DateTimeFormat("fr-FR", { dateStyle: "long" }).format(new Date())
const SHORT = new Intl.DateTimeFormat("fr-FR", { day: "2-digit", month: "2-digit" })

// One row per day: every team gets its own time column, so a weekend reads
// across. A youth plateau can hold several matches at once, hence a list per team.
const rows = computed(() => {
  const days = new Map<string, { date: string; kickoff: Date; byTeam: Record<string, Match[]> }>()
  for (const match of props.matches) {
    let day = days.get(match.date)
    if (!day) {
      day = { date: match.date, kickoff: match.kickoff, byTeam: {} }
      days.set(match.date, day)
    }
    ;(day.byTeam[match.competitionKey] ??= []).push(match)
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
      <div>
        <h2 class="text-lg font-bold">{{ club }}</h2>
        <p class="text-xs text-base-content/60">
          Saison {{ season }} · synthèse au {{ printedOn }}
        </p>
      </div>
      <button class="btn btn-primary btn-sm print:hidden" @click="print">Imprimer</button>
    </header>

    <p v-if="!teams.length" class="py-8 text-center text-base-content/60">
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
            <th class="border-t-4 align-bottom" :style="{ borderTopColor: team.color }">
              {{ team.label }}
            </th>
          </template>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="row in rows"
          :key="row.date"
          class="break-inside-avoid align-top"
          data-testid="summary-row"
        >
          <td class="whitespace-nowrap font-medium tabular-nums">
            {{ weekdayLabel(row.kickoff) }} {{ SHORT.format(row.kickoff) }}
            <template v-if="absenceOn(row.date)"> {{ absenceOn(row.date)!.flag }}</template>
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
                <div class="text-[0.65rem] text-base-content/60">
                  {{ match.atHome ? "Dom." : "Ext."
                  }}<template v-if="match.venue"> · {{ match.venue }}</template>
                </div>
              </div>
            </td>
          </template>
        </tr>
      </tbody>
    </table>
  </article>
</template>
