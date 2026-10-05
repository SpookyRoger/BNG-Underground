<template>
  <section ref="root" class="bngu-style-page">
    <small>ACTIVE CAR · {{ spec.name }}</small><h2>Make it yours.</h2>
    <p>Choose a colour and finish, then buy one respray. Browsing keeps your fitted paint. Each respray costs {{ money(state.prices.paint) }} and adds one style point.</p>
    <p class="bngu-muted">Fitted · {{ fittedName }}</p>
    <h3>Colour</h3>
    <div class="bngu-paint-grid" aria-label="Choose paint colour"><BngButton v-for="paint in paints" :key="paint.id" accent="base" :data-bngu-paint="paint.id" :class="{ selected: colourId === paint.id }" :aria-pressed="colourId === paint.id" @click="colourId = paint.id"><span class="bngu-swatch" :style="{ backgroundColor: paintColor(paint) }"></span>{{ paint.name }}{{ car.paint === paint.id ? ' · fitted' : '' }}</BngButton></div>
    <template v-if="state.features.paintFinishes !== false"><h3>Finish</h3><div class="bngu-actions" aria-label="Choose paint finish"><BngButton v-for="finish in finishes" :key="finish.id" accent="base" :class="{ selected: finishId === finish.id }" :aria-pressed="finishId === finish.id" @click="finishId = finish.id">{{ finish.name }}{{ fittedFinish === finish.id ? ' · fitted' : '' }}</BngButton></div></template>
    <article v-if="selectedColour && selectedFinish" class="bngu-card bngu-respray-quote" aria-live="polite"><small>YOUR RESPRAY</small><h3><span class="bngu-swatch" :style="{ backgroundColor: paintColor(selectedColour) }"></span>{{ selectedColour.name }} · {{ selectedFinish.name }}</h3><p>{{ selectedFinish.description }}</p><p class="bngu-prize">{{ money(state.prices.paint) }}<small v-if="affordable">{{ money(state.cash - state.prices.paint) }} remaining</small></p><BngButton accent="base" data-bngu-buy-respray :disabled="!ready || fitted || !affordable || state.busy" @click="purchase">{{ fitted ? 'Colour & finish fitted ✓' : 'Buy & apply respray' }}</BngButton><p class="bngu-muted" role="status">{{ fitted ? 'Choose a different colour or finish for a new respray.' : !ready ? 'Park and stop at a physical workshop to respray this car.' : !affordable ? 'You need ' + money(state.prices.paint - state.cash) + ' more.' : 'One payment covers the colour and finish. A later respray is a new purchase.' }}</p><p class="bngu-muted">The swatch shows your colour choice. Reflections depend on the car and lighting; see the applied finish when you return to driving.</p></article>
    <h3>Body style</h3><p>Matched kit or two custom bodywork groups +2 · Club/Pro grip package +1.</p>
    <template v-if="state.features.bodywork && state.features.liveWorkshop"><p class="bngu-muted">Inspect front and rear bumpers, side skirts, hoods and spoilers on your actual car. Each build and kit setting remembers its own pieces.</p><BngButton accent="base" :disabled="!ready || state.busy" @click="$emit('command', 'enterWorkshop')">Inspect individual body pieces</BngButton></template>
    <BngButton v-if="!car.bodykit" accent="base" :disabled="!ready || state.cash < state.prices.bodykit" @click="$emit('command', 'bodykit')">Buy & fit style kit · {{ money(state.prices.bodykit) }}</BngButton><BngButton v-else accent="base" :disabled="!ready" @click="$emit('command', 'toggleKit')">{{ car.kitEquipped === false ? 'Fit owned style kit · free' : 'Remove style kit · free' }}</BngButton>
  </section>
</template>
<script setup>
import { computed, ref, watch } from "vue"
import { BngButton } from "@/common/components/base"
import { useScopedNav } from "@/services/scopedNav/api"
import { array, money, paintColor } from "../presentation.js"
const props = defineProps({ state: { type: Object, required: true }, spec: { type: Object, required: true }, car: { type: Object, required: true }, ready: Boolean })
const emit = defineEmits(["command"])
const root = ref(null), colourId = ref(null), finishId = ref(null), nav = useScopedNav()
const paints = computed(() => array(props.state.paints))
const finishes = computed(() => array(props.state.paintShop?.finishes))
const fittedFinish = computed(() => props.car.paint ? props.car.paintFinish || props.state.paintShop?.defaultFinish : null)
const fittedName = computed(() => props.car.paint ? (paints.value.find(entry => entry.id === props.car.paint)?.name || "Campaign colour") + " · " + (finishes.value.find(entry => entry.id === fittedFinish.value)?.name || "Campaign finish") : "Base build paint")
const selectedColour = computed(() => paints.value.find(entry => entry.id === colourId.value))
const selectedFinish = computed(() => finishes.value.find(entry => entry.id === finishId.value))
const fitted = computed(() => props.car.paint === colourId.value && fittedFinish.value === finishId.value)
const affordable = computed(() => props.state.cash >= props.state.prices.paint)
watch(() => JSON.stringify([props.state.activeCar, props.car.paint, props.car.paintFinish, props.state.paintShop?.defaultFinish, props.state.features.paintFinishes]), () => {
  colourId.value = props.car.paint || paints.value[0]?.id
  finishId.value = fittedFinish.value || props.state.paintShop?.defaultFinish
}, { immediate: true })
function purchase() {
  if (!props.ready || props.state.busy || fitted.value || !affordable.value || !selectedColour.value || !selectedFinish.value) return
  emit("command", "paint", { car: props.state.activeCar, basePaint: props.car.paint || false, baseFinish: fittedFinish.value || false, colour: colourId.value, finish: finishId.value })
}
function focusSelection() {
  const target = Array.from(root.value?.querySelectorAll("[data-bngu-paint]") || []).find(el => el.getAttribute("data-bngu-paint") === colourId.value)
  if (!target) return false
  target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target); return true
}
defineExpose({ focusSelection })
</script>
