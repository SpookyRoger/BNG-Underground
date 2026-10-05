import { lua } from "@/bridge"
import Launcher from "./Launcher.vue"
import Board from "./Board.vue"
import Workshop from "./Workshop.vue"
import { installMenuShortcut } from "./menuShortcut.js"

const sourceId = "bngUnderground.routes"
let removeShortcut
const routes = [{
  path: "/bng-underground",
  name: "bngUnderground.launcher",
  component: Launcher,
  meta: {
    uiTypes: ["vue"],
    uiTypesFilter: "only",
    uiApps: { shown: false },
    topBar: { visible: false },
    luaRoute: {
      title: "BNG Underground", backTarget: "menu",
      scopeTree: { "bngu-launcher": { preferAutoFocus: true, backTargetType: "route" } },
      onEnter: "bngUnderground.onMenuEnter", onLeave: "bngUnderground.onMenuLeave",
    },
  },
}, {
  path: "/bng-underground/board",
  name: "bngUnderground.board",
  component: Board,
  meta: {
    uiTypes: ["vue"], uiTypesFilter: "only",
    uiApps: { shown: false }, topBar: { visible: false },
    luaRoute: {
      title: "BNG Underground", backTarget: "play",
      scopeTree: { "bngu-board": { preferAutoFocus: true, backTargetType: "route" } },
      onEnter: "bngUnderground.onBoardEnter", onLeave: "bngUnderground.onBoardLeave",
    },
  },
}, {
  path: "/bng-underground/workshop",
  name: "bngUnderground.workshop",
  component: Workshop,
  meta: {
    uiTypes: ["vue"], uiTypesFilter: "only",
    uiApps: { shown: false }, topBar: { visible: false },
    luaRoute: {
      title: "BNG Underground workshop", backTarget: "play",
      scopeTree: { "bngu-workshop": { preferAutoFocus: true, backTargetType: "route" } },
      onEnter: "bngUnderground.onWorkshopEnter", onLeave: "bngUnderground.onWorkshopLeave",
    },
  },
}]

export async function onLoad() {
  await lua.extensions.load("bngUnderground")
  window.bngRoutes.add([{ path: sourceId, routes }])
  const result = await lua.extensions.ui_router_routeManager.registerModRoutes(
    sourceId,
    routes.map(({ name, path, meta }) => ({ name, path, meta })),
  )
  if (!result?.success) {
    window.bngRoutes.remove([sourceId])
    throw new Error("BNG Underground launch screen registration failed: " + JSON.stringify(result?.errors || result))
  }
  await lua.extensions.ui_pause_actions.registerModButton({
    id: "bngUnderground.board",
    tabId: "mods",
    label: "BNG Underground",
    icon: "AIRace",
    componentName: "/ui/ui-vue/mods/bngUnderground/PauseCard.vue",
  })
  removeShortcut = installMenuShortcut()
}

export async function onUnload() {
  removeShortcut?.()
  removeShortcut = null
  await lua.extensions.ui_pause_actions.unregisterModButton("bngUnderground.board")
  window.bngRoutes.remove([sourceId])
  await lua.extensions.ui_router_routeManager.unregisterModRoutes(sourceId, { fallbackRoute: "menu" })
}
