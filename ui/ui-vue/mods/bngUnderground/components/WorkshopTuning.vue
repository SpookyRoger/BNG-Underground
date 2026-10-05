<template>
  <section ref="root" class="workshop-tuning" aria-label="Preview and save your fitted car setup">
    <header><small>FITTED HARDWARE · FREE TUNING</small><h2>Tune it here.</h2><p>Up/down selects an adjustment. Left/right changes its value. Your car previews the whole setup.</p></header>
    <nav class="tune-groups" aria-label="Tuning groups"><BngButton v-for="entry in groups" :key="entry" accent="base" :class="{ selected: group === entry }" :aria-pressed="group === entry" :disabled="locked" @click="setGroup(entry)">{{ entry }}</BngButton></nav>
    <div class="tune-list" bng-nav-scroll>
      <BngButton v-for="control in visibleControls" :key="control.id" accent="base" class="tune-row" :data-workshop-adjustment="control.id" :class="{ changed: changed(control), selected: selectedId === control.id }" :disabled="locked"
        v-bng-on-ui-nav-focus:horizontal.repeat="navigationFor(control)" @focusin="select(control, $event)" @mouseenter="select(control)" @click="review">
        <span><strong>{{ control.label }}</strong><small>{{ display(control, draft[control.id]) }} {{ control.unit }}{{ changed(control) ? ' · UNSAVED' : '' }}</small></span>
        <i class="tune-range"><b :style="{ width: percentage(control) + '%' }"></b></i>
      </BngButton>
      <p v-if="!visibleControls.length">{{ group === 'Changes' ? 'No unsaved adjustments.' : 'No adjustments in this group.' }}</p>
    </div>
    <div class="tune-detail" bng-nav-scroll>
      <template v-if="selected"><strong>{{ selected.label }}</strong><p>{{ selected.description }}</p><p class="value-guide">Saved {{ display(selected, savedValue(selected)) }} · Hardware {{ display(selected, selected.baseline) }} {{ selected.unit }}<br>Range {{ controlRange(selected) }} {{ selected.unit }}</p>
        <div class="tune-step"><BngButton accent="base" :disabled="locked || atLimit(selected, -1)" :aria-label="'Decrease ' + selected.label" @click="adjust(selected, -1)">−</BngButton><BngButton accent="base" :disabled="locked || closeValue(draft[selected.id], selected.baseline)" @click="hardwareValue">Hardware value</BngButton><BngButton accent="base" :disabled="locked || atLimit(selected, 1)" :aria-label="'Increase ' + selected.label" @click="adjust(selected, 1)">+</BngButton></div>
      </template>
      <p v-if="group === 'Alignment'" class="value-guide">Alignment is native adjustment percentage, not measured wheel angles.</p>
      <p v-if="group === 'Final drive'" class="value-guide">Higher ratios give more revs at the same wheel speed. Linked front/rear settings remain matched.</p>
      <p v-if="shift" class="value-guide">{{ shift.from }} → {{ shift.to }} retains {{ shift.percent.toFixed(1) }}% of revs at the same wheel speed{{ shift.rising ? ' · next gear is equal or shorter' : '' }}.</p>
      <BngButton accent="base" data-workshop-save-setup :disabled="!canSave" @click="save">{{ saveLabel }}</BngButton>
      <div class="tune-secondary"><BngButton accent="base" :disabled="locked || !dirty" @click="discard">Discard preview</BngButton><BngButton accent="base" :disabled="locked || !controls.length" @click="hardwareSetup">Preview hardware setup</BngButton></div>
      <p class="value-guide" role="status">{{ dirty ? changedControls.length + ' unsaved adjustments · Save fits all groups together.' : 'Your saved setup is selected.' }} Hardware changes rebuild the paused car; dynamic suspension settling happens when driving resumes.</p>
      <BngButton accent="base" :disabled="locked" @click="$emit('parts')">Browse parts</BngButton>
    </div>
  </section>
</template>
<script setup>
import { ref, computed, watch, nextTick, onUnmounted } from "vue"
import { BngButton } from "@/common/components/base"
import { vBngOnUiNavFocus } from "@/common/directives"
import { useScopedNav } from "@/services/scopedNav/api"
import { array, controlText as display, controlDisplayValue, controlRange } from "../presentation.js"
import { canonical, wrapIndex } from "../workshopControls.js"
import { savedValues, closeValue, adjustValue } from "../tuningDraft.js"
import { gearSpacing } from "../gearing.js"
const props = defineProps({ state: { type: Object, required: true }, spec: Object, locked: Boolean, sending: Boolean, savePreview: { type: Function, required: true } })
const emit = defineEmits(["preview", "parts"]), nav = useScopedNav()
const root = ref(null), draft = ref({}), group = ref("All"), selectedId = ref("")
const navigationHandlers = new Map()
let disposed = false, wantsSaveFocus = false
const tuning = computed(() => props.state.tuning || {}), controls = computed(() => array(tuning.value.controls))
const car = computed(() => props.state.garage?.[props.state.activeCar] || {})
const shop = computed(() => props.state.liveWorkshop || {})
const overrides = computed(() => car.value.tuning?.[tuning.value.key] || {})
const identity = computed(() => props.state.activeCar + "/" + tuning.value.signature + "/" + tuning.value.savedSignature)
const groups = computed(() => ["All", "Changes", ...new Set(controls.value.map(control => control.group))])
const savedValue = control => overrides.value[control.id] ?? control.baseline
const changed = control => !closeValue(draft.value[control.id], savedValue(control))
const changedControls = computed(() => controls.value.filter(changed)), dirty = computed(() => changedControls.value.length > 0)
const visibleControls = computed(() => group.value === "All" ? controls.value : group.value === "Changes" ? changedControls.value : controls.value.filter(control => control.group === group.value))
const selected = computed(() => controls.value.find(control => control.id === selectedId.value))
const shift = computed(() => gearSpacing(controls.value, draft.value).find(row => row.from === selected.value?.gear))
const request = computed(() => tuning.value.savedSignature ? { kind: "tuning", car: props.state.activeCar, argument: { car: tuning.value.car, build: tuning.value.key, hardware: tuning.value.signature, saved: tuning.value.savedSignature, values: { ...draft.value } } } : null)
const quoteMatches = computed(() => !!request.value && canonical(request.value) === canonical(shop.value.quote?.request))
const canSave = computed(() => dirty.value && !props.locked && !props.sending && shop.value.ready && quoteMatches.value && shop.value.quote?.canBuy)
const saveLabel = computed(() => props.locked ? "Please wait…" : !dirty.value ? "Saved setup selected" : !canSave.value ? "Preparing this setup…" : "Save & fit setup · free")
function percentage(control) {
  const low = controlDisplayValue(control, control.display?.rawMin ?? control.min), high = controlDisplayValue(control, control.display?.rawMax ?? control.max)
  return Math.max(0, Math.min(100, (controlDisplayValue(control, draft.value[control.id]) - low) / (high - low) * 100))
}
function select(control, event) { selectedId.value = control.id; event?.currentTarget?.scrollIntoView({ block: "nearest" }) }
function adjust(control, direction) { if (!props.locked) { wantsSaveFocus = false; selectedId.value = control.id; draft.value[control.id] = adjustValue(control, draft.value[control.id], direction) } }
function navigationFor(control) {
  if (!navigationHandlers.has(control.id)) navigationHandlers.set(control.id, direction => {
    const fitted = controls.value.find(entry => entry.id === control.id)
    if (fitted) adjust(fitted, direction)
  })
  return navigationHandlers.get(control.id)
}
function atLimit(control, direction) { return closeValue(adjustValue(control, draft.value[control.id], direction), draft.value[control.id]) }
function hardwareValue() { if (!props.locked && selected.value) draft.value[selected.value.id] = selected.value.baseline }
function hardwareSetup() { if (!props.locked) { wantsSaveFocus = false; draft.value = savedValues(controls.value) } }
function discard() { wantsSaveFocus = false; draft.value = savedValues(controls.value, overrides.value) }
async function focusSelection() {
  await nextTick()
  const rows = Array.from(root.value?.querySelectorAll("[data-workshop-adjustment]:not(:disabled)") || [])
  const target = rows.find(row => row.getAttribute("data-workshop-adjustment") === selectedId.value) || rows[0] || root.value?.querySelector("[bng-nav-item]:not(:disabled)")
  if (target) { target.scrollIntoView({ block: "nearest" }); nav.requestScopeFocus("bngu-workshop", target); return true }
  return false
}
async function setGroup(value) { if (props.locked) return; wantsSaveFocus = false; group.value = value; await focusSelection() }
function stepGroup(direction) { const values = groups.value;setGroup(values[wrapIndex(values.indexOf(group.value), direction, values.length)]);return false }
async function focusSave() {
  if (!wantsSaveFocus || !canSave.value) return
  await nextTick();const target = root.value?.querySelector("[data-workshop-save-setup]:not(:disabled)")
  if (target) { nav.requestScopeFocus("bngu-workshop", target);wantsSaveFocus = false }
}
function review() { wantsSaveFocus = true;focusSave() }
async function save() { if (canSave.value) { wantsSaveFocus = false;await props.savePreview(request.value) } }
function draftState() { return { dirty: dirty.value, ready: canSave.value, changedCount: changedControls.value.length, carName: props.spec?.name, signature: identity.value + canonical(draft.value), request: request.value } }
function isDraftCurrent(value) { return value.signature === identity.value + canonical(draft.value) }
function discardDraft(value) { if (!isDraftCurrent(value)) return false;discard();return true }
function refreshPreview() { if (!disposed && request.value) emit("preview", request.value) }
watch(identity, discard, { immediate: true })
watch(() => canonical(request.value), refreshPreview, { immediate: true })
watch(() => visibleControls.value.map(control => control.id).join("|"), () => {
  const focusedRow = document.activeElement?.closest?.("[data-workshop-adjustment]")
  const lostSelection = root.value?.contains(focusedRow) && !visibleControls.value.some(control => control.id === focusedRow.getAttribute("data-workshop-adjustment"))
  if (!visibleControls.value.some(control => control.id === selectedId.value)) selectedId.value = visibleControls.value[0]?.id || ""
  if (lostSelection) nextTick(() => { if (!disposed && !props.locked) focusSelection() })
}, { immediate: true })
watch(canSave, focusSave)
watch(() => props.locked, locked => { if (locked) wantsSaveFocus = false })
onUnmounted(() => { disposed = true;wantsSaveFocus = false;navigationHandlers.clear() })
defineExpose({ focusSelection, stepGroup, draftState, isDraftCurrent, discardDraft, refreshPreview })
</script>
<style scoped>
.workshop-tuning { color: #faf3ff; }header { padding: 1rem 1.1rem .4rem; }h2 { margin: .25rem 0; font-size: 1.35rem; }p { line-height: 1.4; font-size: .8rem; }small,.value-guide { color: #cbbcd8; font-size: .7rem; }header small { color: #8de6d9; letter-spacing: .08em; }
.tune-groups { display: flex; gap: .25rem; overflow-x: auto; padding: .2rem .7rem .6rem; flex-shrink: 0; }.tune-groups > * { flex-shrink: 0; }.selected { box-shadow: inset 0 -3px #83e8d8; }
.tune-list { overflow: auto; min-height: 6rem; flex: 1 1 35%; padding: .3rem .7rem; display: flex; flex-direction: column; gap: .35rem; }.tune-row { display: flex; flex-direction: column; align-items: stretch; text-align: left; flex-shrink: 0; padding: .65rem .75rem; }.tune-row span { display: flex; flex-direction: column; gap: .3rem; }.tune-row.changed small { color: #8de6d9; }.tune-range { display: block; height: .2rem; background: #eee2; margin-top: .45rem; }.tune-range b { display: block; height: 100%; background: #83e8d8; }
.tune-detail { padding: .7rem 1rem 1rem; border-top: 1px solid #8e71ab55; overflow: auto; flex: 0 1 auto; max-height: 53%; }.tune-step,.tune-secondary { display: flex; gap: .25rem; flex-wrap: wrap; }.tune-step { justify-content: space-between; }.tune-detail > :deep(.bng-button) { width: 100%; }.tune-secondary { margin-top: .3rem; }.value-guide { margin: .5rem 0; }
</style>
