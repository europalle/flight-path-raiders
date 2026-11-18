-- Flight Path Raiders: deterministic combat simulator.
-- Rules for portability (technical design 3 and 11): whole numbers below 2^31 (Fengari's integers
-- are 32-bit; products that can exceed that are done in floating point and floored), every division
-- floored through idiv, arrays walked with numeric for loops, the seeded RNG as the only randomness.
local _, ns = ...
if not ns then ns = FPR_ENGINE or {}; FPR_ENGINE = ns end  -- in WoW the addon's private table; in tests a global

ns.ENGINE_VERSION = 10  -- 10: traits and morale; 9: Normal per boss, softer card checks; 8: input checks, gear band in the engine, stronger checksum, moments only in Normal (7: per-character gear, frames)

local floor = math.floor
local function idiv(a, b) return floor(a / b) end
local function pm(v, permille) return idiv(v * permille, 1000) end

local HASH_M = 2147483647
-- Hash products exceed 32 bits, so they are computed in floating point (see rng.lua).
local function mix(h, v)
  v = v % HASH_M
  if v < 0 then v = v + HASH_M end
  return (h * 31.0 + v) % HASH_M
end

-- Builds a fight from inputs; returns { result, rounds, events, checksum, raid }.
-- inputs = { boss, mode, seed, tactic, gl, consumables = {food,elixirs,flasks}, buffs = {...},
--            raid = { {name, class, spec, zone, potion, firegear}, ... } }
-- potion (or the older name fireres) = one Fire Protection Potion; firegear = 0, 1 or 2 fire resistance pieces.
-- Optional per character: skill (0-100), fam (boss familiarity, 0-10). Optional inputs.pairs =
-- { {a = slot, b = slot, v = 0-20}, ... } chemistry between two characters in this raid.
function ns.Simulate(inputs)
  local D = ns.Data
  local valid, why = ns.Validate(inputs, false)
  if not valid then error("FPR: bad fight input: " .. why, 2) end
  local rng = ns.NewRNG(inputs.seed)
  local boss_def = D.BOSSES[inputs.boss]
  local mode = D.MODES[inputs.mode]
  local tac = D.TACTICS[inputs.tactic]
  local TR = D.TRAITS
  local gl = inputs.gl or 60
  if gl < 1 then gl = 1 elseif gl > 100 then gl = 100 end
  local glmul = 1000 + D.GL_STEP * (gl - 60)
  local cons = inputs.consumables or {}
  local buffs = inputs.buffs or {}

  local events, h = {}, 7
  local round = 0
  local function log(code, a, b, text)
    events[#events + 1] = { round = round, code = code, a = a or 0, b = b or 0, text = text }
    h = mix(h, round); h = mix(h, code); h = mix(h, a or 0); h = mix(h, b or 0)
  end

  -- Raid-wide multipliers from consumables and world buffs.
  local hp_mul, pow_mul, crit = 1000, 1000, D.CRIT_CHANCE
  if cons.food then hp_mul = hp_mul + D.CONSUMABLES.food.hp end
  if cons.elixirs then pow_mul = pow_mul + D.CONSUMABLES.elixirs.power end
  if cons.flasks then hp_mul = hp_mul + D.CONSUMABLES.flasks.hp; pow_mul = pow_mul + D.CONSUMABLES.flasks.power end
  if buffs.dragonslayer then pow_mul = pow_mul + D.WORLD_BUFFS.dragonslayer.power end
  if buffs.songbloom then crit = crit + D.WORLD_BUFFS.songbloom.crit end
  if buffs.warchief then hp_mul = hp_mul + D.WORLD_BUFFS.warchief.hp end
  if cons.food and D.CONSUMABLES.food.power then pow_mul = pow_mul + D.CONSUMABLES.food.power end
  if buffs.warchief and D.WORLD_BUFFS.warchief.power then pow_mul = pow_mul + D.WORLD_BUFFS.warchief.power end

  -- Raid-wide spec auras.
  local has = {}
  for i = 1, #inputs.raid do
    local c = inputs.raid[i]
    has[c.class .. ":" .. c.spec] = true
    has[c.class] = true
  end
  if has["paladin:retribution"] then hp_mul = hp_mul + 100; pow_mul = pow_mul + 100 end -- Blessing of Kings
  if has["warlock:demonology"] then hp_mul = hp_mul + 50 end                               -- Blood Pact

  -- Characters.
  local raid = {}
  for i = 1, #inputs.raid do
    local c = inputs.raid[i]
    local cls = D.CLASSES[c.class]
    local role = D.SPECS[c.class][c.spec]
    local base = D.ROLE_BASE[role]
    local cgl = glmul  -- optional per-character gear level (the playtest's real gear)
    if c.gl then
      local g = c.gl
      if mode.band then  -- ranked modes hold gear inside the band (design doc 2), in the engine so verifiers agree
        if g < mode.band[1] then g = mode.band[1] elseif g > mode.band[2] then g = mode.band[2] end
      end
      cgl = 1000 + D.GL_STEP * (g - 60)
    end
    local hp = pm(pm(base.hp, cgl), hp_mul)
    local power = pm(pm(base.power, cgl), pow_mul)
    local spec_power = D.SPEC_POWER[c.class .. ":" .. c.spec]
    if spec_power then power = pm(power, spec_power) end
    -- Fire resistance gear trades power for resistance (pass 3).
    local pieces = c.firegear or 0
    if pieces > 2 then pieces = 2 end
    if pieces > 0 then power = pm(power, 1000 - D.FIRE.piece_power * pieces) end
    local fr = D.FIRE.piece * pieces
    if has["paladin"] or has["shaman"] then fr = fr + D.FIRE.aura end -- Fire Resistance Aura / Totem
    local firered = idiv(fr * D.FIRE.per_point, 10)
    if firered > D.FIRE.cap then firered = D.FIRE.cap end
    local armor = D.ARMOR[cls.armor] + ((role == "tank") and D.TANK_ARMOR_BONUS or 0)
    if c.class == "druid" and c.spec == "feral" then armor = armor + 60; hp = pm(hp, 1100) end -- Bear Form
    if armor > D.ARMOR_CAP then armor = D.ARMOR_CAP end
    raid[i] = {
      slot = i, name = c.name, class = c.class, spec = c.spec, role = role, zone = c.zone,
      maxhp = hp, hp = hp, power = power, armor = armor, speed = cls.speed,
      caster = cls.caster, mana = D.MANA_START, threat = 0, alive = true,
      threatmul = (role == "tank") and D.TANK_THREAT or D.OTHER_THREAT,
      fireres = (c.potion or c.fireres) and 1 or 0, crit = crit, fr = fr, firered = firered,
      used = {}, stacks = 0, shield_wall = 0, dealt = 0, healed = 0, alive_rounds = 0,
      skill = c.skill or 0, fam = c.fam or 0, skip_from = 0, skip_to = -1, zone_bonus = 0,
    }
    local q = raid[i]
    if q.skill > 100 then q.skill = 100 elseif q.skill < 0 then q.skill = 0 end
    if q.fam > D.FAMILIARITY.cap then q.fam = D.FAMILIARITY.cap elseif q.fam < 0 then q.fam = 0 end
    local p = raid[i]
    if (p.zone == "ranged" and has["druid:balance"]) then p.crit = p.crit + 30 end
    if (p.zone == "melee" and (has["druid:feral"] or has["druid:feralcat"])) then p.crit = p.crit + 30 end
    -- Traits (design doc 4.4): one or two per character, as a set.
    p.tr = {}
    local tl = c.traits or {}
    for k = 1, #tl do if TR[tl[k]] then p.tr[tl[k]] = true end end
    p.morale = c.morale or D.MORALE.start
    p.new, p.looted = c.new and true or false, c.looted and true or false
  end
  -- Trait effects that set up the fight.
  local n_new, favourite, backseat, pulls_early = 0, false, false, false
  for i = 1, #raid do
    local p = raid[i]
    if p.new then n_new = n_new + 1 end
    if p.tr.raid_leaders_favourite then favourite = true end
    if p.tr.backseat_raid_leader then backseat = true end
    if p.tr.pulls_on_cooldown then pulls_early = true end
  end
  for i = 1, #raid do
    local p = raid[i]
    local t = p.tr
    if t.hardcore_andy then p.maxhp = pm(p.maxhp, 1000 + TR.hardcore_andy.stats); p.hp = p.maxhp; p.power = pm(p.power, 1000 + TR.hardcore_andy.stats) end
    if t.parse_goblin then p.power = pm(p.power, 1000 + TR.parse_goblin.power) end
    if t.pulls_on_cooldown then p.power = pm(p.power, 1000 + TR.pulls_on_cooldown.power); p.threatmul = pm(p.threatmul, 1000 + TR.pulls_on_cooldown.power) end
    if t.keyboard_turner then p.speed = p.speed - TR.keyboard_turner.speed; if p.role ~= "tank" then p.threatmul = 0 end end
    if t.pug_hero and n_new >= TR.pug_hero.new then p.power = pm(p.power, 1000 + TR.pug_hero.power) end
    if t.main_character and p.looted then p.power = pm(p.power, 1000 + TR.main_character.power) end
    -- Morale above 80: +5% power, Normal only (ranked scores can't be inflated). The raid leader's favourite lifts everyone 10.
    local m = p.morale + (favourite and TR.raid_leaders_favourite.morale or 0)
    if m > 100 then m = 100 end
    p.morale_eff = m
    if not mode.band and m > D.MORALE.vibe_at then p.power = pm(p.power, 1000 + D.MORALE.vibe_power) end
    if pulls_early and p.role == "healer" then p.mana = pm(p.mana, TR.pulls_on_cooldown.healer_mana) end
  end
  -- A backseat raid leader makes the tactic card 5% stronger (each modifier moves 5% further from 100%).
  if backseat then
    local t2 = {}
    for k, v in pairs(tac) do
      if type(v) == "number" then t2[k] = 1000 + pm(v - 1000, 1000 + TR.backseat_raid_leader.card) else t2[k] = v end
    end
    tac = t2
  end

  -- Action order: speed high to low, then roster slot (stable, explicit insertion sort).
  local order = {}
  for i = 1, #raid do order[i] = raid[i] end
  for i = 2, #order do
    local v, j = order[i], i - 1
    while j >= 1 and (order[j].speed < v.speed or (order[j].speed == v.speed and order[j].slot > v.slot)) do
      order[j + 1] = order[j]; j = j - 1
    end
    order[j + 1] = v
  end

  -- Chemistry: bonds between pairs, and the raid's cohesion (average over every pair).
  local bond = {}
  for i = 1, #raid do bond[i] = {} end
  local chem_sum = 0
  local plist = inputs.pairs or {}
  for k = 1, #plist do
    local e = plist[k]
    local v = e.v or 0
    if v > D.CHEMISTRY.cap then v = D.CHEMISTRY.cap elseif v < 0 then v = 0 end
    if e.a ~= e.b and bond[e.a] and bond[e.b] and bond[e.a][e.b] == nil then
      bond[e.a][e.b] = v; bond[e.b][e.a] = v; chem_sum = chem_sum + v
    end
  end
  local npairs = idiv(#raid * (#raid - 1), 2)
  local cohesion10 = 0  -- cohesion x10 (0-200), whole numbers only
  if npairs > 0 then cohesion10 = idiv(chem_sum * 10, npairs) end
  local skill_sum = 0
  for i = 1, #raid do skill_sum = skill_sum + raid[i].skill end
  local avg_skill = (#raid > 0) and idiv(skill_sum, #raid) or 0
  -- Skill, cohesion and familiarity with this boss raise power (up to +3% each at the defaults).
  for i = 1, #raid do
    local p = raid[i]
    p.power = pm(p.power, 1000 + idiv(p.skill * D.SKILL.power, 100) + idiv(cohesion10 * D.CHEMISTRY.power, 200)
      + p.fam * D.FAMILIARITY.power)
    if p.role ~= "tank" then p.threatmul = pm(p.threatmul, 1000 - idiv(p.skill * D.SKILL.threat, 100)) end
  end

  local boss_hp = pm(boss_def.hp, mode.hp)
  if inputs.mode == "normal" and boss_def.normal_hp then boss_hp = pm(boss_hp, boss_def.normal_hp) end  -- per-boss Normal tuning
  local boss = { name = boss_def.name, maxhp = boss_hp, submerged = false }
  boss.hp = boss.maxhp
  local adds = {}
  local target = nil  -- the boss's current target
  local moments = { clutch = 0, early = false, early_target = nil }
  local add_name = boss_def.add_name or "a fire add"
  local function spawn_adds(n, hp)
    for a = 1, n do
      local ahp = pm(hp, mode.hp)
      if inputs.mode == "normal" and boss_def.normal_hp then ahp = pm(ahp, boss_def.normal_hp) end
      adds[#adds + 1] = { hp = ahp, maxhp = ahp, alive = true, frozen = 0, held = 0, died = 0 }
    end
    local first = #adds - n + 1
    if has["hunter:survival"] then adds[first].frozen = 3 end
    if has["warlock:demonology"] and adds[first + 1] then adds[first + 1].held = 4 end
    if has["hunter:beastmastery"] and adds[first + 2] then adds[first + 2].held = 2 end
  end
  local function add_dies(ad)
    ad.alive = false; ad.died = round
    log(27, 0, 0, string.upper(string.sub(add_name, 1, 1)) .. string.sub(add_name, 2) .. " dies.")
  end
  local cursed_until = 0     -- Lucifrown: mana costs double through this round
  local bomb = nil           -- Baron Get-Down: the character carrying the bomb
  local pups_done = false    -- Magmadad: all pups died inside the window
  local kick_ready_round = 1

  local function alive_in(zone)
    local list = {}
    for i = 1, #raid do
      local p = raid[i]
      if p.alive and (zone == nil or p.zone == zone) then list[#list + 1] = p end
    end
    return list
  end

  local function count_alive_role(role)
    local n = 0
    for i = 1, #raid do if raid[i].alive and raid[i].role == role then n = n + 1 end end
    return n
  end

  local function kill(p, cause)
    -- Once-per-fight saves, in a fixed order.
    if p.class == "mage" and p.spec == "frost" and not p.used.iceblock then
      p.used.iceblock = true; p.hp = 1
      log(30, p.slot, 1, p.name .. " Ice Blocks and survives."); return
    end
    if p.class == "paladin" and not p.used.bubble then
      p.used.bubble = true; p.hp = 1
      log(30, p.slot, 2, p.name .. " bubbles and survives."); return
    end
    if moments.clutch > 0 then
      moments.clutch = moments.clutch - 1; p.hp = pm(p.maxhp, D.MOMENTS.clutch_hp)
      log(41, p.slot, 0, p.name .. " somehow survives. Somebody screams on voice chat."); return
    end
    p.alive = false; p.hp = 0
    log(31, p.slot, cause, p.name .. " dies.")
  end

  local function damage(p, amount, cause, fire, magic)
    if not p.alive then return end
    if p.tr.never_stands_in_fire and (cause == 25 or cause == 68) then return end  -- ground effects
    -- Fire ignores armour; fire resistance reduces it instead (pass 3). Other magic ignores both.
    local dmg
    if fire then dmg = pm(amount, 1000 - p.firered) elseif magic then dmg = amount else dmg = pm(amount, 1000 - p.armor) end
    dmg = pm(dmg, tac.taken)
    if cause ~= 24 then dmg = pm(dmg, 1000 - D.FAMILIARITY.per_point * p.fam) end -- knows the mechanics
    if cause ~= 24 and cause ~= 26 then  -- boss mechanics, not melee or adds
      if p.tr.stands_in_fire then dmg = pm(dmg, 1000 + TR.stands_in_fire.taken) end
      if p.tr.parse_goblin then dmg = pm(dmg, 1000 + TR.parse_goblin.taken) end
    end
    if p.class == "warrior" and p.spec == "fury" then dmg = pm(dmg, 1100) end
    if p.shield_wall > 0 then dmg = pm(dmg, 250) end
    if dmg < 1 then dmg = 1 end
    h = mix(h, dmg)  -- damage taken is part of the checksum
    p.hp = p.hp - dmg
    if p.class == "warrior" and p.spec == "fury" and p.stacks < 3 then p.stacks = p.stacks + 1 end
    if p.hp <= 0 then kill(p, cause)
    elseif p.class == "warrior" and p.spec == "protection" and not p.used.shieldwall and p.hp * 1000 < p.maxhp * 200 then
      p.used.shieldwall = true; p.shield_wall = 2
      log(32, p.slot, 0, p.name .. " raises Shield Wall.")
    end
  end

  local function heal(p, amount)
    if not p.alive then return 0 end
    local before = p.hp
    p.hp = p.hp + amount
    if p.hp > p.maxhp then p.hp = p.maxhp end
    h = mix(h, p.hp - before)  -- healing done is part of the checksum
    return p.hp - before
  end

  local function most_injured(list, tanks_first)
    -- Healers count a tank as more hurt than it is, so tanks are not left behind (pass 3).
    local best, bestv, bestpct = nil, 100000, 1001
    for i = 1, #list do
      local p = list[i]
      local pct = idiv(p.hp * 1000, p.maxhp)
      local v = pct
      if tanks_first and p.role == "tank" then v = v - D.TANK_HEAL_PRIORITY end
      if v < bestv then best, bestv, bestpct = p, v, pct end
    end
    return best, bestpct
  end
  local function boss_hit(amount)
    if rng:chance(D.BOSS_CRIT) then return pm(amount, D.BOSS_CRIT_MULT) end
    return amount
  end

  local function roll(p, amount)
    local mult = D.CRIT_MULT
    if p.class == "warlock" and p.spec == "destruction" then mult = 1550 end
    if rng:chance(p.crit) then
      local extra = 0
      if p.class == "mage" and p.spec == "fire" then extra = 500 end -- Ignite
      return pm(amount, mult + extra), true
    end
    return amount, false
  end

  local function pick_tank(current)
    -- The boss keeps its target until someone's threat passes 110% of the target's (design doc 5).
    -- With no living target, it takes the first living tank, else the highest threat.
    local best = nil
    for i = 1, #raid do
      local p = raid[i]
      if p.alive and (best == nil or p.threat > best.threat) then best = p end
    end
    if current and current.alive then
      if best and best ~= current and best.threat * 1000 > current.threat * D.AGGRO_MARGIN then
        if best.role ~= "tank" then log(28, best.slot, 0, best.name .. " pulls aggro!") end
        return best
      end
      return current
    end
    for i = 1, #raid do
      local p = raid[i]
      if p.alive and p.role == "tank" and (best == nil or best.role ~= "tank" or p.threat >= best.threat) then
        if best == nil or best.role ~= "tank" or p.threat > best.threat then best = p end
      end
    end
    return best
  end

  log(1, boss.maxhp, #raid, boss.name .. " is pulled (" .. inputs.mode .. ").")

  -- Raid moments: at most one random event per pull, rolled from the seed. Good moments are more
  -- likely in a raid with chemistry, bad ones in a raid with low skill.
  -- Director, 2026-11-18: no raid moments in ranked modes (Heroic and Mythic); Normal and practice only.
  if #raid > 0 and inputs.moments ~= false and not mode.band and rng:chance(D.MOMENTS.chance) then
    local M = D.MOMENTS
    local good = M.good_base + idiv(cohesion10, 10)
    local bad = M.bad_base + idiv(100 - avg_skill, 10)
    local list = { {"pep", good}, {"clutch", good}, {"zone", good}, {"dc", bad}, {"early", bad}, {"repair", bad}, {"coffee", bad} }
    local total = 0
    for i = 1, #list do total = total + list[i][2] end
    local r = rng:int(total)
    local pick = list[1][1]
    for i = 1, #list do
      if r <= list[i][2] then pick = list[i][1]; break end
      r = r - list[i][2]
    end
    local function anyone(filter)
      local c = {}
      for i = 1, #raid do if filter(raid[i]) then c[#c + 1] = raid[i] end end
      if #c == 0 then return nil end
      return c[rng:int(#c)]
    end
    if pick == "pep" then
      for i = 1, #raid do raid[i].power = pm(raid[i].power, 1000 + M.pep_power) end
      log(40, 0, 0, "The raid leader gives a speech nobody will forget. Everyone hits a little harder.")
    elseif pick == "clutch" then
      moments.clutch = M.clutch_saves
      for i = 1, #raid do raid[i].crit = raid[i].crit + M.lucky_crit end
      log(41, 0, 1, "Everyone feels lucky tonight. Crits everywhere.")
    elseif pick == "zone" then
      local p = anyone(function(x) return x.role == "damage" end)
      if p then p.zone_bonus = M.zone_rounds; log(42, p.slot, 0, p.name .. " is in the zone.") end
    elseif pick == "dc" then
      local p = anyone(function(x) return true end)
      p.skip_from, p.skip_to = 3, 5
      log(43, p.slot, 0, p.name .. " disconnects. Back in round 6, hopefully.")
    elseif pick == "early" then
      moments.early = true
      for i = 1, #raid do if raid[i].role == "damage" then raid[i].skip_from, raid[i].skip_to = 1, 1 end end
      log(44, 0, 1, "Someone pulls before the tanks are ready. Round 1 is chaos.")
    elseif pick == "repair" then
      local p = anyone(function(x) return x.role == "damage" end)
      if p then
        p.power = pm(p.power, 1000 - M.repair_power)
        log(45, p.slot, 0, p.name .. " forgot to repair. Red gear, sad numbers.")
      end
    elseif pick == "coffee" then
      local p = anyone(function(x) return x.role == "healer" end)
      if p then p.skip_from, p.skip_to = 1, M.coffee_rounds; log(46, p.slot, 0, p.name .. " is still getting coffee.") end
    end
  end

  -- Traits that roll at the pull, in roster order (deterministic).
  local pack_until = 0
  for i = 1, #raid do
    local p = raid[i]
    if p.tr.partner_aggro and rng:chance(TR.partner_aggro.chance) then
      p.skip_from, p.skip_to = TR.partner_aggro.after + 1, 999
      log(50, p.slot, 0, p.name .. " will have to leave after round " .. TR.partner_aggro.after .. ". \"Sorry guys, gotta go.\"")
    end
    if p.tr.pet_on_aggressive and p.class == "hunter" and pack_until == 0 and rng:chance(TR.pet_on_aggressive.chance) then
      pack_until = TR.pet_on_aggressive.rounds
      log(51, p.slot, 0, p.name .. "'s pet was on aggressive. An extra pack joins the fight.")
    end
  end
  if pulls_early then log(52, 0, 0, "Someone pulled before the healers finished drinking.") end

  local result = "enrage"
  while true do
    round = round + 1
    if round > D.MAX_ROUNDS then
      log(90, 0, 0, boss.name .. " enrages. The raid is wiped.")
      result = "enrage"; break
    end
    local mode_dmg = mode.dmg
    if inputs.mode == "normal" and boss_def.normal_dmg then mode_dmg = pm(mode_dmg, boss_def.normal_dmg) end

    -- 1. The boss acts.
    if round == boss_def.submerge_at then
      boss.submerged = true; boss.surface_at = round + boss_def.submerge_rounds
      spawn_adds(boss_def.adds, boss_def.add_hp)
      log(20, boss_def.adds, 0, boss.name .. " sinks into the lava and summons " .. boss_def.adds .. " fire adds.")
    end
    -- Magmadad: pups from the pull. Majordomo: interns from the pull while he stays away.
    if round == 1 and boss_def.pups then
      spawn_adds(boss_def.pups, boss_def.add_hp)
      log(60, boss_def.pups, 0, boss.name .. " brings his " .. boss_def.pups .. " magma pups. \"Say hi, kids.\"")
    end
    if round == 1 and boss_def.interns then
      spawn_adds(boss_def.interns, boss_def.add_hp)
      boss.submerged = true; boss.surface_at = 1000
      log(63, boss_def.interns, 0, boss.name .. " sends " .. boss_def.interns .. " interns to deal with it.")
    end
    if boss_def.interns and boss.submerged and round > 1 then
      local left = 0
      for a = 1, #adds do if adds[a].alive then left = left + 1 end end
      if left == 0 then
        boss.submerged = false
        log(64, 0, 0, "\"Fine. FINE.\" " .. boss.name .. " joins the fight himself.")
      end
    end
    -- Lucifrown: a curse every few rounds doubles mana costs. A decurser (mage or druid) shortens it.
    if boss_def.curse_every and not boss.submerged and round % boss_def.curse_every == 0 then
      local len = boss_def.curse_rounds
      if has["mage"] or has["druid"] then
        len = boss_def.decursed_rounds
        log(66, 0, 1, boss.name .. " curses the raid. Decursed fast.")
      else
        log(66, 0, 0, boss.name .. " curses the raid. Nobody can decurse. Mana costs double.")
      end
      cursed_until = round + len - 1
    end
    if boss.submerged and round >= boss.surface_at then
      boss.submerged = false
      log(21, 0, 0, boss.name .. " rises again.")
    end

    if not boss.submerged then
      -- Lava throw every 4 rounds (Subtlety rogue's Kick can cancel one every 5 rounds).
      if boss_def.throw_every and round % boss_def.throw_every == 0 then
        local kicker = nil
        for i = 1, #raid do
          local p = raid[i]
          if p.alive and p.class == "rogue" and p.spec == "subtlety" and kicker == nil then kicker = p end
        end
        if kicker and round >= kick_ready_round then
          kick_ready_round = round + 5
          log(22, kicker.slot, 0, kicker.name .. " kicks the wind-up. No throw this time.")
        else
          -- Meeting 2026-11-18: the throw deals a share of max health (ignoring armour) instead of
          -- killing outright. Targets the lowest-health melee; with no melee, Front; then anyone.
          local victims = alive_in("melee")
          if #victims == 0 then victims = alive_in("front") end
          if #victims == 0 then victims = alive_in(nil) end
          local v = most_injured(victims)
          if v then
            if v.fireres > 0 then
              v.fireres = v.fireres - 1
              log(23, v.slot, 1, boss.name .. " throws " .. v.name .. " into the lava. Fire Resistance saves them.")
            else
              log(23, v.slot, 0, boss.name .. " throws " .. v.name .. " into the lava.")
              local burn = pm(pm(pm(v.maxhp, mode.throw), tac.taken), 1000 - v.firered)
              burn = pm(burn, 1000 - D.FAMILIARITY.per_point * v.fam)
              if v.tr.stands_in_fire then burn = pm(burn, 1000 + TR.stands_in_fire.taken) end
              if v.tr.parse_goblin then burn = pm(burn, 1000 + TR.parse_goblin.taken) end
              v.hp = v.hp - burn
              if v.hp <= 0 then kill(v, 23) end
            end
          end
        end
      end
      -- Melee on the current target.
      target = pick_tank(target)
      local early_hit = false
      if moments.early and round <= D.MOMENTS.early_rounds then
        if round == 1 then
          local nt = {}
          for i = 1, #raid do if raid[i].alive and raid[i].role ~= "tank" then nt[#nt + 1] = raid[i] end end
          if #nt > 0 then
            moments.early_target = nt[rng:int(#nt)]
            log(44, moments.early_target.slot, 0, boss.name .. " turns on " .. moments.early_target.name .. " before the tanks are ready.")
          end
        end
        local et = moments.early_target
        if et and et.alive then target = et; early_hit = true end
      end
      if inputs.trace and target then inputs.trace[#inputs.trace + 1] = target.slot end
      if target then
        local hit = pm(boss_def.melee, mode_dmg)
        if target.class == "paladin" and target.spec == "protection" then hit = pm(hit, 1050) end
        if early_hit then hit = pm(hit, D.MOMENTS.early_hit) end
        damage(target, boss_hit(hit), 24, false)
      end
      -- Magma Splash every 2nd round on a zone picked by the seed.
      if boss_def.splash and round % 2 == 0 then
        local zone = D.ZONES[rng:int(4)]
        local list = alive_in(zone)
        if #list > 0 then
          if tac.area_single then
            local v = list[rng:int(#list)]
            if rng:chance(idiv(v.skill * D.SKILL.dodge, 100)) then
              log(35, v.slot, 0, v.name .. " sidesteps the Magma Splash.")
            else
              log(25, v.slot, 1, "Magma Splash hits " .. v.name .. ".")
              damage(v, boss_hit(pm(boss_def.splash, mode_dmg)), 25, true)
            end
          else
            log(25, #list, 0, "Magma Splash hits the " .. zone .. " zone.")
            local splash = boss_hit(pm(boss_def.splash, mode_dmg))
            for i = 1, #list do
              if rng:chance(idiv(list[i].skill * D.SKILL.dodge, 100)) then
                log(35, list[i].slot, 0, list[i].name .. " sidesteps the Magma Splash.")
              else
                damage(list[i], splash, 25, true)
              end
            end
          end
        end
      end
      -- Baron Get-Down: last round's bomb goes off, then a new character is marked.
      if boss_def.bomb then
        if bomb and bomb.alive then
          local amt = boss_hit(pm(boss_def.bomb, mode_dmg))
          if tac.area_single then
            log(62, bomb.slot, 1, bomb.name .. " GETS DOWN, out of the group, and explodes alone.")
            damage(bomb, amt, 62, true)
          else
            local list = alive_in(bomb.zone)
            log(62, bomb.slot, #list, bomb.name .. " explodes in the " .. bomb.zone .. " zone.")
            for i = 1, #list do
              local q = list[i]
              if q == bomb then damage(q, amt, 62, true)
              elseif not q.tr.never_stands_in_fire then damage(q, pm(amt, boss_def.bomb_others or 1000), 62, true) end
            end
          end
        end
        bomb = nil
        if round >= 2 then
          local nt = {}
          for i = 1, #raid do if raid[i].alive and raid[i].role ~= "tank" then nt[#nt + 1] = raid[i] end end
          if #nt > 0 then bomb = nt[rng:int(#nt)]; log(61, bomb.slot, 0, bomb.name .. " is the bomb.") end
        end
      end
      -- Lucifrown: Shadow Volley on everyone each round (magic, ignores armour), Frown on a zone every 3rd.
      if boss_def.volley then
        local list = alive_in(nil)
        local amt = pm(boss_def.volley, mode_dmg)
        for i = 1, #list do damage(list[i], amt, 67, false, true) end
      end
      if boss_def.frown and round % 3 == 0 then
        local zone = D.ZONES[rng:int(4)]
        local stacked = inputs.tactic == "stack"
        local list = stacked and alive_in(nil) or alive_in(zone)
        log(68, #list, 0, stacked and (boss.name .. " frowns at the whole stacked raid.") or (boss.name .. " frowns at the " .. zone .. " zone."))
        local amt = boss_hit(pm(boss_def.frown, mode_dmg))
        if stacked then amt = pm(amt, boss_def.frown_stack or 1000) end
        for i = 1, #list do damage(list[i], amt, 68, false, true) end
      end
    end
    -- Pet on aggressive: the extra pack hits a random non-tank for a few rounds.
    if round <= pack_until then
      local nt = {}
      for i = 1, #raid do if raid[i].alive and raid[i].role ~= "tank" then nt[#nt + 1] = raid[i] end end
      if #nt > 0 then damage(nt[rng:int(#nt)], pm(TR.pet_on_aggressive.hit, mode_dmg), 26, false) end
    end
    -- Adds attack (fire adds, pups, interns).
    local frost_slow = has["mage:frost"]
    for a = 1, #adds do
      local ad = adds[a]
      if ad.alive and ad.frozen == 0 and ad.held == 0 then
        local hit = pm(boss_def.add_hit, mode_dmg)
        if frost_slow then hit = pm(hit, 850) end
        if boss_def.add_aoe then  -- pups pulse fire on the whole raid
          local list = alive_in(nil)
          for i = 1, #list do damage(list[i], hit, 26, boss_def.add_fire ~= false) end
          hit = 0
        end
        local holder = nil
        for i = 1, #raid do
          local p = raid[i]
          if p.alive and p.class == "paladin" and p.spec == "protection" and holder == nil then holder = p end
        end
        local list = alive_in(nil)
        if holder then hit = pm(hit, 600) end -- Consecration: the paladin takes add hits at 60%
        if hit > 0 and #list > 0 then damage(holder or list[rng:int(#list)], hit, 26, boss_def.add_fire ~= false) end
      end
      if ad.frozen > 0 then ad.frozen = ad.frozen - 1 end
      if ad.held > 0 then ad.held = ad.held - 1 end
    end

    -- 2. Characters act in speed order.
    local healmul = tac.heal
    if tac.area_single then healmul = tac.heal end
    for k = 1, #order do
      local p = order[k]
      local tabbed = false
      if p.alive and p.tr.alt_tabbed and rng:chance(TR.alt_tabbed.chance) then
        tabbed = true; log(53, p.slot, 0, p.name .. " is alt-tabbed.")
      end
      if p.alive and not tabbed and (round < p.skip_from or round > p.skip_to) then
        if p.role == "healer" then
          local curse = (round <= cursed_until) and 2 or 1
          local cost = pm(D.HEAL_COST, tac.mana) * curse
          local list = alive_in(nil)
          local t, pct = most_injured(list, true)
          if t and pct < 1000 then
            local big = pct < D.BIG_HEAL_BELOW
            if big then cost = pm(D.BIG_HEAL_COST, tac.mana) * curse end
            if p.mana >= cost then
              p.mana = p.mana - cost
              local amount = pm(p.power, healmul)
              if big then amount = pm(amount, D.BIG_HEAL_MULT) end
              local crit_amt, did = roll(p, amount)
              if did and p.class == "paladin" then p.mana = p.mana + 6 end -- Illumination
              if t.role == "tank" and bond[p.slot][t.slot] then
                crit_amt = pm(crit_amt, 1000 + D.CHEMISTRY.tank_heal * bond[p.slot][t.slot])
              end
              p.healed = p.healed + heal(t, crit_amt)
              -- Spec extras.
              if p.class == "priest" and p.spec == "holy" then
                local zl = alive_in(t.zone)
                for i = 1, #zl do if zl[i] ~= t then p.healed = p.healed + heal(zl[i], pm(p.power, 450)) end end
              elseif p.class == "shaman" and p.spec == "restoration" then
                local second = most_injured(list)
                if second then p.healed = p.healed + heal(second, pm(p.power, 300)) end
              elseif p.class == "druid" and p.spec == "restoration" then
                local second = most_injured(list)
                if second then p.healed = p.healed + heal(second, pm(p.power, 330)) end
              end
            end
          end
          if p.class == "priest" and p.spec == "discipline" and target and target.alive then
            p.healed = p.healed + heal(target, 40) -- Power Word: Shield, simplified as 40 healing on the boss's target
          end
          if p.class == "shaman" and p.spec == "restoration" and not p.used.manatide and p.mana < 40 then
            p.used.manatide = true
            for i = 1, #raid do if raid[i].role == "healer" then raid[i].mana = raid[i].mana + 30 end end
            log(33, p.slot, 0, p.name .. " drops Mana Tide.")
          end
        else
          -- Damage: adds first when any are alive and not held, else the boss if it is up.
          local amount = p.power
          if p.caster then
            local cost = D.CASTER_COST * ((round <= cursed_until) and 2 or 1)
            if p.class == "mage" and p.spec == "arcane" and round <= 3 then cost = cost * 2; amount = pm(amount, 1200) end
            if p.mana >= cost then p.mana = p.mana - cost else amount = idiv(amount, 2) end
          end
          amount = pm(amount, tac.dmg)
          if p.zone_bonus >= round then amount = pm(amount, 1000 + D.MOMENTS.zone_power) end
          -- Meeting 2026-11-18: melee specs outside the Melee zone, and tanks outside Front, hit at half.
          if (D.MELEE_SPECS[p.class .. ":" .. p.spec] and p.zone ~= "melee") or (p.role == "tank" and p.zone ~= "front") then
            amount = idiv(amount, 2)
          end
          if p.class == "warrior" and p.spec == "fury" then amount = pm(amount, 1000 + 50 * p.stacks) end
          if p.class == "rogue" and p.spec == "assassination" then
            if p.stacks < 5 then p.stacks = p.stacks + 1 end
            amount = pm(amount, 1000 + 30 * p.stacks)
          end
          if p.class == "warlock" and p.spec == "affliction" then
            local ramp = 12 * round; if ramp > 120 then ramp = 120 end
            amount = pm(amount, 1000 + ramp)
          end
          if (p.zone == "melee" or p.zone == "ranged") and has["hunter:marksmanship"] then amount = pm(amount, 1050) end
          if p.zone == "melee" and has["shaman:enhancement"] then amount = pm(amount, 1100) end
          if has["warlock:affliction"] and (p.class == "warlock" or (p.class == "priest" and p.spec == "shadow") or (p.class == "mage" and p.spec == "fire")) then amount = pm(amount, 1100) end -- Curse of the Elements: fire and shadow only
          local dealt, did = roll(p, amount)
          local fire_penalty = boss_def.fire_immune and p.class == "mage" and p.spec == "fire"
          if fire_penalty then dealt = idiv(dealt, 2) end
          -- Choose a target.
          local hit_add = nil
          if p.role ~= "tank" or boss.submerged then
            for a = 1, #adds do
              if adds[a].alive and hit_add == nil then hit_add = adds[a] end
            end
          end
          local cleave = (p.class == "shaman" and p.spec == "elemental") or (p.class == "rogue" and p.spec == "combat" and round % 6 <= 2)
          if hit_add then
            hit_add.hp = hit_add.hp - dealt; p.dealt = p.dealt + dealt
            if hit_add.hp <= 0 then add_dies(hit_add) end
            -- Majordomo: stacked, the raid drags the interns together and every hit splashes onto another.
            if boss_def.interns and inputs.tactic == "stack" then
              for a = 1, #adds do
                if adds[a].alive and adds[a] ~= hit_add then
                  adds[a].hp = adds[a].hp - pm(dealt, boss_def.stack_splash)
                  if adds[a].hp <= 0 then add_dies(adds[a]) end
                  break
                end
              end
            end
            if cleave then
              for a = 1, #adds do
                if adds[a].alive and adds[a] ~= hit_add then
                  adds[a].hp = adds[a].hp - idiv(dealt, 2)
                  if adds[a].hp <= 0 then add_dies(adds[a]) end
                  break
                end
              end
            end
          elseif not boss.submerged then
            if p.class == "warrior" and p.spec == "arms" and boss.hp * 1000 < boss.maxhp * 200 then dealt = pm(dealt, 1300) end
            if p.class == "warlock" and p.spec == "destruction" and boss.hp * 1000 < boss.maxhp * 100 then dealt = pm(dealt, 2000) end
            boss.hp = boss.hp - dealt; p.dealt = p.dealt + dealt
            local th = pm(pm(dealt, p.threatmul), tac.threat)
            if p.zone_bonus >= round then th = pm(th, 1000 - D.MOMENTS.zone_threat) end  -- in the zone: watching threat too
            p.threat = p.threat + th
            if p.class == "priest" and p.spec == "shadow" then
              local zl = alive_in(p.zone)
              for i = 1, #zl do heal(zl[i], pm(dealt, 150)) end
            end
          end
        end
      end
    end

    -- 3. Threat check, mana, shield wall, battle res, end conditions.
    for i = 1, #raid do
      local p = raid[i]
      if p.alive then p.alive_rounds = p.alive_rounds + 1 end
      if p.alive and p.caster then p.mana = p.mana + D.MANA_REGEN end
      if p.shield_wall > 0 then p.shield_wall = p.shield_wall - 1 end
    end
    -- Druid Battle Res: the first dead healer or tank, once per fight.
    for i = 1, #raid do
      local d = raid[i]
      if d.alive and d.class == "druid" and not d.used.bres then
        for j = 1, #raid do
          local x = raid[j]
          if not x.alive and (x.role == "healer" or x.role == "tank") and not d.used.bres and not x.tr.hardcore_andy then
            d.used.bres = true; x.alive = true; x.hp = pm(x.maxhp, 300)
            log(34, x.slot, d.slot, d.name .. " battle-resses " .. x.name .. ".")
          end
        end
      end
    end

    -- Optional playback frames (not part of the checksum): health after each round.
    if inputs.frames then
      local f = { boss = boss.hp < 0 and 0 or boss.hp, away = boss.submerged, adds = 0, hp = {} }
      for a = 1, #adds do if adds[a].alive then f.adds = f.adds + 1 end end
      for i = 1, #raid do f.hp[i] = raid[i].alive and raid[i].hp or 0 end
      inputs.frames[#inputs.frames + 1] = f
    end
    -- Magmadad's pups: dead pups get back up unless every pup died within the window.
    if boss_def.pups and not pups_done then
      local first, dead = nil, 0
      for a = 1, #adds do
        if not adds[a].alive then
          dead = dead + 1
          if first == nil or adds[a].died < first then first = adds[a].died end
        end
      end
      if dead == #adds then
        pups_done = true
        log(65, 0, 1, "All the pups are down at once. Magmadad is sad. \"Time for a timeout.\"")
      elseif dead > 0 and round - first >= boss_def.pup_window then
        for a = 1, #adds do
          if not adds[a].alive then adds[a].alive = true; adds[a].hp = adds[a].maxhp end
        end
        log(65, dead, 0, "The pups get back up. \"Walk it off, champ.\"")
      end
    end

    if boss.hp <= 0 and not boss.submerged then
      log(80, round, 0, boss_def.defeat and (boss_def.defeat .. " (round " .. round .. ")") or (boss.name .. " dies in round " .. round .. "."))
      result = "kill"; break
    end
    if count_alive_role("tank") + count_alive_role("healer") == 0 then
      log(91, 0, 0, "Every tank and healer is dead. Wipe.")
      result = "wipe"; break
    end
  end

  local survivors = 0
  for i = 1, #raid do if raid[i].alive then survivors = survivors + 1 end end
  h = mix(h, survivors); h = mix(h, boss.hp < 0 and 0 or boss.hp)
  for i = 1, #raid do  -- every character's end state
    local p = raid[i]
    h = mix(h, p.hp); h = mix(h, p.mana); h = mix(h, p.dealt); h = mix(h, p.healed)
  end
  return {
    result = result, rounds = round > D.MAX_ROUNDS and D.MAX_ROUNDS or round,
    events = events, checksum = floor(h), boss_hp = boss.hp < 0 and 0 or boss.hp,
    boss_maxhp = boss.maxhp, raid = raid, survivors = survivors,
    engine = ns.ENGINE_VERSION,
  }
end
