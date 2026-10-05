// Wait for the saved native transaction, rather than treating a queued spawn as success.
export async function awaitTransaction(value, read, delay) {
  if (!value?.pending || typeof value.ticket !== "string") return value
  const ticket = value.ticket
  while (true) {
    const result = await read(ticket)
    if (!result?.pending) return result?.ok === true
    if (result.ticket !== ticket) return false
    await delay(200)
  }
}
