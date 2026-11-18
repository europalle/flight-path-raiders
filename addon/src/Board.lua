-- Flight Path Raiders: the board window. 960 x 540 UI units (16:9), scaled 70-120% on top of a default
-- of about 70% of the screen width (UX, 2026-11-18). Movable; position and scale saved per account.
-- Textures and the real screens arrive with the hi-fi work; this is the frame they live in.
local _, ns = ...
local Board = {}
ns.Board = Board

local W, H = 960, 540
-- Theme tokens (art direction doc). Colours are 0-1 for SetColorTexture/SetTextColor.
local THEMES = {
  light = { paper = { 0.953, 0.925, 0.863 }, panel = { 0.984, 0.965, 0.918 }, ink = { 0.165, 0.129, 0.098 },
            muted = { 0.420, 0.365, 0.298 }, rule = { 0.847, 0.800, 0.702 }, accent = { 0.769, 0.290, 0.102 } },
  dark  = { paper = { 0.110, 0.122, 0.149 }, panel = { 0.145, 0.165, 0.200 }, ink = { 0.902, 0.882, 0.827 },
            muted = { 0.702, 0.678, 0.620 }, rule = { 0.227, 0.251, 0.298 }, accent = { 1.000, 0.541, 0.239 } },
}
local PAGES = { "Hub", "Roster", "Tavern", "Journal", "Guild" }
local frame, title, tabs, body, pageText

local function theme()
  local t = ns.db and ns.db.settings.theme or "auto"
  if t == "auto" then return "dark" end  -- WoW's own frames are dark; light is a choice
  return t
end

function Board.ApplyTheme()
  if not frame then return end
  local T = THEMES[theme()]
  frame.bg:SetColorTexture(T.paper[1], T.paper[2], T.paper[3], 0.97)
  body.bg:SetColorTexture(T.panel[1], T.panel[2], T.panel[3], 0.9)
  title:SetTextColor(T.ink[1], T.ink[2], T.ink[3])
  pageText:SetTextColor(T.muted[1], T.muted[2], T.muted[3])
  for i, tab in ipairs(tabs) do
    local c = (tab.page == Board.page) and T.accent or T.ink
    tab.label:SetTextColor(c[1], c[2], c[3])
    tab.line:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], (tab.page == Board.page) and 1 or 0)
  end
end

function Board.ApplyScale()
  if not frame then return end
  -- Default size: about 70% of the screen width at scale 1.0.
  local fit = (UIParent:GetWidth() * 0.70) / W
  frame:SetScale(fit * (ns.db.settings.scale or 1))
end

function Board.ApplyPosition()
  if not frame then return end
  frame:ClearAllPoints()
  local p = ns.db.settings.point
  if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint("CENTER") end
end

function Board.Show(page)
  Board.page = page or Board.page or "Hub"
  pageText:SetText(Board.page .. ": coming in the vertical slice. Try /fpr selftest.")
  Board.ApplyTheme()
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
  tinsert(UISpecialFrames, "FlightPathRaidersBoard")  -- Escape closes it
  frame.bg = frame:CreateTexture(nil, "BACKGROUND"); frame.bg:SetAllPoints()

  title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", 30, -22)
  title:SetText("Flight Path Raiders")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -8, -8)

  tabs = {}
  local x = 24
  for i, name in ipairs(PAGES) do
    local tab = CreateFrame("Button", nil, frame)
    tab:SetSize(110, 34); tab:SetPoint("TOPLEFT", x, -58); tab.page = name
    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); tab.label:SetPoint("CENTER"); tab.label:SetText(name)
    tab.line = tab:CreateTexture(nil, "ARTWORK"); tab.line:SetPoint("BOTTOMLEFT"); tab.line:SetPoint("BOTTOMRIGHT"); tab.line:SetHeight(3)
    tab:SetScript("OnClick", function() Board.Show(name) end)
    tabs[i] = tab
    x = x + 118
  end

  body = CreateFrame("Frame", nil, frame)
  body:SetPoint("TOPLEFT", 24, -102); body:SetPoint("BOTTOMRIGHT", -24, 24)
  body.bg = body:CreateTexture(nil, "BACKGROUND"); body.bg:SetAllPoints()
  pageText = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  pageText:SetPoint("CENTER")

  Board.ApplyScale(); Board.ApplyPosition()
  frame:Hide()
end

function Board.Toggle()
  if not frame then build() end
  if frame:IsShown() then frame:Hide() else frame:Show(); Board.Show() end
end
