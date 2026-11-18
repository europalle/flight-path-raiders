-- A small stand-in for the WoW client API, enough to load the addon in standard Lua 5.1 and drive it
-- headless: frames remember scripts and shown state, chat output is captured. Not a full emulator.
WOW_CHAT = {}
local function mock(name)
  local o = { _name = name, _scripts = {}, _shown = true, _points = {} }
  return setmetatable(o, { __index = function(t, k)
    return function(self, ...) return self end   -- any other method: accept and chain
  end })
end
local function frame(kind, name)
  local f = mock(name or kind)
  f._shown = true
  f.SetScript = function(self, ev, fn) self._scripts[ev] = fn end
  f.GetScript = function(self, ev) return self._scripts[ev] end
  f.Show = function(self) self._shown = true end
  f.Hide = function(self) self._shown = false end
  f.IsShown = function(self) return self._shown end
  f.CreateTexture = function() return mock("texture") end
  f.CreateFontString = function()
    local fs = mock("fontstring"); fs.SetText = function(s, t) s._text = t end; fs.GetText = function(s) return s._text end; return fs
  end
  f.SetPoint = function(self, ...) self._points[#self._points + 1] = { ... } end
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
CreateFrame = function(kind, name) return frame(kind, name) end
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
