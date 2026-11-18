-- Flight Path Raiders: addon core. Namespace, saved data, slash commands.
local ADDON, ns = ...
ns.ADDON = ADDON
local Core = {}
ns.Core = Core

local SAVE_VERSION = 2
local DEFAULTS = {
  version = SAVE_VERSION,
  settings = { scale = 1.0, theme = "auto", point = nil, playback = "animated", speed = 1 },
  guild = nil,          -- the game state (engine/game.lua), created on first open; one guild per account (design doc)
}

local function copyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      copyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function Core.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffe0a040Flight Path Raiders:|r " .. tostring(msg))
end

-- Save data migrations: each step upgrades one version. Nothing is ever deleted silently.
local MIGRATIONS = {
  [1] = function(db) end,  -- 1 to 2: adds the guild (created on first open) and the playback speed (a default)
}

-- The guild, created the first time anyone asks for it. A guild from an older rules version is kept as-is;
-- engine/game.lua bumps st.v when a migration is needed.
function Core.Guild()
  if not ns.db.guild then
    ns.db.guild = ns.Game.NewGame(((time and time()) or 1) % 2147483646 + 1)
  end
  return ns.db.guild
end

local function loadSave()
  FlightPathRaidersDB = FlightPathRaidersDB or {}
  local db = FlightPathRaidersDB
  local v = db.version or SAVE_VERSION
  while v < SAVE_VERSION do
    local step = MIGRATIONS[v]
    if step then step(db) end
    v = v + 1
  end
  copyDefaults(DEFAULTS, db)
  db.version = SAVE_VERSION
  ns.db = db
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    loadSave()
    events:UnregisterEvent("ADDON_LOADED")
  end
end)

local function help()
  Core.Print("/fpr opens the board. /fpr selftest checks the combat engine. /fpr scale 70-120 sets the size. /fpr theme light|dark|auto. /fpr reset puts the board back in the middle.")
end

SLASH_FLIGHTPATHRAIDERS1 = "/fpr"
SLASH_FLIGHTPATHRAIDERS2 = "/flightpathraiders"
SlashCmdList.FLIGHTPATHRAIDERS = function(msg)
  local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")), 2)
  if cmd == "" or cmd == nil then
    ns.Board.Toggle()
  elseif cmd == "selftest" then
    ns.SelfTestRun()
  elseif cmd == "scale" then
    local n = tonumber(arg)
    if not n or n < 70 or n > 120 then return Core.Print("Scale is 70 to 120 (percent).") end
    ns.db.settings.scale = n / 100
    ns.Board.ApplyScale()
  elseif cmd == "theme" then
    if arg ~= "light" and arg ~= "dark" and arg ~= "auto" then return Core.Print("Theme is light, dark or auto.") end
    ns.db.settings.theme = arg
    ns.Board.ApplyTheme()
  elseif cmd == "reset" then
    ns.db.settings.point = nil
    ns.Board.ApplyPosition()
  else
    help()
  end
end
