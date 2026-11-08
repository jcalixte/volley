<script setup lang="ts">
import { computed } from "vue"
import type { Match } from "@/lib/matches"
import { mapsUrl } from "@/lib/matches"
import { absenceOn } from "@/lib/absences"
import { countdown, monthShortLabel, weekdayLabel } from "@/lib/format"

const props = defineProps<{ match: Match; now: number }>()

const absence = computed(() => absenceOn(props.match.date))
const when = computed(() => countdown(props.match.kickoff, new Date(props.now)))
</script>

<!-- Sits on the primary header, whose colour is the same in both themes, so
     every colour here is primary or primary-content. The dark tint keeps
     text at /80 above 6:1; a light tint would drop it under 4.5:1. -->
<template>
  <article
    class="grid grid-cols-[auto_1fr] overflow-hidden rounded-box bg-black/20"
    aria-labelledby="next-match-title"
  >
    <div
      class="flex w-20 flex-col items-center justify-center bg-primary-content py-4 text-primary sm:w-28"
    >
      <span class="text-xs font-semibold uppercase tracking-wider">
        {{ weekdayLabel(match.kickoff) }}
      </span>
      <span class="font-display text-6xl font-bold leading-none tabular-nums sm:text-7xl">
        {{ match.kickoff.getDate() }}
      </span>
      <span class="text-xs font-semibold uppercase tracking-wider">
        {{ monthShortLabel(match.kickoff) }}
      </span>
    </div>

    <div class="min-w-0 p-4 sm:p-5">
      <div class="flex flex-wrap items-center gap-2">
        <h2
          id="next-match-title"
          class="text-xs font-medium uppercase tracking-wider text-primary-content/80"
        >
          Prochain match
        </h2>
        <span
          class="rounded-full bg-primary-content px-2 py-0.5 text-xs font-semibold text-primary"
        >
          {{ when }}
        </span>
      </div>

      <p class="mt-3 text-sm text-primary-content/80">
        {{ match.atHome ? "Réception de" : "Déplacement à" }}
      </p>
      <p
        class="font-display text-3xl font-bold uppercase leading-none break-words sm:text-4xl"
        data-testid="next-opponent"
      >
        {{ match.opponent }}
      </p>

      <div class="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm">
        <span class="font-display text-xl font-semibold leading-none tabular-nums">
          {{ match.time }}
        </span>
        <a
          v-if="match.venue"
          class="inline-flex min-w-0 items-center gap-1 underline-offset-2 hover:underline focus-visible:underline"
          :href="mapsUrl(match)"
          target="_blank"
          rel="noopener"
          :title="`Ouvrir ${match.venue} dans Maps`"
        >
          <svg
            class="size-4 shrink-0"
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

      <div class="mt-1 flex flex-wrap gap-x-2 text-xs text-primary-content/80">
        <span>{{ match.competition }}</span>
        <span v-if="absence" class="flex gap-1">
          <span aria-hidden="true">{{ absence.flag }}</span>
          <span>{{ absence.reason }}</span>
        </span>
      </div>
    </div>
  </article>
</template>
