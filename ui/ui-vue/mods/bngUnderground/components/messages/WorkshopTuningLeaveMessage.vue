<template>
  <div>
    <p>{{ carName }} · {{ changedCount }} unsaved {{ changedCount === 1 ? 'adjustment' : 'adjustments' }}.</p>
    <p>Save fits the whole previewed setup for free before continuing. Discard restores your saved setup; other builds keep theirs.</p>
    <p v-if="!canSave">The preview must finish before it can be saved. Keep editing to wait, or discard these adjustments.</p>
    <p>Back or Start keeps this draft open. Unbought parts and setups are restored before driving resumes.</p>
  </div>
</template>
<script setup>
defineProps({ carName: String, changedCount: Number, canSave: Boolean })
</script>
