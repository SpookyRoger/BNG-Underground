<template>
  <section>
    <small>YOUR CAR. YOUR CHOICE.</small><h1>The race board.</h1>
    <p>Bronze clears a regular event. Rivals require first place. Choose any different clears in your chapter; repeats earn cash but no new reputation.</p>
    <div class="bngu-actions" aria-label="Event type"><BngButton v-for="kind in disciplines" :key="kind" accent="base" :class="{ selected: discipline === kind }" :aria-pressed="discipline === kind" @click="discipline = kind; page = 0">{{ kind }}</BngButton></div>
    <div class="bngu-actions" aria-label="Chapter"><BngButton accent="base" :class="{ selected: chapter === 0 }" :aria-pressed="chapter === 0" @click="chapter = 0; page = 0">All open chapters</BngButton><BngButton v-for="entry in array(state.chapterList)" :key="entry.id" accent="base" :class="{ selected: chapter === entry.id }" :aria-pressed="chapter === entry.id" @click="chapter = entry.id; page = 0">CH {{ entry.id }} · {{ entry.name }}{{ entry.unlocked ? '' : ' · preview' }}</BngButton></div>
    <p class="bngu-muted">{{ filtered.length }} events · {{ chapter ? 'Chapter ' + chapter : 'All unlocked chapters' }}</p>
    <div class="bngu-card-grid">
      <article v-for="event in visible" :key="event.id" class="bngu-card" :class="{ rival: event.boss }">
        <small>{{ event.kind }} · CH {{ event.chapter }} <span v-if="event.record?.cleared">· {{ event.record.medal }} ✓</span></small>
        <h2>{{ event.name }}</h2><p>{{ event.description }}</p>
        <p class="bngu-course-fact">{{ courseLabel(event) }}</p>
        <dl class="bngu-medal-targets"><div v-for="target in raceTargets(event)" :key="target.medal"><dt>{{ target.medal }}</dt><dd>{{ target.target }}</dd></div></dl>
        <p v-if="event.kind === 'Time attack'" class="bngu-muted">Targets cover the full race{{ event.course?.laps > 1 ? ' · all ' + event.course.laps + ' laps' : '' }}.</p>
        <p v-if="event.kind === 'Drag'" class="bngu-muted">Finish first without disqualification and meet the elapsed-time target.</p>
        <p class="bngu-prize">{{ payoutLabel(event) }} <small>{{ event.payout?.replay ? 'REPLAY' : 'FIRST CLEAR' }} · +{{ event.payout?.rep || 0 }} REP · {{ event.payout?.sponsor ? 'SPONSOR INCLUDED' : 'RACE PURSE' }}</small></p>
        <p v-if="event.payout?.sponsor" class="bngu-muted">{{ sponsorLabel(event) }}. Base purse {{ basePayoutLabel(event) }}.</p>
        <p v-if="!event.unlocked">{{ event.lockReason }}</p>
        <div class="bngu-actions">
          <BngButton accent="base" :disabled="state.busy || !event.unlocked" @click="$emit('command', 'navigateEvent', event.id)">GPS · {{ distance(event.distance) }}</BngButton>
          <BngButton accent="base" :disabled="state.busy || !event.canStart" @click="$emit('command', 'startEvent', event.id)">{{ event.record?.cleared ? 'Replay race' : 'Start at meet' }}</BngButton>
        </div>
        <p v-if="event.unlocked && !event.canStart" class="bngu-muted">Drive to the meet before starting your first attempt.</p>
      </article>
    </div>
    <p v-if="!filtered.length">No events match this selection. Choose another event type or chapter.</p>
    <div class="bngu-pagination"><BngButton accent="base" :disabled="page === 0" @click="page--">Previous events</BngButton><span>{{ page + 1 }} / {{ pageCount }}</span><BngButton accent="base" :disabled="page + 1 >= pageCount" @click="page++">Next events</BngButton></div>
  </section>
</template>
<script setup>
import { ref, computed, watch } from "vue"
import { BngButton } from "@/common/components/base"
import { array, distance, disciplines, courseLabel, payoutLabel, basePayoutLabel, sponsorLabel, raceTargets } from "../presentation.js"
const props = defineProps({ state: { type: Object, required: true }, focusChapter: { type: Number, default: null } })
defineEmits(["command"])
const discipline = ref("All"), chapter = ref(0), page = ref(0)
watch(() => props.focusChapter, id => { if (id != null) { chapter.value = id; discipline.value = "All"; page.value = 0 } }, { immediate: true })
const filtered = computed(() => array(props.state.eventList).filter(event => (discipline.value === "All" || event.kind === discipline.value) && (chapter.value ? event.chapter === chapter.value : event.chapter <= props.state.chapter)))
const pageCount = computed(() => Math.max(1, Math.ceil(filtered.value.length / 4)))
watch(pageCount, count => { page.value = Math.min(page.value, count - 1) })
const visible = computed(() => filtered.value.slice(page.value * 4, page.value * 4 + 4))
</script>
