<template>
  <div>
    <p>{{ carName }} / {{ buildName }}</p>
    <p>{{ changedCount }} unsaved {{ changedCount === 1 ? 'adjustment' : 'adjustments' }}.</p>
    <p v-if="allowApply">Apply fits every changed group together before continuing. Discard keeps the saved setup.</p>
    <p v-else>Restoring hardware discards the draft and removes saved adjustments from this build. Other builds retain their setups.</p>
    <p v-if="allowApply && !canApply">Applying requires stopped access at a physical workshop. Keep editing to retain this draft.</p>
    <p>Back or Start keeps your changes here.</p>
  </div>
</template>
<script setup>
defineProps({ carName: String, buildName: String, changedCount: Number, canApply: Boolean, allowApply: Boolean })
</script>
