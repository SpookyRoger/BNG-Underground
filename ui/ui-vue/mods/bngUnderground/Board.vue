<template>
  <main class="bngu-board" v-bng-scoped-nav="{ scopeId: 'bngu-board', activateOnMount: true, preferAutoFocus: true, canDeactivate: handleBack }" v-bng-on-ui-nav:menu="handleBack">
    <link rel="stylesheet" href="/ui/ui-vue/mods/bngUnderground/board.css">
    <header class="bngu-board-header">
      <div><strong>BNG UNDERGROUND</strong><small>CAMPAIGN MENU · GAME PAUSED</small></div>
      <div v-if="state.active" class="bngu-board-balances"><span>{{ money(state.cash) }}<small>BANK</small></span><span>{{ state.rep }}<small>REPUTATION</small></span></div>
      <BngButton v-if="state.active" accent="base" :disabled="view.busy" @click="send('repair')">Repair · {{ state.prices.repair === 0 ? 'free' : money(state.prices.repair) }}</BngButton>
      <BngButton accent="base" :disabled="view.busy || guardPending" @click="close">Return to driving</BngButton>
    </header>
    <p v-if="notice" class="bngu-board-notice" :class="{ error: notice.kind === 'error' }" role="status">{{ notice.text }}</p>
    <p v-if="state.error" class="bngu-board-notice error" role="alert">{{ state.error }}</p>
    <div v-if="state.active" class="bngu-board-shell">
      <aside bng-nav-scroll>
        <small>CHAPTER {{ state.chapter }}</small><h2>{{ state.chapterInfo.name }}</h2><p>{{ state.chapterInfo.district }}</p>
        <nav aria-label="Campaign pages">
          <BngButton v-for="item in pages" :key="item.id" accent="base" :data-bngu-page="item.id" :class="{ selected: page === item.id }" :aria-pressed="page === item.id" @click="setPage(item.id)">{{ item.name }}</BngButton>
        </nav>
        <p v-if="state.introduction">Mara's car · opening drive<br>Park at Quarryside to choose your own keys.</p>
        <p v-else-if="!state.completed">{{ state.chapterWins }} / {{ state.chapterInfo.requiredWins }} different clears<br>{{ state.chapterInfo.requiredRep }} REP opens {{ state.chapterInfo.boss }}'s challenge.</p>
        <p v-else>CITY CHAMPION</p>
        <BngButton v-if="state.features.night" accent="base" :disabled="pending" @click="send('night', !state.preferences.night)">{{ state.preferences.night ? 'Night atmosphere: on' : 'Original lighting: on' }}</BngButton>
        <BngButton v-if="state.features.minimap" accent="base" :disabled="pending" @click="send('minimap', !state.preferences.minimap)">Campaign minimap: {{ state.preferences.minimap ? 'on' : 'off' }}</BngButton>
        <BngButton v-if="state.features.streetTraffic" accent="base" :disabled="view.busy || guardPending" @click="send('streetTraffic', !state.streetTraffic.enabled)">Street traffic: {{ state.streetTraffic.enabled ? 'on' : 'off' }}</BngButton>
        <p v-if="state.features.streetTraffic" class="bngu-traffic-status" role="status">{{ state.streetTraffic.label }}<br v-if="state.streetTraffic.message"><span v-if="state.streetTraffic.message">{{ state.streetTraffic.message }}</span></p>
        <BngButton v-if="state.streetTraffic?.enabled && state.streetTraffic.canRetry" accent="base" :disabled="view.busy || guardPending" @click="send('retryTraffic')">Retry street traffic</BngButton>
        <BngButton accent="base" :disabled="pending" @click="send('stockMenu')">Game settings & options</BngButton>
        <BngButton accent="base" :disabled="state.busy || pending" @click="send('leave')">Save & return to main menu</BngButton>
      </aside>
      <section ref="content" class="bngu-board-content" bng-nav-scroll :class="{ 'bngu-contained-page': page === 'city' || page === 'inbox' || page === 'garage' || page === 'sponsors' || page === 'results' }" :aria-label="page">
        <BoardCity v-if="page === 'city'" ref="cityPage" :state="view" :focus-event="focusEvent" @command="send" @races="setPage('events')" @dealership="setPage('garage')"></BoardCity>
        <BoardRaces v-if="page === 'events'" :state="view" :focus-chapter="focusChapter" @command="send"></BoardRaces>
        <BoardGarage v-if="page === 'garage'" ref="garagePage" :state="view" :before-leave="guarded" @command="send"></BoardGarage>
        <BoardSponsors v-if="page === 'sponsors'" ref="sponsorsPage" :state="view" @command="send" @event="openInvite"></BoardSponsors>
        <BoardMessages v-if="page === 'inbox'" ref="messagesPage" :state="view" @command="send" @event="openInvite"></BoardMessages>
        <BoardProgress v-if="page === 'progress'" :state="view" @command="send" @chapter="openChapter"></BoardProgress>
        <BoardResults v-if="page === 'results'" ref="resultsPage" :state="view" @command="send" @event="openInvite" @page="setPage"></BoardResults>
      </section>
    </div>
    <section v-else class="bngu-board-loading"><h1>{{ loading ? 'Opening your campaign…' : 'Campaign unavailable' }}</h1><p v-if="!loading">Start or continue BNG Underground from its main-menu button.</p><BngButton v-if="!loading" @click="refresh">Retry</BngButton></section>
    <footer><span>D-PAD / LEFT STICK · NAVIGATE</span><span>CONFIRM · {{ page === 'city' ? 'SET GPS' : 'SELECT' }}</span><span>BACK / ESC · {{ page === 'inbox' ? 'INBOX / DRIVING' : page === 'garage' ? 'CARS / DRIVING' : page === 'results' ? 'RUNS / DRIVING' : 'RETURN TO DRIVING' }}</span><span>PROGRESS SAVES AUTOMATICALLY</span></footer>
    <CarTransactionStatus v-if="state.carTransaction?.active" :status="state.carTransaction" :recovering="recoveringCar" @restore="recoverCar('restoreSavedCar')" @abort="recoverCar('abortCarChange')" />
  </main>
</template>

<script setup>
import { ref, computed, nextTick, onMounted, onUnmounted } from "vue"
import { BngButton } from "@/common/components/base"
import { vBngScopedNav, vBngOnUiNav } from "@/common/directives"
import { useBridge } from "@/bridge"
import { useScopedNav } from "@/services/scopedNav/api"
import { openConfirmation } from "@/services/popup"
import { createDraftGuard } from "./draftGuard.js"
import TuningLeaveMessage from "./components/messages/TuningLeaveMessage.vue"
import { command, requestState } from "./campaignApi.js"
import { money } from "./presentation.js"
import BoardCity from "./components/BoardCity.vue"
import BoardRaces from "./components/BoardRaces.vue"
import BoardGarage from "./components/BoardGarage.vue"
import BoardSponsors from "./components/BoardSponsors.vue"
import BoardMessages from "./components/BoardMessages.vue"
import BoardProgress from "./components/BoardProgress.vue"
import BoardResults from "./components/BoardResults.vue"
import CarTransactionStatus from "./components/CarTransactionStatus.vue"

const { events } = useBridge()
const nav = useScopedNav()
const content = ref(null), cityPage = ref(null), messagesPage = ref(null), garagePage = ref(null), sponsorsPage = ref(null), resultsPage = ref(null)
const state = ref({ active: false })
const page = ref("city")
const focusEvent = ref(null)
const focusChapter = ref(null)
const notice = ref(null)
const pending = ref(false)
const recoveringCar = ref(false)
const guardPending = ref(false)
const loading = ref(true)
let noticeTimer, disposed = false
const view = computed(() => ({ ...state.value, busy: state.value.busy || pending.value }))
const guardedActions = new Set(["enterWorkshop", "streetTraffic", "retryTraffic", "close", "leave", "stockMenu", "repair", "tow", "navigateEvent", "navigateLocation", "startEvent", "buyCar", "selectCar", "upgrade", "equip", "paint", "bodykit", "toggleKit", "driftBuild", "dragBuild", "buyPart", "fitPart", "buyBodywork", "fitBodywork", "resetTune"])
const draftGuard = createDraftGuard({
  getDraft: () => page.value === "garage" ? garagePage.value?.draftState() : null,
  isBusy: () => !!view.value.busy,
  isCurrent: draft => !!garagePage.value?.isDraftCurrent(draft),
  confirm: (draft, allowApply) => openConfirmation("Unsaved tuning", {
    component: TuningLeaveMessage,
    props: { carName: draft.carName, buildName: draft.buildName, changedCount: draft.changedCount, canApply: draft.ready && allowApply, allowApply },
  }, [
    { label: "Keep editing", value: "keep", extras: { cancel: true, default: true, outsideCancel: true } },
    { label: allowApply ? "Discard & continue" : "Discard & restore hardware", value: "discard", extras: { destructive: true } },
    ...(allowApply ? [{ label: "Apply & continue · free", value: "apply", extras: { confirm: true, disabled: !draft.ready } }] : []),
  ], "", false),
  apply: draft => executeSend("tune", draft.request),
  discard: draft => !!garagePage.value?.discardDraft(draft),
  focus: async () => { await nextTick(); focusContent() },
  notify: text => receiveMessage({ kind: "error", text }),
  onActive: active => { guardPending.value = active },
})
function guarded(next, options) { return draftGuard.run(next, options) }
const pages = computed(() => [
  { id: "city", name: "Map" },
  ...(!state.value.introduction ? [{ id: "events", name: "Races" }] : []),
  ...(!state.value.introduction && state.value.features?.results ? [{ id: "results", name: "Results" }] : []),
  ...(!state.value.introduction ? [{ id: "progress", name: "Progress" }] : []),
  { id: "garage", name: state.value.introduction ? "Dealership" : "Garage" },
  ...(!state.value.introduction && state.value.features?.sponsors ? [{ id: "sponsors", name: "Sponsors" }] : []),
  { id: "inbox", name: "Messages" + (state.value.unreadMessages ? " · " + state.value.unreadMessages : "") },
])
function focusContent() {
  if (page.value === "city") { cityPage.value?.focusSelection(); return }
  if (page.value === "inbox") { messagesPage.value?.focusSelection(); return }
  if (page.value === "garage") { garagePage.value?.focusSelection(); return }
  if (page.value === "sponsors") { sponsorsPage.value?.focusSelection(); return }
  if (page.value === "results") { resultsPage.value?.focusSelection(); return }
  const target = content.value?.querySelector("[bng-nav-item]:not(:disabled)")
  if (target) nav.requestScopeFocus("bngu-board", target)
  else nav.requestScopeFocus("bngu-board", `[data-bngu-page='${page.value}']`)
}
async function setPage(id) {
  if (id === page.value) { if (!guardPending.value) focusContent(); return }
  return guarded(async () => { focusEvent.value = null; focusChapter.value = null; page.value = id; await nextTick(); focusContent() })
}
async function openInvite(id) { return guarded(async () => { focusEvent.value = id; page.value = "city"; await nextTick(); focusContent() }) }
async function openChapter(id) { return guarded(async () => { focusChapter.value = id; page.value = "events"; await nextTick(); focusContent() }) }
function receiveState(value) {
  if (disposed || !value || typeof value !== "object") return
  const firstActive = !state.value.active && value.active
  state.value = value
  loading.value = false
  if (firstActive) {
    page.value = value.menuPage || "city"
    nextTick(focusContent)
  }
}
function receiveMessage(value) {
  if (disposed) return
  notice.value = value
  clearTimeout(noticeTimer)
  noticeTimer = setTimeout(() => { notice.value = null }, 6500)
}
async function refresh() {
  loading.value = true
  try { receiveState(await requestState()) }
  catch (error) { receiveMessage({ kind: "error", text: String(error.message || error) }) }
  finally { loading.value = false }
}
async function send(action, argument) {
  if (guardPending.value || pending.value) return false
  if (guardedActions.has(action)) return guarded(() => executeSend(action, argument), { allowApply: action !== "resetTune" })
  return executeSend(action, argument)
}
async function executeSend(action, argument) {
  if (pending.value) return false
  pending.value = true
  try {
    const result = await command(action, argument)
    if (disposed) return false
    if (["buyStarter", "buyCar", "selectCar", "upgrade", "equip", "paint", "bodykit", "toggleKit", "driftBuild", "dragBuild", "tune", "resetTune", "buyPart", "fitPart", "signSponsor", "showcase", "readMessage", "readMessages"].includes(action)) receiveState(await requestState())
    return result === true
  }
  catch (error) { receiveMessage({ kind: "error", text: String(error.message || error) }); return false }
  finally { pending.value = false }
}
async function recoverCar(action) {
  if (recoveringCar.value || state.value.carTransaction?.phase !== "fault") return
  recoveringCar.value = true
  try { await command(action); if (!disposed) receiveState(await requestState()) }
  catch (error) { receiveMessage({ kind: "error", text: String(error.message || error) }) }
  finally { recoveringCar.value = false }
}
function close() { send("close") }
function handleBack() {
  if (guardPending.value || view.value.busy) return false
  if (page.value === "inbox" && messagesPage.value?.back()) return false
  if (page.value === "garage" && garagePage.value?.back()) return false
  if (page.value === "results" && resultsPage.value?.back()) return false
  close(); return false
}
onMounted(() => { events.on("BNGUState", receiveState); events.on("BNGUMessage", receiveMessage); refresh() })
onUnmounted(() => { disposed = true; draftGuard.dispose(); events.off("BNGUState", receiveState); events.off("BNGUMessage", receiveMessage); clearTimeout(noticeTimer) })
</script>
