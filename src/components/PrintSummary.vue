<script setup lang="ts">
import { computed } from "vue"
import type { Match } from "@/lib/matches"
import type { Ranking } from "@/lib/standings"
import { absenceOn } from "@/lib/absences"
import { weekdayLabel } from "@/lib/format"

const props = defineProps<{
  club: string
  season: string
  teams: { key: string; label: string; color: string }[]
  matches: Match[]
  rankings: Ranking[]
}>()

const printedOn = new Intl.DateTimeFormat("fr-FR", { dateStyle: "long" }).format(new Date())
const SHORT = new Intl.DateTimeFormat("fr-FR", { day: "2-digit", month: "2-digit" })

// One row per kickoff, so teams playing the same weekend sit side by side. A
// youth plateau can hold several matches at once, hence a list per team.
const rows = computed(() => {
  const slots = new Map<
    string,
    { date: string; time: string; kickoff: Date; byTeam: Record<string, Match[]> }
  >()
  const perDay = new Map<string, number>()
  for (const match of props.matches) {
    const id = `${match.date} ${match.time}`
    let slot = slots.get(id)
    if (!slot) {
      slot = { date: match.date, time: match.time, kickoff: match.kickoff, byTeam: {} }
      slots.set(id, slot)
      perDay.set(match.date, (perDay.get(match.date) ?? 0) + 1)
    }
    ;(slot.byTeam[match.competitionKey] ??= []).push(match)
  }
  // The date cell spans every kickoff of its day, so only the day's first row draws it.
  return [...slots.values()].map((slot, index, list) => ({
    ...slot,
    span: list[index - 1]?.date === slot.date ? 0 : perDay.get(slot.date)!,
  }))
})

const rankings = computed(() =>
  props.teams.flatMap((team) => {
    const ranking = props.rankings.find((table) => table.key === team.key)
    if (!ranking) return []
    const ours = ranking.rows.find((row) => row.ours)
    const standing = ours
      ? `${ours.rank}${ours.rank === 1 ? "er" : "e"} sur ${ranking.rows.length} · ${ours.points} pts`
      : undefined
    return [{ ...team, ranking, standing }]
  }),
)

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
          <th class="w-12">Heure</th>
          <th
            v-for="team in teams"
            :key="team.key"
            class="border-t-4 align-bottom"
            :style="{ borderTopColor: team.color }"
          >
            {{ team.label }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="row in rows"
          :key="`${row.date} ${row.time}`"
          class="break-inside-avoid align-top"
          data-testid="summary-row"
        >
          <td
            v-if="row.span"
            :rowspan="row.span"
            class="whitespace-nowrap font-medium tabular-nums"
          >
            {{ weekdayLabel(row.kickoff) }} {{ SHORT.format(row.kickoff) }}
            <template v-if="absenceOn(row.date)"> {{ absenceOn(row.date)!.flag }}</template>
          </td>
          <td class="tabular-nums">{{ row.time }}</td>
          <td v-for="team in teams" :key="team.key">
            <div v-for="match in row.byTeam[team.key] ?? []" :key="match.code">
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
        </tr>
      </tbody>
    </table>

    <div v-if="rankings.length" class="mt-6 grid gap-4 sm:grid-cols-2 print:grid-cols-2">
      <section
        v-for="team in rankings"
        :key="team.key"
        class="break-inside-avoid"
        data-testid="summary-ranking"
      >
        <h3
          class="mb-1 flex items-baseline justify-between gap-2 border-l-4 pl-2 text-xs font-semibold"
          :style="{ borderColor: team.color }"
        >
          <span>{{ team.label }}</span>
          <span v-if="team.standing" class="font-normal text-base-content/70">
            {{ team.standing }}
          </span>
        </h3>
        <table class="table table-xs">
          <thead>
            <tr>
              <th class="w-6 text-right">#</th>
              <th>Équipe</th>
              <th class="text-right">Pts</th>
              <th class="text-right">J</th>
              <th class="text-right">Sets</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in team.ranking.rows"
              :key="row.rank"
              :class="row.ours && 'font-semibold'"
            >
              <td class="text-right tabular-nums">{{ row.rank }}</td>
              <td>{{ row.team }}</td>
              <td class="text-right tabular-nums">{{ row.points }}</td>
              <td class="text-right tabular-nums">{{ row.played }}</td>
              <td class="text-right tabular-nums">{{ row.setsWon }}–{{ row.setsLost }}</td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
  </article>
</template>
