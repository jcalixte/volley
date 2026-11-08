<script setup lang="ts">
import { computed, ref } from "vue"
import { calendarLinks } from "@/lib/matches"
import TablerIcon from "@/components/TablerIcon.vue"

const props = defineProps<{
  /** Picked championship keys; none means the whole club. */
  competitions: string[]
  label: string
  colors: string[]
}>()

const ICONS = {
  calendarPlus: [
    "M12.5 21h-6.5a2 2 0 0 1 -2 -2v-12a2 2 0 0 1 2 -2h12a2 2 0 0 1 2 2v5",
    "M16 3v4M8 3v4M4 11h16M16 19h6M19 16v6",
  ],
  google: [
    "M20.945 11a9 9 0 1 1 -3.284 -5.997l-2.655 2.392a5.5 5.5 0 1 0 2.119 6.605h-4.125v-3h7.945z",
  ],
  apple: [
    "M8.286 7.008c-3.216 0 -4.286 3.23 -4.286 5.92c0 3.229 2.143 8.072 4.286 8.072c1.165 -.05 1.799 -.538 3.214 -.538c1.406 0 1.607 .538 3.214 .538s4.286 -3.229 4.286 -5.381c-.03 -.011 -2.649 -.434 -2.679 -3.23c-.02 -2.335 2.589 -3.179 2.679 -3.228c-1.096 -1.606 -3.162 -2.113 -3.75 -2.153c-1.535 -.12 -3.032 1.077 -3.75 1.077c-.729 0 -2.036 -1.077 -3.214 -1.077z",
    "M12 4a2 2 0 0 0 2 -2a2 2 0 0 0 -2 2",
  ],
  copy: [
    "M7 9.667a2.667 2.667 0 0 1 2.667 -2.667h8.666a2.667 2.667 0 0 1 2.667 2.667v8.666a2.667 2.667 0 0 1 -2.667 2.667h-8.666a2.667 2.667 0 0 1 -2.667 -2.667z",
    "M4.012 16.737a2.005 2.005 0 0 1 -1.012 -1.737v-10c0 -1.1 .9 -2 2 -2h10c.75 0 1.158 .385 1.5 1",
  ],
  check: ["M5 12l5 5l10 -10"],
  download: ["M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-2", "M7 11l5 5l5 -5", "M12 4l0 12"],
}

const agenda = computed(() => calendarLinks(props.competitions))

const copied = ref(false)

// Firefox on Android opens neither webcal: nor Google's importer for everyone,
// so the raw feed address stays reachable by hand.
async function copyFeed() {
  await navigator.clipboard.writeText(agenda.value.url)
  copied.value = true
  setTimeout(() => (copied.value = false), 3000)
}
</script>

<template>
  <div class="dropdown dropdown-end max-sm:w-full">
    <div tabindex="0" role="button" class="btn h-11 btn-outline max-sm:w-full">
      <TablerIcon class="size-5" :paths="ICONS.calendarPlus" />
      Ajouter à mon agenda
    </div>
    <ul
      tabindex="0"
      class="dropdown-content menu z-10 w-80 max-w-[calc(100vw-2rem)] rounded-box bg-base-100 p-2 shadow-lg ring-1 ring-base-300"
    >
      <li class="menu-title flex-row items-center gap-1.5 text-xs text-base-content/70">
        <span
          v-for="color in colors"
          :key="color"
          class="size-2.5 shrink-0 rounded-full"
          :style="{ backgroundColor: color }"
          aria-hidden="true"
        />
        <span>{{ label }}</span>
      </li>
      <li>
        <a class="items-start" :href="agenda.google" target="_blank" rel="noopener">
          <TablerIcon class="mt-0.5 size-5 shrink-0" :paths="ICONS.google" />
          <span>
            S'abonner avec Google Agenda
            <span class="block text-xs font-normal text-base-content/70">
              Android et web · se met à jour quand la FFVB change une date
            </span>
          </span>
        </a>
      </li>
      <li>
        <a class="items-start" :href="agenda.webcal">
          <TablerIcon class="mt-0.5 size-5 shrink-0" :paths="ICONS.apple" />
          <span>
            S'abonner avec Apple Agenda
            <span class="block text-xs font-normal text-base-content/70">
              iPhone, iPad, Mac et Outlook
            </span>
          </span>
        </a>
      </li>
      <li>
        <button type="button" class="items-start" @click="copyFeed">
          <TablerIcon
            class="mt-0.5 size-5 shrink-0"
            :class="copied && 'text-success'"
            :paths="copied ? ICONS.check : ICONS.copy"
          />
          <span class="text-left">
            <span aria-live="polite">{{
              copied ? "Lien copié" : "Copier le lien du calendrier"
            }}</span>
            <span class="block text-xs font-normal text-base-content/70">
              À coller dans « ajouter par URL » de n'importe quelle app
            </span>
          </span>
        </button>
      </li>
      <li>
        <a class="items-start" :href="agenda.file" download="volley-st-maur.ics">
          <TablerIcon class="mt-0.5 size-5 shrink-0" :paths="ICONS.download" />
          <span>
            Télécharger le fichier .ics
            <span class="block text-xs font-normal text-base-content/70">
              Copie figée, à réimporter après chaque changement
            </span>
          </span>
        </a>
      </li>
    </ul>
  </div>
</template>
