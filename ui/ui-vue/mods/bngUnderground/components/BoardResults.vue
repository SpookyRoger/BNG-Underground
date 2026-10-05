<template>
  <section ref="root" class="bngu-results-page">
    <small>YOUR RACE JOURNAL</small><h1>Make every run count.</h1>
    <p>Recent runs, newest first. Browse to see what you earned, then choose your next stop.</p>
    <div v-if="results.length" class="bngu-results-columns">
      <div class="bngu-results-list" bng-nav-scroll aria-label="Recent race results">
        <BngButton v-for="entry in results" :key="entry.id" accent="base" class="bngu-result-row" :class="{ selected: selected?.id === entry.id }" :aria-pressed="selected?.id === entry.id" :data-bngu-result="entry.id" @focusin="highlight(entry, $event)" @mouseenter="selectedId = entry.id" @click="openResult(entry)">
          <strong>{{ entry.name }}</strong><small>{{ resultOutcome(entry) }}</small>
          <span>{{ resultMeasurement(entry) }}</span><span>{{ money(entry.cash) }} · +{{ entry.rep }} REP</span>
        </BngButton>
      </div>
      <div ref="detail" class="bngu-results-detail" bng-nav-scroll @focusin="detailActive = true">
        <article v-if="selected" class="bngu-card">
          <small>{{ selected.kind }} · RUN {{ selected.attempt }}<span v-if="nativeResultDate(selected.date)"> · {{ nativeResultDate(selected.date) }}</span></small>
          <h2>{{ selected.name }}</h2><p class="bngu-result-outcome">{{ resultOutcome(selected) }}</p>
          <p>{{ selected.carName }} · {{ selected.buildName }}</p>
          <strong class="bngu-result-measurement">{{ resultMeasurement(selected) }}</strong>
          <p v-if="!selected.won">This run did not meet the race’s clear target. There was no entry fee. Another race and another owned build are always options.</p>
          <div class="bngu-result-rewards" aria-label="Rewards earned on this run">
            <div><span>Race purse</span><strong>{{ money(selected.basePurse) }}</strong></div>
            <template v-if="selected.sponsorPayment">
              <div><span>{{ selected.sponsorPayment.name }} · race bonus</span><strong>{{ money(selected.sponsorPayment.raceBonus) }}</strong></div>
              <div v-if="selected.sponsorPayment.completion"><span>Contract completion</span><strong>{{ money(selected.sponsorPayment.completion) }}</strong></div>
            </template>
            <div class="total"><span>Total earned</span><strong>{{ money(selected.cash) }}</strong></div>
            <div><span>Reputation earned</span><strong>+{{ selected.rep }} REP</strong></div>
          </div>
          <p v-if="selected.won && !selected.first" class="bngu-muted">Replay purse · reputation and different-clear progress were already earned on the first clear.</p>
          <p v-if="selected.chapterAfter > selected.chapterBefore" class="bngu-result-unlock">CHAPTER {{ selected.chapterAfter }} OPEN · {{ selected.chapterName }}</p>
          <p v-else-if="selected.completed" class="bngu-result-unlock">CITY CHAMPION · All open meets remain available.</p>
          <p>{{ selected.text }}</p>
          <div class="bngu-result-actions">
            <BngButton accent="base" :disabled="state.busy || !event" @click="$emit('event', selected.eventId)">Show this race on Map</BngButton>
            <BngButton accent="base" :disabled="state.busy || !event?.unlocked" @click="$emit('command', 'navigateEvent', selected.eventId)">Set GPS · race start</BngButton>
            <BngButton accent="base" :disabled="state.busy" @click="$emit('command', 'navigateLocation', 'home')">Set GPS · Mara’s Garage</BngButton>
            <BngButton accent="base" :disabled="state.busy" @click="$emit('page', 'progress')">Your next chapter</BngButton>
            <BngButton accent="base" :disabled="state.busy" @click="$emit('page', 'inbox')">Messages & invitations</BngButton>
          </div>
          <p class="bngu-muted">Parts and tuning are fitted at a physical workshop. History records this run’s car and build type; purchases afterward do not rewrite its rewards.</p>
        </article>
      </div>
    </div>
    <article v-else class="bngu-card"><h2>Your next run starts here.</h2><p>Complete or attempt a campaign race to record it. Older saves retain all their progress; past runs are not recreated.</p><BngButton accent="base" data-bngu-results-empty :disabled="state.busy" @click="$emit('page', 'city')">Browse races on Map</BngButton></article>
    <p class="bngu-results-hint">D-PAD · BROWSE / CONFIRM · NEXT STOP / BACK · {{ detailActive ? 'RECENT RUNS' : 'RETURN TO DRIVING' }}</p>
  </section>
</template>
<script setup>
import { computed, ref, nextTick, watch } from "vue"
import { BngButton } from "@/common/components/base"
import { useScopedNav } from "@/services/scopedNav/api"
import { array, money } from "../presentation.js"
import { resultOutcome, resultMeasurement, nativeResultDate } from "../resultPresentation.js"
const props = defineProps({ state: { type: Object, required: true } })
defineEmits(["command", "event", "page"])
const root = ref(null), detail = ref(null), nav = useScopedNav(), selectedId = ref(null), detailActive = ref(false)
const results = computed(() => array(props.state.recentResults))
const selected = computed(() => results.value.find(entry => entry.id === selectedId.value) || results.value[0])
const event = computed(() => array(props.state.eventList).find(entry => entry.id === selected.value?.eventId))
function highlight(entry, event) {
  detailActive.value = false; selectedId.value = entry.id
  event.currentTarget.scrollIntoView({ block: "nearest", inline: "nearest" })
  if (detail.value) detail.value.scrollTop = 0
}
function focusSelection() {
  const target = Array.from(root.value?.querySelectorAll("[data-bngu-result]") || []).find(element => element.getAttribute("data-bngu-result") === selected.value?.id) || root.value?.querySelector("[data-bngu-results-empty]")
  if (!target) return false
  detailActive.value = false
  target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target)
  return true
}
async function openResult(entry) {
  selectedId.value = entry.id; await nextTick()
  const target = detail.value?.querySelector("[bng-nav-item]:not(:disabled)")
  if (target) { detailActive.value = true; target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target) }
}
function back() {
  if (!detailActive.value) return false
  detailActive.value = false; nextTick(focusSelection); return true
}
// Refreshes with unchanged IDs must preserve controller focus in the detail.
watch(() => results.value.map(entry => entry.id).join("|"), () => {
  if (selectedId.value && !results.value.some(entry => entry.id === selectedId.value)) {
    selectedId.value = results.value[0]?.id || null; detailActive.value = false; nextTick(focusSelection)
  }
})
defineExpose({ focusSelection, back })
</script>
