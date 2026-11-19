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
  if ns.MEDIA.bosses and ns.MEDIA.bosses[b.id] then UI.tex(x, y, w, h, "boss-" .. b.id)
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
  local party = g.DungeonParty(st)
  local names = {}
  for i, id in ipairs(party) do names[i] = g.byId(st, id).name end
  UI.button(484, 286, 220, 40, "Quick dungeon", function()
    local o = g.Dungeon(st)
    if o.error then B().Toast(o.error) else
      local msg = "Dungeon: +" .. o.gold .. " gold, " .. #(o.items or {}) .. " items"
      if o.levels and #o.levels > 0 then msg = msg .. ", " .. #o.levels .. " level-ups" end
      if o.tome then msg = msg .. ", and a Tome of Respec!" end
      B().Toast(msg .. ".")
      if #st.pending > 0 then P.LootWindow() return end
    end
    B().Render()
  end, { tip = "The five lowest-level raiders go: " .. table.concat(names, ", ") .. ". Everyone else gets half the XP. Gold and gear rise with level." })
  local pend = #st.pending
  UI.button(712, 286, 224, 40, pend > 0 and ("Loot waiting: " .. pend) or "No loot waiting", function() P.LootWindow() end, { disabled = pend == 0 })
  UI.button(484, 334, 220, 40, "End the week", function()
    confirm("End week " .. st.week .. "? Lockouts reset and benched raiders come back. Morale under 20 may quit.", function()
      g.EndWeek(st); B().Render() end, "End the week")
  end)
  UI.button(712, 334, 224, 40, "DKP store (" .. st.dkp .. ")", function() P.DKPStore() end, { tip = "Spend DKP on a boss's item for the highest mode you've cleared." })
  UI.text(484, 382, "Heroic score: " .. UI.money(g.heroicScore(st)) .. " (best " .. UI.money(st.bestScore) .. ")", { size = 12, col = "muted", w = 452 })
  -- Today's quests (Phase 4): they complete on their own during normal play.
  UI.text(484, 404, "Today's quests", { head = true, size = 14 })
  for i, q in ipairs(st.quests or {}) do
    local y = 404 + i * 21
    UI.icon(484, y, 14, q.done and "check" or "scroll")
    UI.text(504, y + 1, q.text .. (q.need > 1 and not q.done and (" (" .. q.got .. "/" .. q.need .. ")") or ""), { size = 12, col = q.done and "good" or "ink", w = 330 })
    UI.text(836, y + 1, q.done and "Done" or ("30 g · 2 DKP"), { size = 11.5, col = "muted", w = 100, justify = "RIGHT" })
  end
  -- One line under the quests: low morale first, else the latest news.
  local low = {}
  for _, c in ipairs(st.roster) do if c.morale < 40 then low[#low + 1] = c.name .. " " .. c.morale end end
  if #low > 0 then
    UI.icon(484, 494, 14, "warn")
    UI.text(504, 494, #low .. " low on morale: " .. table.concat(low, ", ") .. ". Under 20 they may quit at the end of the week.", { size = 11.5, w = 432, wrap = true, h = 30 })
  elseif #st.news > 0 then
    UI.text(484, 494, st.news[#st.news], { size = 11.5, col = "muted", w = 452, wrap = true, h = 30 })
  end
end

-- ------------------------------------------------------------------ roster
function P.Roster(st, args)
  local g = G()
  -- Layout follows ux/hifi/roster-*.svg. Filters by role along the top.
  local counts = { tank = 0, healer = 0, damage = 0 }
  for _, c in ipairs(st.roster) do local r = g.role(c.cls, c.spec) counts[r] = counts[r] + 1 end
  local filter = args.filter or "all"
  local x = 24
  for _, f in ipairs({ { "all", "All " .. #st.roster }, { "tank", "Tanks " .. counts.tank }, { "healer", "Healers " .. counts.healer }, { "damage", "Damage " .. counts.damage } }) do
    local w = #f[2] * 7 + 30
    UI.button(x, 100, w, 28, f[2], function() B().Go("Roster", { filter = f[1], sel = args.sel }) end, { kind = filter == f[1] and "selected" or "normal", size = 12 })
    x = x + w + 6
  end
  local list = {}
  for _, c in ipairs(st.roster) do if filter == "all" or g.role(c.cls, c.spec) == filter then list[#list + 1] = c end end
  local sel = args.sel and g.byId(st, args.sel) or list[1] or st.roster[1]
  local cols = { { 70, "Name" }, { 178, "Class · spec" }, { 316, "Lv" }, { 342, "GL" }, { 374, "Morale" }, { 456, "Status" } }
  for _, c in ipairs(cols) do UI.text(c[1], 137, c[2], { size = 11, col = "muted" }) end
  for i, c in ipairs(list) do
    local y = 156 + (i - 1) * 24
    local on = sel and c.id == sel.id
    UI.panel(24, y, 520, 22, "row", on and "accent" or "rule")
    UI.portrait(28, y + 1, 20, c.cls, c.look, c.benched)
    UI.text(70, y + 4, c.name, { size = 12.5, col = c.benched and "muted" or "ink" })
    UI.icon(178, y + 4, 14, "class-" .. c.cls)
    UI.text(196, y + 4, UI.title(c.cls) .. " · " .. g.specName(c.cls, c.spec), { size = 12, w = 118 })
    UI.text(316, y + 4, tostring(g.level(c)), { size = 12, col = g.level(c) < g.LEVEL.cap and "accent" or "ink" })
    UI.text(342, y + 4, tostring(g.gearLevel(c)), { size = 12 })
    UI.bar(374, y + 8, 36, 7, c.morale / 100, UI.moraleCol(c.morale))
    UI.text(416, y + 4, tostring(c.morale), { size = 11.5, col = UI.moraleCol(c.morale) })
    if c.morale < 40 then UI.icon(440, y + 4, 13, "warn") end
    if c.benched then UI.rect(456, y + 3, 60, 16, "bad"); UI.text(456, y + 5, "Benched", { size = 11, col = "badtext", w = 60, justify = "CENTER" })
    else UI.text(456, y + 4, (st.week - c.joined < 2) and "New" or "Ready", { size = 12, col = "muted" }) end
    UI.button(24, y, 520, 22, nil, function() B().Go("Roster", { sel = c.id, filter = filter }) end, { kind = "row", tip = "Show " .. c.name })
  end
  if #list < 14 then UI.text(24, 496, "Roster " .. #st.roster .. " / " .. g.ECON.rosterMax, { size = 12, col = "muted" }) end
  if not sel then return end
  local c = sel
  UI.panel(560, 100, 376, 424, nil, nil, true)
  UI.portrait(578, 118, 72, c.cls, c.look, c.benched)
  UI.text(662, 120, c.name, { head = true, size = 22 })
  UI.text(662, 150, c.race .. " " .. UI.title(c.cls) .. " · " .. g.specName(c.cls, c.spec) .. " · " .. g.RARITY[c.rarity].label, { size = 12, col = "muted", w = 260 })
  local lv = g.level(c)
  UI.text(704, 170, "Level " .. lv .. " · GL " .. g.gearLevel(c) .. " · skill " .. math.floor(c.skill10 / 10), { size = 12 })
  if lv < g.LEVEL.cap then
    UI.bar(704, 188, 150, 5, (c.xp or 0) / g.xpNeed(lv), "accent")
    UI.button(704, 184, 150, 12, nil, nil, { kind = "row", tip = (c.xp or 0) .. " / " .. g.xpNeed(lv) .. " XP to level " .. (lv + 1) })
  end
  local pips = ({ common = 1, rare = 2, epic = 3, legendary = 4 })[c.rarity] or 1
  for i = 1, 4 do UI.rect(663 + (i - 1) * 9, 174, 6, 6, i <= pips and UI.T().rarity[c.rarity] or "barbg") end
  UI.text(578, 202, "Traits", { size = 12, col = "muted" })
  local y = 222
  for _, t in ipairs(c.traits) do
    local tr = g.TRAITS[t]
    UI.panel(578, y, 340, 40, "row"); UI.text(588, y + 3.5, tr.name, { size = 12.5 })
    UI.text(588, y + 20.5, tr.text, { size = 11.5, col = "muted", w = 322 })
    UI.button(578, y, 340, 40, nil, nil, { kind = "row", tip = tr.name .. ": " .. tr.text })
    y = y + 44
  end
  local extra = y - 266  -- 0 with one trait; the rest of the panel moves down with a second
  UI.text(578, 272 + extra, "Morale", { size = 12, col = "muted" })
  UI.bar(640, 276 + extra, 220, 10, c.morale / 100, UI.moraleCol(c.morale)); UI.text(870, 272 + extra, tostring(c.morale), { size = 13, w = 48, justify = "RIGHT" })
  UI.text(578, 290 + extra, "Under 20 they may quit at the end of the week.", { size = 11.5, col = "muted" })
  local gy = 316 + extra
  local step = extra > 0 and 28 or 30
  UI.text(578, gy, "Gear", { size = 12, col = "muted" })
  for k, slot in ipairs({ "weapon", "armor", "trinket" }) do
    local it = c.gear[slot]
    local ry = gy + 20 + (k - 1) * step
    UI.panel(578, ry, 340, 26, "row"); UI.icon(586, ry + 5, 16, slot == "armor" and UI.itemIcon(it, g.ARMOR[c.cls]) or slot)
    UI.text(608, ry + 6, it.name, { size = 12, col = it.q == "epic" and UI.T().rarity.epic or it.q == "rare" and UI.T().rarity.rare or "ink", w = 240 })
    UI.text(858, ry + 6, "GL " .. it.lvl, { size = 12, w = 52, justify = "RIGHT" })
    if g.FLAVOUR[it.name] then UI.button(578, ry, 340, 26, nil, nil, { kind = "row", tip = it.name .. "\n" .. g.FLAVOUR[it.name] }) end
  end
  UI.text(578, math.min(434, gy + 20 + 3 * step + 4), "Fire Whelp gear " .. c.fire .. " of 2", { size = 12 })
  local rcost = g.RespecCost(st, c.id)
  local tomes = st.tomes or 0
  local canRespec = st.gold >= rcost or tomes > 0
  UI.button(578, 460, 112, 40, "Respec " .. rcost .. " g", function()
    B().OpenModal(function()
      UI.panel(280, 170, 400, 210, "panel", "rule", true)
      UI.text(300, 188, "Respec " .. c.name, { head = true, size = 16 })
      UI.text(300, 212, "Costs " .. rcost .. " gold; the next one costs more. The price drops a step each week without one." ..
        (tomes > 0 and (" You have " .. tomes .. " Tome" .. (tomes > 1 and "s" or "") .. " of Respec: free, and the price stays.") or ""), { size = 11.5, col = "muted", w = 360 })
      local specs = g.SPECS[c.cls]
      for i, sp in ipairs(specs) do
        local cur = sp[1] == c.spec
        UI.button(300 + (i - 1) * (360 / #specs), 256, 360 / #specs - 6, 40, sp[2], function()
          B().Toast(g.Respec(st, c.id, sp[1], tomes > 0)); B().CloseModal()
        end, { kind = cur and "selected" or "normal", size = 12, disabled = cur or not canRespec, tip = cur and "Current spec" or (tomes > 0 and "Uses a Tome of Respec" or (rcost .. " gold")) })
      end
      UI.button(560, 320, 100, 36, "Cancel", function() B().CloseModal() end)
    end)
  end, { size = 12.5, disabled = not canRespec, tip = not canRespec and "Not enough gold." or "Change spec" })
  UI.button(698, 460, 132, 40, "Fire gear " .. g.ECON.fireGear .. " g", function() B().Toast(g.BuyFire(st, c.id)); B().Render() end,
    { size = 12.5, disabled = c.fire >= 2 or st.gold < g.ECON.fireGear, tip = "Fire resistance for Ragnaroast. Two pieces at most." })
  local back = math.floor(g.RARITY[c.rarity].cost * g.ECON.dismissBack / 100 + 0.5)
  UI.button(838, 460, 80, 40, "Dismiss", function()
    confirm("Dismiss " .. c.name .. "? You get " .. back .. " gold back, and every friendship they had is gone.", function() B().Toast(g.Dismiss(st, c.id)); B().Go("Roster") end, "Dismiss")
  end, { size = 12.5, disabled = #st.roster <= 1 })
  UI.text(578, 503, "Dismiss gives back " .. back .. " gold and ends every friendship.", { size = 11, col = "muted" })
end

-- ------------------------------------------------------------------ DKP store (Phase 4, #40)
function P.DKPStore()
  local g = G()
  local pick = { boss = nil, slot = "weapon", armor = "plate" }
  B().OpenModal(function(st)
    UI.panel(200, 110, 560, 330, "panel", "rule", true)
    UI.icon(220, 128, 30, "gem")
    UI.text(260, 126, "DKP store", { head = true, size = 20 })
    UI.text(260, 152, "You have " .. st.dkp .. " DKP. Pick a boss you've killed and a slot: you get its item for the highest mode you've cleared.", { size = 12, col = "muted", w = 480 })
    local x = 220
    for _, b in ipairs(g.BOSSES) do
      local lvl, mode = g.TokenLevel(st, b.id)
      if lvl and not pick.boss then pick.boss = b.id end
      UI.button(x, 190, 100, 34, b.name:match("^(%S+)"), function() pick.boss = b.id end,
        { size = 12, kind = pick.boss == b.id and "selected" or "normal", disabled = not lvl, tip = lvl and (b.name .. ": " .. g.MODES[mode].label .. " items, gear level " .. lvl) or ("Kill " .. b.name .. " first.") })
      x = x + 106
    end
    for i, slot in ipairs({ "weapon", "armor", "trinket" }) do
      UI.button(220 + (i - 1) * 176, 238, 170, 34, UI.title(slot) .. " · " .. g.ECON.tokens[slot] .. " DKP", function() pick.slot = slot end,
        { size = 12, kind = pick.slot == slot and "selected" or "normal" })
    end
    if pick.slot == "armor" then
      for i, t in ipairs({ "plate", "mail", "leather", "cloth" }) do
        UI.button(220 + (i - 1) * 132, 284, 126, 30, UI.title(t), function() pick.armor = t end, { size = 11.5, kind = pick.armor == t and "selected" or "normal" })
      end
    end
    local cost = g.ECON.tokens[pick.slot]
    local lvl = pick.boss and g.TokenLevel(st, pick.boss)
    if pick.boss and lvl then
      local name = g.BOSS[pick.boss].loot[pick.slot][1]
      UI.text(220, 330, name .. ", gear level " .. lvl .. ".", { size = 13 })
    end
    UI.button(420, 380, 150, 40, "Buy " .. cost .. " DKP", function()
      local o = g.BuyToken(st, pick.boss, pick.slot, pick.armor)
      if o.error then B().Toast(o.error) else B().Toast("Bought " .. o.item.name .. ".") ; B().CloseModal(); P.LootWindow() end
    end, { kind = "primary", size = 14, disabled = not lvl or st.dkp < cost, tip = not lvl and "Kill a boss first." or st.dkp < cost and "Not enough DKP." or nil })
    UI.button(590, 380, 150, 40, "Close", function() B().CloseModal() end)
  end)
end

-- ------------------------------------------------------------------ tavern
function P.Tavern(st)
  local g = G()
  -- Layout follows ux/hifi/tavern-*.svg.
  local head = UI.text(24, 104, "The Bench & Barrel", { head = true, size = 20 })
  UI.text(math.max(214, 24 + head:GetStringWidth() + 10), 111, #st.tavern .. " recruits this week · new faces at the weekly reset", { size = 12, col = "muted" })
  local cost = g.RerollCost(st)
  UI.button(790, 100, 146, 36, "Reroll " .. cost .. " g", function() B().Toast(g.Reroll(st)); B().Render() end,
    { disabled = st.gold < cost, tip = "The price doubles with every reroll this week." })
  for i, c in ipairs(st.tavern) do
    local x, y = 24 + (i - 1) * 184, 144
    local rc = c.rarity ~= "common" and UI.T().rarity[c.rarity] or nil
    UI.panel(x, y, 176, 346, "panel", rc or "rule")
    UI.rect(x + 8, y + 8, 160, 132, "barbg")
    UI.tex(x + 56, y + 12, 64, 128, "body-" .. c.cls .. "-" .. (c.look or 0) .. "-" .. UI.theme)
    if c.cls == "warlock" then UI.rect(x + 100, y + 12, 64, 16, "accent", 1, "plate"); UI.text(x + 100, y + 14, "Rare find", { size = 11, col = "badtext", w = 64, justify = "CENTER" }) end
    UI.text(x + 10, y + 148, c.name, { head = true, size = 18 })
    UI.icon(x + 11, y + 175, 14, "class-" .. c.cls); UI.text(x + 30, y + 175, c.race .. " " .. UI.title(c.cls), { size = 12, w = 140 })
    UI.text(x + 10, y + 193, g.specName(c.cls, c.spec), { size = 12, col = "muted" })
    local pips = ({ common = 1, rare = 2, epic = 3, legendary = 4 })[c.rarity] or 1
    for k = 1, 4 do UI.rect(x + 11 + (k - 1) * 9, y + 219, 6, 6, k <= pips and UI.T().rarity[c.rarity] or "barbg") end
    UI.text(x + 54, y + 214, g.RARITY[c.rarity].label, { size = 12, col = UI.T().rarity[c.rarity] })
    UI.text(x + 96, y + 214, "Lv " .. g.level(c) .. " · GL " .. g.gearLevel(c), { size = 12, w = 70, justify = "RIGHT" })
    UI.text(x + 10, y + 237, "Traits", { size = 11, col = "muted" })
    for k, t in ipairs(c.traits) do
      local ty = y + 254 + (k - 1) * 18
      UI.text(x + 10, ty, g.TRAITS[t].name, { size = 12, w = 158 })
      UI.button(x + 6, ty - 2, 164, 18, nil, nil, { kind = "row", tip = g.TRAITS[t].name .. ": " .. g.TRAITS[t].text })
    end
    local full = #st.roster >= g.ECON.rosterMax
    UI.button(x + 8, 442, 160, 40, "Hire " .. UI.money(c.price) .. " g", function() B().Toast(g.Hire(st, i)); B().Render() end,
      { disabled = full or st.gold < c.price, tip = full and "Roster full (15). Dismiss someone first." or st.gold < c.price and "Not enough gold." or nil })
  end
  UI.icon(26, 498, 16, "warn")
  UI.text(48, 498.5, "Roster " .. #st.roster .. " / 15. Hired raiders start at morale 70 and count as new for 2 weeks. Hover a trait for what it does.", { size = 11.5, col = "muted" })
end

-- ------------------------------------------------------------------ journal
local function stripFill(s) return (string.gsub(s, "{%w+}", "...")) end
function P.Journal(st, args)
  local g = G()
  local sel = g.BOSS[args.boss or "magmadad"]
  UI.text(24, 104, "The Molten Bore", { head = true, size = 20 })  -- layout follows ux/hifi/journal-*.svg
  for i, b in ipairs(g.BOSSES) do
    local y = 136 + (i - 1) * 76
    local seen = st.progress[b.id].pulls > 0
    local found, total = 0, #b.abilities
    for _, a in ipairs(b.abilities) do if (st.journal[b.id] or {})[a.id] then found = found + 1 end end
    UI.panel(24, y, 250, 68, "row", b.id == sel.id and "accent" or "rule")
    if seen then bossArt(32, y + 8, 52, 52, b) else UI.rect(32, y + 8, 52, 52, "barbg"); UI.icon(48, y + 24, 20, "lock") end
    UI.text(94, y + 11, seen and b.name or "Not reached yet", { size = 13, col = seen and "ink" or "muted" })
    if seen then
      UI.text(94, y + 29.5, bossState(st, b), { size = 11.5, col = "muted" })
      UI.text(94, y + 46.5, found .. "/" .. total .. " abilities found", { size = 11.5 })
    end
    UI.button(24, y, 250, 68, nil, function() B().Go("Journal", { boss = b.id }) end, { kind = "row", disabled = not seen, tip = seen and ("Read about " .. b.name) or "Not reached yet" })
  end
  local b = sel
  UI.panel(288, 100, 648, 424, nil, nil, true)
  bossArt(306, 118, 170, 120, b)
  UI.text(492, 122, b.name, { head = true, size = 24 })
  local p = st.progress[b.id]
  UI.text(492, 156, "Boss " .. b.index .. " of 5 · pulled " .. p.pulls .. (p.pulls == 1 and " time · " or " times · ") .. p.normalKills .. " Normal and " .. p.heroicKills .. " Heroic kills", { size = 12, col = "muted", w = 430 })
  UI.text(492, 179.5, b.pull, { size = 12.5, w = 430 })
  local fam = 0
  if #st.roster > 0 then
    local ids = {}
    for _, c in ipairs(st.roster) do ids[#ids + 1] = c.id end
    fam = g.famAvg(st, ids, b.id)
  end
  UI.panel(492, 206, 236, 26, "row")
  UI.text(504, 212, "Your raid knows this fight:", { size = 11.5 }); UI.bar(668, 215, 50, 8, fam / 10, "accent")
  UI.text(306, 249, "Abilities", { head = true, size = 17 })
  local y = 276
  for _, a in ipairs(b.abilities) do
    local wk = (st.journal[b.id] or {})[a.id]
    UI.panel(306, y, 612, 46, wk and "row" or "panel", "rule")
    if wk then
      UI.icon(316, y + 15, 16, "check")
      UI.text(342, y + 6, a.name, { size = 13 }); UI.text(842, y + 8, "found week " .. wk, { size = 11, col = "muted", w = 66, justify = "RIGHT" })
      UI.text(342, y + 25.5, a.text, { size = 11.5, col = "muted", w = 566 })
    else
      UI.text(318, y + 11, "?", { head = true, size = 20, col = "muted" })
      UI.text(342, y + 6, "Not seen yet", { size = 13, col = "muted" })
      UI.text(342, y + 25.5, "Pull again: it shows up later in the fight.", { size = 11.5, col = "muted" })
    end
    y = y + 52
  end
  y = math.max(y, 432)
  UI.text(306, y + 3, "Worked out", { head = true, size = 17 }); y = y + 27
  local any = false
  for _, l in ipairs(g.LESSONS[b.id] or {}) do
    local tier = (st.lessonTier or {})[b.id .. ":" .. l.id] or -1
    if tier >= 1 and y < 500 then
      any = true
      local solid = tier >= 2
      UI.panel(306, y, 612, 26, solid and "row" or "panel", solid and "good" or "rule")
      if solid then UI.icon(314, y + 5, 16, "check") end
      UI.text(334, y + 6, stripFill(solid and l.t[3] or ("Clue: " .. l.t[2])), { size = 11.5, col = solid and "ink" or "muted", w = 576 })
      y = y + 30
    end
  end
  if not any then UI.text(306, y, "Nothing yet. The recap after each wipe gets clearer as your raid learns the fight.", { size = 12, col = "muted" }) end
end

-- ------------------------------------------------------------------ settings
function P.Settings(st, args)
  -- Layout follows ux/hifi/settings-*.svg: sections on the left, the chosen one on the right.
  B().tabs = false
  local s = ns.db.settings
  local section = args.section or "Display"
  UI.panel(24, 70, 200, 454)
  for i, t in ipairs({ "Display", "Playback", "Accessibility", "Guild data" }) do
    UI.button(36, 84 + (i - 1) * 48, 176, 40, t, function() B().Go("Settings", { section = t }) end, { kind = t == section and "selected" or "normal", size = 13.5 })
  end
  UI.panel(238, 70, 698, 454, nil, nil, true)
  local function seg(x, y, opts, cur, set, w)
    for i, o in ipairs(opts) do
      UI.button(x + (i - 1) * (w + 6), y, w, 34, o[2], function() set(o[1]); B().Render() end, { kind = o[1] == cur and "selected" or "normal", size = 12.5 })
    end
  end
  -- label(y): y is the hi-fi baseline of the label; the addon draws from the top of the line.
  local function label(y, a, b) UI.text(262, y - 13.5, a, { size = 13.5 }); if b then UI.text(262, y + 6.5, b, { size = 11.5, col = "muted" }) end end
  local function heading(y, t) UI.text(262, y - 18, t, { head = true, size = 18 }) end
  local function playback(top)
    heading(top + 18, "Playback")
    label(top + 54, "Motion", "Summary only skips playback")
    seg(440, top + 34, { { "animated", "Full" }, { "summary", "Summary only" } }, s.playback, function(v) s.playback = v end, 120)
    label(top + 110, "Speed")
    seg(440, top + 92, { { 1, "x1" }, { 2, "x2" }, { 4, "x4" } }, s.speed or 1, function(v) s.speed = v end, 64)
  end
  if section == "Display" then
    heading(104, "Board")
    label(140, "Theme", "Auto follows the time of day")
    seg(440, 120, { { "light", "Field Journal" }, { "dark", "Midnight" }, { "auto", "Auto" } }, s.theme, function(v) s.theme = v end, 136)
    label(196, "Size", "Same as /fpr scale")
    UI.button(440, 178, 40, 30, "-", function() B().SetScale((s.scale or 1) - 0.05) end, { tip = "Smaller" })
    UI.text(486, 184, math.floor((s.scale or 1) * 100 + 0.5) .. "%", { size = 14, w = 60, justify = "CENTER" })
    UI.button(552, 178, 40, 30, "+", function() B().SetScale((s.scale or 1) + 0.05) end, { tip = "Bigger" })
    label(250, "Position", "Lost it? /fpr reset")
    UI.button(440, 232, 150, 36, "Reset to centre", function() s.point = nil; B().ApplyPosition() end, { size = 12.5 })
    playback(288)
    heading(452, "Checks")
    label(486, "Self-test", "18 golden fights, here")
    UI.button(440, 466, 150, 38, "Run self-test", function() ns.SelfTestRun(); B().Render() end, { size = 13 })
    if ns.lastSelfTest then UI.text(602, 474, ns.lastSelfTest, { size = 12, col = ns.lastSelfTestOk and "good" or "bad", w = 210 }) end
  elseif section == "Playback" then
    playback(86)
    UI.text(262, 250, "Playback replays a pull that is already decided. Skipping never changes the result.", { size = 12, col = "muted", w = 640 })
  elseif section == "Accessibility" then
    heading(104, "Keyboard and sound")
    label(140, "Keyboard", "Tab moves between buttons; Enter presses; Escape lets go")
    seg(560, 120, { { true, "On" }, { false, "Off" } }, s.keys ~= false, function(v) s.keys = v end, 64)
    label(196, "Sounds", "Every sound also shows on screen")
    seg(560, 176, { { true, "On" }, { false, "Off" } }, s.sound ~= false, function(v) s.sound = v end, 64)
    UI.text(262, 236, "In combat the board hands every key back to the game.", { size = 12, col = "muted", w = 640 })
  else
    heading(104, "Guild data")
    UI.text(262, 122, "Your guild is saved with your account (FlightPathRaidersDB). Week " .. st.week .. ", " .. #st.roster .. " raiders.", { size = 12.5, w = 640 })
    label(180, "New guild", "Starts over. This one is gone for good.")
    UI.button(560, 160, 150, 36, "New guild", function()
      confirm("Start a new guild? This one is gone for good.", function() ns.db.guild = nil; B().Go("Hub") end, "Start over")
    end, { size = 12.5 })
  end
  UI.button(820, 466, 96, 40, "Done", function() B().Go("Hub") end, { kind = "primary", size = 19 })
end
