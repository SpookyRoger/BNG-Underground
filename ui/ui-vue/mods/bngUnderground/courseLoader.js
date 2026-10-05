// One in-flight request and one latest selection; no route data enters the save.
export function createCourseLoader({ fetch, update, delay = 160, schedule = setTimeout, cancel = clearTimeout }) {
  const cached = new Map()
  let selected = null, revision = 0, queued = null, timer = null, busy = false, disposed = false
  async function flush() {
    if (disposed || busy || !queued) return
    const request = queued; queued = null; busy = true
    try {
      const data = await fetch(request.id)
      if (disposed || request.revision !== revision || request.id !== selected) return
      if (!data || data.eventId !== request.id || typeof data.available !== "boolean") throw new Error("Course outline is not ready. You can retry or set GPS.")
      if (data.available && (!Array.isArray(data.points) || data.points.length < 2 || !["road", "checkpoints"].includes(data.mode) || !data.points.every(point => Array.isArray(point) && Number.isFinite(point[0]) && Number.isFinite(point[1])))) throw new Error("Course outline is not ready. You can retry or set GPS.")
      if (data.available || !data.retryable) cached.set(request.id, data)
      update({ ...data, status: "ready" })
    } catch (error) {
      if (!disposed && request.revision === revision && request.id === selected) update({ eventId: request.id, status: "error", available: false, points: [], retryable: true, reason: String(error?.message || error || "Course outline unavailable.") })
    } finally {
      busy = false
      if (!disposed && queued && timer === null) flush()
    }
  }
  function select(id, force = false) {
    if (disposed) return
    selected = id || null; revision++; queued = null
    if (timer !== null) cancel(timer)
    timer = null
    if (!selected) { update({ status: "idle", available: false, points: [] }); return }
    if (force) cached.delete(selected)
    if (cached.has(selected)) { update({ ...cached.get(selected), status: "ready" }); return }
    update({ eventId: selected, status: "loading", available: false, points: [] })
    queued = { id: selected, revision }
    timer = schedule(() => { timer = null; flush() }, delay)
  }
  function dispose() { disposed = true; revision++; queued = null; if (timer !== null) cancel(timer); timer = null; cached.clear() }
  return { select, retry: () => select(selected, true), dispose }
}
