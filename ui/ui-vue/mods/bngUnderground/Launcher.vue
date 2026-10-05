<template>
  <main class="bngu-launcher" v-bng-scoped-nav="{ scopeId: 'bngu-launcher', activateOnMount: true, preferAutoFocus: true, canDeactivate: handleBack }" v-bng-on-ui-nav:menu="handleBack">
    <header>
      <span class="bngu-launch-logo">BNG <strong>UNDERGROUND</strong></span>
      <BngButton :disabled="starting" @click="back">Back to main menu</BngButton>
    </header>
    <section class="bngu-launch-content">
      <div class="bngu-launch-intro">
        <span class="bngu-launch-kicker">WEST COAST, USA · SINGLE PLAYER</span>
        <h1>Your car.<br>Your name.<br>Your city.</h1>
        <p>Choose your meets. Build a garage. Challenge the crews that own the night.</p>
        <div v-if="ready && !data.blockedSave" class="bngu-launch-facts"><span>{{ data.eventCount }} EVENTS</span><span>{{ data.chapterCount }} CHAPTERS</span><span>{{ data.carCount }} CARS TO OWN</span></div>
        <p class="bngu-launch-muted">A separate campaign with its own money, garage and progress.</p>
      </div>
      <div class="bngu-launch-panel">
        <p v-if="loading" role="status">Loading your campaign…</p>
        <p v-if="error || data.error" class="bngu-launch-error" role="alert">{{ error || data.error }}</p>
        <BngButton v-if="!loading && !ready" @click="loadCampaign">Retry loading campaign</BngButton>
        <template v-if="!loading && ready && !data.blockedSave">
          <template v-if="data.hasProfile">
            <span class="bngu-launch-kicker">YOUR CAMPAIGN</span>
            <h2>Welcome back.</h2>
            <p>Chapter {{ data.chapter }} · {{ data.chapterName }}</p>
            <div class="bngu-launch-save"><strong>{{ money(data.cash) }}</strong><span>{{ data.rep }} REP</span><span>{{ data.ownedCars }} cars owned</span></div>
            <p>{{ data.activeCarName }}</p>
            <template v-if="!confirmNew">
              <BngButton accent="base" class="bngu-launch-primary" :disabled="starting || data.blockedSave || data.careerActive" @click="start(false)">{{ starting ? 'Loading West Coast, USA…' : 'Continue campaign →' }}</BngButton>
              <BngButton :disabled="starting || data.careerActive" @click="confirmNew = true">New campaign</BngButton>
            </template>
            <template v-else>
              <h2>Start fresh?</h2><p>This replaces your current BNG Underground campaign. Your cars, money and race progress will reset. The new night begins in Mara's modified car.</p>
              <BngButton :disabled="starting" @click="confirmNew = false">Keep current campaign</BngButton>
              <BngButton accent="base" :disabled="starting || data.careerActive" @click="start(true)">Replace campaign & start fresh</BngButton>
            </template>
          </template>
          <template v-else>
            <span class="bngu-launch-kicker">START A NEW CAMPAIGN</span>
            <h2>A friend. A set of keys. A new city.</h2>
            <p>Mara lends you her modified 200BX for the opening drive. Follow GPS to Quarryside Auto Sales, then choose your own Covet, Pessima or 200BX from a {{ money(data.startingCash) }} budget.</p>
            <p>Keep the change. Build your own garage. Choose your own races.</p>
            <BngButton accent="base" class="bngu-launch-primary" :disabled="starting || data.blockedSave || data.careerActive" @click="start(false)">{{ starting ? 'Loading West Coast, USA…' : 'Start a new campaign →' }}</BngButton>
          </template>
          <p class="bngu-launch-muted">The city loads automatically. While driving, press Start/Escape to open your paused city map. Race events always use cars you own.</p>
        </template>
        <p v-if="data.careerActive" class="bngu-launch-error">Return to the main menu from your current Career before starting BNG Underground.</p>
      </div>
    </section>
    <footer>BNG UNDERGROUND · {{ data.version || '0.10.0' }} <span>OWN YOUR CARS. PICK YOUR RACES.</span></footer>
  </main>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from "vue"
import { BngButton } from "@/common/components/base"
import { vBngScopedNav, vBngOnUiNav } from "@/common/directives"
import { useBridge } from "@/bridge"
import { getLaunchData, launchFromMenu } from "./campaignApi.js"

const { lua, events } = useBridge()
const data = ref({ starters: [] })
const confirmNew = ref(false)
const loading = ref(true)
const ready = ref(false)
const starting = ref(false)
const error = ref("")
const money = value => "$" + Math.floor(value || 0).toLocaleString("en-US")

function receiveMessage(message) {
  if (message?.kind === "error") { error.value = message.text; starting.value = false }
}

async function start(fresh = false) {
  if (starting.value || !ready.value || data.value.blockedSave) return
  starting.value = true
  error.value = ""
  try {
    const result = await launchFromMenu(fresh ? "newCampaign" : null)
    if (!result?.ok) { error.value = result?.error || "The campaign could not start."; starting.value = false }
  } catch (e) {
    error.value = "The campaign could not start: " + String(e.message || e)
    starting.value = false
  }
}

function back() { if (!starting.value) lua.extensions.ui_router.navigate("menu", null, {}) }
function handleBack() { if (confirmNew.value && !starting.value) confirmNew.value = false; else back(); return false }

async function loadCampaign() {
  loading.value = true
  ready.value = false
  error.value = ""
  data.value = { starters: [] }
  try {
    const response = await getLaunchData()
    if (!response || typeof response !== "object" || (!response.blockedSave &&
      (typeof response.hasProfile !== "boolean" || !Array.isArray(response.starters) || !Number.isFinite(response.startingCash) ||
        ![response.eventCount, response.chapterCount, response.carCount].every(value => Number.isInteger(value) && value > 0)))) {
      throw new Error("The campaign returned no usable launch data.")
    }
    data.value = response
    ready.value = true
  } catch (e) {
    error.value = "Campaign data could not be loaded: " + String(e.message || e)
  } finally { loading.value = false }
}

onMounted(() => {
  events.on("BNGUMessage", receiveMessage)
  loadCampaign()
})
onUnmounted(() => events.off("BNGUMessage", receiveMessage))
</script>

<style scoped>
.bngu-launcher { position: absolute; inset: 0; overflow: auto; background: radial-gradient(ellipse at 8% 25%, #392553 0, transparent 50%), #0e0b16; color: #f5f0ff; font-family: 'Overpass', Arial, sans-serif; padding: 32px 5vw 24px; box-sizing: border-box; }
.bngu-launcher header { display: flex; align-items: center; justify-content: space-between; gap: 20px; }
.bngu-launch-logo { font-size: 27px; font-weight: 900; letter-spacing: 1px; }
.bngu-launch-logo strong { color: #bb9afb; font-size: 19px; }
.bngu-launch-content { display: grid; grid-template-columns: 1fr 1fr; gap: 6vw; align-items: center; min-height: calc(100vh - 160px); max-width: 1500px; margin: auto; padding: 35px 0; box-sizing: border-box; }
.bngu-launch-kicker { color: #80ddcf; font-size: 12px; letter-spacing: 2px; font-weight: 700; }
.bngu-launch-intro h1 { font-size: clamp(40px, 5.5vw, 87px); line-height: 1.02; margin: 24px 0; font-weight: 900; letter-spacing: -3px; }
.bngu-launcher p { line-height: 1.6; font-size: 16px; }
.bngu-launch-intro p { max-width: 420px; }
.bngu-launch-facts { display: flex; flex-wrap: wrap; gap: 17px; margin: 28px 0; color: #c6b0f0; font-size: 11px; font-weight: 700; letter-spacing: 1px; }
.bngu-launcher .bngu-launch-muted { color: #a39aae; font-size: 13px; }
.bngu-launch-panel { padding: 32px; background: #1c1629; border: 1px solid #4b3b63; border-radius: 16px; }
.bngu-launch-panel h2 { font-size: 30px; margin: 12px 0; }
.bngu-launch-starters { display: flex; flex-direction: column; gap: 9px; margin: 22px 0; }
.bngu-launch-car { width: 100%; display: flex; align-items: center; justify-content: flex-start; text-align: left; gap: 15px; padding: 8px; background: #100d19; color: #f5f0ff; border: 1px solid #493859; border-radius: 8px; }
.bngu-launch-car.selected { border-color: #c0a0ff; background: #352749; }
.bngu-launch-car img { width: 115px; height: 66px; object-fit: cover; border-radius: 5px; }
.bngu-launch-car strong, .bngu-launch-car small, .bngu-launch-car b { display: block; }
.bngu-launch-car strong { font-size: 16px; }
.bngu-launch-car small { font-size: 10px; color: #b4a7c5; margin: 3px 0; }
.bngu-launch-car b { color: #a6e0c9; font-size: 13px; }
.bngu-launch-primary { display: block; width: 100%; margin-top: 20px; padding: 16px; color: #140e20; background: #c1a0ff; font-weight: 800; border-radius: 7px; }
.bngu-launch-save { display: flex; flex-wrap: wrap; gap: 18px; align-items: baseline; padding: 24px 0; border-top: 1px solid #493859; border-bottom: 1px solid #493859; margin: 22px 0; }
.bngu-launch-save strong { font-size: 35px; }.bngu-launch-save span { color: #b1a2c4; font-size: 13px; }
.bngu-launcher .bngu-launch-error { padding: 14px; border: 1px solid #a65979; background: #431e32; color: #ffd0dc; }
.bngu-launcher footer { display: flex; justify-content: space-between; flex-wrap: wrap; gap: 10px; color: #867792; font-size: 10px; letter-spacing: 1px; }
.bngu-launcher :deep(button:focus) { outline: 3px solid #9affde; outline-offset: 4px; }
@media (max-width: 950px) { .bngu-launch-content { gap: 24px; } .bngu-launch-panel { padding: 20px; } .bngu-launch-intro h1 { font-size: 48px; } }
@media (max-width: 650px) { .bngu-launch-content { grid-template-columns: 1fr; } .bngu-launch-logo { font-size: 20px; }.bngu-launch-logo strong { font-size: 13px; } .bngu-launch-intro h1 { font-size: 44px; } }
</style>
