<script setup lang="ts">
import { computed } from "vue"
import type { Match } from "@/lib/matches"
import { mapsUrl } from "@/lib/matches"
import { absenceOn } from "@/lib/absences"
import { weekdayLabel } from "@/lib/format"
import HomeIcon from "@/components/HomeIcon.vue"

const props = defineProps<{ match: Match; color: string }>()

const absence = computed(() => absenceOn(props.match.date))
</script>

<!-- The competition name beside the colour stripe keeps colour from being the
     only cue. -->
<template>
  <li
    class="relative flex items-center gap-4 overflow-hidden rounded-box bg-base-100 py-3 pr-4 pl-5 ring-1 ring-base-300/60"
  >
    <span
      class="absolute inset-y-0 left-0 w-1.5"
      :style="{ backgroundColor: color }"
      aria-hidden="true"
    />

    <div class="flex w-11 shrink-0 flex-col items-center leading-none">
      <span class="text-xs font-semibold uppercase tracking-wider text-base-content/70">
        {{ weekdayLabel(match.kickoff) }}
      </span>
      <span class="font-display text-4xl font-bold tabular-nums">{{
        match.kickoff.getDate()
      }}</span>
    </div>

    <div class="min-w-0 flex-1">
      <span
        v-if="match.atHome"
        class="badge badge-sm gap-1 badge-primary font-semibold uppercase tracking-wide"
      >
        <HomeIcon class="size-3" aria-hidden="true" />
        Domicile
      </span>
      <span v-else class="badge badge-sm badge-ghost font-semibold uppercase tracking-wide">
        Extérieur
      </span>

      <p class="mt-1 font-display text-xl font-bold uppercase leading-tight break-words">
        {{ match.opponent }}
      </p>

      <div class="mt-0.5 flex flex-wrap items-center gap-x-3 text-xs text-base-content/70">
        <a class="link-hover link" :href="match.ffvbUrl" target="_blank" rel="noopener">{{
          match.competition
        }}</a>
        <a
          v-if="match.venue"
          class="link-hover link inline-flex min-w-0 items-center gap-1"
          :href="mapsUrl(match)"
          target="_blank"
          rel="noopener"
          :title="`Ouvrir ${match.venue} dans Maps`"
        >
          <svg
            class="size-3 shrink-0"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="M9 11a3 3 0 1 0 6 0a3 3 0 0 0 -6 0" />
            <path
              d="M17.657 16.657l-4.243 4.243a2 2 0 0 1 -2.827 0l-4.244 -4.243a8 8 0 1 1 11.314 0z"
            />
          </svg>
          <span class="truncate">{{ match.venue }}</span>
        </a>
        <span v-if="absence" role="img" :title="absence.reason" :aria-label="absence.reason">{{
          absence.flag
        }}</span>
      </div>
      <p
        v-if="match.played && match.score"
        class="mt-0.5 text-xs text-base-content/70 tabular-nums"
      >
        {{ match.score.replaceAll(",", " · ") }}
      </p>
    </div>

    <div class="shrink-0 text-right">
      <template v-if="match.played">
        <div class="flex items-center justify-end gap-2">
          <span
            class="grid size-6 place-items-center rounded-full text-xs font-bold"
            :class="match.won ? 'bg-success text-success-content' : 'bg-base-300 text-base-content'"
            :title="match.won ? 'Victoire' : 'Défaite'"
          >
            <span aria-hidden="true">{{ match.won ? "V" : "D" }}</span>
            <span class="sr-only">{{ match.won ? "Victoire" : "Défaite" }}</span>
          </span>
          <span class="font-display text-3xl font-bold leading-none tabular-nums">
            {{ match.ourSets }}–{{ match.theirSets }}
          </span>
        </div>
      </template>
      <div v-else class="font-display text-2xl font-semibold leading-none tabular-nums">
        {{ match.time }}
      </div>
    </div>
  </li>
</template>
