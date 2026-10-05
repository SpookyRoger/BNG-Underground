<template>
  <section ref="root" class="bngu-sponsors-page">
    <small>BACK YOUR BUILD</small><h1>Get noticed.</h1>
    <p>One contract at a time. Choose different qualifying meets for a completion payment. Every qualifying clear earns a race bonus; a delivered meet cannot add another contract clear.</p>
    <div class="bngu-sponsors-columns">
      <div class="bngu-sponsors-list" bng-nav-scroll aria-label="Browse sponsor contracts">
        <BngButton v-for="entry in sponsors" :key="entry.id" accent="base" class="bngu-sponsor-row" :class="{ selected: selectedId === entry.id }" :data-bngu-sponsor="entry.id" @focusin="highlight(entry, $event)" @mouseenter="selectedId = entry.id" @click="openContract(entry)"><strong>{{ entry.name }}</strong><small>{{ entry.completed ? 'COMPLETED ✓' : entry.active ? 'ACTIVE · ' + entry.clears + ' / ' + entry.wins : 'CH ' + entry.chapter + ' · STYLE ' + entry.style }}</small></BngButton>
      </div>
      <div ref="detail" class="bngu-sponsors-detail" bng-nav-scroll>
        <article v-if="selected" class="bngu-card">
          <small>{{ selected.active ? 'YOUR ACTIVE CONTRACT' : selected.completed ? 'CONTRACT COMPLETED' : 'CH ' + selected.chapter + ' · STYLE ' + selected.style }}</small><h2>{{ selected.name }}</h2><p>{{ selected.tagline }}</p>
          <strong class="bngu-prize">{{ money(selected.reward) }} at completion</strong><p>{{ selected.wins }} different clears · +{{ Math.round(selected.bonus * 100) }}% on qualifying purses</p><p>{{ selected.kinds.join(' / ') }}</p>
          <p v-if="selected.active"><strong>{{ selected.clears }} / {{ selected.wins }} delivered</strong> · {{ selected.remaining }} more different clears</p><p v-if="selected.reason" class="bngu-muted">{{ selected.reason }}</p>
          <BngButton v-if="!selected.active && !selected.completed" accent="base" :disabled="state.busy || !selected.signable" @click="sign">Sign {{ selected.name }}</BngButton>
          <p class="bngu-muted">Already-cleared races count when cleared again after signing. Repeating a delivered race still earns the percentage bonus, but does not move the contract forward. Style is checked when signing; you can change cars and builds afterward.</p>
          <p v-if="selected.deliveredNames?.length" class="bngu-muted">Delivered · {{ selected.deliveredNames.join(' · ') }}</p>
          <h3>{{ selected.active ? 'Choose your next qualifying meet' : 'Qualifying meets open now' }}</h3>
          <BngButton v-for="event in qualifying" :key="event.id" accent="base" class="bngu-sponsor-meet" :disabled="state.busy" @click="$emit('event', event.id)"><strong>{{ event.name }}</strong><small>{{ event.kind }} · CH {{ event.chapter }} · {{ payoutLabel(event) }} {{ event.payout?.replay ? 'replay' : 'first clear' }}{{ event.payout?.sponsor?.completion ? ' · COMPLETES YOUR CONTRACT' : '' }}</small></BngButton>
          <p v-if="!qualifying.length">No new qualifying meets are open. Other races remain available; chapter progression can open more choices.</p>
          <p class="bngu-muted">Confirm a meet to highlight it on Map, then select it to set GPS. Quoted amounts include only your currently active sponsor.</p>
        </article>
      </div>
    </div>
  </section>
</template>
<script setup>
import { computed, ref, nextTick, watch } from "vue"
import { BngButton } from "@/common/components/base"
import { useScopedNav } from "@/services/scopedNav/api"
import { array, money, payoutLabel } from "../presentation.js"
const props = defineProps({ state: { type: Object, required: true } })
const emit = defineEmits(["command", "event"])
const root = ref(null), detail = ref(null), nav = useScopedNav(), selectedId = ref(props.state.sponsor?.id || null)
const sponsors = computed(() => array(props.state.sponsors))
const selected = computed(() => sponsors.value.find(entry => entry.id === selectedId.value) || sponsors.value[0])
const qualifying = computed(() => array(selected.value?.eventIds).map(id => array(props.state.eventList).find(event => event.id === id)).filter(Boolean))
function highlight(entry, event) { selectedId.value = entry.id; event?.currentTarget?.scrollIntoView({ block: "nearest", inline: "nearest" }) }
function focusSelection() {
  const target = Array.from(root.value?.querySelectorAll("[data-bngu-sponsor]") || []).find(el => el.getAttribute("data-bngu-sponsor") === selected.value?.id)
  if (target) { target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target); return true }
  return false
}
async function openContract(entry) {
  selectedId.value = entry.id; await nextTick()
  const target = detail.value?.querySelector("[bng-nav-item]:not(:disabled)")
  if (target) { target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target) }
}
async function sign() { emit("command", "signSponsor", selected.value.id) }
watch(() => sponsors.value.map(entry => entry.id).join("|"), () => { if (!sponsors.value.some(entry => entry.id === selectedId.value)) selectedId.value = props.state.sponsor?.id || sponsors.value[0]?.id }, { immediate: true })
watch(() => props.state.sponsor?.id, async () => { await nextTick(); focusSelection() })
defineExpose({ focusSelection })
</script>
