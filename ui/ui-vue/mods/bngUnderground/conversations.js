// Read-only grouping over saved inbox order. Sender selection has no read side effect.
export function contacts(messages) {
  const rows = [], bySender = new Map()
  for (const message of messages) {
    let row = bySender.get(message.sender)
    if (!row) { row = { sender: message.sender, count: 0, unread: 0, latest: message }; bySender.set(message.sender, row); rows.push(row) }
    row.count++; if (!message.read) row.unread++
  }
  return rows
}
export function conversation(messages, sender = null, unreadOnly = false) {
  return messages.filter(message => (sender === null || message.sender === sender) && (!unreadOnly || !message.read))
}
export function unreadIds(messages, sender = null) { return conversation(messages, sender, true).map(message => message.id) }
