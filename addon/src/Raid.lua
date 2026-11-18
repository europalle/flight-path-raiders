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
  -- After a Heroic wipe the dead are benched: they leave the plan, the rest pull again (design doc 4.5).
  if mode == "heroic" then
    for i = #prep.ids, 1, -1 do local c = g.byId(st, prep.ids[i]) if not c or c.benched then table.remove(prep.ids, i) end end
  end
  B().crumb = "Prep · " .. b.name .. " (" .. g.MODES[mode].label .. ")"
  -- Banner: what the raid knows about this boss.
  UI.panel(24, 100, 912, 62)
  P.bossArt(32, 106, 78, 50, b)
  local known = {}
  for _, a in ipairs(b.abilities) do if (st.journal[b.id] or {})[a.id] then known[#known + 1] = a.name end end
  UI.text(122, 112, #known > 0 and ("Seen: " .. table.concat(known, ", ") .. ".") or "Nobody has seen this fight yet. Pull it and the journal fills in.", { size = 13, w = 640 })
  local answer
  for _, l in ipairs(g.LESSONS[b.id] or {}) do if ((st.lessonTier or {})[b.id .. ":" .. l.id] or -1) >= 2 then answer = l.t[3] end end
  UI.icon(122, 138, 16, "book")
  UI.text(142, 138, answer and ("Journal: " .. answer) or "The recap after a wipe tells you what went wrong.", { size = 12, col = "muted", w = 780 })
  -- Raid by zone. Click a card to send it to the bench; the small button changes the zone.
  local inRaid = {}
  for _, id in ipairs(prep.ids) do inRaid[id] = true end
  for zi, z in ipairs(ZONES) do
    local y = 174 + (zi - 1) * 54
    UI.text(30, y + 14, ZONE_LABEL[z], { head = true, size = 16 })
    -- Cards share the row: up to 4 at full width, more get narrower so nobody in the raid is hidden (S1).
    local members = {}
    for _, id in ipairs(prep.ids) do local c = g.byId(st, id) if c and prep.zones[tostring(id)] == z then members[#members + 1] = c end end
    local n = #members
    local cw = n <= 4 and 152 or math.floor((640 - (n - 1) * 6) / n)
    for k, c in ipairs(members) do
      local id = c.id
      local x = 96 + (k - 1) * (cw + (n <= 4 and 8 or 6))
      local wide = cw >= 120
      UI.panel(x, y, cw, 48, "row")
      UI.portrait(x + 4, y + 4, 40, c.cls, c.look)
      if wide then
        UI.text(x + 50, y + 5, c.name, { size = 13, w = 70 })
        UI.icon(x + cw - 20, y + 4, 14, "role-" .. g.role(c.cls, c.spec))
        UI.text(x + 50, y + 21, g.specName(c.cls, c.spec), { size = 11, col = "muted", w = 74 })
        UI.text(x + 50, y + 33, "GL " .. g.gearLevel(c), { size = 11 })
        UI.text(x + 84, y + 33, "Mor " .. c.morale, { size = 11, col = UI.moraleCol(c.morale) })
      else
        UI.text(x + 48, y + 6, c.name, { size = 11, w = cw - 50 })
      end
      if prep.potions[tostring(id)] then UI.icon(x + 30, y + 30, 14, "firepot") end
      UI.button(x, y, cw - 30, 48, nil, function()
        for i, v in ipairs(prep.ids) do if v == id then table.remove(prep.ids, i); break end end
        ns.Audio.Play("bench"); B().Render()
      end, { kind = "row", tip = c.name .. ", " .. g.specName(c.cls, c.spec) .. ", GL " .. g.gearLevel(c) .. ", morale " .. c.morale .. ": click to bench for this pull" })
      UI.button(x + cw - 26, y + 24, 24, 20, string.sub(ZONE_LABEL[z], 1, 1), function()
        local nz = ZONES[(zi % 4) + 1]; prep.zones[tostring(id)] = nz; B().Render()
      end, { size = 11, tip = c.name .. ": move to " .. ZONE_LABEL[ZONES[(zi % 4) + 1]] })
    end
  end
  -- Bench.
  UI.panel(744, 172, 192, 210)
  UI.text(758, 180, "Bench", { head = true, size = 16 })
  local y = 206
  for _, c in ipairs(st.roster) do
    if not inRaid[c.id] and y < 370 then
      local blocked = mode == "heroic" and c.benched
      UI.panel(756, y, 168, 38, "row", blocked and "bad" or "rule")
      UI.portrait(760, y + 3, 32, c.cls, c.look, blocked)
      UI.text(798, y + 5, c.name, { size = 12.5, col = blocked and "muted" or "ink" })
      UI.text(798, y + 20, blocked and "Benched until reset" or (UI.title(c.cls) .. " · GL " .. g.gearLevel(c)), { size = 11, col = "muted" })
      UI.button(756, y, 168, 38, nil, function()
        table.insert(prep.ids, c.id); prep.zones[tostring(c.id)] = g.defaultZone(c); prep.fireOn[tostring(c.id)] = 0; B().Render()
      end, { kind = "row", disabled = blocked or #prep.ids >= 10, tip = blocked and "Died on Heroic this week." or #prep.ids >= 10 and "Raids take 10." or "Add to the raid" })
      y = y + 44
    end
  end
  -- Tactic cards.
  UI.text(30, 402, "Tactic", { head = true, size = 16 })
  for i, id in ipairs(g.CARD_ORDER) do
    local x = 96 + (i - 1) * 160
    local on = prep.tactic == id
    UI.button(x, 392, 152, 48, g.CARDS[id], function() prep.tactic = id; ns.Audio.Play("pick"); B().Render() end,
      { kind = on and "selected" or "normal", size = 14, tip = g.CARDS[id] .. ": " .. g.CARD_TEXT[id] })
    if on then UI.icon(x + 23, 409, 14, "check") end
    -- The card's headline effect under it; the whole effect is in its tooltip.
    local short = string.match(g.CARD_TEXT[id], "^([^;]+)") or g.CARD_TEXT[id]
    UI.text(x, 444, short, { size = 11, col = on and "ink" or "muted", w = 152, justify = "CENTER" })
  end
  -- Consumables. Fire gear is worn automatically on Ragnaroast; potions go to melee and tanks with one toggle.
  UI.text(30, 478, "Prep", { head = true, size = 16 })
  local x = 96
  local hasMage = false
  for _, id in ipairs(prep.ids) do local c = g.byId(st, id) if c and c.cls == "mage" then hasMage = true end end
  local chips = { { "food", "Food " .. (hasMage and "free (mage)" or (g.ECON.cauldron.food .. " g")), "food" },
    { "elixirs", "Elixirs " .. g.ECON.cauldron.elixirs .. " g", "elixir" }, { "flasks", "Flasks " .. g.ECON.cauldron.flasks .. " g", "flask" } }
  for _, ch in ipairs(chips) do
    local on = prep.cons[ch[1]]
    UI.button(x, 474, 140, 28, ch[2], function() prep.cons[ch[1]] = not prep.cons[ch[1]]; B().Render() end, { kind = on and "selected" or "normal", size = 11.5 })
    x = x + 146
  end
  if b.id == "ragnaroast" then
    local any = false
    for _, id in ipairs(prep.ids) do if prep.potions[tostring(id)] then any = true end end
    UI.button(x, 474, 196, 28, "Fire potions: melee + tanks", function()
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
  -- The first problem or warning sits in the banner's corner, like the hi-fi's warning pill.
  local note = problems[1] or warnings[1]
  if note then
    UI.rect(560, 112, 364, 38, "row", 1, "plate")
    UI.icon(568, 123, 16, "warn")
    UI.text(590, 117, note, { size = 11.5, col = problems[1] and "bad" or "ink", w = 328, wrap = true, h = 30 })
  end
  UI.text(744, 458, "This pull costs", { size = 12, col = "muted" })
  UI.text(744, 475, cost .. " gold of " .. UI.money(st.gold), { size = 13 })
  local last = st.lastPrep[b.id .. ":" .. mode]
  if last and last.tactic == prep.tactic then UI.text(744, 494.5, "Same as last pull", { size = 11.5, col = "accent" }) end
  UI.button(840, 462, 96, 52, "Pull", function() P.DoPull(st, prep) end, { kind = "primary", size = 22, disabled = problems[1] ~= nil, tip = problems[1] })
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
  UI.tex(25, 71, 608, 338, "stage-" .. UI.theme)
  if ns.MEDIA.bosses and ns.MEDIA.bosses[b.id] then UI.tex(360, 110, 270, 270, "bossart-" .. b.id)
  else  -- no drawing yet (art prompts F3-F6): a name plate on the stage instead
    UI.rect(410, 196, 210, 56, "row", 1, "plate")
    UI.text(410, 206, b.name, { head = true, size = 22, w = 210, justify = "CENTER" })
    UI.text(410, 234, "drawing to come", { size = 11, col = "muted", w = 210, justify = "CENTER" })
  end
  -- Columns by zone, healers at the back on the left, tanks facing the boss (as the hi-fi stage).
  local colx = { back = 60, ranged = 140, melee = 230, front = 300 }
  local inZone, count = {}, { front = 0, melee = 0, ranged = 0, back = 0 }
  for _, c in ipairs(input.raid) do inZone[c.zone] = (inZone[c.zone] or 0) + 1 end
  for i, c in ipairs(input.raid) do
    local z = colx[c.zone] and c.zone or "ranged"
    local n = inZone[c.zone] or 1
    local step = math.min(70, 200 / math.max(1, n - 1))
    local y0 = 270 - step * (n - 1) / 2
    local hp = f.h and f.h[i] or 1
    local ch = nil
    for _, x in ipairs(st.roster) do if x.name == c.name then ch = x end end
    UI.portrait(colx[z], y0 + count[z] * step, 46, c.class, ch and ch.look or 0, hp <= 0)
    count[z] = count[z] + 1
  end
  -- Round and boss health.
  UI.panel(648, 70, 288, 118)
  UI.text(662, 80, "Round", { size = 12, col = "muted" })
  UI.text(662, 92, tostring(r), { head = true, size = 40 }); UI.text(690 + (r >= 10 and 18 or 0), 116, "/ 20", { size = 16, col = "muted" })
  if b.submerge_at or g.BOSS[b.id].id == "ragnaroast" then UI.text(800, 80, "Sinks at round 10", { size = 11.5, col = "muted", w = 122, justify = "RIGHT" }) end
  UI.text(662, 147, b.name, { size = 13 })
  local pct = (f.b or run.bossMax) / run.bossMax
  UI.text(860, 147, math.floor(pct * 100 + 0.5) .. "%", { size = 13, w = 62, justify = "RIGHT" })
  UI.bar(662, 168, 260, 12, pct, "accent")
  -- Log: the last lines up to this round.
  UI.panel(648, 198, 288, 212)
  UI.text(662, 206, "What happened", { head = true, size = 16 })
  local lines = {}
  for _, e in ipairs(run.events) do if e.r <= r and e.t and e.t ~= "" then lines[#lines + 1] = e end end
  local y = 236
  for i = math.max(1, #lines - 5), #lines do
    local e = lines[i]
    UI.text(662, y + 0.5, "R" .. e.r, { size = 11.5, col = "muted" }); UI.text(692, y, e.t, { size = 12, col = LOGCOL[e.c] or "ink", w = 236 })
    y = y + 26
  end
  -- Raid health.
  for i, c in ipairs(input.raid) do
    local x = 24 + (i - 1) * 91.5
    local hp = f.h and f.h[i] or 1
    local mx = run.raid[i] and run.raid[i].maxhp or 1
    local frac = math.max(0, hp) / math.max(1, mx)
    if not f.h then frac = 1 end
    UI.panel(x, 420, 86, 40, "row")
    UI.text(x + 6, 424.5, c.name, { size = 11.5, col = frac <= 0 and "muted" or "ink", w = 74 })
    if frac <= 0 then UI.text(x + 40, 425, "Dead", { size = 11, col = "bad", w = 40, justify = "RIGHT" }) end
    UI.bar(x + 6, 444, 74, 6, frac, frac > 0.4 and "hp" or "bad")
  end
  local speed = ns.db.settings.speed or 1
  UI.button(24, 474, 120, 44, args.paused and "Play" or "Pause", function() args.paused = not args.paused; B().Render() end)
  UI.button(152, 474, 110, 44, "Speed x" .. speed, function() ns.db.settings.speed = speed == 4 and 1 or speed * 2; B().Render() end)
  UI.button(270, 474, 190, 44, "Skip to result", function() B().Go("Results", { out = out, prep = args.prep }) end, { kind = "primary", size = 19 })
  UI.button(468, 474, 150, 44, "Summary only", function()
    ns.db.settings.playback = "summary"; B().Go("Results", { out = out, prep = args.prep })
  end, { tip = "Go straight to results from now on (Settings can turn playback back on)" })
  UI.text(636, 480.5, "The result was decided at Pull.", { size = 11.5, col = "muted", w = 300, justify = "RIGHT" })
  UI.text(636, 496.5, "Skipping loses nothing.", { size = 11.5, col = "muted", w = 300, justify = "RIGHT" })
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
  -- Coordinates follow ux/hifi/results-*.svg (text tops are the hi-fi baseline minus the size).
  UI.panel(24, 100, 912, 66, "row", kill and "good" or "bad")
  UI.text(44, 114, (kill and "Kill" or out.result == "wipe" and "Wipe" or "Out of time") .. " in round " .. out.run.rounds, { head = true, size = 26 })
  local right = kill and ("+" .. out.gold .. " gold · +" .. out.dkp .. " DKP") or (b.name .. " at " .. math.floor(100 * out.run.bossHp / out.run.bossMax + 0.5) .. "%")
  UI.text(600, 119, right, { size = 13, w = 316, justify = "RIGHT" })
  local sub = out.mode == "heroic" and ("Heroic score this week " .. UI.money(g.heroicScore(st))) or (#out.benched > 0 and (#out.benched .. " benched until reset") or "")
  UI.text(600, 138, sub, { size = 12, col = "muted", w = 316, justify = "RIGHT" })
  UI.text(44, 179, kill and b.kill or (out.joke or ""), { size = 13, w = 880 })
  -- Recap (a wipe) or the "you won, but" note (a kill).
  local L = out.lesson or out.note
  UI.panel(24, 204, 560, 132)
  UI.rect(24, 204, 5, 132, "warn")
  if L then
    UI.text(42, 215, kill and "YOU WON, BUT" or "WHAT HAPPENED", { size = 11, col = "warn" })
    UI.text(42, 234.5, L.text, { size = 13.5, w = 530, wrap = true, h = 50 })
    if L.next ~= "" then UI.text(42, 288, L.next, { size = 12, col = "muted", w = 530 }) end
  else
    UI.text(42, 234.5, "Clean kill. Nothing to add.", { size = 13.5 })
  end
  if #out.found > 0 then UI.icon(42, 310, 16, "book"); UI.text(64, 313, "New in the journal: " .. table.concat(out.found, ", "), { size = 12, w = 510 }) end
  -- Gold, getting better, morale.
  local money = {}
  if out.spent > 0 then money[#money + 1] = "Prep -" .. out.spent end
  if out.gold > 0 then money[#money + 1] = (out.lockout and "Lockout loot" or out.reclear and "Re-clear" or "Kill") .. " +" .. out.gold end
  if out.repair > 0 then money[#money + 1] = "Repairs -" .. out.repair end
  if out.repairWaived then money[#money + 1] = "Repairs waived: first wipe this week (" .. out.repairWaived .. " gold)" end
  if out.buffsLost then money[#money + 1] = "World buffs lost" end
  UI.text(24, 349, "Gold", { head = true, size = 15 })
  UI.text(24, 372, #money > 0 and table.concat(money, " · ") or "No change.", { size = 12, w = 560 })
  local gr = out.growth
  UI.text(24, 397, "Getting better", { head = true, size = 15 })
  UI.text(24, 420, gr.counted and string.format("Skill +%.1f · knows %s +%.1f · chemistry +%.2f", gr.skill, b.name, gr.fam, gr.chem) or "Nothing more to learn from this boss this week.", { size = 12, w = 560 })
  UI.text(24, 445, "Morale", { head = true, size = 15 })
  UI.text(24, 468, moraleSummary(out.morale), { size = 12, w = 560 })
  local alerts = {}
  if #out.quit > 0 then alerts[#alerts + 1] = table.concat(out.quit, " and ") .. " rage quit the guild" end
  if #out.benched > 0 then alerts[#alerts + 1] = "Benched until reset: " .. table.concat(out.benched, ", ") end
  if #alerts > 0 then UI.icon(24, 492, 16, "warn"); UI.text(46, 493, table.concat(alerts, ". ") .. ".", { size = 12, col = "bad", w = 540 }) end
  -- Replay with another card (wipes only, once per boss a week).
  local ri = g.ReplayInfo(st)
  UI.panel(600, 204, 336, 132, nil, nil, true)
  UI.text(618, 216, "Replay that pull", { head = true, size = 16 })
  if args.replay then
    local w = args.replay.run
    UI.text(618, 242, "With " .. g.CARDS[args.replay.card] .. ": " .. (w.result == "kill" and "kill in round " .. w.rounds or (w.result .. ", boss at " .. math.floor(100 * w.bossHp / w.bossMax + 0.5) .. "%")) .. ".", { size = 13, w = 300, wrap = true, h = 40 })
    UI.text(618, 290, "Nothing was won or lost. Try it for real with Change plan.", { size = 11.5, col = "muted", w = 300, wrap = true, h = 30 })
  elseif ri.ok then
    UI.text(618, 242, "The same pull with another card.", { size = 12, col = "muted", w = 300 })
    UI.text(618, 258, "Nothing is won or lost. Once per boss a week.", { size = 12, col = "muted", w = 300 })
    local k = 0
    for _, c in ipairs(g.CARD_ORDER) do
      if c ~= args.prep.tactic and k < 3 then
        UI.button(618 + k * 104, 284, 96, 36, g.CARDS[c], function() args.replay = g.Replay(st, c); B().Render() end, { size = 12.5 })
        k = k + 1
      end
    end
  else
    UI.text(618, 242, kill and "Kills can't be replayed." or "Used for this boss this week.", { size = 12, col = "muted", w = 300 })
  end
  UI.button(600, 466, 150, 50, "Pull again", function() P.DoPull(st, args.prep) end,
    { kind = "primary", size = 20, disabled = #g.Problems(st, args.prep) > 0, tip = g.Problems(st, args.prep)[1] })
  UI.button(758, 466, 110, 50, "Change plan", function() B().Go("Prep", { boss = out.boss, mode = out.mode, prep = args.prep }) end, { size = 13 })
  UI.button(876, 466, 60, 50, "Hub", function() B().Go("Hub") end, { size = 13 })
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
    UI.panel(150, 92, 660, 412, "panel", "rule", true)
    UI.icon(170, 110, 40, "chest")
    UI.text(222, 106, "Loot", { head = true, size = 24 })
    UI.text(222, 138, #st.pending .. (#st.pending == 1 and " item" or " items") .. " · boss loot can only go to someone who was in the pull · numbers are gear level gained", { size = 11.5, col = "muted", w = 570 })
    -- Two items at a time, with paging; three candidates at a time, with a button for the rest (S2).
    if not P.lootFirst or P.lootFirst > #st.pending then P.lootFirst = 1 end
    P.candOff = P.candOff or {}
    for i = P.lootFirst, math.min(P.lootFirst + 1, #st.pending) do
      local it = st.pending[i]
      local y = 168 + (i - P.lootFirst) * 134
      UI.panel(168, y, 624, 122, "row")
      UI.icon(184, y + 16, 48, it.slot == "armor" and it.type or it.slot)
      UI.text(248, y + 17, it.name, { size = 15, col = UI.T().rarity[it.q] or "ink", w = 530 })
      if g.FLAVOUR[it.name] then UI.button(244, y + 13, 300, 22, nil, nil, { kind = "row", tip = it.name .. "\n" .. g.FLAVOUR[it.name] }) end
      UI.text(248, y + 38, UI.title(it.q) .. " · " .. (it.slot == "armor" and (UI.title(it.type) .. " armor") or UI.title(it.slot)) .. " · gear level " .. it.lvl .. " · " .. (it.from or ""), { size = 12, col = "muted", w = 530 })
      local list = candidates(st, it)
      local best = list[1] and list[1].gain > 0 and list[1].c.id
      local warn
      local off = P.candOff[it] or 0
      if off >= #list then off = 0 end
      for k = 1, math.min(3, #list - off) do
        local cd = list[k + off]
        local x = 248 + (k - 1) * 142
        UI.button(x, y + 58, 136, 40, "", function() B().Toast(g.AssignPending(st, i, cd.c.id)); ns.Audio.Play("assign"); B().Render() end,
          { kind = cd.c.id == best and "selected" or "normal", tip = "Give it to " .. cd.c.name })
        UI.portrait(x + 14, y + 64, 28, cd.c.cls, cd.c.look)
        UI.text(x + 46, y + 71, cd.c.name, { size = 12.5, col = cd.c.id == best and "seltext" or "ink", w = 56 })
        UI.text(x + 92, y + 71, (cd.gain > 0 and "+" or "") .. cd.gain, { size = 12.5, col = cd.c.id == best and "seltext" or "ink", w = 28, justify = "RIGHT" })
      end
      if #list > 3 then
        UI.button(672, y + 58, 24, 40, ">", function() P.candOff[it] = off + 3; B().Render() end,
          { size = 13, tip = (#list - 3) .. " more can use it: show them" })
      end
      for _, cd in ipairs(list) do
        for _, t in ipairs(cd.c.traits) do
          if t == "needs_on_everything" and cd.c.id ~= best then warn = cd.c.name .. " has Needs on Everything: 15% chance they take it anyway." end
        end
      end
      if #list == 0 then UI.text(248, y + 70, "Nobody in the pull can use this.", { size = 12, col = "muted" }) end
      UI.button(700, y + 58, 84, 40, "Sell " .. g.sellValue(it) .. " g", function() B().Toast(g.AssignPending(st, i, "sell")); ns.Audio.Play("assign"); B().Render() end, { size = 12 })
      if warn then UI.icon(250, y + 102, 14, "warn"); UI.text(270, y + 102, warn, { size = 11.5, w = 500 })
      else UI.text(248, y + 102, it.slot == "armor" and ("Only " .. it.type .. " wearers are offered " .. it.type .. ".") or "", { size = 11.5, col = "muted", w = 500 }) end
    end
    UI.text(170, 458.5, "Loot drama can happen: 10% per item.", { size = 11.5, col = "muted" })
    if #st.pending > 2 then
      local last = math.min(P.lootFirst + 1, #st.pending)
      UI.text(170, 478, "Items " .. P.lootFirst .. "-" .. last .. " of " .. #st.pending, { size = 11.5 })
      UI.button(300, 470, 80, 30, "Next", function() P.lootFirst = (last >= #st.pending) and 1 or last + 1; B().Render() end, { size = 12, tip = "Show the next items" })
    end
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
