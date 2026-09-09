<script setup lang="ts">
import { computed } from "vue"
import type { Match } from "@/lib/matches"
import { mapsUrl } from "@/lib/matches"
import { absenceOn } from "@/lib/absences"
import { weekdayLabel } from "@/lib/format"

const props = defineProps<{ match: Match }>()

const absence = computed(() => absenceOn(props.match.date))
</script>

<template>
  <li class="flex items-center gap-4 rounded-box bg-base-100 px-4 py-3 ring-1 ring-base-300/60">
    <div class="flex w-12 shrink-0 flex-col items-center leading-none">
      <span class="text-[0.65rem] uppercase text-base-content/50">
        {{ weekdayLabel(match.kickoff) }}
      </span>
      <span class="text-2xl font-semibold tabular-nums">{{ match.kickoff.getDate() }}</span>
    </div>

    <div class="min-w-0 flex-1">
      <div class="flex items-center gap-2">
        <span
          class="badge badge-xs shrink-0"
          :class="match.atHome ? 'badge-primary' : 'badge-ghost'"
        >
          {{ match.atHome ? "Domicile" : "Extérieur" }}
        </span>
        <span class="truncate font-medium">{{ match.opponent }}</span>
        <span
          v-if="absence"
          class="shrink-0 text-sm leading-none"
          :title="absence.reason"
          :aria-label="absence.reason"
          role="img"
          >{{ absence.flag }}</span
        >
      </div>
      <div class="mt-0.5 flex flex-wrap items-center gap-x-2 text-xs text-base-content/60">
        <a class="link-hover link" :href="match.ffvbUrl" target="_blank" rel="noopener">{{
          match.competition
        }}</a>
        <a
          v-if="match.venue"
          class="link-hover link inline-flex items-center gap-1 truncate"
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
      </div>
    </div>

    <div class="shrink-0 text-right">
      <template v-if="match.played">
        <div
          class="text-lg font-semibold tabular-nums"
          :class="match.won ? 'text-success' : 'text-base-content/50'"
        >
          {{ match.ourSets }}–{{ match.theirSets }}
        </div>
        <div v-if="match.score" class="text-[0.65rem] text-base-content/50">
          {{ match.score.replaceAll(",", " · ") }}
        </div>
      </template>
      <div v-else class="text-lg tabular-nums text-base-content/70">{{ match.time }}</div>
    </div>
  </li>
</template>
