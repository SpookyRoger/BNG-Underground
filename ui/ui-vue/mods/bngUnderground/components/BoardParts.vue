<template>
  <section ref="root" class="bngu-parts-page">
    <small>ACTIVE CAR · {{ spec.name }} / {{ buildName }}</small><h2>Build it your way.</h2>
    <p>Choose engine kits, brakes, suspension, differentials or wheels and tyres. Owned hardware can be refitted for free. Each grip build keeps its own selection.</p>
    <p v-if="!state.parts?.grip">Specialist drift and drag builds keep their matched hardware. Fit a stock, Street, Club or Pro grip build in Build to choose individual parts.</p>
    <template v-else>
      <div class="bngu-actions bngu-parts-categories"><BngButton v-for="entry in categories" :key="entry.id" accent="base" :class="{ selected: category === entry.id }" :aria-pressed="category === entry.id" @click="setCategory(entry.id)">{{ entry.name }}</BngButton></div>
      <div class="bngu-parts-columns">
        <div class="bngu-parts-list" bng-nav-scroll aria-label="Browse parts">
          <BngButton v-for="entry in choices" :key="entry.id" accent="base" class="bngu-parts-row" :class="{ selected: selectedId === entry.id }" :data-bngu-part="entry.id" @focusin="highlight(entry, $event)" @mouseenter="selectedId = entry.id" @click="openChoice(entry)"><strong>{{ entry.name }}</strong><small>{{ entry.fitted ? 'FITTED ✓' : entry.owned ? 'OWNED · FREE REFIT' : money(entry.cost) }}{{ !entry.compatible ? ' · OTHER BUILD' : !entry.unlocked ? ' · CHAPTER ' + entry.chapter : '' }}</small></BngButton>
        </div>
        <div ref="detail" class="bngu-parts-detail" bng-nav-scroll>
          <article v-if="selected" class="bngu-card">
            <small>{{ buildName }} · {{ categoryInfo?.name }}</small><h2>{{ selected.name }}</h2><p>{{ selected.description }}</p>
            <p class="bngu-parts-current"><small>CURRENTLY FITTED</small><strong>{{ categoryInfo?.current?.name || 'Base build hardware' }}</strong></p>
            <p v-if="selected.engineName" class="bngu-muted">For {{ $ctx_t(selected.engineName) }} · keeps the engine block and drivetrain.</p>
            <ul v-if="selected.partNames?.length" class="bngu-unlock-list"><li v-for="(name, index) in selected.partNames" :key="index">{{ $ctx_t(name) }}</li></ul>
            <p v-if="selected.controls?.length" class="bngu-muted">Adjustable after fitting: {{ selected.controls.join(' · ') }}</p>
            <section v-if="comparison" class="bngu-parts-comparison">
              <p>Native adjustments · {{ comparison.currentCount }} currently available → {{ comparison.proposedCount }} with this set</p>
              <p v-if="comparison.added.length" class="bngu-muted">Adds: {{ comparison.added.map(row => row.after.label).join(' · ') }}</p>
              <p v-if="comparison.removed.length" class="bngu-muted">Removes: {{ comparison.removed.map(row => row.before.label).join(' · ') }}</p>
              <p v-if="resetControls.length" class="bngu-parts-reset" role="status">Fitting resets {{ resetControls.length }} saved {{ resetControls.length === 1 ? 'adjustment' : 'adjustments' }}: {{ resetControls.map(control => control.label).join(' · ') }}. Other groups keep their saved values.</p>
              <BngButton accent="base" :aria-expanded="compareOpen" @click="compareOpen = !compareOpen">{{ compareOpen ? 'Hide adjustment comparison' : 'Compare adjustments' }}</BngButton>
              <div v-if="compareOpen" class="bngu-parts-comparison-body">
                <p v-if="!comparison.rows.length" class="bngu-muted">Both sets keep fixed native settings in this category.</p>
                <table v-else class="bngu-parts-compare-table"><caption>Hardware values and adjustment ranges</caption><thead><tr><th scope="col">Adjustment</th><th scope="col">Current hardware</th><th scope="col">Selected hardware</th></tr></thead><tbody><tr v-for="row in comparison.rows" :key="row.id"><th scope="row">{{ (row.after || row.before).label }}<small>{{ row.kind === 'added' ? 'ADDED' : row.kind === 'removed' ? 'REMOVED' : row.kind === 'changed' ? 'RANGE / SETUP CHANGES' : 'AVAILABLE' }}</small></th><td><template v-if="row.before"><strong>{{ controlText(row.before) }} {{ row.before.unit }}</strong><small>Range {{ controlRange(row.before) }} {{ row.before.unit }}</small><small v-if="row.before.savedValue !== undefined">Saved {{ controlText(row.before, row.before.savedValue) }} {{ row.before.unit }}{{ resetControls.some(control => control.id === row.id) ? ' · resets on fitting' : '' }}</small></template><span v-else>Unavailable</span></td><td><template v-if="row.after"><strong>{{ controlText(row.after) }} {{ row.after.unit }}</strong><small>Range {{ controlRange(row.after) }} {{ row.after.unit }}</small></template><span v-else>Unavailable</span></td></tr></tbody></table>
                <p v-if="comparison.rows.some(row => (row.after || row.before).display)" class="bngu-muted">Alignment percentages follow the native adjustment scale, not measured wheel angles. Hardware values are the fitted part's setup.</p>
              </div>
            </section>
            <p v-if="!selected.compatible">This set requires a different engine or mounting hardware. Preview it on another compatible grip build.</p>
            <p v-else-if="selected.fitted">This hardware is already fitted.</p>
            <p v-else-if="!selected.unlocked">Reach chapter {{ selected.chapter }} to buy this set.</p>
            <p v-else-if="!selected.owned && state.cash < selected.cost">You need {{ money(selected.cost - state.cash) }} more.</p>
            <p v-if="!selected.owned" class="bngu-prize">{{ money(selected.cost) }}</p>
            <BngButton accent="base" data-bngu-fit-part :disabled="!ready || selected.fitted || !selected.compatible || !selected.unlocked || (!selected.owned && state.cash < selected.cost)" @click="fit">{{ selected.id === 'base' ? 'Restore base hardware · free' : selected.owned ? 'Fit owned parts · free' : 'Buy & fit · ' + money(selected.cost) }}</BngButton>
            <p class="bngu-muted">Fitting restores {{ array(categoryInfo?.resetGroups).join(' and ') || 'this category' }} tuning. Other groups keep their settings. Hardware already included in an owned package is available without another charge. Full package prices do not refund separate earlier purchases.</p>
          </article>
        </div>
      </div>
    </template>
  </section>
</template>
<script setup>
import { computed, ref, watch, nextTick } from "vue"
import { BngButton } from "@/common/components/base"
import { useScopedNav } from "@/services/scopedNav/api"
import { array, money, controlText, controlRange } from "../presentation.js"
import { compareAdjustments } from "../partsComparison.js"
const props = defineProps({ state: { type: Object, required: true }, spec: { type: Object, required: true }, ready: Boolean, buildName: String })
const emit = defineEmits(["command"])
const root = ref(null), detail = ref(null), nav = useScopedNav()
const compareOpen = ref(false)
const category = ref(array(props.state.parts?.categories)[0]?.id || ""), selectedId = ref("base")
const categories = computed(() => array(props.state.parts?.categories))
const categoryInfo = computed(() => categories.value.find(entry => entry.id === category.value))
const choices = computed(() => [
  { id: "base", name: "Base build hardware", description: (categoryInfo.value?.description || "") + " Restore the parts from your current base package.", adjustments: array(categoryInfo.value?.baseControls), owned: true, compatible: true, unlocked: true, fitted: !props.state.parts?.selected?.[category.value] },
  ...array(props.state.parts?.options).filter(entry => entry.category === category.value),
])
const selected = computed(() => choices.value.find(entry => entry.id === selectedId.value) || choices.value[0])
const comparison = computed(() => selected.value?.compatible ? compareAdjustments(array(categoryInfo.value?.current?.controls), array(selected.value.adjustments)) : null)
const resetControls = computed(() => selected.value?.compatible && !selected.value.fitted ? array(categoryInfo.value?.current?.controls).filter(control => array(categoryInfo.value?.resetIds).includes(control.id)) : [])
function highlight(entry, event) { selectedId.value = entry.id; event?.currentTarget?.scrollIntoView({ block: "nearest", inline: "nearest" }) }
function focusSelection() {
  const target = Array.from(root.value?.querySelectorAll("[data-bngu-part]") || []).find(el => el.getAttribute("data-bngu-part") === selectedId.value)
  if (target) { target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target); return true }
  return false
}
async function setCategory(id) { category.value = id; selectedId.value = "base"; compareOpen.value = false; await nextTick(); focusSelection() }
async function openChoice(entry) {
  selectedId.value = entry.id; await nextTick()
  const target = detail.value?.querySelector("[data-bngu-fit-part]:not(:disabled)") || detail.value?.querySelector("[bng-nav-item]:not(:disabled)")
  if (target) { target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target) }
}
function fit() {
  if (!props.ready || props.state.busy) return
  emit("command", selected.value.owned ? "fitPart" : "buyPart", { car: props.state.parts.car, build: props.state.parts.key, hardware: props.state.parts.signature, category: category.value, part: selected.value.id })
}
watch(() => props.state.parts?.key, () => { selectedId.value = "base" })
watch(() => categories.value.map(entry => entry.id).join("|"), () => {
  if (!categories.value.some(entry => entry.id === category.value)) { category.value = categories.value[0]?.id || ""; selectedId.value = "base" }
})
defineExpose({ focusSelection })
</script>
