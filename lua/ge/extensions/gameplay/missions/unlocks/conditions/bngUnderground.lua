local function controller() return rawget(_G,'bngUnderground') end
return {
  bnguEvent={
    info='BNG Underground campaign progression',
    getLabel=function(c)
      local mod=controller()
      if not mod then return 'Start BNG Underground from its main-menu button.' end
      local ok,reason=mod.canEnter(c.eventId)
      return ok and 'BNG Underground: available' or reason
    end,
    conditionMet=function(c) local mod=controller();return mod and mod.canEnter(c.eventId) or false end
  },
  bnguOutsideCampaign={
    info='Stock challenges are unavailable during BNG Underground',hidden=true,
    getLabel=function() return 'Return to ordinary Freeroam for stock challenges.' end,
    conditionMet=function() local mod=controller();return not (mod and mod.isActive()) end
  },
  bnguVisible={
    info='Visible while this BNG Underground chapter is unlocked',hidden=true,
    getLabel=function() return 'BNG Underground' end,
    conditionMet=function(c) local mod=controller();return mod and mod.isEventVisible(c.eventId) or false end
  }
}
