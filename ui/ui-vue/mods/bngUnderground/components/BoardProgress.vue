<template>
  <section>
    <small>YOUR NAME ON THE STREETS.</small><h1>{{ state.completed ? 'The city knows you.' : 'Build your reputation.' }}</h1>
    <p>Choose your own path through each chapter. Clear different events and earn reputation to open its rival challenge. Beat the rival to unlock the next chapter. Earlier races stay open.</p>
    <p class="bngu-muted">Bronze is enough for a regular clear, including a podium in an AI race. Rivals require first place. Drift, drag and the longer time attacks are optional; repeats do not add another different clear.</p>
    <div class="bngu-progress-list">
      <article v-for="chapter in array(state.chapterList)" :key="chapter.id" class="bngu-card" :class="{ selected: chapter.current, rival: chapter.rivalCleared }">
        <small>CHAPTER {{ chapter.id }} · {{ chapter.rivalCleared ? 'RIVAL BEATEN' : chapter.current ? 'YOUR CURRENT CHAPTER' : chapter.unlocked ? 'OPEN' : 'UPCOMING' }}</small>
        <h2>{{ chapter.name }}</h2><p>{{ chapter.district }} · {{ chapter.regularCount }} regular races to choose from</p>
        <div class="bngu-progress-facts"><span><strong>{{ chapter.clears }} / {{ chapter.requiredWins }}</strong>Different clears needed</span><span><strong>{{ state.rep }} / {{ chapter.requiredRep }}</strong>Reputation needed</span><span><strong>{{ chapter.boss }}</strong>{{ chapter.rivalCleared ? 'Rival cleared' : chapter.rivalOpen ? 'Ready to challenge' : 'Rival challenge locked' }}</span></div>
        <p v-if="!chapter.rivalCleared && !chapter.rivalOpen">{{ chapter.rivalReason }}</p>
        <p v-if="chapter.unlocks?.length" class="bngu-muted">Available from this chapter · builds at workshops; optional covers at their feature locations:</p>
        <ul v-if="chapter.unlocks?.length" class="bngu-unlock-list"><li v-for="unlock in chapter.unlocks" :key="unlock.type + unlock.name">{{ unlock.name }}{{ unlock.reward != null ? ' · optional cover · style ' + unlock.style + ' · earn ' + money(unlock.reward) : unlock.cost != null ? ' · ' + money(unlock.cost) : unlock.costMin != null ? ' · ' + money(unlock.costMin) + (unlock.costMax > unlock.costMin ? '–' + money(unlock.costMax) : '') : ' · price varies by car' }}{{ unlock.count ? ' · ' + unlock.count + ' choices by car/build' : '' }}</li></ul>
        <div class="bngu-actions"><BngButton accent="base" @click="$emit('chapter', chapter.id)">{{ chapter.unlocked ? 'Browse chapter races' : 'Preview chapter races' }}</BngButton><BngButton accent="base" :disabled="state.busy || !chapter.rivalOpen" @click="$emit('command', 'navigateEvent', chapter.rivalEventId)">{{ chapter.rivalCleared ? 'GPS · rival rematch' : 'GPS · ' + chapter.boss + "'s challenge" }}</BngButton></div>
      </article>
    </div>
  </section>
</template>
<script setup>
import { BngButton } from "@/common/components/base"
import { array, money } from "../presentation.js"
defineProps({ state: { type: Object, required: true } })
defineEmits(["command", "chapter"])
</script>
