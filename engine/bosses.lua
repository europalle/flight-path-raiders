-- Flight Path Raiders: boss mechanics as hooks. A boss in data.lua is plain numbers; each mechanic here
-- is switched on by the field it needs (pups, bomb, curse_every...) and runs at fixed points of a round.
-- Simulate calls ns.BossHooks.run(phase, F) with F, the fight context (state plus helpers).
-- Adding a boss means adding data and, if it does something new, one mechanic here; Simulate itself
-- does not change, which keeps it clear of Lua 5.1's 60-upvalue limit (gate review, issue #29).
-- Order inside a phase is fixed by PHASES, so results never depend on table iteration order.
local _, ns = ...
if not ns then ns = FPR_ENGINE or {}; FPR_ENGINE = ns end
local floor = math.floor
local function idiv(a, b) return floor(a / b) end
local function pm(v, permille) return idiv(v * permille, 1000) end

local M = {}

-- ---------------------------------------------------------------- start of the round (before the boss acts)
M.submerge = { key = "submerge_at", start = function(F)
  local B = F.boss_def
  if F.round == B.submerge_at then
    F.boss.submerged = true; F.boss.surface_at = F.round + B.submerge_rounds
    F.spawn_adds(B.adds, B.add_hp)
    F.log(20, B.adds, 0, F.boss.name .. " sinks into the lava and summons " .. B.adds .. " fire adds.")
  end
end }
-- Magmadad: pups from the pull. Majordomo: interns from the pull while he stays away.
M.pups = { key = "pups", start = function(F)
  local B = F.boss_def
  if F.round == 1 then
    F.spawn_adds(B.pups, B.add_hp)
    F.log(60, B.pups, 0, F.boss.name .. " brings his " .. B.pups .. " magma pups. \"Say hi, kids.\"")
  end
end,
-- Dead pups get back up unless every pup died within the window.
round_end = function(F)
  local B, adds = F.boss_def, F.adds
  if F.pups_done then return end
  local first, dead = nil, 0
  for a = 1, #adds do
    if not adds[a].alive then
      dead = dead + 1
      if first == nil or adds[a].died < first then first = adds[a].died end
    end
  end
  if dead == #adds then
    F.pups_done = true
    F.log(65, 0, 1, "All the pups are down at once. Magmadad is sad. \"Time for a timeout.\"")
  elseif dead > 0 and F.round - first >= B.pup_window then
    for a = 1, #adds do
      if not adds[a].alive then adds[a].alive = true; adds[a].hp = adds[a].maxhp end
    end
    F.log(65, dead, 0, "The pups get back up. \"Walk it off, champ.\"")
  end
end }
M.interns = { key = "interns", start = function(F)
  local B, boss, adds = F.boss_def, F.boss, F.adds
  if F.round == 1 then
    F.spawn_adds(B.interns, B.add_hp)
    boss.submerged = true; boss.surface_at = 1000
    F.log(63, B.interns, 0, boss.name .. " sends " .. B.interns .. " interns to deal with it.")
  end
  if boss.submerged and F.round > 1 then
    local left = 0
    for a = 1, #adds do if adds[a].alive then left = left + 1 end end
    if left == 0 then
      boss.submerged = false
      F.log(64, 0, 0, "\"Fine. FINE.\" " .. boss.name .. " joins the fight himself.")
    end
  end
end,
-- Stacked, the raid drags the interns together and every hit on one splashes onto another.
hit_add = function(F, hit_add, dealt)
  if F.inputs.tactic ~= "stack" then return end
  local adds = F.adds
  for a = 1, #adds do
    if adds[a].alive and adds[a] ~= hit_add then
      adds[a].hp = adds[a].hp - pm(dealt, F.boss_def.stack_splash)
      if adds[a].hp <= 0 then F.add_dies(adds[a]) end
      break
    end
  end
end }
-- Lucifrown: a curse every few rounds doubles mana costs. A decurser (mage or druid) shortens it.
M.curse = { key = "curse_every", start = function(F)
  local B = F.boss_def
  if not F.boss.submerged and F.round % B.curse_every == 0 then
    local len = B.curse_rounds
    if F.has["mage"] or F.has["druid"] then
      len = B.decursed_rounds
      F.log(66, 0, 1, F.boss.name .. " curses the raid. Decursed fast.")
    else
      F.log(66, 0, 0, F.boss.name .. " curses the raid. Nobody can decurse. Mana costs double.")
    end
    F.cursed_until = F.round + len - 1
  end
end }

-- ---------------------------------------------------------------- the boss acts (only while not submerged)
-- Lava throw every few rounds (a Subtlety rogue's Kick can cancel one every 5 rounds).
M.throw = { key = "throw_every", before_melee = function(F)
  local B, D, TR, raid, round = F.boss_def, F.D, F.TR, F.raid, F.round
  if round % B.throw_every ~= 0 then return end
  local kicker = nil
  for i = 1, #raid do
    local p = raid[i]
    if p.alive and p.class == "rogue" and p.spec == "subtlety" and kicker == nil then kicker = p end
  end
  if kicker and round >= F.kick_ready_round then
    F.kick_ready_round = round + 5
    F.log(22, kicker.slot, 0, kicker.name .. " kicks the wind-up. No throw this time.")
    return
  end
  -- Meeting 2026-11-18: the throw deals a share of max health (ignoring armour) instead of
  -- killing outright. Targets the lowest-health melee; with no melee, Front; then anyone.
  local victims = F.alive_in("melee")
  if #victims == 0 then victims = F.alive_in("front") end
  if #victims == 0 then victims = F.alive_in(nil) end
  local v = F.most_injured(victims)
  if not v then return end
  if v.fireres > 0 then
    v.fireres = v.fireres - 1
    F.log(23, v.slot, 1, F.boss.name .. " throws " .. v.name .. " into the lava. Fire Resistance saves them.")
  else
    F.log(23, v.slot, 0, F.boss.name .. " throws " .. v.name .. " into the lava.")
    local burn = pm(pm(pm(v.maxhp, F.mode.throw), F.tac.taken), 1000 - v.firered)
    burn = pm(burn, 1000 - D.FAMILIARITY.per_point * v.fam)
    if v.tr.stands_in_fire then burn = pm(burn, 1000 + TR.stands_in_fire.taken) end
    if v.tr.parse_goblin then burn = pm(burn, 1000 + TR.parse_goblin.taken) end
    v.hp = v.hp - burn
    if v.hp <= 0 then F.kill(v, 23) end
  end
end }
-- Magma Splash every 2nd round on a zone picked by the seed.
M.splash = { key = "splash", after_melee = function(F)
  local B, D, rng, tac = F.boss_def, F.D, F.rng, F.tac
  if F.round % 2 ~= 0 then return end
  local zone = D.ZONES[rng:int(4)]
  local list = F.alive_in(zone)
  if #list == 0 then return end
  if tac.area_single then
    local v = list[rng:int(#list)]
    if rng:chance(idiv(v.skill * D.SKILL.dodge, 100)) then
      F.log(35, v.slot, 0, v.name .. " sidesteps the Magma Splash.")
    else
      F.log(25, v.slot, 1, "Magma Splash hits " .. v.name .. ".")
      F.damage(v, F.boss_hit(pm(B.splash, F.mode_dmg)), 25, true)
    end
  else
    F.log(25, #list, 0, "Magma Splash hits the " .. zone .. " zone.")
    local splash = F.boss_hit(pm(B.splash, F.mode_dmg))
    for i = 1, #list do
      if rng:chance(idiv(list[i].skill * D.SKILL.dodge, 100)) then
        F.log(35, list[i].slot, 0, list[i].name .. " sidesteps the Magma Splash.")
      else
        F.damage(list[i], splash, 25, true)
      end
    end
  end
end }
-- Baron Get-Down: last round's bomb goes off, then a new character is marked.
M.bomb = { key = "bomb", after_melee = function(F)
  local B, raid = F.boss_def, F.raid
  local bomb = F.bomb
  if bomb and bomb.alive then
    local amt = F.boss_hit(pm(B.bomb, F.mode_dmg))
    if F.tac.area_single then
      F.log(62, bomb.slot, 1, bomb.name .. " GETS DOWN, out of the group, and explodes alone.")
      F.damage(bomb, amt, 62, true)
    else
      local list = F.alive_in(bomb.zone)
      F.log(62, bomb.slot, #list, bomb.name .. " explodes in the " .. bomb.zone .. " zone.")
      for i = 1, #list do
        local q = list[i]
        if q == bomb then F.damage(q, amt, 62, true)
        elseif not q.tr.never_stands_in_fire then F.damage(q, pm(amt, B.bomb_others or 1000), 62, true) end
      end
    end
  end
  F.bomb = nil
  if F.round >= 2 then
    local nt = {}
    for i = 1, #raid do if raid[i].alive and raid[i].role ~= "tank" then nt[#nt + 1] = raid[i] end end
    if #nt > 0 then F.bomb = nt[F.rng:int(#nt)]; F.log(61, F.bomb.slot, 0, F.bomb.name .. " is the bomb.") end
  end
end }
-- Lucifrown: Shadow Volley on everyone each round (magic, ignores armour), the Frown on a zone every 3rd.
M.volley = { key = "volley", after_melee = function(F)
  local list = F.alive_in(nil)
  local amt = pm(F.boss_def.volley, F.mode_dmg)
  for i = 1, #list do F.damage(list[i], amt, 67, false, true) end
end }
M.frown = { key = "frown", after_melee = function(F)
  local B = F.boss_def
  if F.round % 3 ~= 0 then return end
  local zone = F.D.ZONES[F.rng:int(4)]
  local stacked = F.inputs.tactic == "stack"
  local list = stacked and F.alive_in(nil) or F.alive_in(zone)
  F.log(68, #list, 0, stacked and (F.boss.name .. " frowns at the whole stacked raid.") or (F.boss.name .. " frowns at the " .. zone .. " zone."))
  local amt = F.boss_hit(pm(B.frown, F.mode_dmg))
  if stacked then amt = pm(amt, B.frown_stack or 1000) end
  for i = 1, #list do F.damage(list[i], amt, 68, false, true) end
end }

-- The order each phase runs its mechanics in.
local PHASES = {
  start = { "submerge", "pups", "interns", "curse" },
  before_melee = { "throw" },
  after_melee = { "splash", "bomb", "volley", "frown" },
  hit_add = { "interns" },
  round_end = { "pups" },
}
ns.BossHooks = {
  mechanics = M,
  run = function(phase, F, a, b)
    local list = PHASES[phase]
    for i = 1, #list do
      local m = M[list[i]]
      if F.boss_def[m.key] then m[phase](F, a, b) end
    end
  end,
}
