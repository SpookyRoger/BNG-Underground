// Native subtab events are analog triggers. One pull selects one camera angle;
// noisy values or holding a trigger must not repeatedly cycle the views.
export function createTriggerLatch(pressAt = 0.55, releaseAt = 0.2) {
  let held = false
  return value => {
    const amount = Number(value)
    if (!Number.isFinite(amount)) return false
    if (amount <= releaseAt) held = false
    if (amount < pressAt || held) return false
    held = true
    return true
  }
}

export function wrapIndex(index, direction, count) {
  if (count < 1) return -1
  return ((Math.max(0, index) + direction) % count + count) % count
}

// Compare nested request payloads independently of Lua/JSON key ordering.
export function canonical(value) {
  return value && typeof value === "object" ? JSON.stringify(Object.keys(value).sort().map(key => [key, canonical(value[key])])) : JSON.stringify(value)
}
