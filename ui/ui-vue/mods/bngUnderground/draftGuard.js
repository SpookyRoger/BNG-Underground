// Presentation-only coordinator. Native UI and campaign commands are injected.
export function createDraftGuard({ getDraft, isBusy, isCurrent, confirm, apply, discard, focus, notify, onActive }) {
  let active = false, disposed = false, popup = null
  async function run(next, { allowApply = true } = {}) {
    if (disposed || active || isBusy()) return false
    const draft = getDraft()
    if (!draft?.dirty) { await next(); return true }
    active = true; onActive(true)
    let continued = false
    try {
      popup = confirm(draft, allowApply)
      const choice = await popup
      popup = null
      if (disposed) return false
      if (choice !== "apply" && choice !== "discard") return false
      if (isBusy()) return false
      if (!isCurrent(draft)) { notify("The fitted setup changed. Review Tuning before leaving."); return false }
      if (choice === "apply") {
        if (!allowApply || !draft.ready || !await apply(draft)) return false
      } else if (!discard(draft)) return false
      if (disposed) return false
      await next(); continued = true
      return true
    } catch (error) {
      if (!disposed && error) notify(String(error.message || error))
      return false
    } finally {
      popup = null; active = false
      if (!disposed) { onActive(false); if (!continued) await focus() }
    }
  }
  function dispose() { disposed = true; popup?.close?.("keep"); popup = null }
  return { run, dispose, get active() { return active } }
}
