<template>
  <section ref="root" class="bngu-car-change" role="status" v-bng-scoped-nav="{ scopeId: 'bngu-car-change', activateOnMount: true, preferAutoFocus: true, trapPolicy: 'always', canDeactivate: keepPaused }" v-bng-on-ui-nav:menu="keepPaused">
    <article><small>GAME PAUSED · YOUR SAVED GARAGE IS PROTECTED</small><h1>{{ status.label }}</h1>
      <p>{{ status.restoring ? 'Restoring and positioning the paid car before the menu can continue.' : 'Waiting for BeamNG to initialize and position your car. The change saves only when it is ready.' }}</p>
      <template v-if="status.phase === 'fault'"><p class="error">{{ status.error }}</p><p>You can keep waiting for a late reply, restore the saved car, or return to the main menu with the paid garage. Back/Start keeps this screen paused.</p>
        <BngButton accent="base" data-car-change-recovery :disabled="recovering" @click="$emit('restore')">Restore saved car · discard change</BngButton>
        <BngButton accent="base" :disabled="recovering" @click="$emit('abort')">Keep paid garage & return to main menu</BngButton>
      </template>
      <p v-else>Preparation is still running. Gameplay inputs are captured until the car is ready.</p>
    </article>
  </section>
</template>
<script setup>
import { ref, watch, nextTick } from "vue"
import { BngButton } from "@/common/components/base"
import { vBngScopedNav, vBngOnUiNav } from "@/common/directives"
import { useScopedNav } from "@/services/scopedNav/api"
const props = defineProps({ status: { type: Object, required: true }, recovering: Boolean })
defineEmits(["restore", "abort"])
const root = ref(null), nav = useScopedNav()
function keepPaused() { return false }
watch(() => [props.status.phase, props.recovering], async ([phase, recovering]) => {
  if (phase !== "fault" || recovering) return
  await nextTick();const target = root.value?.querySelector("[data-car-change-recovery]:not(:disabled)")
  if (target) nav.requestScopeFocus("bngu-car-change", target)
}, { immediate: true })
</script>
<style scoped>
.bngu-car-change { position: absolute; inset: 0; z-index: 50; display: flex; justify-content: center; align-items: center; padding: 2rem; background: #130d20f5; }
article { width: min(42rem,100%); max-height: 90vh; overflow: auto; padding: 2rem; background: #241a32; border: 1px solid #8e71ab; border-radius: .8rem; }small { color: #8de6d9; letter-spacing: .08em; }h1 { font-size: 1.8rem; }p { line-height: 1.5; }.error { color: #ffbfb8; }article > :deep(.bng-button) { display: flex; width: 100%; margin-top: .7rem; }
</style>
