-- A small stand-in for the WoW client API, enough to load the addon in standard Lua 5.1 and drive it
-- headless: frames remember scripts and shown state, chat output is captured. Not a full emulator.
WOW_CHAT = {}
local function mock(name)
  local o = { _name = name, _scripts = {}, _shown = true, _points = {} }
  return setmetatable(o, { __index = function(t, k)
    return function(self, ...) return self end   -- any other method: accept and chain
  end })
end
WOW_TEXTURES = {}  -- every texture path set, so tests can check the files exist
-- Layout calls are recorded (not just accepted) so tools/addon_shot.py can draw what the addon drew.
local function layout(o)
  o._points = {}
  o.SetPoint = function(self, ...) self._points[#self._points + 1] = { ... } end
  o.ClearAllPoints = function(self) self._points = {}; self._all = nil end
  o.SetAllPoints = function(self, t) self._all = t or rawget(self, "_parent") end
  o.SetWidth = function(self, w) self._w = w end
  o.SetHeight = function(self, h) self._h = h end
  o.SetSize = function(self, w, h) self._w, self._h = w, h end
  o.SetAlpha = function(self, a) self._alpha = a end
end
local function region(kind, parent, layer, sub)
  local r = mock(kind); r._parent = parent; r._shown = true; r._layer = layer; r._sub = sub or 0; layout(r)
  r.SetDrawLayer = function(self, l, s) self._layer = l; self._sub = s or 0 end
  r.SetColorTexture = function(self, a, b, c, d) self._color = { a, b, c, d or 1 }; self._path = nil end
  r.SetVertexColor = function(self, a, b, c, d) self._vertex = { a, b, c, d or 1 } end
  r.SetDesaturated = function(self, v) self._desat = v end
  r.SetFont = function(self, f, size) self._font, self._size = f, size end
  r.SetTextColor = function(self, a, b, c, d) self._textcol = { a, b, c, d or 1 } end
  r.SetJustifyH = function(self, j) self._justify = j end
  r.SetWordWrap = function(self, w) self._wrap = w end
  r.Show = function(self) self._shown = true end
  r.Hide = function(self) self._shown = false end
  r.IsShown = function(self) return self._shown end
  r.SetText = function(self, t) self._text = t end
  r.GetText = function(self) return self._text end
  r.SetTexture = function(self, path) if path then WOW_TEXTURES[path] = true end; self._path = path; self._color = nil end
  return r
end
local function frame(kind, name, parent)
  local f = mock(name or kind)
  f._shown = true; f._parent = parent; f._level = parent and ((rawget(parent, "_level") or 0) + 1) or 0; f._kind = kind
  layout(f); f._regions = {}
  f.SetScript = function(self, ev, fn) self._scripts[ev] = fn end
  f.GetScript = function(self, ev) return self._scripts[ev] end
  f.Show = function(self) self._shown = true end
  f.Hide = function(self) self._shown = false end
  f.IsShown = function(self) return self._shown end
  f.IsVisible = function(self) local x = self; while x do if not x._shown then return false end; x = rawget(x, "_parent") end; return true end
  f.SetPropagateKeyboardInput = function(self, v) self._propagate = v end
  f.GetFrameLevel = function(self) return self._level end
  f.SetFrameLevel = function(self, l) self._level = l end
  f.CreateTexture = function(self, _, layer, _, sub) local t = region("texture", self, layer, sub); f._regions[#f._regions + 1] = t; return t end
  f.CreateFontString = function(self, _, layer) local fs = region("fontstring", self, layer); WOW_FONTSTRINGS[#WOW_FONTSTRINGS + 1] = fs; f._regions[#f._regions + 1] = fs; return fs end
  f.GetPoint = function(self) return "CENTER", nil, "CENTER", 12, -34 end
  f.SetScale = function(self, s) self._scale = s end
  f.StartMoving = function() end
  f.StopMovingOrSizing = function() end
  f.RegisterEvent = function(self, e) local ev = rawget(self, '_events') or {}; rawset(self, '_events', ev); ev[e] = true end
  f.UnregisterEvent = function(self, e) local ev = rawget(self, '_events'); if ev then ev[e] = nil end end
  WOW_FRAMES = WOW_FRAMES or {}
  WOW_FRAMES[#WOW_FRAMES + 1] = f
  if name then _G[name] = f end
  return f
end
CreateFrame = function(kind, name, parent) return frame(kind, name, parent) end
WOW_FONTSTRINGS = {}
UIParent = frame("Frame", "UIParent"); UIParent.GetWidth = function() return 1920 end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) WOW_CHAT[#WOW_CHAT + 1] = m end }
UISpecialFrames = {}
SlashCmdList = {}
tinsert = table.insert
strlower = string.lower
strtrim = function(s) return (string.gsub(s, "^%s*(.-)%s*$", "%1")) end
strsplit = function(sep, s, n)
  local out, start = {}, 1
  while true do
    if n and #out == n - 1 then out[#out + 1] = string.sub(s, start); break end
    local i = string.find(s, sep, start, true)
    if not i then out[#out + 1] = string.sub(s, start); break end
    out[#out + 1] = string.sub(s, start, i - 1); start = i + 1
  end
  return unpack(out)
end
local clock = 0
debugprofilestop = function() clock = clock + 1; return os.clock() * 1000 end
function WOW_FIRE(event, ...)
  for i = 1, #WOW_FRAMES do
    local f = WOW_FRAMES[i]
    local ev = rawget(f, '_events'); if ev and ev[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
  end
end
time = os.time
date = os.date
GameTooltip = mock("GameTooltip")
-- Test helpers: every visible button and every visible text, as the player would see them.
function WOW_BUTTONS()
  local out = {}
  for _, f in ipairs(WOW_FRAMES) do
    if f._kind == "Button" and f:IsVisible() then out[#out + 1] = f end
  end
  return out
end
function WOW_CLICK(label)
  -- The topmost match wins, like a real click: a window's buttons sit above the page under its scrim.
  local best
  for _, b in ipairs(WOW_BUTTONS()) do
    if (rawget(b, "labelText") == label or rawget(b, "tip") == label) and (not best or b._level > best._level) then best = b end
  end
  if not best then return false, "no visible button " .. label end
  if not rawget(best, "enabled") then return false, "disabled: " .. tostring(rawget(best, "tip")) end
  best._scripts.OnClick(best); return true
end
function WOW_VISIBLE_TEXT()
  local out = {}
  for _, fs in ipairs(WOW_FONTSTRINGS) do
    local p = rawget(fs, "_parent")
    local t = rawget(fs, "_text")
    if fs._shown and type(t) == "string" and t ~= "" and (not p or p:IsVisible()) then out[#out + 1] = t end
  end
  return table.concat(out, "\n")
end
function WOW_TICK(seconds)
  local b = FlightPathRaidersBoard
  local fn = b and b._scripts.OnUpdate
  if fn then fn(b, seconds) end
  return fn ~= nil
end
IsShiftKeyDown = function() return WOW_SHIFT == true end
InCombatLockdown = function() return WOW_COMBAT == true end
-- Presses a key on the board, like the player would. Returns the label of the focused button after.
function WOW_KEY(key, shift)
  WOW_SHIFT = shift
  local b = FlightPathRaidersBoard
  b._scripts.OnKeyDown(b, key)
  WOW_SHIFT = false
  local f = FPR_NS.Board.focused
  return f and (rawget(f, "labelText") or rawget(f, "tip")) or nil
end
