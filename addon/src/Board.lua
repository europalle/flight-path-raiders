-- Flight Path Raiders: the board window. 960 x 540 UI units (16:9), scaled 70-120% on top of a default
-- of about 70% of the screen width (UX, 2026-11-18). Movable; position, scale and theme saved per account.
-- The board draws the chrome (border, title bar, tabs, purse) and routes to a page in ns.Pages.
-- Nothing runs while it is closed: playback's OnUpdate is only set while a pull is playing.
local _, ns = ...
local Board = {}
ns.Board = Board
ns.Pages = ns.Pages or {}

local W, H = 960, 540
local TABS = { { "Hub", 24, 87 }, { "Roster", 119, 108 }, { "Tavern", 235, 108 }, { "Journal", 351, 115 } }
local frame, chrome, body, modal
Board.page, Board.args = "Hub", {}

local function theme()
  local t = ns.db and ns.db.settings.theme or "auto"
  if t == "auto" then
    local h = tonumber(date("%H")) or 12
    return (h >= 7 and h < 19) and "light" or "dark"   -- Auto follows the time of day (Settings)
  end
  return t
end
Board.themeNow = theme

function Board.State() return ns.Core.Guild() end

local function drawChrome()
  local UI = ns.UI
  UI.begin(chrome)
  frame.bg:SetTexture(UI.media("bg-" .. UI.theme), "REPEAT", "REPEAT")
  frame.bg:SetHorizTile(true); frame.bg:SetVertTile(true)
  -- Heavy border: edges, then corners on top.
  UI.tex(28, 0, W - 56, 14, "edge-h-" .. UI.theme); UI.tex(28, H - 14, W - 56, 14, "edge-h-" .. UI.theme)
  UI.tex(0, 28, 14, H - 56, "edge-v-" .. UI.theme); UI.tex(W - 14, 28, 14, H - 56, "edge-v-" .. UI.theme)
  UI.tex(0, 0, 34, 34, "corner-1-" .. UI.theme); UI.tex(W - 34, 0, 34, 34, "corner-2-" .. UI.theme)
  UI.tex(0, H - 34, 34, 34, "corner-3-" .. UI.theme); UI.tex(W - 34, H - 34, 34, 34, "corner-4-" .. UI.theme)
  -- Title bar.
  UI.button(26, 20, 196, 30, "", function() Board.Go("Hub") end, { kind = "row", tip = "Back to the hub" })
  UI.text(30, 24, "Flight Path Raiders", { head = true, size = 20 })
  UI.text(236, 28, "/ " .. (Board.crumb or Board.page), { size = 15, col = "muted" })
  UI.text(700, 30, math.floor((ns.db.settings.scale or 1) * 100 + 0.5) .. "%", { size = 12, col = "muted", w = 52, justify = "RIGHT" })
  UI.button(764, 20, 32, 32, "-", function() Board.SetScale((ns.db.settings.scale or 1) - 0.05) end, { tip = "Smaller" })
  UI.button(804, 20, 32, 32, "+", function() Board.SetScale((ns.db.settings.scale or 1) + 0.05) end, { tip = "Bigger" })
  UI.button(844, 20, 32, 32, "", function() Board.Go("Settings") end, { tip = "Settings", icon = "gear" })
  UI.button(884, 20, 32, 32, "X", function() frame:Hide() end, { tip = "Close (Escape)" })
  -- Tabs and purse, on the pages that have them.
  if Board.tabs then
    for _, t in ipairs(TABS) do
      local on = Board.page == t[1]
      UI.button(t[2], 58, t[3], 34, t[1], function() ns.Audio.Play("tab"); Board.Go(t[1]) end, { kind = on and "selected" or "normal", size = 13.5 })
    end
    local st = Board.State()
    UI.text(614, 69, "Week " .. st.week, { size = 12.5, col = "muted", w = 120, justify = "RIGHT" })
    UI.icon(744, 67, 14, "coin"); UI.text(762, 69, UI.money(st.gold), { size = 12.5, w = 70 })
    UI.icon(838, 67, 14, "gem"); UI.text(856, 69, st.dkp .. " DKP", { size = 12.5, w = 80 })
  end
  UI.finish(chrome)
end

-- Draws the current page. Pages set Board.tabs (show tabs) and Board.crumb before drawing their body.
function Board.Render()
  if not frame or not frame:IsShown() then return end
  local UI = ns.UI
  UI.theme = theme()
  local page = ns.Pages[Board.page] or ns.Pages.Hub
  Board.tabs, Board.crumb = true, nil
  UI.begin(body)
  page(Board.State(), Board.args or {})
  UI.finish(body)
  drawChrome()
  if Board.modal then
    UI.begin(modal)
    UI.scrim(W, H)
    local keep = Board.modal(Board.State())   -- a window returns false when it has nothing left to show
    UI.finish(modal)
    if keep == false then Board.modal = nil; modal:Hide() end
  else
    modal:Hide()
  end
  Board.RefreshFocus()
end

-- Keyboard reach (gate check 5): Tab and Shift-Tab (or the arrow keys) move a focus ring through every
-- button in reading order, Enter or Space presses it, Escape closes a window and then the board.
-- Focus shows the button's tooltip, so a greyed-out button still says why. Keys the board doesn't use
-- pass through to the game; nothing changes in combat, where key handling is protected.
local focusIndex = 0
local function focusList()
  if Board.modal and modal:IsShown() then return modal.focus or {} end
  local list = {}
  for _, b in ipairs(chrome.focus or {}) do list[#list + 1] = b end
  for _, b in ipairs(body.focus or {}) do list[#list + 1] = b end
  return list
end
function Board.RefreshFocus()
  local list = focusList()
  for _, b in ipairs(list) do b:SetFocus(false) end
  if focusIndex > #list then focusIndex = #list end
  local b = list[focusIndex]
  if b then
    b:SetFocus(true)
    if b.tip then GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(b.tip, 1, 1, 1, 1, true); GameTooltip:Show() else GameTooltip:Hide() end
  end
  Board.focused = b
end
local MOVE = { TAB = 1, DOWN = 1, RIGHT = 1, UP = -1, LEFT = -1 }
local function onKey(self, key)
  local used = false
  local list = focusList()
  if MOVE[key] and (key == "TAB" or focusIndex > 0) and #list > 0 then
    local step = MOVE[key]
    if key == "TAB" and IsShiftKeyDown() then step = -1 end
    focusIndex = ((focusIndex - 1 + step) % #list) + 1
    Board.RefreshFocus(); used = true
  elseif (key == "ENTER" or key == "SPACE") and Board.focused then
    local b = Board.focused
    if b.enabled and b.fn then b.fn() end
    used = true
  elseif key == "ESCAPE" and Board.modal then
    Board.CloseModal(); used = true
  elseif key == "ESCAPE" then
    self:Hide(); used = true
  end
  if not InCombatLockdown() then self:SetPropagateKeyboardInput(not used) end
end


function Board.Go(page, args)
  focusIndex = 0  -- a new page starts focus from the top, so Tab always means "from the start"
  Board.StopPlayback()
  Board.page, Board.args, Board.modal = page, args or {}, nil
  Board.Render()
end
-- A window over the page (loot, confirmations). fn(st) draws it; Board.CloseModal() closes it.
function Board.OpenModal(fn) Board.modal = fn; focusIndex = 0; Board.Render() end
function Board.CloseModal() Board.modal = nil; focusIndex = 0; Board.Render() end
function Board.Toast(msg) Board.toast = msg; ns.Core.Print(msg) end

-- Playback ticks only while a pull is playing.
function Board.StartPlayback(fn) frame:SetScript("OnUpdate", fn) end
function Board.StopPlayback() if frame then frame:SetScript("OnUpdate", nil) end end

function Board.ApplyTheme() Board.Render() end
function Board.ApplyScale()
  if not frame then return end
  local fit = (UIParent:GetWidth() * 0.70) / W
  frame:SetScale(fit * (ns.db.settings.scale or 1))
end
function Board.SetScale(s)
  s = math.floor(s * 100 + 0.5) / 100
  if s < 0.7 or s > 1.2 then return end
  ns.db.settings.scale = s; Board.ApplyScale(); Board.Render()
end
function Board.ApplyPosition()
  if not frame then return end
  frame:ClearAllPoints()
  local p = ns.db.settings.point
  if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint("CENTER") end
end

local function build()
  frame = CreateFrame("Frame", "FlightPathRaidersBoard", UIParent)
  frame:SetSize(W, H)
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    ns.db.settings.point = { point, rel, x, y }
  end)
  frame:SetScript("OnHide", function() Board.StopPlayback() end)
  tinsert(UISpecialFrames, "FlightPathRaidersBoard")  -- Escape closes it, also when keyboard input is passed on
  frame:EnableKeyboard(true)
  frame:SetPropagateKeyboardInput(true)
  frame:SetScript("OnKeyDown", onKey)
  frame.bg = frame:CreateTexture(nil, "BACKGROUND"); frame.bg:SetAllPoints(frame)
  body = ns.UI.container(frame, frame:GetFrameLevel() + 1)
  chrome = ns.UI.container(frame, frame:GetFrameLevel() + 10)
  modal = ns.UI.container(frame, frame:GetFrameLevel() + 20)
  modal:EnableMouse(true)  -- the scrim swallows clicks meant for the page underneath
  Board.frame = frame
  Board.ApplyScale(); Board.ApplyPosition()
  frame:Hide()
end

function Board.Toggle()
  if not frame then build() end
  if frame:IsShown() then frame:Hide(); ns.Audio.Play("close") else frame:Show(); ns.Audio.Play("open"); Board.Render() end
end
function Board.Open(page)
  if not frame then build() end
  frame:Show(); Board.Go(page or Board.page)
end
