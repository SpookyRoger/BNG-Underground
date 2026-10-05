<template>
  <main ref="root" class="bngu-workshop" v-bng-scoped-nav="{ scopeId: 'bngu-workshop', activateOnMount: true, preferAutoFocus: true, canDeactivate: handleBack }" v-bng-on-ui-nav:menu="handleBack"
    v-bng-on-ui-nav:tab_l="previousCategory" v-bng-on-ui-nav:tab_r="nextCategory"
    v-bng-on-ui-nav:subtab_l="previousView" v-bng-on-ui-nav:subtab_r="nextView"
    v-bng-on-ui-nav:context="toggleInspectionFocus">
    <header class="workshop-header">
      <div><small>BNG UNDERGROUND · {{ shop.site === 'home' ? "MARA'S GARAGE" : siteName }}</small><h1>{{ spec.name || 'Your workshop' }}</h1><span>INSPECTION BAY · GAME PAUSED</span></div>
      <div class="bank"><strong>{{ money(state.cash) }}</strong><small>BANK · BROWSING IS FREE</small></div>
      <BngButton accent="base" :disabled="buying || guardPending || shop.exiting" @click="exit('play')">Leave workshop</BngButton>
    </header>
    <nav class="workshop-categories" aria-label="Choose parts category">
      <span class="category-hint"><BngBinding ui-event="tab_l" controller track-ignore /><BngBinding ui-event="tab_r" controller track-ignore /><small>{{ categoryId === 'tuning' ? 'TUNING GROUP' : 'CATEGORY' }}</small></span>
      <BngButton v-for="entry in categories" :key="entry.id" accent="base" :data-workshop-category="entry.id" :class="{ selected: categoryId === entry.id }" :aria-pressed="categoryId === entry.id" :disabled="buying || guardPending || shop.exiting" @click="chooseCategory(entry.id)">{{ entry.name }}</BngButton>
    </nav>
    <p v-if="notice || shop.error" class="workshop-notice" :class="{ error: shop.error || notice?.kind === 'error' }" role="status">{{ shop.error || notice.text }}</p>
    <WorkshopTuning v-if="shop.active && categoryId === 'tuning'" ref="tuningPage" class="workshop-options" :state="state" :spec="spec" :locked="buying || guardPending || shop.exiting" :sending="previewSending" :save-preview="savePreview" @preview="queuePreview" @parts="chooseCategory(lastPartsCategory)" />
    <section v-else-if="shop.active" class="workshop-options" aria-label="Browse fitted car upgrades">
      <div class="option-heading"><small>{{ categoryName }}</small><strong>See it on your car.</strong><p>Scroll to preview. Confirm a choice to review its purchase.</p></div>
      <div class="option-list" bng-nav-scroll>
        <BngButton v-for="entry in choices" :key="entry.id" accent="base" class="option-row" :class="{ selected: selectedId === entry.id }" :data-workshop-choice="entry.id" :disabled="buying || shop.exiting" @focusin="highlight(entry, $event)" @mouseenter="highlight(entry)" @click="review(entry)">
          <i v-if="entry.rgba" class="paint-chip" :style="{ background: colour(entry.rgba) }"></i>
          <span><strong>{{ entry.name }}</strong><small>{{ entry.fitted ? 'FITTED' : !entry.compatible ? 'INCOMPATIBLE BUILD' : entry.blockedBy ? 'OWN ' + entry.blockedBy.toUpperCase() + ' FIRST' : !entry.unlocked ? 'CHAPTER ' + entry.chapter : entry.owned ? 'OWNED · FREE TO FIT' : money(entry.cost) }}</small></span>
        </BngButton>
      </div>
      <div v-if="categoryId === 'paint' && selectedId !== 'saved'" class="finish-list" aria-label="Paint finish">
        <BngButton v-for="entry in finishes" :key="entry.id" accent="base" :class="{ selected: finishId === entry.id }" :aria-pressed="finishId === entry.id" :disabled="buying || shop.exiting" @click="finishId = entry.id">{{ entry.name }}</BngButton>
      </div>
      <div class="option-detail" bng-nav-scroll>
        <p>{{ selected?.description }}</p>
        <div v-if="selected?.partNames?.length" class="hardware-names"><small>FITTED NATIVE HARDWARE</small><span v-for="(name, index) in selected.partNames" :key="index">{{ typeof name === 'string' ? name : $ctx_t(name) }}</span></div>
        <p v-if="!selected?.compatible">{{ bodyCategory ? 'This piece needs a different body, front end or fender width. The saved car is shown.' : 'Choose a compatible grip build in Garage. The saved car is shown.' }}</p>
        <p v-else-if="selected && !selected.unlocked">You can inspect this upgrade now. <template v-if="selected.blockedBy">Own {{ selected.blockedBy }} before buying this build. </template><template v-if="state.chapter < selected.chapter">Purchases unlock in chapter {{ selected.chapter }}.</template></p>
        <p v-if="categoryId === 'build'">This changes the matched base. Individual parts and saved setups remain separate for each build; unbought previews are restored when you leave.</p>
        <p v-if="quoteMatches && shop.quote && !shop.quote.fitted">{{ money(shop.quote.cost) }} to fit · {{ money(state.cash - shop.quote.cost) }} remaining</p>
        <BngButton accent="base" data-workshop-buy :disabled="!canBuy" @click="buy">{{ buyLabel }}</BngButton>
        <p v-if="categoryInfo?.resetGroups && selected && !selected.fitted" class="reset-note">Fitting resets {{ array(categoryInfo.resetGroups).join(' and ') }} adjustments. Your other tuning stays fitted.</p>
        <p class="temporary-note">Unbought previews are removed when you leave. Every purchase saves immediately.</p>
      </div>
    </section>
    <div class="inspection-controls" :class="{ inspecting: inspectionFocused }" @focusin="inspectionFocused = true" @focusout="inspectionBlur">
      <small class="view-hint"><BngBinding ui-event="subtab_l" controller track-ignore /><span>INSPECT YOUR CAR</span><BngBinding ui-event="subtab_r" controller track-ignore /></small>
      <div><BngButton v-for="entry in array(shop.views)" :key="entry.id" accent="base" :data-workshop-view="entry.id" :disabled="buying || shop.exiting" :class="{ selected: shop.viewId === entry.id }" @click="view(entry.id)">{{ entry.name }}</BngButton></div>
      <span v-if="shop.loading" class="view-loading">Your selected angle applies when the car is ready.</span>
      <BngButton v-if="categories.some(entry => entry.id === 'tuning')" accent="base" :disabled="buying || guardPending || shop.exiting" @click="chooseCategory(categoryId === 'tuning' ? lastPartsCategory : 'tuning')">{{ categoryId === 'tuning' ? 'Browse parts & builds' : 'Tune this car' }}</BngButton>
      <BngButton accent="base" :disabled="buying || guardPending || shop.exiting" @click="exit('board')">Car collection</BngButton>
    </div>
    <WorkshopStats class="inspection-stats" :baseline="shop.baselineStats" :current="shop.stats" :measuring="shop.measuring || shop.pending" />
    <div v-if="status" class="preview-status" role="status">{{ status }}</div>
    <WorkshopRecovery v-if="shop.phase === 'fault'" ref="recoveryPage" :status="shop" :busy="buying || recoveringSaved || guardPending" @restore="recoverSaved" @retry="exit('play')" @abort="abort" />
    <footer><span>{{ categoryId === 'tuning' ? 'UP / DOWN · SELECT · LEFT / RIGHT · ADJUST' : 'D-PAD / STICK · BROWSE PARTS' }}</span><span><BngBinding ui-event="context" controller track-ignore /> {{ inspectionFocused ? (categoryId === 'tuning' ? 'BACK TO ADJUSTMENTS' : 'BACK TO PARTS') : 'FOCUS CAR VIEWS' }}</span><span><BngBinding ui-event="ok" controller track-ignore /> {{ categoryId === 'tuning' ? 'REVIEW / SAVE' : 'REVIEW / BUY' }}</span><span>BACK / START · RESTORE & LEAVE</span></footer>
  </main>
</template>
<script setup>
import { ref, computed, watch, nextTick, onMounted, onUnmounted } from "vue"
import { BngButton, BngBinding } from "@/common/components/base"
import { vBngScopedNav, vBngOnUiNav } from "@/common/directives"
import { useBridge } from "@/bridge"
import { useScopedNav } from "@/services/scopedNav/api"
import { useUINavBlocker } from "@/services/uiNavTracker"
import { command, requestState } from "./campaignApi.js"
import { array, money } from "./presentation.js"
import WorkshopStats from "./components/WorkshopStats.vue"
import WorkshopTuning from "./components/WorkshopTuning.vue"
import WorkshopRecovery from "./components/WorkshopRecovery.vue"
import WorkshopTuningLeaveMessage from "./components/messages/WorkshopTuningLeaveMessage.vue"
import { openConfirmation } from "@/services/popup"
import { createDraftGuard } from "./draftGuard.js"
import { canonical, createTriggerLatch, wrapIndex } from "./workshopControls.js"
const { events } = useBridge(), nav = useScopedNav()
useUINavBlocker().ensureNoBlock(["tab_l", "tab_r", "subtab_l", "subtab_r", "context"])
const root = ref(null), state = ref({ active: false }), categoryId = ref(""), selectedId = ref("base"), finishId = ref("metallic")
const notice = ref(null), buying = ref(false), previewSending = ref(false), guardPending = ref(false), tuningPage = ref(null), recoveryPage = ref(null), recoveringSaved = ref(false)
const lastPartsCategory = ref("")
const inspectionFocused = ref(false), rememberedChoices = new Map()
const leftTrigger = createTriggerLatch(), rightTrigger = createTriggerLatch()
let disposed = false, queuedRequest = null, lastRequestKey = "", wantsPurchaseFocus = false
const shop = computed(() => state.value.liveWorkshop || { active: false })
const spec = computed(() => array(state.value.vehicleList).find(car => car.id === state.value.activeCar) || {})
const car = computed(() => state.value.garage?.[state.value.activeCar] || {})
const siteName = computed(() => array(state.value.locations).find(site => site.id === shop.value.site)?.name || "WORKSHOP")
const categories = computed(() => [
  ...(state.value.parts?.grip ? array(state.value.parts.categories) : []),
  ...array(state.value.bodyworkShop?.categories).map(entry => ({ id: "body-" + entry.id, name: entry.name })),
  { id: "paint", name: "Paint" }, ...(spec.value.stylePartCount ? [{ id: "style", name: "Matched kit" }] : []),
  ...(state.value.workshopBuilds ? [{ id: "build", name: "Builds" }] : []),
  ...(state.value.features?.liveTuning && array(state.value.tuning?.controls).length ? [{ id: "tuning", name: "Tuning" }] : []),
])
const bodyCategory = computed(() => categoryId.value.startsWith("body-") ? categoryId.value.slice(5) : null)
const categoryInfo = computed(() => bodyCategory.value ? array(state.value.bodyworkShop?.categories).find(entry => entry.id === bodyCategory.value) : array(state.value.parts?.categories).find(entry => entry.id === categoryId.value))
const categoryName = computed(() => categories.value.find(entry => entry.id === categoryId.value)?.name || "PARTS")
const finishes = computed(() => array(state.value.paintShop?.finishes).filter(entry => state.value.features?.paintFinishes !== false || entry.id === (car.value.paintFinish || state.value.paintShop?.defaultFinish)))
const choices = computed(() => {
  if (categoryId.value === "tuning") return []
  if (categoryId.value === "build") return array(state.value.workshopBuilds?.options)
  if (bodyCategory.value) return [
    { id: "base", name: "Equipped-build " + categoryName.value.toLowerCase(), description: "Remove this personal override and use the piece from your current build and matched-kit setting. Other pieces stay fitted.", owned: true, compatible: true, unlocked: true, fitted: !state.value.bodyworkShop?.selected?.[bodyCategory.value], cost: 0 },
    ...array(state.value.bodyworkShop?.options).filter(entry => entry.category === bodyCategory.value && !entry.base),
  ]
  if (categoryId.value === "paint") return [
    { id: "saved", name: "Keep fitted paint", description: "Your saved colour and finish.", owned: true, compatible: true, unlocked: true, fitted: true, cost: 0 },
    ...array(state.value.paints).map(entry => ({ ...entry, description: "Preview this colour with a native paint finish.", owned: false, compatible: true, unlocked: true, fitted: car.value.paint === entry.id && (car.value.paintFinish || state.value.paintShop?.defaultFinish) === finishId.value, cost: state.value.prices?.paint })),
  ]
  if (categoryId.value === "style") return [
    { id: "original", name: "Without matched kit", description: "Use your equipped build beneath its personal bodywork choices. Each build/kit setting remembers its own pieces.", owned: true, compatible: true, unlocked: true, fitted: !car.value.bodykit || car.value.kitEquipped === false, cost: 0 },
    { id: "kit", name: "Style kit", description: "The existing matched native kit. Personal pieces override it; included kit hardware can be refitted free. Inspect the front, side and rear before buying.", owned: !!car.value.bodykit, compatible: true, unlocked: true, fitted: car.value.bodykit && car.value.kitEquipped !== false, cost: car.value.bodykit ? 0 : state.value.prices?.bodykit },
  ]
  return [{ id: "base", name: "Base " + categoryName.value, description: categoryInfo.value?.description, owned: true, compatible: true, unlocked: true, fitted: !state.value.parts?.selected?.[categoryId.value], cost: 0 }, ...array(state.value.parts?.options).filter(entry => entry.category === categoryId.value)]
})
const selected = computed(() => choices.value.find(entry => entry.id === selectedId.value) || choices.value[0])
const previewRequest = computed(() => {
  const entry = selected.value
  if (!shop.value.active || !entry || !categoryId.value) return null
  if (!entry.compatible || (categoryId.value === "paint" && entry.id === "saved")) return { kind: "saved", car: state.value.activeCar }
  if (categoryId.value === "build") {
    const builds = state.value.workshopBuilds
    return builds ? { kind: "build", car: state.value.activeCar, argument: { car: builds.car, hardware: builds.signature, choice: entry.id } } : null
  }
  if (bodyCategory.value) {
    const body = state.value.bodyworkShop
    return body ? { kind: "bodywork", car: state.value.activeCar, argument: { car: body.car, build: body.key, hardware: body.signature, category: bodyCategory.value, part: entry.id } } : null
  }
  if (categoryId.value === "paint") return { kind: "paint", car: state.value.activeCar, argument: { car: state.value.activeCar, basePaint: car.value.paint || false, baseFinish: car.value.paint ? (car.value.paintFinish || state.value.paintShop?.defaultFinish) : false, colour: entry.id, finish: finishId.value } }
  if (categoryId.value === "style") return { kind: "style", car: state.value.activeCar, argument: entry.id === "kit" }
  const parts = state.value.parts
  return parts ? { kind: "part", car: state.value.activeCar, argument: { car: parts.car, build: parts.key, hardware: parts.signature, category: categoryId.value, part: entry.id } } : null
})
const quoteMatches = computed(() => !!previewRequest.value && canonical(previewRequest.value) === canonical(shop.value.quote?.request))
const canBuy = computed(() => !buying.value && !previewSending.value && shop.value.ready && quoteMatches.value && shop.value.quote?.canBuy)
const buyLabel = computed(() => {
  if (buying.value) return "Saving your upgrade…"
  if (!selected.value?.compatible) return bodyCategory.value ? "This piece does not fit this build" : "Choose a compatible build"
  if (shop.value.pending || previewSending.value || !quoteMatches.value) return "Preparing this preview…"
  if (shop.value.quote?.fitted) return "Already fitted"
  if (selected.value?.blockedBy) return "Own " + selected.value.blockedBy + " first"
  if (!shop.value.quote?.unlocked) return "Locked until chapter " + selected.value?.chapter
  if (state.value.cash < shop.value.quote?.cost) return "Need " + money(shop.value.quote.cost - state.value.cash) + " more"
  return shop.value.quote?.cost ? "Buy & fit · " + money(shop.value.quote.cost) : categoryId.value === "build" ? "Fit owned build · free" : "Fit owned hardware · free"
})
const status = computed(() => shop.value.exiting ? "Restoring your paid build before returning…" : shop.value.phase === "fault" ? "Car readiness delayed" : shop.value.pending ? (shop.value.measuring ? "Reading this car's performance…" : "Preparing your car preview…") : "")
const colour = rgba => `rgb(${rgba.slice(0, 3).map(n => Math.round(n * 255)).join(",")})`
const draftGuard = createDraftGuard({
  getDraft: () => categoryId.value === "tuning" ? tuningPage.value?.draftState() : null,
  isBusy: () => buying.value || recoveringSaved.value || (shop.value.exiting && shop.value.phase !== "fault"),
  isCurrent: draft => !!tuningPage.value?.isDraftCurrent(draft),
  confirm: (draft, allowApply) => openConfirmation("Unsaved workshop setup", {
    component: WorkshopTuningLeaveMessage,
    props: { carName: draft.carName, changedCount: draft.changedCount, canSave: draft.ready && allowApply },
  }, [
    { label: "Keep editing", value: "keep", extras: { cancel: true, default: true, outsideCancel: true } },
    { label: "Discard & continue", value: "discard", extras: { destructive: true } },
    ...(allowApply ? [{ label: "Save & continue · free", value: "apply", extras: { confirm: true, disabled: !draft.ready } }] : []),
  ], "", false),
  apply: draft => savePreview(draft.request),
  discard: draft => !!tuningPage.value?.discardDraft(draft),
  focus: focusWorkspace,
  notify: text => receiveMessage({ kind: "error", text }),
  onActive: active => { guardPending.value = active },
})
function receiveState(value) {
  if (disposed || !value) return
  state.value = value
  if (!categories.value.some(entry => entry.id === categoryId.value)) {
    categoryId.value = categories.value[0]?.id || ""
    selectedId.value = fittedChoice(categoryId.value)
  }
  if (!categories.value.some(entry => entry.id === lastPartsCategory.value && entry.id !== "tuning")) lastPartsCategory.value = categories.value.find(entry => entry.id !== "tuning")?.id || ""
  if (!choices.value.some(entry => entry.id === selectedId.value)) selectedId.value = choices.value[0]?.id || "base"
  if (!finishes.value.some(entry => entry.id === finishId.value)) finishId.value = finishes.value[0]?.id || "metallic"
}
function receiveMessage(value) { if (!disposed) notice.value = value }
async function queuePreview(request) {
  if (!request || disposed || buying.value || recoveringSaved.value || shop.value.exiting || shop.value.phase === "fault") return
  const key = canonical(request)
  if (key === lastRequestKey && !queuedRequest) return
  queuedRequest = request
  if (previewSending.value) return
  previewSending.value = true
  try {
    while (queuedRequest && !disposed && !shop.value.exiting && !recoveringSaved.value) {
      const next = queuedRequest; queuedRequest = null; lastRequestKey = canonical(next)
      const ok = await command("workshopPreview", next)
      if (!ok && !disposed) notice.value = { kind: "error", text: "This preview could not be prepared. Review the fitted car and choose again." }
    }
  } catch (error) { receiveMessage({ kind: "error", text: String(error.message || error) }) }
  finally { previewSending.value = false }
}
function highlight(entry, event) {
  if (buying.value || shop.value.exiting) return
  if (selectedId.value !== entry.id) { selectedId.value = entry.id; wantsPurchaseFocus = false }
  event?.currentTarget?.scrollIntoView({ block: "nearest" })
}
async function focusChoice() {
  await nextTick()
  if (disposed) return
  if (categoryId.value === "tuning") { await tuningPage.value?.focusSelection(); return }
  const target = Array.from(root.value?.querySelectorAll("[data-workshop-choice]") || []).find(el => el.getAttribute("data-workshop-choice") === selectedId.value)
  if (target) nav.requestScopeFocus("bngu-workshop", target)
}
async function focusWorkspace() {
  if (shop.value.phase === "fault") return recoveryPage.value?.focusRecovery()
  return focusChoice()
}
function fittedChoice(id) {
  if (id === "build") return array(state.value.workshopBuilds?.options).find(entry => entry.fitted)?.id || "stock"
  if (id.startsWith("body-")) return state.value.bodyworkShop?.selected?.[id.slice(5)] || "base"
  return id === "paint" ? "saved" : id === "style" ? (car.value.bodykit && car.value.kitEquipped !== false ? "kit" : "original") : state.value.parts?.selected?.[id] || "base"
}
async function chooseCategory(id) {
  if (buying.value || guardPending.value || shop.value.exiting || !categories.value.some(entry => entry.id === id)) return
  if (categoryId.value === id) { await focusChoice(); return }
  return draftGuard.run(() => switchCategory(id))
}
async function switchCategory(id) {
  rememberedChoices.set(categoryId.value, selectedId.value)
  if (categoryId.value !== "tuning") lastPartsCategory.value = categoryId.value
  categoryId.value = id
  const remembered = rememberedChoices.get(id)
  selectedId.value = choices.value.some(entry => entry.id === remembered) ? remembered : fittedChoice(id)
  wantsPurchaseFocus = false; await focusChoice()
  const tab = Array.from(root.value?.querySelectorAll("[data-workshop-category]") || []).find(el => el.getAttribute("data-workshop-category") === id)
  tab?.scrollIntoView({ block: "nearest", inline: "nearest" })
}
function stepCategory(direction) {
  if (guardPending.value || buying.value || recoveringSaved.value || shop.value.exiting || shop.value.phase === "fault") return false
  if (categoryId.value === "tuning") return tuningPage.value?.stepGroup(direction) ?? false
  const entries = categories.value
  const index = wrapIndex(entries.findIndex(entry => entry.id === categoryId.value), direction, entries.length)
  if (index >= 0) chooseCategory(entries[index].id)
  return false
}
function previousCategory() { return stepCategory(-1) }
function nextCategory() { return stepCategory(1) }
function stepView(direction) {
  if (shop.value.phase === "fault" || recoveringSaved.value) return false
  const entries = array(shop.value.views)
  const index = wrapIndex(entries.findIndex(entry => entry.id === shop.value.viewId), direction, entries.length)
  if (index >= 0) view(entries[index].id)
  return false
}
function previousView(event) { if (leftTrigger(event.detail.value)) stepView(-1); return false }
function nextView(event) { if (rightTrigger(event.detail.value)) stepView(1); return false }
function inspectionBlur(event) { if (!event.currentTarget.contains(event.relatedTarget)) inspectionFocused.value = false }
function toggleInspectionFocus() {
  if (buying.value || guardPending.value || recoveringSaved.value || shop.value.exiting || shop.value.phase === "fault") return false
  wantsPurchaseFocus = false
  if (inspectionFocused.value) focusChoice()
  else nextTick(() => {
    const targets = Array.from(root.value?.querySelectorAll("[data-workshop-view]:not(:disabled)") || [])
    const target = targets.find(el => el.getAttribute("data-workshop-view") === shop.value.viewId) || targets[0]
    if (target) nav.requestScopeFocus("bngu-workshop", target)
  })
  return false
}
async function focusPurchase() {
  if (!wantsPurchaseFocus || !canBuy.value) return
  await nextTick()
  const target = root.value?.querySelector("[data-workshop-buy]:not(:disabled)")
  if (target) { nav.requestScopeFocus("bngu-workshop", target); wantsPurchaseFocus = false }
}
function review(entry) { highlight(entry); wantsPurchaseFocus = true; focusPurchase() }
async function buy() {
  if (!canBuy.value) return
  return savePreview(previewRequest.value)
}
async function savePreview(request) {
  if (disposed || buying.value || previewSending.value || !shop.value.ready || !shop.value.quote?.canBuy || canonical(request) !== canonical(shop.value.quote.request)) return false
  buying.value = true; wantsPurchaseFocus = false
  let saved = false
  try {
    const ok = await command("workshopBuy", { token: shop.value.quote.token, revision: shop.value.quote.revision })
    if (!ok) receiveMessage({ kind: "error", text: "The change was not saved. Your preview is still temporary." })
    const updated = await requestState()
    receiveState(updated); lastRequestKey = ""; saved = !!ok && !!updated
  } catch (error) { receiveMessage({ kind: "error", text: String(error.message || error) }) }
  finally {
    buying.value = false
    if (!disposed) { if (categoryId.value === "tuning") tuningPage.value?.refreshPreview(); else queuePreview(previewRequest.value); if (!guardPending.value) focusChoice() }
  }
  return saved
}
function view(id) { if (!buying.value && !guardPending.value && !shop.value.exiting) { wantsPurchaseFocus = false; command("workshopView", id).catch(error => receiveMessage({ kind: "error", text: String(error) })) } }
function exit(target) { return draftGuard.run(() => command("exitWorkshop", target)) }
function recoverSaved() {
  return draftGuard.run(async () => {
    if (disposed || shop.value.phase !== "fault" || recoveringSaved.value) return false
    recoveringSaved.value = true; queuedRequest = null; lastRequestKey = ""; wantsPurchaseFocus = false
    rememberedChoices.clear(); selectedId.value = fittedChoice(categoryId.value)
    try {
      const ok = await command("workshopRecover")
      if (disposed) return false
      receiveState(await requestState())
      selectedId.value = fittedChoice(categoryId.value)
      finishId.value = car.value.paintFinish || state.value.paintShop?.defaultFinish || "metallic"
      if (!ok) receiveMessage({ kind: "error", text: "The saved car could not be prepared. Your paid build remains protected." })
      return ok === true
    } catch (error) { receiveMessage({ kind: "error", text: String(error.message || error) }); return false }
    finally {
      recoveringSaved.value = false
      if (!disposed) {
        if (categoryId.value === "tuning") tuningPage.value?.refreshPreview()
        else queuePreview(previewRequest.value)
        focusWorkspace()
      }
    }
  }, { allowApply: false })
}
function abort() { return draftGuard.run(() => command("workshopAbort"), { allowApply: false }) }
function handleBack() { exit("play"); return false }
watch(() => canonical(previewRequest.value), () => queuePreview(previewRequest.value))
watch(canBuy, focusPurchase)
onMounted(async () => {
  events.on("BNGUState", receiveState); events.on("BNGUMessage", receiveMessage)
  try { receiveState(await requestState()); finishId.value = car.value.paintFinish || state.value.paintShop?.defaultFinish || "metallic"; await focusChoice() }
  catch (error) { receiveMessage({ kind: "error", text: String(error.message || error) }) }
})
onUnmounted(() => { disposed = true; draftGuard.dispose(); queuedRequest = null; events.off("BNGUState", receiveState); events.off("BNGUMessage", receiveMessage) })
</script>
<style scoped>
.bngu-workshop { position: absolute; inset: 0; display: flex; flex-direction: column; color: #faf3ff; background: linear-gradient(180deg,#120d20e8 0,transparent 32%,transparent 76%,#120d20d9 100%); font-family: 'Overpass',sans-serif; padding: 1.4rem 2rem 2.5rem; }
.workshop-header { display: flex; align-items: center; justify-content: space-between; gap: 2rem; }.workshop-header h1 { margin: .3rem 0; font-size: 1.9rem; }.workshop-header span, small { font-size: .72rem; letter-spacing: .11em; color: #8de6d9; }.bank { margin-left: auto; text-align: right; }.bank strong { display: block; font-size: 1.8rem; }.bank small { color: #e2d6ee; }
.workshop-categories { display: flex; gap: .4rem; margin-top: 1.2rem; flex-wrap: nowrap; overflow-x: auto; flex-shrink: 0; padding: .2rem; }.workshop-categories > * { flex-shrink: 0; }.category-hint,.view-hint { display: flex; align-items: center; gap: .4rem; }.category-hint { padding-right: .6rem; }.selected { box-shadow: inset 0 -3px #83e8d8; }.workshop-notice { position: absolute; top: 11.5rem; left: 2rem; max-width: 55%; padding: .8rem 1rem; border-radius: .4rem; background: #20172fe8; }.error { color: #ffbfb8; }
.workshop-options { position: absolute; top: 11rem; right: 2rem; bottom: 5.3rem; width: clamp(19rem,29vw,29rem); display: flex; flex-direction: column; background: #181123f2; border: 1px solid #8e71ab88; border-radius: .8rem; overflow: hidden; }
.option-heading { padding: 1rem 1.2rem .5rem; }.option-heading strong { display: block; font-size: 1.3rem; margin: .3rem 0; }.option-heading p { font-size: .8rem; color: #d8c8e4; margin: .4rem 0; }.option-list { overflow: auto; flex: 1 1 40%; min-height: 6rem; padding: .4rem .8rem; display: flex; flex-direction: column; gap: .4rem; }.option-row { flex-shrink: 0; justify-content: flex-start; text-align: left; min-height: 3.7rem; }.option-row span { display: flex; flex-direction: column; gap: .3rem; }.option-row small { font-size: .66rem; }.paint-chip { width: 1.5rem; height: 1.5rem; margin-right: .7rem; border-radius: 50%; border: 1px solid #fff8; flex-shrink: 0; }
.finish-list { display: grid; grid-template-columns: 1fr 1fr; gap: .2rem; padding: .4rem .8rem; }.option-detail { flex: 0 1 auto; max-height: 43%; overflow: auto; padding: .4rem 1.2rem 1rem; border-top: 1px solid #8e71ab55; font-size: .85rem; }.option-detail > :deep(.bng-button) { width: 100%; }.hardware-names { display: flex; flex-direction: column; gap: .25rem; font-size: .72rem; }.reset-note,.temporary-note { color: #c5b4d6; font-size: .72rem; line-height: 1.4; }
.inspection-controls { position: absolute; bottom: 5.8rem; left: 37%; width: 29%; display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: .6rem; border-radius: .6rem; background: #181123b8; border: 1px solid #8e71ab55; }.inspection-controls.inspecting { border-color: #83e8d8; }.inspection-controls > div { display: flex; gap: .3rem; }.view-loading { font-size: .7rem; color: #dbd1e4; text-align: center; }.inspection-stats { position: absolute; left: 2rem; bottom: 5.5rem; width: 29%; }.preview-status { position: absolute; top: 43%; left: 37%; padding: .7rem 1.1rem; border: 1px solid #90e9d988; border-radius: .5rem; background: #171124eb; font-size: .8rem; }
footer { position: absolute; bottom: 2rem; left: 2rem; right: 2rem; display: flex; justify-content: space-between; gap: .5rem 1rem; flex-wrap: wrap; font-size: .68rem; letter-spacing: .06em; color: #dbd1e4; }footer > span { display: flex; align-items: center; gap: .4rem; }
@media (max-height: 850px) { .workshop-header h1 { font-size: 1.35rem; }.workshop-header strong { font-size: 1.35rem; }.bngu-workshop { padding-top: .7rem; }.workshop-categories { margin-top: .6rem; }.workshop-options { top: 8.5rem; }.workshop-notice { top: 9rem; }.option-heading { padding: .6rem 1rem .3rem; }.option-heading p { margin: .15rem 0; }.option-detail { max-height: 39%; }.inspection-stats { width: 32%; }.inspection-controls { left: 37%; width: 29%; } }
</style>
