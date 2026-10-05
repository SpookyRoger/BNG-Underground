<template>
  <section class="bngu-pause-card">
    <h2>BNG Underground</h2>
    <p v-if="active">Return to your race board, garage, sponsors and messages.</p>
    <p v-else>Start or continue your campaign using the BNG Underground button on the main menu.</p>
    <BngButton v-if="active" @click="openBoard">Open campaign board</BngButton>
    <p v-if="error" role="alert">{{ error }}</p>
  </section>
</template>
<script setup>
import { ref, onMounted } from "vue"
import { BngButton } from "@/common/components/base"
import { lua } from "@/bridge"
import { isActive, showBoard } from "./campaignApi.js"
const active = ref(false)
const error = ref("")
onMounted(async () => {
  try { active.value = await isActive() }
  catch (e) { error.value = "Campaign status could not be loaded: " + String(e.message || e) }
})
async function openBoard() {
  try {
    await showBoard()
  } catch (e) { error.value = String(e.message || e) }
}
</script>
<style scoped>
.bngu-pause-card { padding: 24px; color: #f3eeff; background: #21172f; border-radius: 12px; }
.bngu-pause-card h2 { color: #c4a5ff; }.bngu-pause-card p { line-height: 1.6; }
</style>
