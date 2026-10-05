<template>
  <section ref="root" class="bngu-city-page">
    <header class="bngu-page-heading"><small>YOUR CITY. YOUR NEXT MOVE.</small><h1>{{ state.introduction ? 'A first night in Belasco.' : 'Belasco after dark.' }}</h1><p>{{ state.introduction ? "Follow Mara's GPS to Quarryside. Park and stop to choose your own car." : 'Scroll the races to see where they are. Confirm a race to set GPS and drive.' }}</p></header>
    <div class="bngu-city-columns">
      <div class="bngu-map-column">
        <div class="bngu-city-map" bng-no-child-nav="true" aria-label="West Coast road map">
          <svg viewBox="0 0 1000 1000" preserveAspectRatio="none" aria-hidden="true"><path class="bngu-map-roads-minor" :d="minorRoads" /><path class="bngu-map-roads" :d="majorRoads" /><path class="bngu-map-course" :class="{ checkpoints: coursePreview.mode === 'checkpoints' }" :d="coursePath" vector-effect="non-scaling-stroke" /><path class="bngu-map-bearing" :d="bearingPath" /><path class="bngu-map-gps" :d="gpsPath" /><g v-for="marker in courseMarkers" :key="marker.label"><circle class="bngu-course-endpoint" :cx="marker.x" :cy="marker.y" r="8" vector-effect="non-scaling-stroke" /><text class="bngu-course-endpoint-label" :x="marker.x + 12" :y="marker.y - 9">{{ marker.label }}</text></g></svg>
          <span class="bngu-map-label">WEST COAST, USA · NORTH ↑</span>
          <BngButton v-for="pin in visibleRaces" :key="pin.event.id" accent="base" :nav-item="false" :tab-index="-1" :disabled="state.busy" class="bngu-map-pin" :class="{ selected: listKind === 'races' && selectedId === pin.event.id, rival: pin.event.boss }" :style="pinPlot(pin)" :aria-label="pin.number + '. ' + pin.event.name + ' — set GPS'" @mouseenter="highlight(pin.event, 'races')" @click="$emit('command', 'navigateEvent', pin.event.id)">{{ pin.number }}</BngButton>
          <BngButton v-for="site in visibleSites" :key="site.id" accent="base" :nav-item="false" :tab-index="-1" :disabled="state.busy" class="bngu-map-pin bngu-site-pin" :class="{ selected: listKind === 'places' && selectedId === site.id }" :style="plot(site.pos)" :aria-label="site.name + ' — set GPS'" @mouseenter="highlight(site, 'places')" @click="$emit('command', 'navigateLocation', site.id)">{{ site.type === 'dealership' ? 'D' : site.type === 'meet' ? 'M' : 'G' }}</BngButton>
          <span v-if="state.playerPosition && onMap(state.playerPosition)" class="bngu-map-player" :style="plot(state.playerPosition)" aria-label="Your car"></span>
          <span class="bngu-map-caption">WHITE · YOUR CAR / GOLD · HIGHLIGHTED / GREEN · GPS</span>
        </div>
        <div class="bngu-map-summary" aria-live="polite"><template v-if="selected"><small>{{ listKind === 'races' ? selected.kind : selected.type }} · {{ distance(selected.distance) }} FROM YOUR CAR</small><strong>{{ selected.name }}</strong><p v-if="listKind === 'races'">{{ courseLabel(selected) }} · {{ payoutLabel(selected) }} {{ selected.payout?.replay ? 'replay' : 'first clear' }}</p><p v-if="listKind === 'races' && selected.payout?.sponsor">{{ sponsorLabel(selected) }}</p><p>{{ selected.description }}</p></template><p v-else>Choose a destination from the list.</p></div>
        <p v-if="previewEventId" class="bngu-course-status" role="status">{{ coursePreview.status === 'loading' ? 'Loading course outline…' : coursePreview.available ? (coursePreview.mode === 'checkpoints' ? 'GOLD · CHECKPOINT CONNECTIONS / ROADS MAY DIFFER' : 'GOLD · SELECTED COURSE') + ' · ' + courseLabel(selected) : coursePreview.reason }}<BngButton v-if="coursePreview.retryable" accent="base" :disabled="state.busy || coursePreview.status === 'loading'" @click="courseLoader.retry()">Retry outline</BngButton></p>
        <div class="bngu-map-controls" aria-label="Map controls"><BngButton accent="base" :disabled="zoom >= 4" @click="changeZoom(1.5)">Zoom +</BngButton><BngButton accent="base" :disabled="zoom <= 0.5" @click="changeZoom(1 / 1.5)">Zoom −</BngButton><BngButton accent="base" @click="pan(0, 1)">North</BngButton><BngButton accent="base" @click="pan(0, -1)">South</BngButton><BngButton accent="base" @click="pan(-1, 0)">West</BngButton><BngButton accent="base" @click="pan(1, 0)">East</BngButton><BngButton accent="base" @click="centerPlayer">Your car</BngButton><BngButton v-if="coursePreview.available" accent="base" @click="fitCourse(true)">Show course & car</BngButton><BngButton accent="base" @click="wholeCity">Whole city</BngButton></div>
        <p v-if="mapError" class="bngu-muted">{{ mapError }}</p>
      </div>
      <div class="bngu-map-destinations">
        <div class="bngu-tabs" aria-label="Destinations"><BngButton v-if="!state.introduction" accent="base" :class="{ selected: listKind === 'races' }" :aria-pressed="listKind === 'races'" @click="setList('races')">Races · {{ openEvents.length }}</BngButton><BngButton accent="base" :class="{ selected: listKind === 'places' }" :aria-pressed="listKind === 'places'" @click="setList('places')">Places · {{ locations.length }}</BngButton></div>
        <div v-if="listKind === 'races'" class="bngu-destination-scroll" bng-nav-scroll aria-label="Available races">
          <BngButton v-for="(event, index) in openEvents" :key="event.id" accent="base" class="bngu-destination-row" :class="{ selected: selectedId === event.id, rival: event.boss }" data-bngu-map-entry :data-bngu-race="event.id" :disabled="state.busy" @focusin="highlight(event, 'races', $event)" @mouseenter="highlight(event, 'races')" @click="$emit('command', 'navigateEvent', event.id)"><span class="bngu-destination-number">{{ index + 1 }}</span><span class="bngu-destination-copy"><small>{{ event.kind }} · CH {{ event.chapter }}<span v-if="event.record?.cleared"> · CLEARED ✓</span></small><strong>{{ event.name }}</strong><span>{{ distance(event.distance) }} · {{ payoutLabel(event) }} {{ event.payout?.replay ? 'replay' : 'first clear' }} · +{{ event.payout?.rep || 0 }} REP</span></span><span class="bngu-destination-go" aria-hidden="true">→</span></BngButton>
          <p v-if="!openEvents.length">No open races. Choose Places to find the dealership.</p>
        </div>
        <div v-else class="bngu-destination-scroll" bng-nav-scroll aria-label="Workshops and meets">
          <BngButton v-for="site in locations" :key="site.id" accent="base" class="bngu-destination-row" :class="{ selected: selectedId === site.id }" data-bngu-map-entry :data-bngu-place="site.id" :disabled="state.busy" @focusin="highlight(site, 'places', $event)" @mouseenter="highlight(site, 'places')" @click="$emit('command', 'navigateLocation', site.id)"><span class="bngu-destination-number">{{ site.type === 'dealership' ? 'D' : site.type === 'meet' ? 'M' : 'G' }}</span><span class="bngu-destination-copy"><small>{{ site.type }}</small><strong>{{ site.name }}</strong><span>{{ distance(site.distance) }} from your car</span></span><span class="bngu-destination-go" aria-hidden="true">→</span></BngButton>
        </div>
        <p class="bngu-destination-hint">UP / DOWN · HIGHLIGHT<br>CONFIRM · SET GPS & RETURN TO DRIVING</p>
        <BngButton v-if="state.introduction" accent="base" @click="$emit('dealership')">Choose starter at dealership</BngButton><BngButton v-else accent="base" @click="$emit('races')">Race details & entry</BngButton>
      </div>
    </div>
  </section>
</template>
<script setup>
import { computed, ref, watch, nextTick, onMounted, onUnmounted } from "vue"
import { BngButton } from "@/common/components/base"
import { useScopedNav } from "@/services/scopedNav/api"
import { getMapData, getCourseData } from "../campaignApi.js"
import { createCourseLoader } from "../courseLoader.js"
import { framePoints } from "../mapFraming.js"
import { array, distance, courseLabel, payoutLabel, sponsorLabel } from "../presentation.js"
const props = defineProps({ state: { type: Object, required: true }, focusEvent: { type: String, default: null } })
defineEmits(["command", "races", "dealership"])
const root = ref(null), nav = useScopedNav()
const listKind = ref(props.state.introduction ? "places" : "races"), selectedId = ref(null)
const geometry = ref(null), mapError = ref(""), zoom = ref(1), offset = ref([0, 0])
const coursePreview = ref({ status: "idle", available: false, points: [] })
let disposed = false, autoReveal = true
const openEvents = computed(() => array(props.state.eventList).filter(event => event.unlocked))
const locations = computed(() => array(props.state.locations).filter(site => site.chapter <= props.state.chapter))
const entries = computed(() => listKind.value === "races" ? openEvents.value : locations.value)
const selected = computed(() => entries.value.find(entry => entry.id === selectedId.value))
const previewEventId = computed(() => props.state.features.coursePreviews !== false && listKind.value === "races" ? selected.value?.id || null : null)
const courseLoader = createCourseLoader({ fetch: getCourseData, update: value => { coursePreview.value = value; if (value.available && autoReveal) fitCourse() } })
const bounds = computed(() => {
  const base = geometry.value?.bounds || [-1500, -1600, 2400, 2700]
  const points = [...openEvents.value, ...locations.value].map(entry => entry.pos).filter(Boolean)
  if (coursePreview.value.available) points.push(...array(coursePreview.value.points))
  if (props.state.playerPosition) points.push(props.state.playerPosition)
  const box = [Math.min(base[0], ...points.map(p => p[0])), Math.min(base[1], ...points.map(p => p[1])), Math.max(base[2], ...points.map(p => p[0])), Math.max(base[3], ...points.map(p => p[1]))]
  // Keep outermost destinations clear of the map labels and fanned badges.
  const padding = Math.max(box[2] - box[0], box[3] - box[1]) * .1
  return [box[0] - padding, box[1] - padding, box[2] + padding, box[3] + padding]
})
const span = computed(() => Math.max(bounds.value[2] - bounds.value[0], bounds.value[3] - bounds.value[1]) || 1)
const center = computed(() => [(bounds.value[0] + bounds.value[2]) / 2 + offset.value[0], (bounds.value[1] + bounds.value[3]) / 2 + offset.value[1]])
const project = pos => [50 + (pos[0] - center.value[0]) / span.value * 90 * zoom.value, 50 - (pos[1] - center.value[1]) / span.value * 90 * zoom.value]
const plot = pos => { const [x, y] = project(pos); return { left: x + "%", top: y + "%" } }
const onMap = pos => { const [x, y] = project(pos); return x >= 4 && x <= 96 && y >= 7 && y <= 93 }
// Shared starting points still have one numbered marker per race; fan their badges apart.
const racePins = computed(() => openEvents.value.filter(event => event.pos).map(event => {
  const neighbours = openEvents.value.filter(other => other.pos && Math.hypot(other.pos[0] - event.pos[0], other.pos[1] - event.pos[1]) < 70)
  const angle = neighbours.findIndex(other => other.id === event.id) / neighbours.length * Math.PI * 2
  const radius = neighbours.length > 1 ? Math.max(22, neighbours.length * 18 / Math.PI) : 0
  return { event, number: openEvents.value.indexOf(event) + 1, dx: Math.cos(angle) * radius, dy: Math.sin(angle) * radius }
}))
const visibleRaces = computed(() => racePins.value.filter(pin => onMap(pin.event.pos)))
const visibleSites = computed(() => locations.value.filter(site => site.pos && onMap(site.pos)))
function pinPlot(pin) { const [x, y] = project(pin.event.pos); return { left: `calc(${x}% + ${pin.dx}px)`, top: `calc(${y}% + ${pin.dy}px)` } }
const roadPath = type => array(geometry.value?.roads).filter(road => road[4] === type).map(road => {
  const a = project(road), b = project([road[2], road[3]])
  return `M${a[0] * 10},${a[1] * 10}L${b[0] * 10},${b[1] * 10}`
}).join("")
const majorRoads = computed(() => roadPath(1)), minorRoads = computed(() => roadPath(0))
const gpsPath = computed(() => array(props.state.gpsRoute).map((point, i) => { const [x, y] = project(point); return `${i ? 'L' : 'M'}${x * 10},${y * 10}` }).join(""))
const coursePath = computed(() => coursePreview.value.available && coursePreview.value.eventId === previewEventId.value ? array(coursePreview.value.points).map((point, index) => { const [x, y] = project(point); return `${index ? 'L' : 'M'}${x * 10},${y * 10}` }).join("") : "")
const courseMarkers = computed(() => {
  if (!coursePreview.value.available || coursePreview.value.eventId !== previewEventId.value) return []
  const points = array(coursePreview.value.points), markers = [{ pos: points[0], label: coursePreview.value.closed ? "S/F" : "S" }]
  if (!coursePreview.value.closed) markers.push({ pos: points[points.length - 1], label: "F" })
  return markers.filter(marker => onMap(marker.pos)).map(marker => { const [x, y] = project(marker.pos); return { x: x * 10, y: y * 10, label: marker.label } })
})
const bearingPath = computed(() => {
  if (!selected.value?.pos || !props.state.playerPosition) return ""
  const a = project(props.state.playerPosition), b = project(selected.value.pos)
  return `M${a[0] * 10},${a[1] * 10}L${b[0] * 10},${b[1] * 10}`
})
function changeZoom(factor) { autoReveal = false; zoom.value = Math.min(4, Math.max(0.5, zoom.value * factor)) }
function pan(x, y) { autoReveal = false; offset.value = [offset.value[0] + x * span.value / zoom.value * .15, offset.value[1] + y * span.value / zoom.value * .15] }
function centerOn(pos) { offset.value = [pos[0] - (bounds.value[0] + bounds.value[2]) / 2, pos[1] - (bounds.value[1] + bounds.value[3]) / 2] }
function centerPlayer() { autoReveal = false; if (props.state.playerPosition) centerOn(props.state.playerPosition) }
function wholeCity() { autoReveal = false; zoom.value = 1; offset.value = [0, 0] }
function fitCourse(manual = false) {
  if (manual) autoReveal = true
  if (!coursePreview.value.available || coursePreview.value.eventId !== previewEventId.value) return
  const points = [...array(coursePreview.value.points)]
  if (selected.value?.pos) points.push(selected.value.pos)
  if (props.state.playerPosition) points.push(props.state.playerPosition)
  const frame = framePoints(points, bounds.value)
  if (frame) { zoom.value = frame.zoom; centerOn(frame.position) }
}
function revealDestination(pos) {
  if (!pos) return
  const player = props.state.playerPosition || pos
  if (onMap(pos) && onMap(player)) return
  const extent = Math.max(Math.abs(pos[0] - player[0]), Math.abs(pos[1] - player[1]), 1)
  zoom.value = Math.min(zoom.value, Math.max(0.5, span.value * .7 / extent))
  centerOn([(pos[0] + player[0]) / 2, (pos[1] + player[1]) / 2])
}
function highlight(entry, kind, event) {
  listKind.value = kind; selectedId.value = entry.id
  revealDestination(entry.pos)
  event?.currentTarget?.scrollIntoView({ block: "nearest", inline: "nearest" })
}
function focusSelection() {
  const attribute = listKind.value === "races" ? "data-bngu-race" : "data-bngu-place"
  const buttons = Array.from(root.value?.querySelectorAll(`[${attribute}]`) || [])
  const target = buttons.find(element => element.getAttribute(attribute) === selectedId.value) || buttons[0]
  if (target) {
    target.scrollIntoView({ block: "nearest", inline: "nearest" })
    nav.requestScopeFocus("bngu-board", target)
  }
}
async function setList(kind) {
  listKind.value = kind
  selectedId.value = kind === "places" && props.state.introduction ? props.state.dealership.id : entries.value[0]?.id
  if (selected.value) revealDestination(selected.value.pos)
  await nextTick(); focusSelection()
}
async function selectInvitation(id) {
  const event = openEvents.value.find(entry => entry.id === id)
  if (!event) return
  highlight(event, "races")
  await nextTick(); focusSelection()
}
watch(entries, list => { if (!list.some(entry => entry.id === selectedId.value)) selectedId.value = props.state.introduction ? list.find(entry => entry.id === props.state.dealership.id)?.id || list[0]?.id : list[0]?.id }, { immediate: true })
watch(() => props.focusEvent, id => { if (id) selectInvitation(id) })
watch(previewEventId, id => { autoReveal = true; courseLoader.select(id) }, { immediate: true })
onMounted(async () => {
  if (props.focusEvent) selectInvitation(props.focusEvent)
  try { const data = await getMapData(); if (disposed) return; if (data?.error) mapError.value = data.error; else geometry.value = data }
  catch (error) { if (disposed) return; mapError.value = "Road map unavailable: " + String(error.message || error) }
  if (coursePreview.value.available && autoReveal) fitCourse()
  else if (selected.value && autoReveal) revealDestination(selected.value.pos)
})
onUnmounted(() => { disposed = true; courseLoader.dispose() })
defineExpose({ focusSelection })
</script>
