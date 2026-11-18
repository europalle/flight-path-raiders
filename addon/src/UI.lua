-- Flight Path Raiders: a small immediate-mode UI on top of WoW frames.
-- A page is drawn by calling the widget functions in order every time it renders. Widgets come from a
-- per-container pool and are reused in the same order, so redrawing creates no new frames once a page
-- has been seen; anything not drawn this time is hidden. Coordinates are board units from the top-left
-- of the 960 x 540 board, the same grid as the hi-fi (ux/hifi), y going down.
local _, ns = ...
local UI = {}
ns.UI = UI

local FONT_HEAD = "Fonts\\FRIZQT__.TTF"
local FONT_BODY = "Fonts\\ARIALN.TTF"
local cur          -- container being drawn
UI.theme = "dark"

function UI.T() return ns.MEDIA.themes[UI.theme] end
local function col(c)
  if type(c) == "string" then c = UI.T()[c] or UI.T().ink end
  return c[1], c[2], c[3], c[4] or 1
end
UI.col = col
local function media(name) return ns.MEDIA.path .. name end
UI.media = media

-- A container is a frame with pools. begin() starts a redraw, finish() hides what wasn't used.
function UI.container(parent, level)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints(parent)
  if level then f:SetFrameLevel(level) end
  f.pools, f.used = {}, {}
  return f
end
function UI.begin(c) cur = c; for k in pairs(c.used) do c.used[k] = 0 end; c.focus = {}; c:Show() end
function UI.finish(c)
  for kind, list in pairs(c.pools) do
    for i = (c.used[kind] or 0) + 1, #list do list[i]:Hide() end
  end
end
local function acquire(kind, make)
  local list = cur.pools[kind]
  if not list then list = {}; cur.pools[kind] = list end
  local n = (cur.used[kind] or 0) + 1
  cur.used[kind] = n
  local w = list[n]
  if not w then w = make(); list[n] = w end
  w:Show()
  return w
end
local function place(w, x, y, width, height)
  w:ClearAllPoints()
  w:SetPoint("TOPLEFT", cur, "TOPLEFT", x, -y)
  if width then w:SetWidth(width) end
  if height then w:SetHeight(height) end
end

-- Text. opts: size, col, head (header font), w (width, for justify), justify ("LEFT", "CENTER", "RIGHT"), wrap.
function UI.text(x, y, s, opts)
  opts = opts or {}
  local fs = acquire("text", function() return cur:CreateFontString(nil, "OVERLAY") end)
  fs:SetFont(opts.head and FONT_HEAD or FONT_BODY, opts.size or 13, "")
  fs:SetTextColor(col(opts.col or "ink")); fs:SetAlpha(1)
  fs:SetJustifyH(opts.justify or "LEFT"); fs:SetJustifyV("TOP")
  fs:SetWordWrap(opts.wrap and true or false)
  -- Width 0 means "as wide as the text": pooled strings must not keep the width of their last use.
  place(fs, x, y, opts.w or 0, opts.wrap and opts.h or 0)
  fs:SetText(s)
  return fs
end
-- Draw order inside a container: big panel fills (BACKGROUND), row fills, rules, bars and tags, button
-- backgrounds (all BORDER, by sublevel), then art (ARTWORK) and text (OVERLAY). Button frames sit on top
-- but are see-through, so anything drawn on a button (a portrait, an icon) shows.
local Z = { scrim = { "BACKGROUND", -8 }, panel = { "BACKGROUND", 0 }, row = { "BORDER", -6 }, rule = { "BORDER", -2 },
            rect = { "BORDER", 0 }, barbg = { "BORDER", 1 }, bar = { "BORDER", 2 }, button = { "BORDER", 4 },
            plate = { "ARTWORK", 6 } }  -- plate: a solid box over art (a name on the stage)
function UI.rect(x, y, w, h, c, alpha, z)
  local t = acquire("rect", function() return cur:CreateTexture(nil, "BORDER") end)
  local zz = Z[z or "rect"]
  t:SetDrawLayer(zz[1], zz[2])
  local r, g, b, a = col(c)
  t:SetColorTexture(r, g, b, alpha or a)
  place(t, x, y, w, h)
  return t
end
function UI.tex(x, y, w, h, file, opts)
  opts = opts or {}
  local t = acquire("tex", function() return cur:CreateTexture(nil, "ARTWORK") end)
  t:SetTexture(media(file)); t:SetTexCoord(0, 1, 0, 1)
  t:SetDesaturated(opts.dim and true or false); t:SetAlpha(opts.dim and 0.5 or 1)
  t:SetVertexColor(1, 1, 1, 1)
  place(t, x, y, w, h)
  return t
end
function UI.icon(x, y, size, name, opts) return UI.tex(x, y, size, size, "icon-" .. name, opts) end
function UI.portrait(x, y, size, cls, look, dim) return UI.tex(x, y, size, size, "portrait-" .. cls .. "-" .. (look or 0) .. "-" .. UI.theme, { dim = dim }) end
-- A panel: a fill with a 1-unit rule around it. The default panel is a page-level box; other fills are rows inside one.
function UI.panel(x, y, w, h, fill, rule, corners)
  UI.rect(x, y, w, h, fill or "panel", nil, (fill == nil or fill == "panel") and "panel" or "row")
  local r = rule or "rule"
  UI.rect(x, y, w, 1, r, nil, "rule"); UI.rect(x, y + h - 1, w, 1, r, nil, "rule")
  UI.rect(x, y, 1, h, r, nil, "rule"); UI.rect(x + w - 1, y, 1, h, r, nil, "rule")
  if corners then  -- ornaments sit inside the panel, never across its edge
    local s, i = 16, 2
    UI.tex(x + i, y + i, s, s, "orn-1-" .. UI.theme); UI.tex(x + w - s - i, y + i, s, s, "orn-2-" .. UI.theme)
    UI.tex(x + i, y + h - s - i, s, s, "orn-3-" .. UI.theme); UI.tex(x + w - s - i, y + h - s - i, s, s, "orn-4-" .. UI.theme)
  end
end
function UI.bar(x, y, w, h, frac, c)
  UI.rect(x, y, w, h, "barbg", nil, "barbg")
  if frac > 0 then UI.rect(x, y, math.max(2, w * math.min(1, frac)), h, c or "bar", nil, "bar") end
end
function UI.scrim(w, h) UI.rect(0, 0, w, h, "scrim", nil, "scrim") end

-- Buttons. kind: normal, selected, primary, row (invisible until hovered, for clickable rows and cards).
-- A disabled button greys out and ignores clicks; `tip` shows as a tooltip and is how disabled buttons say why.
function UI.button(x, y, w, h, label, onClick, opts)
  opts = opts or {}
  local kind = opts.kind or "normal"
  if kind ~= "row" then
    -- 3-slice: end caps keep their shape (half the height wide), the middle stretches.
    local cap = math.min(h / 2, w / 2)
    local parts = { { "l", x, cap }, { "m", x + cap, w - 2 * cap }, { "r", x + w - cap, cap } }
    for _, pt in ipairs(parts) do
      if pt[3] > 0 then
        local t = acquire("btnbg", function() return cur:CreateTexture(nil, "BORDER") end)
        t:SetDrawLayer("BORDER", 4)
        t:SetTexture(media("btn-" .. kind .. "-" .. UI.theme .. "-" .. pt[1])); t:SetTexCoord(0, 1, 0, 1)
        t:SetDesaturated(opts.disabled and true or false); t:SetVertexColor(1, 1, 1, opts.disabled and 0.7 or 1)
        place(t, pt[2], y, pt[3], h)
      end
    end
  end
  if label and label ~= "" then
    local size = opts.size or (kind == "primary" and 18 or 13)
    local tc = kind == "primary" and "ptext" or kind == "selected" and "seltext" or "ink"
    local fs = UI.text(x + 4, y + h / 2 - size * 0.62, label, { size = size, head = kind == "primary", col = tc, w = w - 8, justify = "CENTER" })
    if opts.disabled then fs:SetAlpha(0.5) else fs:SetAlpha(1) end
  end
  if opts.icon then UI.icon(x + w / 2 - 9, y + h / 2 - 9, 18, opts.icon) end
  local b = acquire("button", function()
    local b = CreateFrame("Button", nil, cur)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(b); b.hl:SetColorTexture(1, 0.85, 0.5, 0.12)
    -- Keyboard focus ring: four 2-unit edges in the accent colour, shown by Board's Tab handling.
    b.ring = {}
    for i = 1, 4 do b.ring[i] = b:CreateTexture(nil, "OVERLAY") end
    b.ring[1]:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2); b.ring[1]:SetPoint("TOPRIGHT", b, "TOPRIGHT", 2, 2); b.ring[1]:SetHeight(2)
    b.ring[2]:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -2, -2); b.ring[2]:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2); b.ring[2]:SetHeight(2)
    b.ring[3]:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2); b.ring[3]:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -2, -2); b.ring[3]:SetWidth(2)
    b.ring[4]:SetPoint("TOPRIGHT", b, "TOPRIGHT", 2, 2); b.ring[4]:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2); b.ring[4]:SetWidth(2)
    function b.SetFocus(self, on)
      local r, g, bl = col("accent")
      for i = 1, 4 do self.ring[i]:SetColorTexture(r, g, bl, 1); if on then self.ring[i]:Show() else self.ring[i]:Hide() end end
    end
    b:SetScript("OnClick", function(self) if self.enabled and self.fn then self.fn() end end)
    b:SetScript("OnEnter", function(self)
      if not self.tip then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(self.tip, 1, 1, 1, 1, true); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end)
  place(b, x, y, w, h)
  b:SetFrameLevel(cur:GetFrameLevel() + 2)
  b.fn, b.tip, b.enabled = onClick, opts.tip, not opts.disabled
  b.labelText = label  -- for the headless tests
  b:SetFocus(false)
  -- Anything that does something, or explains why it can't, can take keyboard focus.
  if onClick or opts.tip then cur.focus[#cur.focus + 1] = b end
  return b
end

-- Small helpers used across pages.
function UI.money(n) local s = tostring(math.floor(n)); local k; repeat s, k = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2") until k == 0; return s end
function UI.title(s) return (string.gsub(s, "^%l", string.upper)) end
function UI.moraleCol(m) return m < 20 and "bad" or m < 40 and "warn" or m >= 80 and "good" or "ink" end
