-- Flight Path Raiders: deterministic combat simulator.
-- Rules for portability (technical design 3 and 11): whole numbers below 2^31 (Fengari's integers
-- are 32-bit; products that can exceed that are done in floating point and floored), every division
-- floored through idiv, arrays walked with numeric for loops, the seeded RNG as the only randomness.
local _, ns = ...
ns = ns or FPR_ENGINE or {}
FPR_ENGINE = ns

ns.ENGINE_VERSION = 5  -- 5: player skill, boss familiarity, chemistry, raid moments

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
  local rng = ns.NewRNG(inputs.seed)
  local boss_def = D.BOSSES[inputs.boss]
  local mode = D.MODES[inputs.mode]
  local tac = D.TACTICS[inputs.tactic]
  local gl = inputs.gl or 60
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
    local hp = pm(pm(base.hp, glmul), hp_mul)
    local power = pm(pm(base.power, glmul), pow_mul)
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

  local boss = { name = boss_def.name, maxhp = pm(boss_def.hp, mode.hp), submerged = false }
  boss.hp = boss.maxhp
  local adds = {}
  local target = nil  -- the boss's current target
  local moments = { clutch = 0, early = false, early_target = nil }
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

  local function damage(p, amount, cause, fire)
    if not p.alive then return end
    -- Fire ignores armour; fire resistance reduces it instead (pass 3).
    local dmg = fire and pm(amount, 1000 - p.firered) or pm(amount, 1000 - p.armor)
    dmg = pm(dmg, tac.taken)
    if cause ~= 24 then dmg = pm(dmg, 1000 - D.FAMILIARITY.per_point * p.fam) end -- knows the mechanics
    if p.class == "warrior" and p.spec == "fury" then dmg = pm(dmg, 1100) end
    if p.shield_wall > 0 then dmg = pm(dmg, 250) end
    if dmg < 1 then dmg = 1 end
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
  if #raid > 0 and inputs.moments ~= false and rng:chance(D.MOMENTS.chance) then
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

  local result = "enrage"
  while true do
    round = round + 1
    if round > D.MAX_ROUNDS then
      log(90, 0, 0, boss.name .. " enrages. The raid is wiped.")
      result = "enrage"; break
    end
    local mode_dmg = mode.dmg

    -- 1. The boss acts.
    if round == boss_def.submerge_at then
      boss.submerged = true; boss.surface_at = round + boss_def.submerge_rounds
      for a = 1, boss_def.adds do
        adds[a] = { hp = pm(boss_def.add_hp, mode.hp), alive = true, frozen = 0, held = 0 }
      end
      if has["hunter:survival"] then adds[1].frozen = 3 end
      if has["warlock:demonology"] and adds[2] then adds[2].held = 4 end
      if has["hunter:beastmastery"] and adds[3] then adds[3].held = 2 end
      log(20, boss_def.adds, 0, boss.name .. " sinks into the lava and summons " .. boss_def.adds .. " fire adds.")
    end
    if boss.submerged and round >= boss.surface_at then
      boss.submerged = false
      log(21, 0, 0, boss.name .. " rises again.")
    end

    if not boss.submerged then
      -- Lava throw every 4 rounds (Subtlety rogue's Kick can cancel one every 5 rounds).
      if round % boss_def.throw_every == 0 then
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
      if round % 2 == 0 then
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
    end
    -- Fire adds attack.
    local frost_slow = has["mage:frost"]
    for a = 1, #adds do
      local ad = adds[a]
      if ad.alive and ad.frozen == 0 and ad.held == 0 then
        local hit = pm(boss_def.add_hit, mode_dmg)
        if frost_slow then hit = pm(hit, 850) end
        local holder = nil
        for i = 1, #raid do
          local p = raid[i]
          if p.alive and p.class == "paladin" and p.spec == "protection" and holder == nil then holder = p end
        end
        local list = alive_in(nil)
        if holder then hit = pm(hit, 600) end -- Consecration: the paladin takes add hits at 60%
        if #list > 0 then damage(holder or list[rng:int(#list)], hit, 26, true) end
      end
      if ad.frozen > 0 then ad.frozen = ad.frozen - 1 end
      if ad.held > 0 then ad.held = ad.held - 1 end
    end

    -- 2. Characters act in speed order.
    local healmul = tac.heal
    if tac.area_single then healmul = tac.heal end
    for k = 1, #order do
      local p = order[k]
      if p.alive and (round < p.skip_from or round > p.skip_to) then
        if p.role == "healer" then
          local cost = pm(D.HEAL_COST, tac.mana)
          local list = alive_in(nil)
          local t, pct = most_injured(list, true)
          if t and pct < 1000 then
            local big = pct < D.BIG_HEAL_BELOW
            if big then cost = pm(D.BIG_HEAL_COST, tac.mana) end
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
            local cost = D.CASTER_COST
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
            if hit_add.hp <= 0 then hit_add.alive = false; log(27, 0, 0, "A fire add dies.") end
            if cleave then
              for a = 1, #adds do
                if adds[a].alive and adds[a] ~= hit_add then
                  adds[a].hp = adds[a].hp - idiv(dealt, 2)
                  if adds[a].hp <= 0 then adds[a].alive = false; log(27, 0, 0, "A fire add dies.") end
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
          if not x.alive and (x.role == "healer" or x.role == "tank") and not d.used.bres then
            d.used.bres = true; x.alive = true; x.hp = pm(x.maxhp, 300)
            log(34, x.slot, d.slot, d.name .. " battle-resses " .. x.name .. ".")
          end
        end
      end
    end

    if boss.hp <= 0 and not boss.submerged then
      log(80, round, 0, boss.name .. " dies in round " .. round .. ".")
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
  return {
    result = result, rounds = round > D.MAX_ROUNDS and D.MAX_ROUNDS or round,
    events = events, checksum = floor(h), boss_hp = boss.hp < 0 and 0 or boss.hp,
    boss_maxhp = boss.maxhp, raid = raid, survivors = survivors,
    engine = ns.ENGINE_VERSION,
  }
end
