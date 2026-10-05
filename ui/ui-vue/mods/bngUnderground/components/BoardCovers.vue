<template>
  <section ref="root" class="bngu-covers-page">
    <small>LUMEN MAGAZINE</small><h2>Put your build in the spotlight.</h2>
    <p>Bring your styled car to a feature location and stop for a one-time payment. Each earned feature remembers the car you brought. Covers are optional; races stay open.</p>
    <div v-if="covers.length" class="bngu-covers-columns">
      <div class="bngu-covers-list" bng-nav-scroll aria-label="Browse cover shoots">
        <BngButton v-for="entry in covers" :key="entry.id" accent="base" class="bngu-cover-row" :class="{ selected: selectedId === entry.id }" :data-bngu-cover="entry.id" @focusin="highlight(entry, $event)" @mouseenter="selectedId = entry.id" @click="openCover(entry)"><strong>{{ entry.name }}</strong><small>{{ entry.claimed ? 'FEATURED ✓' : !entry.chapterOpen ? 'CHAPTER ' + entry.chapter : entry.ready ? 'READY TO FEATURE' : 'STYLE ' + entry.styleRequired }} · {{ money(entry.reward) }}</small></BngButton>
      </div>
      <div ref="detail" class="bngu-covers-detail" bng-nav-scroll>
        <article v-if="selected" class="bngu-card">
          <small>CH {{ selected.chapter }} · STYLE {{ selected.styleRequired }}</small><h2>{{ selected.name }}</h2><p>{{ selected.description }}</p>
          <strong class="bngu-prize">{{ money(selected.reward) }} {{ selected.claimed ? 'earned' : 'feature payment' }}</strong>
          <p v-if="selected.reason" class="bngu-muted" role="status">{{ selected.reason }}</p>
          <div class="bngu-actions"><BngButton accent="base" :disabled="state.busy || !selected.chapterOpen" @click="$emit('command', 'navigateLocation', selected.id)">{{ selected.claimed ? 'Revisit feature location' : 'GPS to feature location' }}{{ selected.distance != null ? ' · ' + distance(selected.distance) : '' }}</BngButton><BngButton v-if="!selected.claimed" accent="base" :disabled="state.busy || !selected.ready" @click="$emit('command', 'showcase', selected.id)">Claim feature · {{ money(selected.reward) }}</BngButton></div>
          <template v-if="selected.claimed">
            <h3>Your featured build</h3>
            <template v-if="selected.record"><p><strong>{{ featuredCar?.name || selected.record.car }}</strong> · {{ featuredBuild }} · Style {{ selected.record.style }}</p><p>{{ featuredFinish }} · {{ selected.record.kit ? 'Style kit fitted' : 'Base build body style' }}</p><p v-if="featuredPieces">{{ featuredPieces }} personal bodywork {{ featuredPieces === 1 ? 'piece' : 'pieces' }} recorded.</p></template>
            <p v-else class="bngu-muted">Car details are unavailable for this earlier feature.</p>
            <p class="bngu-muted">Your featured car and style stay on record when you change cars or refit parts. Each location pays once.</p>
          </template>
          <template v-else>
            <h3>Your current style · {{ state.style }} / {{ selected.styleRequired }}</h3>
            <ul class="bngu-unlock-list"><li v-for="entry in array(state.styleBreakdown)" :key="entry.id"><strong>+{{ entry.points }} · {{ entry.active ? 'FITTED ✓' : 'AVAILABLE' }} · {{ entry.name }}</strong><p>{{ entry.description }}</p></li></ul>
            <div class="bngu-actions"><BngButton accent="base" @click="$emit('section', 'Style')">Paint & style</BngButton><BngButton accent="base" @click="$emit('section', 'Build')">Browse grip builds</BngButton></div>
            <p class="bngu-muted">Style comes from fitted choices on your active car. Owning a kit or package without fitting it adds no points. Modifications need a stopped visit to a physical workshop; the feature itself is claimed here.</p>
          </template>
        </article>
      </div>
    </div>
    <p v-else>No cover shoots are configured.</p>
  </section>
</template>
<script setup>
import { computed, ref, watch, nextTick } from "vue"
import { BngButton } from "@/common/components/base"
import { useScopedNav } from "@/services/scopedNav/api"
import { array, money, distance } from "../presentation.js"
const props = defineProps({ state: { type: Object, required: true } })
defineEmits(["command", "section"])
const root = ref(null), detail = ref(null), nav = useScopedNav(), selectedId = ref(null)
const covers = computed(() => array(props.state.covers))
const selected = computed(() => covers.value.find(entry => entry.id === selectedId.value) || covers.value[0])
const featuredCar = computed(() => array(props.state.vehicleList).find(car => car.id === selected.value?.record?.car))
const featuredPieces = computed(() => Object.values(selected.value?.record?.bodywork || {}).reduce((count, choices) => count + Object.keys(choices).length, 0))
const featuredBuild = computed(() => {
  const record = selected.value?.record
  if (!record) return ""
  return record.mode === "drift" ? "Drift build" : record.mode === "drag" ? "Drag build" : record.tier === 0 ? "Stock setup" : array(props.state.upgradeTiers)[record.tier - 1]?.name || "Grip build"
})
const featuredFinish = computed(() => {
  const record = selected.value?.record
  if (!record?.paint) return "Base build finish"
  const colour = array(props.state.paints).find(paint => paint.id === record.paint)?.name || "Campaign colour"
  const finish = array(props.state.paintShop?.finishes).find(entry => entry.id === (record.paintFinish || props.state.paintShop?.defaultFinish))?.name || "Campaign finish"
  return colour + " · " + finish
})
function highlight(entry, event) { selectedId.value = entry.id; event?.currentTarget?.scrollIntoView({ block: "nearest", inline: "nearest" }) }
function focusSelection() {
  const target = Array.from(root.value?.querySelectorAll("[data-bngu-cover]") || []).find(el => el.getAttribute("data-bngu-cover") === selected.value?.id)
  if (target) { target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target); return true }
  return false
}
async function openCover(entry) {
  selectedId.value = entry.id; await nextTick()
  const target = detail.value?.querySelector("[bng-nav-item]:not(:disabled)")
  if (target) { target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target) }
}
watch(() => covers.value.map(entry => entry.id).join("|"), () => {
  if (!covers.value.some(entry => entry.id === selectedId.value)) selectedId.value = covers.value.find(entry => !entry.claimed && entry.chapterOpen)?.id || covers.value[0]?.id
}, { immediate: true })
defineExpose({ focusSelection })
</script>
