<script setup lang="ts">
import { computed, ref } from "vue"
import type { Match } from "@/lib/matches"
import { addMonths, monthGrid, startOfMonth, weekdayHeaders } from "@/lib/calendar"
import { monthLabel } from "@/lib/format"
import { absenceOn } from "@/lib/absences"

const props = defineProps<{ matches: Match[] }>()

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

function chipLabel(match: Match): string {
  return match.played ? `${match.ourSets}–${match.theirSets}` : match.time
}
</script>

<template>
  <section>
    <div class="mb-2 flex items-center justify-between gap-2">
      <button class="btn btn-ghost btn-sm" aria-label="Mois précédent" @click="shift(-1)">‹</button>
      <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
        {{ monthLabel(anchor) }}
      </h2>
      <div class="flex items-center gap-1">
        <button
          v-if="!onCurrentMonth"
          class="btn btn-ghost btn-xs"
          @click="anchor = startOfMonth(today)"
        >
          Aujourd'hui
        </button>
        <button class="btn btn-ghost btn-sm" aria-label="Mois suivant" @click="shift(1)">›</button>
      </div>
    </div>

    <!-- Matches fall on Saturdays and Sundays, so those two columns get the
         room and the weekdays get what is left. -->
    <div
      class="grid grid-cols-[repeat(5,minmax(0,1fr))_1.6fr_1.6fr] gap-px overflow-hidden rounded-box bg-base-300/60 ring-1 ring-base-300/60"
    >
      <div
        v-for="(day, column) in weekdayHeaders"
        :key="day"
        class="bg-base-100 py-1 text-center text-[0.6rem] uppercase tracking-wide"
        :class="column >= 5 ? 'font-semibold text-base-content/70' : 'text-base-content/40'"
      >
        {{ day }}
      </div>

      <div
        v-for="day in weeks.flat()"
        :key="day.key"
        class="flex min-h-14 flex-col gap-0.5 p-1"
        :class="[
          day.weekend ? 'bg-base-100 sm:min-h-24' : 'bg-base-100/60',
          day.outside && 'opacity-35',
        ]"
      >
        <span
          class="self-end tabular-nums leading-none"
          :class="[
            day.weekend ? 'text-sm font-semibold' : 'text-[0.65rem] text-base-content/50',
            day.today &&
              'flex size-5 items-center justify-center rounded-full bg-primary text-xs font-bold text-primary-content',
          ]"
        >
          {{ day.date.getDate() }}
        </span>

        <span
          v-for="match in day.matches"
          :key="match.code"
          class="truncate rounded px-1 text-[0.6rem] leading-tight sm:text-[0.7rem]"
          :class="
            match.played
              ? 'bg-base-300 text-base-content/70'
              : match.atHome
                ? 'bg-primary text-primary-content'
                : 'bg-base-content/15 text-base-content'
          "
          :title="`${match.time} · ${match.atHome ? 'Domicile' : 'Extérieur'} · ${match.opponent} · ${match.competition}`"
        >
          <span class="font-semibold tabular-nums">{{ chipLabel(match) }}</span>
          <span class="hidden sm:inline"> {{ match.opponent }}</span>
          <template v-if="absenceOn(match.date)"> {{ absenceOn(match.date)!.flag }}</template>
        </span>
      </div>
    </div>
  </section>
</template>
