<template>
  <section ref="root" class="workshop-recovery" role="dialog" aria-modal="true" aria-labelledby="workshop-recovery-title" v-bng-scoped-nav="{ scopeId: 'bngu-workshop-recovery', activateOnMount: true, preferAutoFocus: true, trapPolicy: 'always', canDeactivate: keepPaused }" v-bng-on-ui-nav:menu="keepPaused">
    <article bng-nav-scroll><small>WORKSHOP RECOVERY · GAME PAUSED</small><h1 id="workshop-recovery-title">Your saved build is protected.</h1>
      <p class="error">{{ status.error }}</p>
      <p>{{ status.canRetryExit ? 'The paid car is restored, but returning to the game screen did not finish.' : 'This car has not finished initializing. You can wait for a late reply or rebuild your saved car here.' }}</p>
      <BngButton accent="base" data-workshop-recover :disabled="busy" @click="$emit('restore')">Restore saved car & stay in workshop</BngButton>
      <BngButton v-if="status.canRetryExit" accent="base" :disabled="busy" @click="$emit('retry')">Retry return to driving</BngButton>
      <BngButton accent="base" :disabled="busy" @click="$emit('abort')">Save paid build & return to main menu</BngButton>
      <p class="hint">Restoring removes unbought previews and cancels a pending exit. Purchases already saved remain yours. Back/Start keeps this screen paused.</p>
    </article>
  </section>
</template>
<script setup>
import { ref, nextTick, watch } from "vue"
import { BngButton } from "@/common/components/base"
import { vBngScopedNav, vBngOnUiNav } from "@/common/directives"
import { useScopedNav } from "@/services/scopedNav/api"
const props = defineProps({ status: { type: Object, required: true }, busy: Boolean })
defineEmits(["restore", "retry", "abort"])
const root = ref(null), nav = useScopedNav()
function keepPaused() { return false }
async function focusRecovery() {
  await nextTick()
  const target = root.value?.querySelector("[data-workshop-recover]:not(:disabled)")
  if (target) nav.requestScopeFocus("bngu-workshop-recovery", target)
}
watch(() => props.busy, busy => { if (!busy) focusRecovery() }, { immediate: true })
defineExpose({ focusRecovery })
</script>
<style scoped>
.workshop-recovery { position:absolute; inset:0; z-index:50; display:flex; align-items:center; justify-content:center; padding:2rem; background:#140d20e8; }
article { width:min(44rem,100%); max-height:85vh; overflow:auto; padding:2rem; background:#241a32; border:1px solid #9b759e; border-radius:.8rem; }
small { color:#8de6d9; letter-spacing:.08em; }h1 { font-size:1.7rem; }p { line-height:1.5; }.error { color:#ffbfb8; }.hint { color:#c5bad4; font-size:.85rem; }
article > :deep(.bng-button) { display:flex; width:100%; margin-top:.7rem; }
</style>
