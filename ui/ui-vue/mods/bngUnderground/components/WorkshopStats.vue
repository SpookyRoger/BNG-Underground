<template>
  <section class="workshop-stats" aria-label="Fitted car and preview comparison">
    <small>FITTED → PREVIEW · NATIVE CAR DATA</small>
    <div v-for="row in rows" :key="row.id" class="stat-row">
      <div><strong>{{ row.name }}</strong><span>{{ value(baseline?.[row.id]) }} → {{ value(current?.[row.id]) }} {{ row.unit }}<b v-if="delta(row.id) !== null">{{ delta(row.id) > 0 ? '+' : '' }}{{ delta(row.id) }}</b></span></div>
      <div class="stat-track"><i class="stat-saved" :style="{ width: bar(baseline?.[row.id], row.limit) }"></i><i class="stat-preview" :style="{ width: bar(current?.[row.id], row.limit) }"></i></div>
    </div>
    <p>{{ measuring ? 'Reading the fitted engine curves and node mass…' : 'Peak engine-curve power/torque; actual node mass. These are not acceleration or handling ratings.' }}</p>
  </section>
</template>
<script setup>
const props = defineProps({ baseline: Object, current: Object, measuring: Boolean })
const rows = [{ id: "power", name: "Power", unit: "PS", limit: 600 }, { id: "torque", name: "Torque", unit: "Nm", limit: 800 }, { id: "weight", name: "Weight", unit: "kg", limit: 2000 }]
const value = n => Number.isFinite(n) ? Math.round(n) : "—"
const bar = (n, limit) => Number.isFinite(n) ? Math.max(0, Math.min(100, n / limit * 100)) + "%" : "0%"
function delta(id) { return Number.isFinite(props.baseline?.[id]) && Number.isFinite(props.current?.[id]) ? Math.round(props.current[id] - props.baseline[id]) : null }
</script>
<style scoped>
.workshop-stats { padding: 1rem 1.3rem; background: #141021ed; border: 1px solid #8973ac77; border-radius: .7rem; }
small { color: #75e0d1; letter-spacing: .12em; font-size: .68rem; }
.stat-row { margin-top: .9rem; }.stat-row > div:first-child { display: flex; justify-content: space-between; gap: 1rem; font-size: .9rem; }b { margin-left: .6rem; color: #7ce7d7; }
.stat-track { height: .32rem; position: relative; margin-top: .45rem; background: #eee2; }.stat-track i { position: absolute; left: 0; height: 100%; transition: width .25s; }.stat-saved { background: #a99dba; top: 0; }.stat-preview { background: #7ce7d7; top: .13rem; }p { font-size: .73rem; line-height: 1.4; color: #c2b8ce; margin: 1rem 0 0; }
</style>
