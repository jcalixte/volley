<script setup lang="ts">
import { computed } from "vue"
import { clubUrl } from "@/lib/club"

const props = defineProps<{ code: string; name: string }>()

const url = computed(() => clubUrl(props.code))
</script>

<template>
  <a v-if="url" class="link link-hover" :href="url">{{ name }}</a>
  <span v-else>{{ name }}</span>
</template>
