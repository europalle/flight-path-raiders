-- Flight Path Raiders: a pull from start to finish. Prep, playback, results and the loot window.
-- Playback replays the engine's per-round frames; the result is decided when Pull is clicked.
local _, ns = ...
local P = ns.Pages
local UI = ns.UI
local function G() return ns.Game end
local function B() return ns.Board end
local ZONES = { "front", "melee", "ranged", "back" }
local ZONE_LABEL = { front = "Front", melee = "Melee", ranged = "Ranged", back = "Back" }

-- ------------------------------------------------------------------ prep
function P.Prep(st, args)
  local g = G()
  local b = g.BOSS[args.boss]
  local mode = args.mode
  if not args.prep then args.prep = g.DefaultPrep(st, args.boss, mode) end
  local prep = args.prep
  B().tabs = false
  B().crumb = "Prep · " .. b.name .. " (" .. g.MODES[mode].label .. ")"
  -- Banner: what the raid knows about this boss.
  UI.panel(24, 70, 912, 56)
  P.bossArt(30, 76, 78, 44, b)
  local known = {}
  for _, a in ipairs(b.abilities) do if (st.journal[b.id] or {})[a.id] then known[#known + 1] = a.name end end
  UI.text(120, 80, #known > 0 and ("Seen: " .. table.concat(known, ", ") .. ".") or "Nobody has seen this fight yet. Pull it and the journal fills in.", { size = 13, w = 640 })
  local answer
  for _, l in ipairs(g.LESSONS[b.id] or {}) do if (st.lessons[b.id .. ":" .. l.id] or 0) >= 4 then answer = l.t[3] end end
  UI.text(120, 100, answer and ("Journal: " .. answer) or "The recap after a wipe tells you what went wrong.", { size = 11.5, col = "muted", w = 800 })
  -- Raid by zone. Click a card to send it to the bench; the small button changes the zone.
  local inRaid = {}
  for _, id in ipairs(prep.ids) do inRaid[id] = true end
  for zi, z in ipairs(ZONES) do
    local y = 136 + (zi - 1) * 54
    UI.text(30, y + 16, ZONE_LABEL[z], { head = true, size = 14 })
    local k = 0
    for _, id in ipairs(prep.ids) do
      local c = g.byId(st, id)
      if c and prep.zones[tostring(id)] == z then
        local x = 96 + k * 160
        if k < 4 then
          UI.panel(x, y, 152, 48, "row")
          UI.portrait(x + 4, y + 4, 40, c.cls, c.look)
          UI.text(x + 50, y + 4, c.name, { size = 12.5, w = 70 })
          UI.icon(x + 132, y + 4, 14, "role-" .. g.role(c.cls, c.spec))
          UI.text(x + 50, y + 19, g.specName(c.cls, c.spec), { size = 11, col = "muted", w = 74 })
          UI.text(x + 50, y + 33, "GL " .. g.gearLevel(c), { size = 11 })
          UI.text(x + 84, y + 33, "Mor " .. c.morale, { size = 11, col = UI.moraleCol(c.morale) })
          if prep.potions[tostring(id)] then UI.icon(x + 30, y + 30, 14, "firepot") end
          UI.button(x, y, 118, 48, nil, function()
            for i, v in ipairs(prep.ids) do if v == id then table.remove(prep.ids, i); break end end
            ns.Audio.Play("bench"); B().Render()
          end, { kind = "row", tip = c.name .. ": click to bench for this pull" })
          UI.button(x + 126, y + 24, 24, 20, string.sub(ZONE_LABEL[z], 1, 1), function()
            local nz = ZONES[(zi % 4) + 1]; prep.zones[tostring(id)] = nz; B().Render()
          end, { size = 11, tip = "Move to " .. ZONE_LABEL[ZONES[(zi % 4) + 1]] })
        end
        k = k + 1
      end
    end
  end
  -- Bench.
  UI.panel(744, 136, 192, 204)
  UI.text(756, 144, "Bench", { head = true, size = 14 })
  local y = 166
  for _, c in ipairs(st.roster) do
    if not inRaid[c.id] and y < 330 then
      local blocked = mode == "heroic" and c.benched
      UI.panel(752, y, 176, 30, "row", blocked and "bad" or "rule")
      UI.portrait(754, y + 2, 26, c.cls, c.look, blocked)
      UI.text(786, y + 3, c.name, { size = 12, col = blocked and "muted" or "ink" })
      UI.text(786, y + 16, blocked and "Benched until reset" or (UI.title(c.cls) .. " · GL " .. g.gearLevel(c)), { size = 11, col = "muted" })
      UI.button(752, y, 176, 30, nil, function()
        table.insert(prep.ids, c.id); prep.zones[tostring(c.id)] = g.defaultZone(c); prep.fireOn[tostring(c.id)] = 0; B().Render()
      end, { kind = "row", disabled = blocked or #prep.ids >= 10, tip = blocked and "Died on Heroic this week." or #prep.ids >= 10 and "Raids take 10." or "Add to the raid" })
      y = y + 34
    end
  end
  -- Tactic cards.
  UI.text(30, 368, "Tactic", { head = true, size = 14 })
  for i, id in ipairs(g.CARD_ORDER) do
    local x = 96 + (i - 1) * 160
    local on = prep.tactic == id
    UI.button(x, 352, 152, 44, g.CARDS[id], function() prep.tactic = id; ns.Audio.Play("pick"); B().Render() end, { kind = on and "selected" or "normal", size = 14 })
    if on then UI.icon(x + 16, 366, 14, "check") end
    UI.text(x, 400, g.CARD_TEXT[id], { size = 11, col = on and "ink" or "muted", w = 152, justify = "CENTER", wrap = true, h = 28 })
  end
  -- Consumables. Fire gear is worn automatically on Ragnaroast; potions go to melee and tanks with one toggle.
  UI.text(30, 446, "Prep", { head = true, size = 14 })
  local x = 96
  local hasMage = false
  for _, id in ipairs(prep.ids) do local c = g.byId(st, id) if c and c.cls == "mage" then hasMage = true end end
  local chips = { { "food", "Food " .. (hasMage and "free (mage)" or (g.ECON.cauldron.food .. " g")), "food" },
    { "elixirs", "Elixirs " .. g.ECON.cauldron.elixirs .. " g", "elixir" }, { "flasks", "Flasks " .. g.ECON.cauldron.flasks .. " g", "flask" } }
  for _, ch in ipairs(chips) do
    local on = prep.cons[ch[1]]
    UI.button(x, 436, 140, 32, ch[2], function() prep.cons[ch[1]] = not prep.cons[ch[1]]; B().Render() end, { kind = on and "selected" or "normal", size = 11.5 })
    x = x + 146
  end
  if b.id == "ragnaroast" then
    local any = false
    for _, id in ipairs(prep.ids) do if prep.potions[tostring(id)] then any = true end end
    UI.button(x, 436, 196, 32, "Fire potions: melee + tanks", function()
      for _, id in ipairs(prep.ids) do
        local z = prep.zones[tostring(id)]
        prep.potions[tostring(id)] = (not any) and (z == "melee" or z == "front") or nil
      end
      B().Render()
    end, { kind = any and "selected" or "normal", size = 11.5, tip = g.ECON.potion .. " gold each. Each one cancels a lava throw." })
    for _, id in ipairs(prep.ids) do local c = g.byId(st, id) if c then prep.fireOn[tostring(id)] = c.fire end end
  end
  -- Cost, warnings, Pull.
  local cost = g.PrepCost(st, prep).gold
  local problems, warnings = g.Problems(st, prep), g.Warnings(st, prep)
  UI.text(96, 478, problems[1] or warnings[1] or "Ready.", { size = 12, col = problems[1] and "bad" or warnings[1] and "warn" or "good", w = 620 })
  if not problems[1] and warnings[2] then UI.text(96, 496, warnings[2], { size = 11.5, col = "warn", w = 620 }) end
  UI.text(744, 470, "This pull costs", { size = 12, col = "muted" })
  UI.text(744, 488, cost .. " gold of " .. UI.money(st.gold), { size = 13 })
  UI.button(840, 462, 96, 52, "Pull", function() P.DoPull(st, prep) end, { kind = "primary", size = 22, disabled = problems[1] ~= nil, tip = problems[1] })
  UI.button(744, 346, 192, 30, "Back to the hub", function() B().Go("Hub") end, { size = 12 })
end

function P.DoPull(st, prep)
  local out = G().Pull(st, prep)
  if out.error then B().Toast(out.error); B().Render(); return end
  ns.Audio.Play("pull")
  if ns.db.settings.playback == "summary" then B().Go("Results", { out = out, prep = prep })
  else B().Go("Playback", { out = out, prep = prep, round = 1, t = 0 }) end
end

-- ------------------------------------------------------------------ playback
local LOGCOL = { [31] = "bad", [23] = "warn", [25] = "warn", [62] = "warn", [68] = "warn", [30] = "good", [32] = "good", [34] = "good", [35] = "good", [22] = "good" }
function P.Playback(st, args)
  local g = G()
  local out = args.out
  local run, input = out.run, out.input
  local b = g.BOSS[out.boss]
  B().tabs = false
  B().crumb = "Pull · " .. b.name .. " (" .. g.MODES[out.mode].label .. ")"
  local r = math.min(args.round, run.rounds)
  local f = run.frames[r] or {}
  -- Stage: the boss on the right, the raid by zone on the left.
  UI.panel(24, 70, 610, 340)
  P.bossArt(330, 150, 290, 145, b)
  local slots = { front = { 250, 120 }, melee = { 190, 120 }, ranged = { 110, 120 }, back = { 34, 120 } }
  local count = { front = 0, melee = 0, ranged = 0, back = 0 }
  for i, c in ipairs(input.raid) do
    local z = c.zone; local s = slots[z] or slots.ranged
    local hp = f.h and f.h[i] or 1
    local ch = nil
    for _, x in ipairs(st.roster) do if x.name == c.name then ch = x end end
    UI.portrait(s[1], s[2] + count[z] * 62, 52, c.class, ch and ch.look or 0, hp <= 0)
    count[z] = count[z] + 1
  end
  -- Round and boss health.
  UI.panel(648, 70, 288, 110)
  UI.text(662, 80, "Round", { size = 12, col = "muted" })
  UI.text(662, 98, tostring(r), { head = true, size = 34 }); UI.text(712, 116, "/ 20", { size = 15, col = "muted" })
  UI.text(662, 146, b.name, { size = 13 })
  local pct = (f.b or run.bossMax) / run.bossMax
  UI.text(860, 146, math.floor(pct * 100 + 0.5) .. "%", { size = 13, w = 62, justify = "RIGHT" })
  UI.bar(662, 164, 260, 10, pct, "accent")
  -- Log: the last lines up to this round.
  UI.panel(648, 190, 288, 220)
  UI.text(662, 198, "What happened", { head = true, size = 14 })
  local lines = {}
  for _, e in ipairs(run.events) do if e.r <= r and e.t and e.t ~= "" then lines[#lines + 1] = e end end
  local y = 222
  for i = math.max(1, #lines - 7), #lines do
    local e = lines[i]
    UI.text(662, y, "R" .. e.r, { size = 11, col = "muted" }); UI.text(692, y, e.t, { size = 11.5, col = LOGCOL[e.c] or "ink", w = 236 })
    y = y + 23
  end
  -- Raid health.
  for i, c in ipairs(input.raid) do
    local x = 24 + (i - 1) * 91.5
    local hp = f.h and f.h[i] or 1
    local mx = run.raid[i] and run.raid[i].maxhp or 1
    local frac = math.max(0, hp) / math.max(1, mx)
    if not f.h then frac = 1 end
    UI.panel(x, 420, 86, 40, "row")
    UI.text(x + 6, 426, c.name, { size = 11.5, col = frac <= 0 and "muted" or "ink", w = 74 })
    if frac <= 0 then UI.text(x + 40, 426, "Dead", { size = 11, col = "bad", w = 40, justify = "RIGHT" }) end
    UI.bar(x + 6, 444, 74, 6, frac, frac > 0.4 and "hp" or "bad")
  end
  local speed = ns.db.settings.speed or 1
  UI.button(24, 474, 120, 44, args.paused and "Play" or "Pause", function() args.paused = not args.paused; B().Render() end)
  UI.button(152, 474, 110, 44, "Speed x" .. speed, function() ns.db.settings.speed = speed == 4 and 1 or speed * 2; B().Render() end)
  UI.button(270, 474, 190, 44, "Skip to result", function() B().Go("Results", { out = out, prep = args.prep }) end, { kind = "primary", size = 17 })
  UI.text(640, 482, "The result was decided at Pull. Skipping loses nothing.", { size = 11.5, col = "muted", w = 296, justify = "RIGHT" })
  -- Tick: one round every 0.9 s at x1.
  B().StartPlayback(function(_, elapsed)
    if args.paused then return end
    args.t = args.t + elapsed
    local step = 0.9 / (ns.db.settings.speed or 1)
    if args.t >= step then
      args.t = 0
      if args.round >= run.rounds then B().Go("Results", { out = out, prep = args.prep })
      else
        args.round = args.round + 1
        for _, e in ipairs(run.events) do
          if e.r == args.round and (e.c == 23 or e.c == 61 or e.c == 68) then ns.Audio.Play("windup"); break end
        end
        B().Render()
      end
    end
  end)
end

-- ------------------------------------------------------------------ results
local function moraleSummary(list)
  local by, order = {}, {}
  for _, m in ipairs(list or {}) do
    if not by[m.why] then by[m.why] = { n = 0, d = m.d }; order[#order + 1] = m.why end
    by[m.why].n = by[m.why].n + 1
  end
  local parts = {}
  for _, why in ipairs(order) do parts[#parts + 1] = UI.title(why) .. ": " .. by[why].n .. (by[why].n == 1 and " raider " or " raiders ") .. (by[why].d > 0 and "+" or "") .. by[why].d end
  return #parts > 0 and table.concat(parts, " · ") or "No change."
end
function P.Results(st, args)
  local g = G()
  local out = args.out
  local b = g.BOSS[out.boss]
  local kill = out.result == "kill"
  B().tabs = false
  B().crumb = "Result · " .. b.name .. " (" .. g.MODES[out.mode].label .. ")"
  UI.panel(24, 70, 912, 60, "row", kill and "good" or "bad")
  UI.text(44, 84, (kill and "Kill" or out.result == "wipe" and "Wipe" or "Out of time") .. " in round " .. out.run.rounds, { head = true, size = 24 })
  local right = kill and ("+" .. out.gold .. " gold · +" .. out.dkp .. " DKP") or (b.name .. " at " .. math.floor(100 * out.run.bossHp / out.run.bossMax + 0.5) .. "%")
  UI.text(600, 84, right, { size = 13, w = 316, justify = "RIGHT" })
  UI.text(44, 140, kill and b.kill or (out.joke or ""), { size = 13, w = 880 })
  -- Recap (a wipe) or the "you won, but" note (a kill).
  local L = out.lesson or out.note
  UI.panel(24, 162, 560, 120)
  UI.rect(24, 162, 5, 120, "warn")
  if L then
    UI.text(42, 172, kill and "YOU WON, BUT" or "WHAT HAPPENED", { size = 11, col = "warn" })
    UI.text(42, 190, L.text, { size = 13, w = 530, wrap = true, h = 54 })
    if L.next ~= "" then UI.text(42, 246, L.next, { size = 12, col = "muted", w = 530 }) end
  else
    UI.text(42, 190, "Clean kill. Nothing to add.", { size = 13 })
  end
  if #out.found > 0 then UI.icon(42, 262, 16, "book"); UI.text(64, 264, "New in the journal: " .. table.concat(out.found, ", "), { size = 12, w = 510 }) end
  -- Gold, getting better, morale.
  local money = {}
  if out.spent > 0 then money[#money + 1] = "Prep -" .. out.spent end
  if out.gold > 0 then money[#money + 1] = (out.lockout and "Lockout loot" or out.reclear and "Re-clear" or "Kill") .. " +" .. out.gold end
  if out.repair > 0 then money[#money + 1] = "Repairs -" .. out.repair end
  if out.repairWaived then money[#money + 1] = "Repairs waived: first wipe this week (" .. out.repairWaived .. " gold)" end
  if out.buffsLost then money[#money + 1] = "World buffs lost" end
  UI.text(24, 294, "Gold", { head = true, size = 14 })
  UI.text(24, 314, #money > 0 and table.concat(money, " · ") or "No change.", { size = 12, w = 560 })
  local gr = out.growth
  UI.text(24, 340, "Getting better", { head = true, size = 14 })
  UI.text(24, 360, gr.counted and string.format("Skill +%.1f · knows %s +%.1f · chemistry +%.2f", gr.skill, b.name, gr.fam, gr.chem) or "Nothing more to learn from this boss this week.", { size = 12, w = 560 })
  UI.text(24, 386, "Morale", { head = true, size = 14 })
  UI.text(24, 406, moraleSummary(out.morale), { size = 12, w = 560, wrap = true, h = 30 })
  local y = 440
  if #out.benched > 0 then UI.text(24, y, "Benched until reset: " .. table.concat(out.benched, ", "), { size = 12, col = "bad", w = 560 }); y = y + 18 end
  if #out.quit > 0 then UI.icon(24, y, 16, "warn"); UI.text(46, y + 1, table.concat(out.quit, " and ") .. " rage quit the guild.", { size = 12, col = "bad", w = 540 }) end
  -- Replay with another card (wipes only, once per boss a week).
  local ri = g.ReplayInfo(st)
  UI.panel(600, 162, 336, 160)
  UI.text(618, 172, "Replay that pull", { head = true, size = 15 })
  if args.replay then
    local w = args.replay.run
    UI.text(618, 200, "With " .. g.CARDS[args.replay.card] .. ": " .. (w.result == "kill" and "kill in round " .. w.rounds or (w.result .. ", boss at " .. math.floor(100 * w.bossHp / w.bossMax + 0.5) .. "%")) .. ".", { size = 13, w = 300, wrap = true, h = 40 })
    UI.text(618, 246, "Nothing was won or lost. Try it for real with Change plan.", { size = 11.5, col = "muted", w = 300, wrap = true, h = 30 })
  elseif ri.ok then
    UI.text(618, 198, "The same pull with another card. Nothing is won or lost. Once per boss a week.", { size = 12, col = "muted", w = 300, wrap = true, h = 34 })
    local k = 0
    for _, c in ipairs(g.CARD_ORDER) do
      if c ~= args.prep.tactic and k < 3 then
        UI.button(618 + k * 104, 270, 96, 36, g.CARDS[c], function() args.replay = g.Replay(st, c); B().Render() end, { size = 12.5 })
        k = k + 1
      end
    end
  else
    UI.text(618, 198, kill and "Kills can't be replayed." or "Used for this boss this week.", { size = 12, col = "muted", w = 300 })
  end
  UI.button(600, 466, 150, 50, "Pull again", function() P.DoPull(st, args.prep) end,
    { kind = "primary", size = 18, disabled = #g.Problems(st, args.prep) > 0, tip = g.Problems(st, args.prep)[1] })
  UI.button(758, 466, 110, 50, "Change plan", function() B().Go("Prep", { boss = out.boss, mode = out.mode, prep = args.prep }) end, { size = 12.5 })
  UI.button(876, 466, 60, 50, "Hub", function() B().Go("Hub") end, { size = 12.5 })
  if not args.sounded then args.sounded = true; ns.Audio.Play(kill and "kill" or "wipe") end
  if #out.loot > 0 and not args.lootShown then args.lootShown = true; ns.Audio.Play("loot"); P.LootWindow() end
end

-- ------------------------------------------------------------------ loot window
local function candidates(st, item)
  local g = G()
  local list = {}
  for _, id in ipairs(item.eligible or {}) do
    local c = g.byId(st, id)
    if c and g.canWear(c, item) then list[#list + 1] = { c = c, gain = item.lvl - c.gear[item.slot].lvl } end
  end
  table.sort(list, function(a, b) if a.gain ~= b.gain then return a.gain > b.gain end return a.c.id < b.c.id end)
  return list
end
function P.LootWindow()
  B().OpenModal(function(st)
    local g = G()
    if #st.pending == 0 then return false end
    UI.panel(150, 92, 660, 412, "panel", "rule")
    UI.icon(170, 108, 40, "chest")
    UI.text(222, 106, "Loot", { head = true, size = 22 })
    UI.text(222, 134, #st.pending .. (#st.pending == 1 and " item" or " items") .. " · boss loot can only go to someone who was in the pull · numbers are gear level gained", { size = 11.5, col = "muted", w = 570 })
    for i = 1, math.min(2, #st.pending) do
      local it = st.pending[i]
      local y = 160 + (i - 1) * 134
      UI.panel(168, y, 624, 122, "row")
      UI.icon(184, y + 16, 48, it.slot == "armor" and it.type or it.slot)
      UI.text(248, y + 12, it.name, { size = 15, col = UI.T().rarity[it.q] or "ink", w = 530 })
      if g.FLAVOUR[it.name] then UI.button(244, y + 8, 300, 22, nil, nil, { kind = "row", tip = it.name .. "\n" .. g.FLAVOUR[it.name] }) end
      UI.text(248, y + 32, UI.title(it.q) .. " · " .. (it.slot == "armor" and (UI.title(it.type) .. " armor") or UI.title(it.slot)) .. " · gear level " .. it.lvl .. " · " .. (it.from or ""), { size = 12, col = "muted", w = 530 })
      local list = candidates(st, it)
      local best = list[1] and list[1].gain > 0 and list[1].c.id
      local warn
      for k = 1, math.min(3, #list) do
        local cd = list[k]
        local x = 248 + (k - 1) * 150
        UI.button(x, y + 56, 144, 40, "", function() B().Toast(g.AssignPending(st, i, cd.c.id)); ns.Audio.Play("assign"); B().Render() end,
          { kind = cd.c.id == best and "selected" or "normal", tip = "Give it to " .. cd.c.name })
        UI.portrait(x + 14, y + 62, 28, cd.c.cls, cd.c.look)
        UI.text(x + 46, y + 69, cd.c.name, { size = 12.5, col = cd.c.id == best and "seltext" or "ink", w = 60 })
        UI.text(x + 98, y + 69, (cd.gain > 0 and "+" or "") .. cd.gain, { size = 12.5, col = cd.c.id == best and "seltext" or "ink", w = 28, justify = "RIGHT" })
      end
      for _, cd in ipairs(list) do
        for _, t in ipairs(cd.c.traits) do
          if t == "needs_on_everything" and cd.c.id ~= best then warn = cd.c.name .. " has Needs on Everything: 15% chance they take it anyway." end
        end
      end
      if #list == 0 then UI.text(248, y + 70, "Nobody in the pull can use this.", { size = 12, col = "muted" }) end
      UI.button(700, y + 56, 84, 40, "Sell " .. g.sellValue(it) .. " g", function() B().Toast(g.AssignPending(st, i, "sell")); ns.Audio.Play("assign"); B().Render() end, { size = 12 })
      if warn then UI.icon(250, y + 102, 14, "warn"); UI.text(270, y + 102, warn, { size = 11.5, w = 500 })
      else UI.text(248, y + 102, it.slot == "armor" and ("Only " .. it.type .. " wearers are offered " .. it.type .. ".") or "", { size = 11.5, col = "muted", w = 500 }) end
    end
    UI.text(170, 462, "Loot drama can happen: 10% per item.", { size = 11.5, col = "muted" })
    UI.button(486, 446, 120, 44, "Decide later", function() B().CloseModal() end)
    UI.button(614, 444, 178, 48, "Hand out", function()
      for _ = 1, 50 do
        if #st.pending == 0 then break end
        local to = g.SuggestFor(st, st.pending[1])
        B().Toast(g.AssignPending(st, 1, to))
      end
      B().CloseModal()
    end, { kind = "primary", size = 20, tip = "Everything to the best upgrade; anything nobody needs is sold" })
  end)
end
