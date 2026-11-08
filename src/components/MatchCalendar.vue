<script setup lang="ts">
import { computed, ref } from "vue"
import type { Match } from "@/lib/matches"
import { addMonths, monthGrid, startOfMonth, weekdayHeaders } from "@/lib/calendar"
import { monthLabel } from "@/lib/format"
import { absenceOn } from "@/lib/absences"
import HomeIcon from "@/components/HomeIcon.vue"

const props = defineProps<{
  matches: Match[]
  colors: Record<string, string>
  teams: { key: string; label: string; color: string }[]
}>()

// Read once: the month must not slide under the user while the tab is open.
const today = new Date()
const anchor = ref(startOfMonth(today))

const weeks = computed(() => monthGrid(anchor.value, props.matches, today))

const onCurrentMonth = computed(
  () =>
    anchor.value.getFullYear() === today.getFullYear() &&
    anchor.value.getMonth() === today.getMonth(),
)

function shift(delta: number) {
  anchor.value = addMonths(anchor.value, delta)
}

// With several teams on the grid, chips add the poule code so colour is not the
// only cue.
const severalTeams = computed(() => props.teams.length > 1)

function chipLabel(match: Match): string {
  return match.played ? `${match.ourSets}–${match.theirSets}` : match.time
}
</script>

<template>
  <section>
    <div class="mb-3 flex items-center justify-between gap-2">
      <button
        class="btn btn-circle btn-ghost size-11"
        aria-label="Mois précédent"
        @click="shift(-1)"
      >
        <svg
          class="size-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path d="M15 6l-6 6l6 6" />
        </svg>
      </button>
      <div class="flex items-center gap-2">
        <h2 class="text-base font-semibold capitalize">{{ monthLabel(anchor) }}</h2>
        <button
          v-if="!onCurrentMonth"
          class="btn btn-ghost btn-sm text-primary"
          @click="anchor = startOfMonth(today)"
        >
          Aujourd'hui
        </button>
      </div>
      <button class="btn btn-circle btn-ghost size-11" aria-label="Mois suivant" @click="shift(1)">
        <svg
          class="size-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path d="M9 6l6 6l-6 6" />
        </svg>
      </button>
    </div>

    <div
      class="grid grid-cols-[repeat(5,minmax(0,1fr))_minmax(0,3fr)_minmax(0,3fr)] gap-px overflow-hidden rounded-box bg-base-300/60 ring-1 ring-base-300/60"
    >
      <div
        v-for="(day, column) in weekdayHeaders"
        :key="day"
        class="bg-base-100 py-1.5 text-center text-[0.65rem] uppercase tracking-wide"
        :class="column >= 5 ? 'font-semibold text-base-content/80' : 'text-base-content/60'"
      >
        {{ day }}
      </div>

      <div
        v-for="day in weeks.flat()"
        :key="day.key"
        class="flex min-h-16 min-w-0 flex-col gap-1 p-1 sm:min-h-24 sm:p-1.5"
        :class="[day.weekend ? 'bg-base-100' : 'bg-base-100/50', day.outside && 'opacity-40']"
      >
        <span
          class="flex size-5 items-center justify-center self-end rounded-full tabular-nums leading-none sm:size-6"
          :class="[
            day.weekend ? 'text-sm font-semibold' : 'text-[0.7rem]',
            day.today
              ? 'bg-primary font-bold text-primary-content'
              : !day.weekend && 'text-base-content/60',
          ]"
        >
          {{ day.date.getDate() }}
        </span>

        <span
          v-for="match in day.matches"
          :key="match.code"
          class="flex min-w-0 items-center gap-1.5 overflow-hidden rounded border-l-3 border-(color:--team) px-1 py-0.5 sm:px-1.5 text-[0.65rem] leading-tight sm:text-xs"
          :class="
            match.played
              ? 'bg-base-300 text-base-content/80'
              : match.atHome
                ? 'bg-(color:--team) text-white'
                : 'bg-(color:--team)/20 text-base-content'
          "
          :style="{ '--team': colors[match.competitionKey] }"
          :title="`${match.time} · ${match.atHome ? 'Domicile' : 'Extérieur'} · ${match.opponent} · ${match.competition}`"
        >
          <span class="shrink-0 font-semibold tabular-nums">{{ chipLabel(match) }}</span>
          <HomeIcon v-if="match.atHome" class="size-3 shrink-0" role="img" aria-label="Domicile" />
          <span v-if="severalTeams" class="hidden shrink-0 font-mono opacity-75 sm:inline">{{
            match.competitionKey
          }}</span>
          <span class="hidden min-w-0 truncate sm:inline">{{ match.opponent }}</span>
          <span
            v-if="absenceOn(match.date)"
            class="ml-auto shrink-0"
            role="img"
            :aria-label="absenceOn(match.date)!.reason"
            >{{ absenceOn(match.date)!.flag }}</span
          >
        </span>
      </div>
    </div>

    <div class="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-base-content/70">
      <span v-for="team in teams" :key="team.key" class="flex items-center gap-1.5">
        <span class="size-2.5 shrink-0 rounded-full" :style="{ backgroundColor: team.color }" />
        <span v-if="severalTeams" class="font-mono">{{ team.key }}</span>
        {{ team.label }}
      </span>
      <span class="flex items-center gap-1 text-base-content/60">
        <HomeIcon class="size-3" aria-hidden="true" />
        domicile, plein · extérieur, clair · joué, gris, notre score d'abord
      </span>
    </div>
  </section>
</template>
