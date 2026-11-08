<script setup lang="ts">
import { computed } from "vue"
import type { Ranking } from "@/lib/standings"

const props = defineProps<{ ranking: Ranking; label: string; color: string }>()

const ourRows = computed(() => props.ranking.rows.filter((row) => row.ours))
</script>

<template>
  <section class="mb-8">
    <div class="mb-3 flex items-center justify-between gap-3">
      <h2
        class="flex min-w-0 items-center gap-2 font-display text-xl font-bold uppercase leading-tight"
      >
        <span
          class="size-3 shrink-0 rounded-full"
          :style="{ backgroundColor: color }"
          aria-hidden="true"
        />
        <span class="min-w-0">{{ label }}</span>
      </h2>
      <a
        class="btn btn-ghost shrink-0 font-normal"
        :href="ranking.ffvbUrl"
        target="_blank"
        rel="noopener"
        :aria-label="`Classement ${label} sur le site de la FFVB`"
      >
        FFVB
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
          <path d="M12 6h-6a2 2 0 0 0 -2 2v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2 -2v-6" />
          <path d="M11 13l9 -9M15 4h5v5" />
        </svg>
      </a>
    </div>

    <!-- Team colours carry white at 4.9:1 or more, so every line here stays
         full white: an opacity would drop the small text under 4.5:1. -->
    <div
      v-for="row in ourRows"
      :key="row.rank"
      class="mb-3 flex items-center gap-4 rounded-box px-4 py-3 text-white"
      :style="{ backgroundColor: color }"
      data-testid="our-rank"
    >
      <p class="shrink-0 font-display text-5xl font-bold leading-none tabular-nums">
        {{ row.rank }}<sup class="text-xl">{{ row.rank === 1 ? "er" : "e" }}</sup>
      </p>
      <div class="min-w-0 text-sm">
        <p class="font-semibold">{{ row.team }}</p>
        <p class="flex flex-wrap gap-x-2">
          <span>sur {{ ranking.rows.length }}</span>
          <span>· {{ row.points }} pts</span>
          <span>· {{ row.won }} V – {{ row.lost }} D</span>
        </p>
      </div>
    </div>

    <div class="overflow-x-auto rounded-box bg-base-100 ring-1 ring-base-300/60">
      <table class="table table-sm">
        <thead>
          <tr>
            <th class="w-8 text-right">#</th>
            <th>Équipe</th>
            <th class="text-right"><abbr title="Points" class="no-underline">Pts</abbr></th>
            <th class="text-right"><abbr title="Matchs joués" class="no-underline">J</abbr></th>
            <th class="hidden text-right sm:table-cell">
              <abbr title="Gagnés" class="no-underline">G</abbr>
            </th>
            <th class="hidden text-right sm:table-cell">
              <abbr title="Perdus" class="no-underline">P</abbr>
            </th>
            <th class="text-right">Sets</th>
            <th class="hidden text-right sm:table-cell">Points</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in ranking.rows"
            :key="row.rank"
            :class="row.ours ? 'bg-primary/10 font-semibold' : ''"
            :aria-current="row.ours ? 'true' : undefined"
          >
            <td class="text-right font-display text-base font-bold tabular-nums">
              {{ row.rank }}
            </td>
            <td class="min-w-32 leading-tight">{{ row.team }}</td>
            <td class="text-right font-semibold tabular-nums">{{ row.points }}</td>
            <td class="text-right tabular-nums text-base-content/70">{{ row.played }}</td>
            <td class="hidden text-right tabular-nums text-base-content/70 sm:table-cell">
              {{ row.won }}
            </td>
            <td class="hidden text-right tabular-nums text-base-content/70 sm:table-cell">
              {{ row.lost }}
            </td>
            <td class="whitespace-nowrap text-right tabular-nums text-base-content/70">
              {{ row.setsWon }}–{{ row.setsLost }}
            </td>
            <td
              class="hidden whitespace-nowrap text-right tabular-nums text-base-content/70 sm:table-cell"
            >
              {{ row.pointsWon }}–{{ row.pointsLost }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <p class="mt-2 flex flex-wrap gap-x-3 text-xs text-base-content/70">
      <span>Pts : points au classement</span>
      <span>J : matchs joués</span>
      <span class="hidden sm:inline">G / P : gagnés / perdus</span>
      <span>Sets et Points : marqués–encaissés</span>
    </p>
  </section>
</template>
