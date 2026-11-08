<script setup lang="ts">
import { ref } from "vue"

type Choice = "light" | "system" | "dark"

const STORAGE_KEY = "theme"

// Tabler outline icons: "sun", "device-desktop", "moon".
const OPTIONS: { value: Choice; label: string; paths: string[] }[] = [
  {
    value: "light",
    label: "Clair",
    paths: [
      "M12 12m-4 0a4 4 0 1 0 8 0a4 4 0 1 0 -8 0",
      "M3 12h1m8 -9v1m8 8h1m-9 8v1m-6.4 -15.4l.7 .7m12.1 -.7l-.7 .7m0 11.4l.7 .7m-12.1 -.7l-.7 .7",
    ],
  },
  {
    value: "system",
    label: "Auto",
    paths: [
      "M3 5a1 1 0 0 1 1 -1h16a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1h-16a1 1 0 0 1 -1 -1v-10z",
      "M7 20h10",
      "M9 16v4",
      "M15 16v4",
    ],
  },
  {
    value: "dark",
    label: "Sombre",
    paths: ["M12 3c.132 0 .263 0 .393 0a7.5 7.5 0 0 0 7.92 12.446a9 9 0 1 1 -8.313 -12.454z"],
  },
]

// "system" stores nothing and sets no data-theme, so DaisyUI follows
// prefers-color-scheme live. index.html applies a stored light/dark choice
// before the app loads, so a reload does not flash the other theme.
const choice = ref<Choice>(storedChoice())

function storedChoice(): Choice {
  const stored = localStorage.getItem(STORAGE_KEY)
  return stored === "light" || stored === "dark" ? stored : "system"
}

function pick(value: Choice) {
  choice.value = value
  if (value === "system") {
    delete document.documentElement.dataset.theme
    localStorage.removeItem(STORAGE_KEY)
  } else {
    document.documentElement.dataset.theme = value
    localStorage.setItem(STORAGE_KEY, value)
  }
}
</script>

<template>
  <!-- Active segment is inverted (base-content fill, 17.7:1 light / 14.7:1 dark)
       and announced by aria-pressed, so the state never rests on colour alone.
       Idle labels at /70 measure 7.5:1 light / 7.4:1 dark. -->
  <div
    role="group"
    aria-label="Thème"
    class="inline-flex rounded-full border border-base-content/20 p-0.5"
  >
    <button
      v-for="option in OPTIONS"
      :key="option.value"
      type="button"
      :aria-pressed="choice === option.value"
      class="inline-flex h-11 items-center gap-1.5 rounded-full px-3.5 text-xs font-medium focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary motion-safe:transition-colors motion-safe:duration-150"
      :class="
        choice === option.value
          ? 'bg-base-content text-base-100'
          : 'text-base-content/70 hover:bg-base-content/10 hover:text-base-content'
      "
      @click="pick(option.value)"
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
        <path v-for="d in option.paths" :key="d" :d="d" />
      </svg>
      {{ option.label }}
    </button>
  </div>
</template>
