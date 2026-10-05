<template>
  <section ref="root" class="bngu-messages-page">
    <header class="bngu-page-heading"><small>WORD ON THE STREET</small><h1>Messages.</h1><p>{{ messages.length }} messages · {{ totalUnread }} unread</p></header>
    <div v-if="!message" class="bngu-tabs"><BngButton accent="base" data-bngu-inbox-tab :class="{ selected: tab === 'messages' }" :aria-pressed="tab === 'messages'" @click="setTab('messages')">Inbox</BngButton><BngButton accent="base" :class="{ selected: tab === 'ledger' }" :aria-pressed="tab === 'ledger'" @click="setTab('ledger')">Account history</BngButton></div>
    <div v-if="message" class="bngu-message-detail bngu-message-scroll" bng-nav-scroll>
      <BngButton accent="base" data-bngu-message-back @click="back">← Back to {{ selectedSender === null ? 'messages' : selectedSender }}</BngButton>
      <article class="bngu-message-full"><small>{{ message.sender }} · {{ message.read ? 'READ' : 'NEW MESSAGE' }}</small><h2>{{ message.title }}</h2><p>{{ message.text }}</p><div class="bngu-actions"><BngButton v-if="!message.read" accent="base" :disabled="state.busy" @click="markRead(message)">Mark as read</BngButton><BngButton v-if="invitedEvent" accent="base" :disabled="state.busy || !invitedEvent.unlocked" @click="$emit('event', invitedEvent.id)">View {{ invitedEvent.name }} on map</BngButton><BngButton v-if="invitedEvent" accent="base" :disabled="state.busy || !invitedEvent.unlocked" @click="$emit('command', 'navigateEvent', invitedEvent.id)">Set GPS to race</BngButton><BngButton v-if="message.locationId" accent="base" :disabled="state.busy" @click="$emit('command', 'navigateLocation', message.locationId)">Set GPS to {{ invitedLocation?.name || 'location' }}</BngButton></div><p v-if="invitedEvent && !invitedEvent.unlocked">{{ invitedEvent.lockReason }}</p><p v-if="invitedEvent" class="bngu-muted">Invitations are optional. Other open races remain available.</p></article>
    </div>
    <div v-else-if="tab === 'messages'" class="bngu-messages-columns">
      <div class="bngu-contacts-list" bng-nav-scroll aria-label="Conversations">
        <BngButton accent="base" class="bngu-contact" data-bngu-contact-kind="all" :class="{ selected: selectedSender === null }" :aria-pressed="selectedSender === null" @focusin="scrollContact" @click="setSender(null)"><strong>All messages</strong><span>{{ messages.length }} messages · {{ totalUnread }} unread</span></BngButton>
        <BngButton v-for="contact in senderList" :key="contact.sender" accent="base" class="bngu-contact" data-bngu-contact-kind="sender" :data-bngu-contact="contact.sender" :class="{ selected: selectedSender === contact.sender }" :aria-pressed="selectedSender === contact.sender" @focusin="scrollContact" @click="setSender(contact.sender)"><strong>{{ contact.sender }}<span v-if="contact.unread" class="bngu-unread-badge">{{ contact.unread }} NEW</span></strong><span class="bngu-contact-preview">{{ contact.latest.title }}</span><span>{{ contact.count }} messages · {{ contact.unread }} unread</span></BngButton>
      </div>
      <div class="bngu-conversation-pane">
        <header class="bngu-conversation-heading"><h2>{{ selectedSender === null ? 'All messages' : selectedSender }}</h2><p>{{ visibleMessages.length }} {{ unreadOnly ? 'unread' : 'messages' }} · newest first</p><div class="bngu-conversation-actions"><BngButton accent="base" data-bngu-unread-filter :aria-pressed="unreadOnly" :class="{ selected: unreadOnly }" @click="setUnreadOnly(!unreadOnly)">{{ unreadOnly ? 'Show all messages' : 'Unread only' }}</BngButton><BngButton accent="base" :disabled="state.busy || !unreadTargets.length" @click="markConversationRead">{{ selectedSender === null ? 'Mark all messages read' : 'Mark conversation read' }} · {{ unreadTargets.length }}</BngButton></div></header>
        <div class="bngu-message-scroll" bng-nav-scroll aria-label="Message previews">
          <article v-for="entry in visibleMessages" :key="entry.id" class="bngu-message-row" :class="{ unread: !entry.read }">
            <BngButton accent="base" class="bngu-message-preview" :data-bngu-message="entry.id" @focusin="scrollPreview" @click="openMessage(entry)"><span class="bngu-message-avatar" aria-hidden="true">{{ entry.sender?.slice(0, 1) || '?' }}</span><span class="bngu-message-copy"><span class="bngu-message-sender">{{ entry.sender }}<span v-if="!entry.read" class="bngu-unread-badge">NEW</span></span><strong>{{ entry.title }}</strong><span class="bngu-message-text">{{ preview(entry.text) }}</span></span><span class="bngu-message-open" aria-hidden="true">→</span></BngButton>
            <BngButton accent="base" class="bngu-message-read" :data-bngu-mark-message="entry.id" :disabled="state.busy || entry.read" @click="markRead(entry)">{{ entry.read ? 'Read ✓' : 'Mark as read' }}</BngButton>
          </article>
          <div v-if="!visibleMessages.length" class="bngu-message-empty"><h2>{{ unreadOnly ? 'You’re caught up.' : 'No messages yet.' }}</h2><p>{{ unreadOnly ? 'Read messages are still available. Show all messages or choose another conversation.' : 'Your contacts will be in touch as you explore and race.' }}</p><BngButton v-if="unreadOnly" accent="base" @click="setUnreadOnly(false)">Show all messages</BngButton></div>
        </div>
      </div>
    </div>
    <div v-else class="bngu-message-scroll" bng-nav-scroll><h2>Account history</h2><div class="bngu-ledger"><div v-for="(entry, row) in visibleLedger" :key="row"><span>{{ entry.reason }}</span><strong>{{ entry.amount < 0 ? '−' : '+' }}{{ money(Math.abs(entry.amount)) }}</strong></div></div><div class="bngu-pagination"><BngButton accent="base" data-bngu-ledger-page :disabled="ledgerPage === 0" @click="setLedgerPage(ledgerPage - 1)">Newer transactions</BngButton><span>{{ ledgerPage + 1 }} / {{ ledgerPages }}</span><BngButton accent="base" data-bngu-ledger-page :disabled="ledgerPage + 1 >= ledgerPages" @click="setLedgerPage(ledgerPage + 1)">Older transactions</BngButton></div></div>
    <p class="bngu-message-hint">{{ message ? 'BACK · RETURN TO CONVERSATION   /   RIGHT STICK · SCROLL' : tab === 'ledger' ? 'CONFIRM · CHANGE PAGE   /   BACK · RETURN TO INBOX' : 'D-PAD · BROWSE   /   CONFIRM · OPEN   /   RIGHT STICK · SCROLL' }}</p>
  </section>
</template>
<script setup>
import { ref, computed, watch, nextTick } from "vue"
import { BngButton } from "@/common/components/base"
import { useScopedNav } from "@/services/scopedNav/api"
import { array, money } from "../presentation.js"
import { contacts, conversation, unreadIds } from "../conversations.js"
const props = defineProps({ state: { type: Object, required: true } })
const emit = defineEmits(["command", "event"])
const root = ref(null), nav = useScopedNav(), selectedId = ref(null), lastOpenedId = ref(null), tab = ref("messages"), ledgerPage = ref(0)
const selectedSender = ref(null), unreadOnly = ref(false)
let restoreReadFocus = null
const messages = computed(() => array(props.state.inbox))
const senderList = computed(() => contacts(messages.value))
const totalUnread = computed(() => unreadIds(messages.value).length)
const visibleMessages = computed(() => conversation(messages.value, selectedSender.value, unreadOnly.value))
const unreadTargets = computed(() => unreadIds(messages.value, selectedSender.value))
const message = computed(() => messages.value.find(entry => entry.id === selectedId.value))
const invitedEvent = computed(() => array(props.state.eventList).find(event => event.id === message.value?.eventId))
const invitedLocation = computed(() => array(props.state.locations).find(site => site.id === message.value?.locationId))
const ledger = computed(() => array(props.state.ledger))
const ledgerPages = computed(() => Math.max(1, Math.ceil(ledger.value.length / 6)))
const visibleLedger = computed(() => ledger.value.slice(ledgerPage.value * 6, ledgerPage.value * 6 + 6))
function preview(text = "") {
  if (text.length <= 360) return text
  const shortened = text.slice(0, 360)
  const space = shortened.lastIndexOf(" ")
  return shortened.slice(0, space > 300 ? space : 360).trimEnd() + "…"
}
function scrollPreview(event) { event.currentTarget.closest(".bngu-message-row").scrollIntoView({ block: "nearest", inline: "nearest" }) }
function scrollContact(event) { event.currentTarget.scrollIntoView({ block: "nearest", inline: "nearest" }) }
function focusContact() {
  const buttons = Array.from(root.value?.querySelectorAll("[data-bngu-contact-kind]") || [])
  const target = buttons.find(element => selectedSender.value === null
    ? element.getAttribute("data-bngu-contact-kind") === "all"
    : element.getAttribute("data-bngu-contact-kind") === "sender" && element.getAttribute("data-bngu-contact") === selectedSender.value) || buttons[0]
  if (target) { target.scrollIntoView({ block: "nearest", inline: "nearest" }); nav.requestScopeFocus("bngu-board", target) }
}
function focusSelection(id = lastOpenedId.value) {
  if (!root.value) return
  if (message.value) { nav.requestScopeFocus("bngu-board", root.value.querySelector("[data-bngu-message-back]")); return }
  if (tab.value === "ledger") {
    const target = root.value.querySelector("[data-bngu-ledger-page]:not(:disabled)") || root.value.querySelector("[data-bngu-inbox-tab]")
    if (target) nav.requestScopeFocus("bngu-board", target)
    return
  }
  const buttons = Array.from(root.value.querySelectorAll("[data-bngu-message]"))
  const target = buttons.find(element => element.getAttribute("data-bngu-message") === id) || buttons[0]
  if (target) {
    target.closest(".bngu-message-row").scrollIntoView({ block: "nearest", inline: "nearest" })
    nav.requestScopeFocus("bngu-board", target)
  } else focusContact()
}
async function openMessage(entry) {
  restoreReadFocus = null
  selectedId.value = entry.id; lastOpenedId.value = entry.id
  if (!entry.read && !props.state.busy) emit("command", "readMessage", entry.id)
  await nextTick(); focusSelection()
}
function markRead(entry) {
  if (props.state.busy || entry.read) return
  restoreReadFocus = { id: entry.id, sender: selectedSender.value }
  emit("command", "readMessage", entry.id)
}
function markConversationRead() {
  if (props.state.busy || !unreadTargets.value.length) return
  const ids = [...unreadTargets.value]
  restoreReadFocus = { id: lastOpenedId.value, sender: selectedSender.value }
  emit("command", "readMessages", ids)
}
async function setSender(sender) {
  restoreReadFocus = null
  selectedSender.value = sender; selectedId.value = null
  await nextTick(); focusSelection()
}
async function setUnreadOnly(value) {
  restoreReadFocus = null; unreadOnly.value = value
  await nextTick(); focusSelection()
}
async function setTab(value) { restoreReadFocus = null; tab.value = value; await nextTick(); focusSelection() }
async function setLedgerPage(value) { ledgerPage.value = Math.max(0, Math.min(ledgerPages.value - 1, value)); await nextTick(); focusSelection() }
function back() {
  if (!selectedId.value && tab.value === "messages") return false
  selectedId.value = null; tab.value = "messages"
  nextTick(() => focusSelection())
  return true
}
// A read may disable a button or remove its unread row. Focus a surviving preview or contact.
watch(() => props.state.busy, (busy, previous) => {
  if (!busy && previous && restoreReadFocus) {
    const target = restoreReadFocus; restoreReadFocus = null
    if (tab.value === "messages" && target.sender === selectedSender.value) nextTick(() => focusSelection(target.id))
  }
})
// Saved history is bounded. Keep filters and details valid when an older entry is trimmed.
watch(messages, () => {
  let changed = false
  if (selectedSender.value !== null && !senderList.value.some(contact => contact.sender === selectedSender.value)) { selectedSender.value = null; changed = true }
  if (selectedId.value && !message.value) { selectedId.value = null; changed = true }
  if (changed && tab.value === "messages") nextTick(() => focusSelection())
})
watch(ledgerPages, pages => { if (ledgerPage.value >= pages) { ledgerPage.value = pages - 1; if (tab.value === "ledger") nextTick(() => focusSelection()) } })
defineExpose({ back, focusSelection })
</script>
