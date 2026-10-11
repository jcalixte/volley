<script setup lang="ts">
import type { Ranking } from "@/lib/standings"

defineProps<{ ranking: Ranking; label: string }>()
</script>

<template>
  <section class="mb-6">
    <h2 class="mb-2 text-sm font-semibold uppercase tracking-wide text-base-content/60">
      <a class="link-hover link" :href="ranking.ffvbUrl" target="_blank" rel="noopener">
        {{ label }}
      </a>
    </h2>

    <div class="overflow-x-auto rounded-box bg-base-100 ring-1 ring-base-300/60">
      <table class="table table-sm">
        <thead>
          <tr>
            <th class="w-8 text-right">#</th>
            <th>Équipe</th>
            <th class="text-right">Pts</th>
            <th class="text-right">J</th>
            <th class="hidden text-right sm:table-cell">G</th>
            <th class="hidden text-right sm:table-cell">P</th>
            <th class="text-right">Sets</th>
            <th class="hidden text-right sm:table-cell" title="Rapport de points">Pts +/-</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in ranking.rows"
            :key="row.rank"
            :class="row.ours ? 'bg-primary/10 font-semibold' : ''"
          >
            <td class="text-right tabular-nums text-base-content/60">{{ row.rank }}</td>
            <td class="max-w-0 truncate">{{ row.team }}</td>
            <td class="text-right tabular-nums">{{ row.points }}</td>
            <td class="text-right tabular-nums text-base-content/60">{{ row.played }}</td>
            <td class="hidden text-right tabular-nums text-base-content/60 sm:table-cell">
              {{ row.won }}
            </td>
            <td class="hidden text-right tabular-nums text-base-content/60 sm:table-cell">
              {{ row.lost }}
            </td>
            <td class="text-right tabular-nums text-base-content/60">
              {{ row.setsWon }}–{{ row.setsLost }}
            </td>
            <td class="hidden text-right tabular-nums text-base-content/60 sm:table-cell">
              {{ row.pointsWon }}–{{ row.pointsLost }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
