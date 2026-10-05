import { useBridge } from "@/bridge"
import { requestState, showBoard } from "./campaignApi.js"

// Capture the native Start/Escape event before the stock body-level menu handler.
// Scope this to campaign driving; native missions and other game modes retain theirs.
export function installMenuShortcut() {
  const { events, lua } = useBridge()
  let campaign = { active: false, busy: false }, route = "menu", opening = false
  const receiveState = value => {
    campaign = value || { active: false }
    if (campaign.active && route === "menu") route = campaign.modal ? "bngUnderground.board" : "play"
  }
  const receiveRoute = value => {
    route = value?.resolved?.name || value?.request?.name || value?.toRoute?.name || route
  }
  const handle = event => {
    if (event.detail?.name === "menu" && event.detail?.value === 1 && campaign.loading) {
      event.preventDefault(); event.stopImmediatePropagation(); return
    }
    if (event.detail?.name !== "menu" || event.detail?.value !== 1 || route !== "play" || !campaign.active || campaign.busy) return
    event.preventDefault()
    event.stopImmediatePropagation()
    if (opening) return
    opening = true
    showBoard("city").then(ok => {
      if (!ok && !campaign.loading) lua.extensions.ui_router.navigate("pause", null, {})
    }).catch(() => { if (!campaign.loading) lua.extensions.ui_router.navigate("pause", null, {}) }).finally(() => { opening = false })
  }
  events.on("BNGUState", receiveState)
  events.on("ui_router_routeChange", receiveRoute)
  events.on("ui_router_routeRefresh", receiveRoute)
  document.addEventListener("ui_nav", handle, true)
  requestState().then(receiveState).catch(() => {})
  return () => {
    document.removeEventListener("ui_nav", handle, true)
    events.off("BNGUState", receiveState)
    events.off("ui_router_routeChange", receiveRoute)
    events.off("ui_router_routeRefresh", receiveRoute)
  }
}
