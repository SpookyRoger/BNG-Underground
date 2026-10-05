<template>
  <div v-if="route.name === 'menu'" class="bngu-menu-entry">
    <BngButton accent="base" class="bngu-menu-button" @click="open">
      <span class="bngu-menu-wordmark">BNG <strong>UNDERGROUND</strong></span>
      <span class="bngu-menu-subtitle">SINGLE PLAYER CAMPAIGN <b>↗</b></span>
    </BngButton>
    <p v-if="error" role="alert">{{ error }}</p>
  </div>
</template>

<script>
const modInfo = { uiSlots: ["mainmenu.top"] }
</script>

<script setup>
import { ref } from "vue"
import { useRoute } from "vue-router"
import { BngButton } from "@/common/components/base"
import { lua } from "@/bridge"

const route = useRoute()
const error = ref("")
async function open() {
  error.value = ""
  try {
    const result = await lua.extensions.ui_router.navigate("bngUnderground.launcher")
    if (result?.result === false || result?.success === false) {
      error.value = "The launch screen is unavailable. Re-enable BNG Underground and restart the game."
    }
  } catch (e) {
    error.value = "BNG Underground could not open: " + String(e.message || e)
  }
}
</script>

<style scoped>
.bngu-menu-entry { max-width: 350px; pointer-events: auto; }
.bngu-menu-button { display: flex; flex-direction: column; align-items: flex-start; min-width: 275px; padding: 15px 20px; color: #faf5ff; background: linear-gradient(120deg, #20132f, #342153); border: 1px solid #b495f7; border-radius: 9px; }
.bngu-menu-wordmark { display: block; font-size: 20px; font-weight: 900; letter-spacing: 1px; }
.bngu-menu-wordmark strong { color: #c7afff; font-size: 15px; }
.bngu-menu-subtitle { display: block; margin-top: 6px; font-size: 10px; letter-spacing: 1.5px; color: #a6e6df; }
.bngu-menu-subtitle b { margin-left: 22px; font-size: 16px; }
.bngu-menu-entry p { padding: 10px; background: #301521; color: #ffc8d3; font-size: 13px; }
</style>
