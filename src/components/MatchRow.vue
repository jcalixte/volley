<script setup lang="ts">
import type { Match } from "@/lib/matches"
import { ffvbUrl } from "@/lib/matches"
import { weekdayLabel } from "@/lib/format"

defineProps<{ match: Match; season: string }>()
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
      </div>
      <div class="mt-0.5 flex flex-wrap items-center gap-x-2 text-xs text-base-content/60">
        <a
          class="link-hover link"
          :href="ffvbUrl(match.poule, match.entity, season)"
          target="_blank"
          rel="noopener"
          >{{ match.competition }}</a
        >
        <span v-if="match.venue" class="truncate">· {{ match.venue }}</span>
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
