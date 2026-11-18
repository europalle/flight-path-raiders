-- Flight Path Raiders: hub, roster, tavern, journal and settings. Layouts follow ux/hifi.
-- Every rule lives in engine/game.lua (ns.Game); pages only draw state and call it.
local _, ns = ...
local P = ns.Pages
local UI = ns.UI
local function G() return ns.Game end
local function B() return ns.Board end

local function confirm(text, yes, yesLabel)
  B().OpenModal(function()
    UI.panel(280, 200, 400, 140, "panel", "rule")
    UI.text(300, 222, text, { size = 14, w = 360, wrap = true, h = 60 })
    UI.button(300, 288, 170, 38, yesLabel or "Yes", function() B().CloseModal(); yes() end)
    UI.button(490, 288, 170, 38, "Cancel", function() B().CloseModal() end)
  end)
end
P.confirm = confirm

-- Which boss and mode to suggest next: the first one this week's lockout still has open.
local function nextTarget(st)
  for _, mode in ipairs({ "normal", "heroic" }) do
    for _, b in ipairs(G().BOSSES) do
      if G().unlocked(st, b.id, mode) then
        local p = st.progress[b.id]
        if not p[mode .. "Week"] then return b, mode end
      end
    end
  end
end
local function bossState(st, b)
  local p = st.progress[b.id]
  local n = p.normalWeek and "N done" or p.normalKills > 0 and "N open" or "N new"
  local h = not G().heroicOpen(st) and "H locked" or p.heroicWeek and "H done" or p.heroicWipes > 0 and ("H " .. p.heroicWipes .. " wipes") or "H open"
  return n .. " · " .. h
end
local function bossArt(x, y, w, h, b)
  if b.id == "ragnaroast" then UI.tex(x, y, w, h, "boss-ragnaroast")
  else UI.rect(x, y, w, h, "barbg"); UI.text(x, y + h / 2 - 14, string.sub(b.name, 1, 1), { head = true, size = 26, col = "muted", w = w, justify = "CENTER" }) end
end
P.bossArt = bossArt

-- ------------------------------------------------------------------ hub
function P.Hub(st)
  local g = G()
  local b, mode = nextTarget(st)
  UI.panel(24, 100, 912, 150)
  if b then
    bossArt(40, 114, 210, 122, b)
    local ready, benched = 0, 0
    for _, c in ipairs(st.roster) do if c.benched then benched = benched + 1 else ready = ready + 1 end end
    UI.text(270, 120, "Next: " .. b.name .. " (" .. g.MODES[mode].label .. ")", { head = true, size = 20 })
    UI.text(270, 150, "Boss " .. b.index .. " of 5 · " .. ready .. " ready" .. (benched > 0 and (", " .. benched .. " benched until reset") or ""), { size = 12.5, col = "muted" })
    local lp = st.lastPull
    if lp then UI.text(270, 172, "Last pull: " .. g.BOSS[lp.prep.boss].name .. ", " .. (lp.result == "kill" and "kill" or (lp.result .. ", boss at " .. lp.bossPct .. "%")) .. ".", { size = 12.5 }) end
    UI.button(756, 146, 162, 62, "Prep pull", function() B().Go("Prep", { boss = b.id, mode = mode }) end, { kind = "primary", size = 20 })
  else
    UI.text(270, 140, "Everything is dead this week.", { head = true, size = 20 })
    UI.text(270, 170, "End the week to reset the lockouts.", { size = 13, col = "muted" })
  end
  -- Raids: every boss, both modes.
  UI.text(24, 262, "The Molten Bore", { head = true, size = 16 })
  for i, bb in ipairs(g.BOSSES) do
    local y = 286 + (i - 1) * 40
    UI.panel(24, y, 440, 34, "row")
    UI.text(36, y + 10, bb.name, { size = 13 })
    UI.text(190, y + 11, bossState(st, bb), { size = 11.5, col = "muted" })
    local p = st.progress[bb.id]
    for k, m in ipairs({ "normal", "heroic" }) do
      local open = g.unlocked(st, bb.id, m)
      local done = m == "heroic" and p.heroicWeek
      local tip = not open and (m == "heroic" and "Kill Ragnaroast on Normal, then the bosses in order each week." or "Kill the boss before it first.") or done and "Dead on Heroic until the weekly reset." or nil
      UI.button(330 + (k - 1) * 66, y + 3, 60, 28, m == "normal" and "Normal" or "Heroic", function() B().Go("Prep", { boss = bb.id, mode = m }) end,
        { size = 11.5, disabled = not open or done, tip = tip })
    end
  end
  -- This week.
  UI.text(484, 262, "This week", { head = true, size = 16 })
  UI.button(484, 286, 220, 40, "Quick dungeon (" .. st.dungeonsLeft .. " left)", function()
    local o = g.Dungeon(st)
    if o.error then B().Toast(o.error) else B().Toast("Dungeon: +" .. o.gold .. " gold" .. (o.item and (", and " .. o.item.name .. " dropped") or "") .. ".") end
    B().Render()
  end, { disabled = st.dungeonsLeft <= 0, tip = "35-45 gold, sometimes a dungeon item" })
  local pend = #st.pending
  UI.button(712, 286, 224, 40, pend > 0 and ("Loot waiting: " .. pend) or "No loot waiting", function() P.LootWindow() end, { disabled = pend == 0 })
  UI.button(484, 334, 220, 40, "End the week", function()
    confirm("End week " .. st.week .. "? Lockouts reset, benched raiders come back, +300 gold from quests. Morale under 20 may quit.", function()
      g.EndWeek(st); B().Render() end, "End the week")
  end)
  UI.text(712, 346, "Heroic score: " .. UI.money(g.heroicScore(st)) .. " (best " .. UI.money(st.bestScore) .. ")", { size = 12, col = "muted", w = 224 })
  -- Low morale warning and recent news.
  local low = {}
  for _, c in ipairs(st.roster) do if c.morale < 40 then low[#low + 1] = c.name .. " " .. c.morale end end
  local y = 388
  if #low > 0 then
    UI.panel(484, y, 452, 40, "row", "warn"); UI.icon(494, y + 12, 16, "warn")
    UI.text(516, y + 8, #low .. " low on morale: " .. table.concat(low, ", "), { size = 12.5, w = 410 })
    UI.text(516, y + 24, "Under 20 they may quit at the end of the week.", { size = 11, col = "muted", w = 410 })
    y = y + 50
  end
  for i = math.max(1, #st.news - 2), #st.news do
    if y > 500 then break end
    UI.text(484, y, st.news[i], { size = 11.5, col = "muted", w = 452, wrap = true, h = 28 }); y = y + 28
  end
end

-- ------------------------------------------------------------------ roster
function P.Roster(st, args)
  local g = G()
  local sel = args.sel and g.byId(st, args.sel) or st.roster[1]
  local cols = { { 70, "Name" }, { 178, "Class · spec" }, { 342, "GL" }, { 374, "Morale" }, { 456, "Status" } }
  for _, c in ipairs(cols) do UI.text(c[1], 106, c[2], { size = 11, col = "muted" }) end
  for i, c in ipairs(st.roster) do
    local y = 122 + (i - 1) * 26
    local on = sel and c.id == sel.id
    UI.panel(24, y, 520, 24, "row", on and "accent" or "rule")
    UI.portrait(28, y + 1, 22, c.cls, c.look, c.benched)
    UI.text(70, y + 5, c.name, { size = 12.5, col = c.benched and "muted" or "ink" })
    UI.icon(178, y + 5, 14, "class-" .. c.cls)
    UI.text(196, y + 5, UI.title(c.cls) .. " · " .. g.specName(c.cls, c.spec), { size = 12, w = 142 })
    UI.text(342, y + 5, tostring(g.gearLevel(c)), { size = 12 })
    UI.bar(374, y + 9, 36, 7, c.morale / 100, UI.moraleCol(c.morale))
    UI.text(414, y + 5, tostring(c.morale), { size = 11.5, col = UI.moraleCol(c.morale) })
    if c.morale < 40 then UI.icon(440, y + 5, 13, "warn") end
    if c.benched then UI.rect(456, y + 4, 60, 16, "bad"); UI.text(456, y + 6, "Benched", { size = 11, col = "badtext", w = 60, justify = "CENTER" })
    else UI.text(456, y + 5, (st.week - c.joined < 2) and "New" or "Ready", { size = 12, col = "muted" }) end
    UI.button(24, y, 520, 24, nil, function() B().Go("Roster", { sel = c.id }) end, { kind = "row" })
  end
  UI.text(24, 122 + #st.roster * 26 + 6, "Roster " .. #st.roster .. " / " .. g.ECON.rosterMax, { size = 12, col = "muted" })
  if not sel then return end
  local c = sel
  UI.panel(560, 100, 376, 424)
  UI.portrait(578, 116, 72, c.cls, c.look, c.benched)
  UI.text(662, 120, c.name, { head = true, size = 20 })
  UI.text(662, 146, c.race .. " " .. UI.title(c.cls) .. " · " .. g.specName(c.cls, c.spec) .. " · " .. g.RARITY[c.rarity].label, { size = 12, col = "muted", w = 260 })
  UI.text(662, 164, "GL " .. g.gearLevel(c) .. " · skill " .. math.floor(c.skill10 / 10), { size = 12 })
  UI.text(578, 198, "Traits", { size = 12, col = "muted" })
  local y = 214
  for _, t in ipairs(c.traits) do
    local tr = g.TRAITS[t]
    UI.panel(578, y, 340, 44, "row"); UI.text(588, y + 4, tr.name, { size = 12.5 })
    UI.text(588, y + 19, tr.text, { size = 10.5, col = "muted", w = 322, wrap = true, h = 24 })
    y = y + 48
  end
  UI.text(578, y + 6, "Morale", { size = 12, col = "muted" })
  UI.bar(640, y + 8, 220, 9, c.morale / 100, UI.moraleCol(c.morale)); UI.text(870, y + 5, tostring(c.morale), { size = 13, w = 48, justify = "RIGHT" })
  y = y + 28
  UI.text(578, y, "Gear", { size = 12, col = "muted" }); y = y + 16
  for _, slot in ipairs({ "weapon", "armor", "trinket" }) do
    local it = c.gear[slot]
    UI.panel(578, y, 340, 24, "row"); UI.icon(586, y + 4, 16, slot == "armor" and (it.type or g.ARMOR[c.cls]) or slot)
    UI.text(608, y + 6, it.name, { size = 12, col = it.q == "epic" and UI.T().rarity.epic or it.q == "rare" and UI.T().rarity.rare or "ink", w = 240 })
    UI.text(858, y + 6, "GL " .. it.lvl, { size = 12, w = 52, justify = "RIGHT" })
    y = y + 27
  end
  UI.text(578, y + 4, "Fire Whelp gear " .. c.fire .. " of 2", { size = 12 })
  y = y + 24
  -- Spec buttons (respec costs gold), fire gear, dismiss.
  local specs = g.SPECS[c.cls]
  for i, s in ipairs(specs) do
    local on = s[1] == c.spec
    UI.button(578 + (i - 1) * (340 / #specs), y, 340 / #specs - 4, 30, s[2], function()
      if on then return end
      confirm("Respec " .. c.name .. " to " .. s[2] .. " for " .. g.ECON.respec .. " gold?", function() B().Toast(g.Respec(st, c.id, s[1])); B().Render() end, "Respec")
    end, { kind = on and "selected" or "normal", size = 11.5, disabled = not on and st.gold < g.ECON.respec, tip = on and "Current spec" or (g.ECON.respec .. " gold") })
  end
  y = y + 36
  UI.button(578, y, 166, 34, "Fire gear " .. g.ECON.fireGear .. " g", function() B().Toast(g.BuyFire(st, c.id)); B().Render() end,
    { size = 12, disabled = c.fire >= 2 or st.gold < g.ECON.fireGear, tip = "Fire resistance for Ragnaroast. Two pieces at most." })
  local back = math.floor(g.RARITY[c.rarity].cost * g.ECON.dismissBack / 100 + 0.5)
  UI.button(752, y, 166, 34, "Dismiss (+" .. back .. " g)", function()
    confirm("Dismiss " .. c.name .. "? You get " .. back .. " gold back, and every friendship they had is gone.", function() B().Toast(g.Dismiss(st, c.id)); B().Go("Roster") end, "Dismiss")
  end, { size = 12, disabled = #st.roster <= 1 })
end

-- ------------------------------------------------------------------ tavern
function P.Tavern(st)
  local g = G()
  UI.text(24, 108, "The Bench & Barrel", { head = true, size = 18 })
  UI.text(230, 112, #st.tavern .. " recruits this week · new faces at the weekly reset", { size = 12, col = "muted" })
  local cost = g.RerollCost(st)
  UI.button(790, 100, 146, 36, "Reroll " .. cost .. " g", function() B().Toast(g.Reroll(st)); B().Render() end,
    { disabled = st.gold < cost, tip = "The price doubles with every reroll this week." })
  for i, c in ipairs(st.tavern) do
    local x, y = 24 + (i - 1) * 184, 144
    local rc = c.rarity ~= "common" and UI.T().rarity[c.rarity] or nil
    UI.panel(x, y, 176, 346, "panel", rc or "rule")
    UI.portrait(x + 44, y + 12, 88, c.cls, c.look)
    UI.text(x + 10, y + 112, c.name, { head = true, size = 17 })
    UI.icon(x + 10, y + 138, 14, "class-" .. c.cls); UI.text(x + 28, y + 139, c.race .. " " .. UI.title(c.cls), { size = 12, w = 140 })
    UI.text(x + 10, y + 158, g.specName(c.cls, c.spec), { size = 12, col = "muted" })
    UI.text(x + 10, y + 180, g.RARITY[c.rarity].label, { size = 12, col = UI.T().rarity[c.rarity] })
    UI.text(x + 96, y + 180, "GL " .. g.gearLevel(c), { size = 12, w = 70, justify = "RIGHT" })
    UI.text(x + 10, y + 204, "Traits", { size = 11, col = "muted" })
    for k, t in ipairs(c.traits) do
      local ty = y + 220 + (k - 1) * 22
      UI.text(x + 10, ty, g.TRAITS[t].name, { size = 12, w = 158 })
      UI.button(x + 6, ty - 2, 164, 20, nil, nil, { kind = "row", tip = g.TRAITS[t].name .. ": " .. g.TRAITS[t].text })
    end
    UI.text(x + 10, y + 268, "Hover a trait for what it does.", { size = 10.5, col = "muted", w = 158 })
    local full = #st.roster >= g.ECON.rosterMax
    UI.button(x + 8, 442, 160, 40, "Hire " .. UI.money(c.price) .. " g", function() B().Toast(g.Hire(st, i)); B().Render() end,
      { disabled = full or st.gold < c.price, tip = full and "Roster full (15). Dismiss someone first." or st.gold < c.price and "Not enough gold." or nil })
  end
  UI.icon(28, 500, 16, "warn")
  UI.text(48, 501, "Roster " .. #st.roster .. " / 15. Hired raiders start at morale 70 and count as new for 2 weeks.", { size = 11.5, col = "muted" })
end

-- ------------------------------------------------------------------ journal
local function stripFill(s) return (string.gsub(s, "{%w+}", "...")) end
function P.Journal(st, args)
  local g = G()
  local sel = g.BOSS[args.boss or "magmadad"]
  UI.text(24, 106, "The Molten Bore", { head = true, size = 18 })
  for i, b in ipairs(g.BOSSES) do
    local y = 136 + (i - 1) * 76
    local seen = st.progress[b.id].pulls > 0
    local found, total = 0, #b.abilities
    for _, a in ipairs(b.abilities) do if (st.journal[b.id] or {})[a.id] then found = found + 1 end end
    UI.panel(24, y, 250, 68, "row", b.id == sel.id and "accent" or "rule")
    if seen then bossArt(32, y + 8, 52, 52, b) else UI.rect(32, y + 8, 52, 52, "barbg"); UI.icon(48, y + 24, 20, "lock") end
    UI.text(94, y + 10, seen and b.name or "Not reached yet", { size = 13, col = seen and "ink" or "muted" })
    if seen then
      UI.text(94, y + 28, bossState(st, b), { size = 11.5, col = "muted" })
      UI.text(94, y + 45, found .. "/" .. total .. " abilities found", { size = 11.5 })
    end
    UI.button(24, y, 250, 68, nil, function() B().Go("Journal", { boss = b.id }) end, { kind = "row", disabled = not seen })
  end
  local b = sel
  UI.panel(288, 100, 648, 424)
  bossArt(306, 118, 170, 120, b)
  UI.text(492, 122, b.name, { head = true, size = 22 })
  local p = st.progress[b.id]
  UI.text(492, 152, "Boss " .. b.index .. " of 5 · pulled " .. p.pulls .. " times · " .. p.normalKills .. " Normal and " .. p.heroicKills .. " Heroic kills", { size = 12, col = "muted", w = 430 })
  UI.text(492, 174, b.pull, { size = 12.5, w = 430 })
  UI.text(306, 252, "Abilities", { head = true, size = 15 })
  local y = 274
  for _, a in ipairs(b.abilities) do
    local wk = (st.journal[b.id] or {})[a.id]
    UI.panel(306, y, 612, 44, wk and "row" or "panel", "rule")
    if wk then
      UI.icon(316, y + 14, 16, "check")
      UI.text(342, y + 6, a.name, { size = 13 }); UI.text(842, y + 6, "week " .. wk, { size = 11, col = "muted", w = 66, justify = "RIGHT" })
      UI.text(342, y + 24, a.text, { size = 11.5, col = "muted", w = 566 })
    else
      UI.text(318, y + 12, "?", { head = true, size = 18, col = "muted" })
      UI.text(342, y + 6, "Not seen yet", { size = 13, col = "muted" })
      UI.text(342, y + 24, "Pull again: it shows up as the fight goes on.", { size = 11.5, col = "muted" })
    end
    y = y + 50
  end
  UI.text(306, y + 4, "Worked out", { head = true, size = 15 }); y = y + 26
  local any = false
  for _, l in ipairs(g.LESSONS[b.id] or {}) do
    local seen = st.lessons[b.id .. ":" .. l.id] or 0
    if seen >= 2 and y < 500 then
      any = true
      local solid = seen >= 4
      UI.panel(306, y, 612, 24, solid and "row" or "panel", solid and "good" or "rule")
      if solid then UI.icon(314, y + 4, 16, "check") end
      UI.text(336, y + 6, stripFill(solid and l.t[3] or ("Clue: " .. l.t[2])), { size = 11.5, col = solid and "ink" or "muted", w = 576 })
      y = y + 28
    end
  end
  if not any then UI.text(306, y, "Nothing yet. The recap after each wipe gets clearer as your raid learns the fight.", { size = 12, col = "muted" }) end
end

-- ------------------------------------------------------------------ settings
function P.Settings(st)
  B().tabs = false
  local s = ns.db.settings
  UI.panel(24, 70, 912, 454)
  local function seg(x, y, opts, cur, set, w)
    for i, o in ipairs(opts) do
      UI.button(x + (i - 1) * (w + 6), y, w, 32, o[2], function() set(o[1]); B().Render() end, { kind = o[1] == cur and "selected" or "normal", size = 12.5 })
    end
  end
  local function label(y, a, b) UI.text(48, y, a, { size = 13.5 }); if b then UI.text(48, y + 18, b, { size = 11.5, col = "muted" }) end end
  UI.text(48, 90, "Board", { head = true, size = 17 })
  label(126, "Theme", "Auto follows the time of day")
  seg(300, 122, { { "light", "Field Journal" }, { "dark", "Midnight" }, { "auto", "Auto" } }, s.theme, function(v) s.theme = v end, 136)
  label(178, "Size", "Same as /fpr scale 70-120")
  UI.button(300, 174, 40, 32, "-", function() B().SetScale((s.scale or 1) - 0.05) end)
  UI.text(346, 182, math.floor((s.scale or 1) * 100 + 0.5) .. "%", { size = 14, w = 60, justify = "CENTER" })
  UI.button(412, 174, 40, 32, "+", function() B().SetScale((s.scale or 1) + 0.05) end)
  label(230, "Position", "Drag the board to move it")
  UI.button(300, 226, 150, 32, "Reset to centre", function() s.point = nil; B().ApplyPosition() end, { size = 12.5 })
  UI.text(48, 280, "Playback", { head = true, size = 17 })
  label(316, "Motion", "Summary only goes straight to the result")
  seg(300, 312, { { "animated", "Full" }, { "summary", "Summary only" } }, s.playback, function(v) s.playback = v end, 136)
  label(366, "Speed")
  seg(300, 362, { { 1, "x1" }, { 2, "x2" }, { 4, "x4" } }, s.speed or 1, function(v) s.speed = v end, 60)
  UI.text(48, 414, "Checks", { head = true, size = 17 })
  label(448, "Self-test", "The golden fights, in your client")
  UI.button(300, 444, 150, 34, "Run self-test", function() ns.SelfTestRun(); B().Render() end, { size = 12.5 })
  if ns.lastSelfTest then UI.text(462, 453, ns.lastSelfTest, { size = 12, col = ns.lastSelfTestOk and "good" or "bad", w = 300 }) end
  UI.button(600, 444, 150, 34, "New guild", function()
    confirm("Start a new guild? This one is gone for good.", function() ns.db.guild = nil; B().Go("Hub") end, "Start over")
  end, { size = 12.5 })
  UI.button(820, 470, 96, 40, "Done", function() B().Go("Hub") end, { kind = "primary" })
end
