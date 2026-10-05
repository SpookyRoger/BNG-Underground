<template>
  <section ref="root" class="bngu-tuning">
    <small>ACTIVE CAR · {{ spec.name }} / {{ buildName }}</small><h2>Tune your build.</h2>
    <p>Tuning is free at the workshop. Your fitted hardware determines what you can adjust. Each car and each build keeps its own setup.</p>
    <div class="bngu-actions"><BngButton accent="base" :disabled="!ready || !dirty" @click="apply">Apply setup · free</BngButton><BngButton accent="base" :disabled="state.busy || !dirty" @click="loadSaved">Discard changes</BngButton><BngButton accent="base" :disabled="!ready || !saved" @click="$emit('command', 'resetTune', buildKey)">Restore hardware setup · free</BngButton></div>
    <p class="bngu-muted" role="status">{{ dirty ? changedControls.length + ' unsaved ' + (changedControls.length === 1 ? 'adjustment' : 'adjustments') + ' · Apply fits every changed group together.' : saved ? 'Your saved setup is fitted. Repair, events and Continue retain it.' : 'The native setup for this hardware is fitted.' }}</p>
    <BngButton v-if="controls.length" accent="base" :disabled="!dirty" :class="{ selected: group === 'Changes' }" :aria-pressed="group === 'Changes'" @click="setGroup('Changes')">Review changes · {{ changedControls.length }}</BngButton>
    <div v-if="controls.length" class="bngu-actions bngu-tuning-groups"><BngButton v-for="entry in ['All', ...groups]" :key="entry" accent="base" :data-bngu-tuning-group="entry" :class="{ selected: group === entry }" :aria-pressed="group === entry" @click="setGroup(entry)">{{ entry }}</BngButton></div>
    <p v-if="group === 'Alignment'" class="bngu-muted">Alignment uses BeamNG's adjustment percentage, not measured wheel angles. Zero is the middle of the adjustment range, not necessarily a straight wheel. Hardware value restores the fitted setup.</p>
    <p v-if="group === 'Final drive'" class="bngu-muted">Final drive changes every gear together. Higher ratios give more revs at the same wheel speed; lower ratios give fewer. Linked front and rear ratios use one setting so they remain matched.</p>
    <article v-if="group === 'Gearing' && spacing.length" class="bngu-card"><h3>Shift spacing</h3><p>Larger ratios shorten a gear; smaller ratios lengthen it. At the same wheel speed, this is the share of engine revs retained by each next gear. It is a ratio comparison, not a speed prediction.</p><ul class="bngu-unlock-list"><li v-for="entry in spacing" :key="entry.from">{{ entry.from }} → {{ entry.to }} · {{ entry.percent.toFixed(1) }}% of revs<span v-if="entry.rising"> · equal or shorter next gear</span></li></ul><p v-if="spacing.some(entry => entry.rising)" class="bngu-muted">A next gear is equal or shorter. Most road setups use progressively taller forward gears. You can adjust the ratios or return each to its Hardware value.</p></article>
    <div v-if="controls.length" class="bngu-tuning-grid">
      <article v-for="control in visibleControls" :key="control.id" class="bngu-card bngu-tuning-card" :class="{ 'bngu-tuning-changed': changed(control) }" :data-bngu-tuning-control="control.id"><small>{{ control.group }}{{ changed(control) ? ' · UNSAVED' : '' }}</small><h3>{{ control.label }}</h3><p>{{ control.description }}</p>
        <div class="bngu-tuning-adjust"><BngButton accent="base" :disabled="state.busy || atLimit(control, -1)" :aria-label="'Decrease ' + control.label" @click="adjust(control, -1)">−</BngButton><strong>{{ display(control, draft[control.id]) }}<small>{{ control.unit }}</small></strong><BngButton accent="base" :disabled="state.busy || atLimit(control, 1)" :aria-label="'Increase ' + control.label" @click="adjust(control, 1)">+</BngButton></div>
        <p class="bngu-muted">Hardware {{ display(control, control.baseline) }} {{ control.unit }} · Range {{ display(control, control.display?.rawMin ?? control.min) }}–{{ display(control, control.display?.rawMax ?? control.max) }}</p>
        <p v-if="changed(control)" class="bngu-muted">Saved {{ display(control, savedValue(control)) }} {{ control.unit }} → Draft {{ display(control, draft[control.id]) }} {{ control.unit }}</p>
        <p v-if="control.group === 'Gearing' && spacingByGear[control.gear]" class="bngu-muted">Shift to {{ spacingByGear[control.gear].to }} · {{ spacingByGear[control.gear].percent.toFixed(1) }}% of revs at the same wheel speed{{ spacingByGear[control.gear].rising ? ' · next gear is equal or shorter' : '' }}.</p>
        <BngButton accent="base" :disabled="state.busy || close(draft[control.id], control.baseline)" @click="draft[control.id] = control.baseline">Hardware value</BngButton>
      </article>
    </div>
    <p v-else>This setup has no adjustable parts in the workshop catalog.</p>
    <p v-if="group === 'Changes' && !dirty" class="bngu-muted">No unsaved adjustments. Choose All or a hardware group to continue tuning.</p>
    <div v-if="controls.length" class="bngu-actions"><BngButton accent="base" :disabled="!ready || !dirty" @click="apply">Apply setup · free</BngButton><BngButton accent="base" :disabled="state.busy || !dirty" @click="loadSaved">Discard changes</BngButton></div>
    <p class="bngu-muted">Fitted hardware determines these controls. Race ECUs can add limiter settings; supported turbos add boost adjustment; adjustable gearboxes and final drives add ratio controls. Fixed native settings stay fixed. PS means metric horsepower. Power and weight on Build describe the base preset and are not recalculated for modifications.</p>
  </section>
</template>
<script setup>
import { ref, computed, watch, nextTick } from "vue"
import { BngButton } from "@/common/components/base"
import { useScopedNav } from "@/services/scopedNav/api"
import { array, controlText as display } from "../presentation.js"
import { gearSpacing } from "../gearing.js"
const props = defineProps({ state: { type: Object, required: true }, spec: { type: Object, required: true }, car: { type: Object, required: true }, ready: Boolean, buildName: String })
const emit = defineEmits(["command"])
const draft = ref({})
const root = ref(null), group = ref("All"), nav = useScopedNav()
const buildKey = computed(() => props.state.tuning?.key)
const controls = computed(() => array(props.state.tuning?.controls))
const groups = computed(() => [...new Set(controls.value.map(control => control.group))])
const visibleControls = computed(() => group.value === "All" ? controls.value : group.value === "Changes" ? changedControls.value : controls.value.filter(control => control.group === group.value))
const spacing = computed(() => gearSpacing(controls.value, draft.value))
const spacingByGear = computed(() => Object.fromEntries(spacing.value.map(entry => [entry.from, entry])))
async function setGroup(value) {
  group.value = value; await nextTick()
  const target = root.value?.querySelector(".bngu-tuning-grid [bng-nav-item]:not(:disabled)")
  if (target) { target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target) }
}
watch(() => groups.value.join("|"), () => { if (group.value !== "Changes" && !groups.value.includes(group.value)) group.value = "All" })
const overrides = computed(() => props.car.tuning?.[buildKey.value] || {})
const saved = computed(() => Object.keys(overrides.value).length > 0)
const signature = computed(() => props.spec.id + "/" + props.state.tuning?.signature + "/" + JSON.stringify(Object.entries(overrides.value).sort(([a], [b]) => a.localeCompare(b))))
function close(a, b) { return Math.abs(a - b) <= 0.0000001 }
function loadSaved() { draft.value = Object.fromEntries(controls.value.map(control => [control.id, overrides.value[control.id] ?? control.baseline])) }
function savedValue(control) { return overrides.value[control.id] ?? control.baseline }
function changed(control) { return !close(draft.value[control.id], savedValue(control)) }
const changedControls = computed(() => controls.value.filter(changed))
const dirty = computed(() => changedControls.value.length > 0)
function rawDirection(control, direction) { return direction * (control.display && control.display.rawMax < control.display.rawMin ? -1 : 1) }
function atLimit(control, direction) {
  const value = draft.value[control.id] ?? control.baseline
  return rawDirection(control, direction) < 0 ? value <= control.min : value >= control.max
}
function adjust(control, direction) {
  const next = (draft.value[control.id] ?? control.baseline) + rawDirection(control, direction) * control.step
  draft.value[control.id] = Number(Math.min(control.max, Math.max(control.min, next)).toFixed(8))
}
function apply() { emit("command", "tune", { build: buildKey.value, hardware: props.state.tuning.signature, values: { ...draft.value } }) }
function draftState() {
  return { dirty: dirty.value, changedCount: changedControls.value.length, carName: props.spec.name, buildName: props.buildName,
    ready: props.ready && !props.state.busy, signature: signature.value,
    request: { build: buildKey.value, hardware: props.state.tuning?.signature, values: { ...draft.value } } }
}
function isDraftCurrent(value) { return value.signature === signature.value }
function discardDraft(value) { if (!isDraftCurrent(value)) return false; loadSaved(); return true }
async function focusSelection() {
  if (dirty.value && !visibleControls.value.some(changed)) group.value = "Changes"
  await nextTick()
  const cards = Array.from(root.value?.querySelectorAll("[data-bngu-tuning-control]") || [])
  const card = cards.find(element => changedControls.value.some(control => control.id === element.getAttribute("data-bngu-tuning-control"))) || cards[0]
  const target = card?.querySelector("[bng-nav-item]:not(:disabled)") || root.value?.querySelector('[data-bngu-tuning-group="All"]') || root.value?.querySelector("[bng-nav-item]:not(:disabled)")
  if (target) { target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target); return true }
  return false
}
watch(() => visibleControls.value.map(control => control.id).join("|"), () => {
  if (group.value === "Changes") nextTick(() => { if (!root.value?.contains(document.activeElement)) focusSelection() })
})
watch(signature, loadSaved, { immediate: true })
defineExpose({ draftState, isDraftCurrent, discardDraft, focusSelection })
</script>
