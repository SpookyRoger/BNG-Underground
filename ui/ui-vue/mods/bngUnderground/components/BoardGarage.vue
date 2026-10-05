<template>
  <section ref="root" class="bngu-garage-page">
    <header class="bngu-page-heading"><small>{{ state.introduction ? 'QUARRYSIDE AUTO SALES' : 'OWN IT. BUILD IT. DRIVE IT.' }}</small><h1>{{ state.introduction ? 'Your first set of keys.' : 'Your garage.' }}</h1></header>
    <div v-if="state.introduction || section !== 'Covers'" class="bngu-workshop-status" :class="{ ready: state.introduction ? state.nearDealership : ready }" role="status">
      <strong>{{ state.introduction ? (state.nearDealership ? 'Dealership open' : 'Visit Quarryside Auto Sales') : (ready ? 'Workshop open · ' + state.workshop.siteName : 'Collection preview · workshop closed') }}</strong>
      <p>{{ state.introduction ? 'Park and stop in the dealership lot to buy your own car. All three cost $9,000; choose the one that feels like you.' : state.workshop.reason }}</p>
      <BngButton v-if="state.introduction" accent="base" :disabled="state.busy" @click="$emit('command', 'navigateLocation', state.dealership.id)">GPS to dealership</BngButton><BngButton v-else-if="!ready && state.workshop.nearestId" accent="base" :disabled="state.busy" @click="$emit('command', 'navigateLocation', state.workshop.nearestId)">GPS to {{ state.workshop.nearestName }} · {{ distance(state.workshop.distance) }}</BngButton>
    </div>
    <article v-if="!state.introduction && state.features.liveWorkshop" class="bngu-card"><small>BUILD YOUR ACTUAL CAR</small><p>Enter the workshop to preview individual parts, wheels, paint, bodywork, matched builds and tuning on your car before saving. Browsing here still works anywhere.</p><BngButton accent="base" :disabled="!ready" @click="$emit('command', 'enterWorkshop')">{{ ready ? 'Enter workshop · ' + state.workshop.siteName : 'Park at a workshop to enter' }}</BngButton></article>
    <div v-if="!state.introduction" class="bngu-tabs bngu-garage-tabs"><BngButton v-for="tab in tabs" :key="tab" accent="base" :data-bngu-garage-tab="tab" :class="{ selected: section === tab }" :aria-pressed="section === tab" @click="setSection(tab)">{{ tab }}</BngButton></div>
    <div v-if="state.introduction || section === 'Cars'" class="bngu-garage-columns">
      <div class="bngu-garage-car-list" bng-nav-scroll aria-label="Browse cars">
        <BngButton v-for="entry in browseCars" :key="entry.id" accent="base" class="bngu-garage-car" :class="{ selected: selectedId === entry.id }" :data-bngu-garage-car="entry.id" @focusin="highlightCar(entry, $event)" @mouseenter="selectedId = entry.id" @click="openCar(entry)"><img :src="carImage(entry)" alt=""><span class="bngu-garage-car-copy"><strong>{{ entry.name }}</strong><small>{{ entry.owned ? (entry.id === state.activeCar ? 'ACTIVE CAR' : 'OWNED') : money(entry.price) }} · {{ entry.drive }}</small><span v-if="!entry.unlocked && !state.introduction">CHAPTER {{ entry.chapter }}</span></span></BngButton>
      </div>
      <div ref="detail" class="bngu-garage-detail" bng-nav-scroll>
        <article v-if="selectedCar" class="bngu-card bngu-car-detail"><img :src="carImage(selectedCar)" :alt="selectedCar.name"><small>{{ selectedCar.drive }} · {{ selectedCar.owned ? 'OWNED' : 'CHAPTER ' + selectedCar.chapter }}</small><h2>{{ selectedCar.name }}</h2><p>{{ selectedCar.description }}</p>
          <div v-if="selectedCar.performance?.stock" class="bngu-car-stats"><span><strong>{{ selectedCar.performance.stock.power }} PS</strong><small>STOCK POWER</small></span><span><strong>{{ selectedCar.performance.stock.weight }} kg</strong><small>STOCK WEIGHT</small></span><span v-if="selectedCar.performance.stock.accel100"><strong>{{ selectedCar.performance.stock.accel100 }} s</strong><small>0–100 KM/H</small></span></div>
          <template v-if="state.introduction"><p class="bngu-prize">{{ money(selectedCar.price) }}<small>{{ money(state.cash - selectedCar.price) }} left to build with</small></p><BngButton accent="base" :disabled="state.busy || !state.nearDealership || state.cash < selectedCar.price" @click="purchaseStarter(selectedCar.id)">Buy {{ selectedCar.name }}</BngButton><p>Your choice returns Mara's car and opens the city meets.</p></template>
          <template v-else-if="!selectedCar.owned"><p class="bngu-prize">{{ money(selectedCar.price) }}</p><BngButton accent="base" :disabled="!ready || !selectedCar.unlocked || state.cash < selectedCar.price" @click="useCar('buyCar', selectedCar.id)">Buy & drive this car</BngButton><p class="bngu-muted">{{ !selectedCar.unlocked ? 'Reach chapter ' + selectedCar.chapter + ' to buy this model.' : state.cash < selectedCar.price ? 'You need ' + money(selectedCar.price - state.cash) + ' more.' : !ready ? 'Purchase at a physical workshop. Use the GPS shortcut above.' : 'Purchase includes the stock setup. Your other cars stay in your collection.' }}</p></template>
          <template v-else-if="selectedCar.id !== state.activeCar"><BngButton accent="base" :disabled="!ready" @click="useCar('selectCar', selectedCar.id)">Drive & modify this car</BngButton><p class="bngu-muted">{{ ready ? 'Switching owned cars is free.' : 'Park at a workshop to switch cars or fit parts.' }}</p></template>
          <template v-else><p class="bngu-muted">This is your active car.</p><BngButton accent="base" @click="ready && state.features.liveWorkshop ? $emit('command', 'enterWorkshop') : setSection(state.features.parts !== false ? 'Parts' : 'Build')">{{ ready ? 'Enter workshop to modify this car' : 'Browse individual parts' }}</BngButton><BngButton accent="base" @click="setSection('Style')">Paint & style</BngButton></template>
          <p class="bngu-muted">UP / DOWN · BROWSE CARS   /   CONFIRM · CAR DETAILS</p>
        </article>
      </div>
    </div>
    <div v-else ref="detail" class="bngu-garage-detail bngu-garage-work" :class="{ 'bngu-contained-work': section === 'Parts' || section === 'Covers' }" bng-nav-scroll>
      <section v-if="section === 'Build'"><small>ACTIVE CAR · {{ spec.name }}</small><h2>{{ buildName }}</h2><p>All packages below apply to your active car. Purchased setups can be refitted for free at a workshop.</p>
        <div v-if="equippedStats" class="bngu-car-stats"><span><strong>{{ equippedStats.power }} PS</strong><small>BASE PACKAGE POWER</small></span><span><strong>{{ equippedStats.weight }} kg</strong><small>BASE PACKAGE WEIGHT</small></span><span><strong>{{ equippedStats.drive }}</strong><small>DRIVE</small></span></div><p v-if="state.parts?.selected && Object.keys(state.parts.selected).length" class="bngu-muted">Individual parts are fitted. These reference figures describe the base preset; modified power and weight are not recalculated.</p>
        <article v-if="nextUpgrade" class="bngu-card"><small>NEXT PACKAGE · CHAPTER {{ nextUpgrade.chapter }}</small><h2>{{ nextUpgrade.name }} · {{ money(nextUpgrade.cost) }}</h2><p>{{ nextUpgrade.description }}</p><p v-if="nextStats">{{ nextStats.power }} PS · {{ nextStats.weight }} kg · {{ nextStats.drive }}</p><BngButton accent="base" :disabled="!ready || state.chapter < nextUpgrade.chapter || state.cash < nextUpgrade.cost" @click="$emit('command', 'upgrade')">Buy & fit {{ nextUpgrade.name }}</BngButton><p v-if="state.chapter < nextUpgrade.chapter" class="bngu-muted">Reach chapter {{ nextUpgrade.chapter }} to buy this package.</p><p v-else-if="state.cash < nextUpgrade.cost" class="bngu-muted">You need {{ money(nextUpgrade.cost - state.cash) }} more.</p></article><p v-else>Every grip package is owned.</p>
        <h2>Owned setups</h2><div class="bngu-actions"><BngButton accent="base" :disabled="!ready || isEquipped(0)" @click="$emit('command', 'equip', 0)">{{ isEquipped(0) ? 'Stock fitted ✓' : 'Fit stock · free' }}</BngButton><BngButton v-for="(tier, index) in ownedTiers" :key="tier.id" accent="base" :disabled="!ready || isEquipped(index + 1)" @click="$emit('command', 'equip', index + 1)">{{ isEquipped(index + 1) ? tier.name + ' fitted ✓' : 'Fit ' + tier.name + ' · free' }}</BngButton></div>
        <h2>Specialist builds</h2><div class="bngu-actions"><BngButton v-if="spec.driftConfig" accent="base" :disabled="!ready || car.mode === 'drift' || (!car.driftOwned && state.cash < spec.driftCost)" @click="$emit('command', 'driftBuild')">{{ car.mode === 'drift' ? 'Drift build fitted ✓' : car.driftOwned ? 'Fit drift build · free' : 'Buy & fit drift · ' + money(spec.driftCost) }}</BngButton><BngButton v-if="spec.dragConfig" accent="base" :disabled="!ready || car.mode === 'drag' || state.chapter < 2 || (!car.dragOwned && state.cash < spec.dragCost)" @click="$emit('command', 'dragBuild')">{{ car.mode === 'drag' ? 'Drag build fitted ✓' : car.dragOwned ? 'Fit drag build · free' : 'Buy & fit drag · ' + money(spec.dragCost) }}</BngButton></div><p v-if="spec.dragConfig && state.chapter < 2" class="bngu-muted">Drag conversions unlock in chapter two.</p><p v-if="!spec.driftConfig && !spec.dragConfig" class="bngu-muted">This model offers grip packages only.</p>
      </section>
      <BoardParts v-if="section === 'Parts'" ref="partsPage" :state="state" :spec="spec" :ready="ready" :build-name="buildName" @command="(action, arg) => $emit('command', action, arg)" />
      <BoardTuning v-if="section === 'Tuning'" ref="tuningPage" :state="state" :spec="spec" :car="car" :ready="ready" :build-name="buildName" @command="(action, arg) => $emit('command', action, arg)" />
      <BoardStyle v-if="section === 'Style'" ref="stylePage" :state="state" :spec="spec" :car="car" :ready="ready" @command="(action, arg) => $emit('command', action, arg)" />
      <BoardCovers v-if="section === 'Covers'" ref="coversPage" :state="state" @command="(action, arg) => $emit('command', action, arg)" @section="setSection" />
    </div>
  </section>
</template>
<script setup>
import { ref, computed, watch, nextTick } from "vue"
import { BngButton } from "@/common/components/base"
import { useScopedNav } from "@/services/scopedNav/api"
import { array, money, distance, carImage } from "../presentation.js"
import BoardTuning from "./BoardTuning.vue"
import BoardParts from "./BoardParts.vue"
import BoardCovers from "./BoardCovers.vue"
import BoardStyle from "./BoardStyle.vue"
const props = defineProps({ state: { type: Object, required: true }, beforeLeave: { type: Function, required: true } })
const emit = defineEmits(["command"])
const root = ref(null), detail = ref(null), partsPage = ref(null), coversPage = ref(null), tuningPage = ref(null), stylePage = ref(null), nav = useScopedNav(), section = ref("Cars")
const selectedId = ref(props.state.activeCar || props.state.starters[0])
let requestedCar = null, restoreActionFocus = null
const tabs = computed(() => ["Cars", "Build", ...(props.state.features.parts !== false ? ["Parts"] : []), ...(props.state.features.tuning !== false ? ["Tuning"] : []), "Style", ...(props.state.features.showcases ? ["Covers"] : [])])
const cars = computed(() => array(props.state.vehicleList))
const browseCars = computed(() => props.state.introduction ? cars.value.filter(car => array(props.state.starters).includes(car.id)) : cars.value)
const selectedCar = computed(() => browseCars.value.find(car => car.id === selectedId.value) || browseCars.value[0])
const spec = computed(() => cars.value.find(car => car.id === props.state.activeCar) || {})
const car = computed(() => props.state.garage?.[props.state.activeCar] || {})
const equippedTier = computed(() => car.value.equippedTier ?? car.value.tier ?? 0)
const ready = computed(() => !!(props.state.workshop?.ready && !props.state.busy))
const tiers = computed(() => array(props.state.upgradeTiers))
const ownedTiers = computed(() => tiers.value.slice(0, car.value.tier || 0))
const nextUpgrade = computed(() => tiers.value[car.value.tier || 0])
const nextStats = computed(() => spec.value.performance?.[nextUpgrade.value?.id])
const equippedStats = computed(() => (!car.value.mode || car.value.mode === "grip") ? spec.value.performance?.[equippedTier.value === 0 ? "stock" : tiers.value[equippedTier.value - 1]?.id] : null)
const buildName = computed(() => car.value.mode === "drift" ? "Drift build" : car.value.mode === "drag" ? "Drag build" : equippedTier.value === 0 ? "Stock setup" : tiers.value[equippedTier.value - 1]?.name)
function isEquipped(tier) { return (!car.value.mode || car.value.mode === "grip") && equippedTier.value === tier }
function highlightCar(entry, event) { selectedId.value = entry.id; event?.currentTarget?.scrollIntoView({ block: "nearest", inline: "nearest" }) }
function focusSelection() {
  if (section.value === "Parts" && partsPage.value?.focusSelection()) return
  if (section.value === "Covers" && coversPage.value?.focusSelection()) return
  if (section.value === "Style" && stylePage.value?.focusSelection()) return
  if (section.value === "Tuning") { tuningPage.value?.focusSelection(); return }
  let target
  if (props.state.introduction || section.value === "Cars") {
    target = Array.from(root.value?.querySelectorAll("[data-bngu-garage-car]") || []).find(el => el.getAttribute("data-bngu-garage-car") === selectedId.value)
  } else target = detail.value?.querySelector("[bng-nav-item]:not(:disabled)")
  if (!target) target = Array.from(root.value?.querySelectorAll("[data-bngu-garage-tab]") || []).find(el => el.getAttribute("data-bngu-garage-tab") === section.value)
  if (target) { target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target) }
}
async function openCar(entry) {
  selectedId.value = entry.id
  await nextTick()
  const target = detail.value?.querySelector("[bng-nav-item]:not(:disabled)")
  if (target) { target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target) }
}
async function setSection(value) {
  if (value === section.value) { focusSelection(); return }
  await props.beforeLeave(async () => { section.value = value; await nextTick(); focusSelection() })
}
function draftState() { return section.value === "Tuning" ? tuningPage.value?.draftState() : null }
function isDraftCurrent(value) { return !!tuningPage.value?.isDraftCurrent(value) }
function discardDraft(value) { return !!tuningPage.value?.discardDraft(value) }
function purchaseStarter(id) { requestedCar = { id, build: false }; emit("command", "buyStarter", id) }
function useCar(action, id) { requestedCar = { id, build: true }; emit("command", action, id) }
function back() { if (section.value === "Cars") return false; setSection("Cars"); return true }
watch(() => props.state.busy, (busy, previous) => {
  if (busy && !previous) restoreActionFocus = root.value?.contains(document.activeElement) ? document.activeElement : null
  if (!busy && previous) {
    if (requestedCar) {
      const request = requestedCar; requestedCar = null
      if (props.state.activeCar === request.id && props.state.garage?.[request.id]) { selectedId.value = request.id; restoreActionFocus = null; setSection(request.build ? "Build" : "Cars"); return }
    }
    const previousTarget = restoreActionFocus; restoreActionFocus = null
    nextTick(() => {
      if (!previousTarget || !root.value?.contains(previousTarget) || previousTarget.disabled) focusSelection()
      else nav.requestScopeFocus("bngu-board", previousTarget)
    })
  }
})
defineExpose({ back, focusSelection, draftState, isDraftCurrent, discardDraft })
</script>
