-- Flight Path Raiders: balance data for the prototype.
-- Owned by Game Tuning & Balancing. Every percentage is per-mille (150 = 15.0%).
-- Values marked "TUNING ASSUMPTION" are not in the design doc yet and are first guesses.
local _, ns = ...
ns = ns or FPR_ENGINE or {}
FPR_ENGINE = ns

local D = {}
ns.Data = D

D.ZONES = { "front", "melee", "ranged", "back" }

-- Starting values at level 60 and gear level 60 (design doc 5, "Starting values").
D.ROLE_BASE = {
  tank   = { hp = 3000, power = 45 },
  damage = { hp = 2000, power = 100 },
  healer = { hp = 1800, power = 120 },  -- power = healing per heal
}

-- Gear level scaling: +20 per-mille (2%) per gear level above 60. TUNING ASSUMPTION.
D.GL_STEP = 20

-- Armour type reduction in per-mille, before role. TUNING ASSUMPTION. Cap 500 (design doc 4.2).
D.ARMOR = { plate = 150, mail = 110, leather = 90, cloth = 50 }
D.TANK_ARMOR_BONUS = 150
D.ARMOR_CAP = 500

-- Crit: 50 per-mille chance, crits deal 1500 per-mille. TUNING ASSUMPTION (crit is not a stat in 4.2).
D.CRIT_CHANCE = 50
D.CRIT_MULT = 1500

-- Mana (design doc 4.2): 100 at start, +5 per round, heal 10, big heal 18.
D.MANA_START, D.MANA_REGEN, D.HEAL_COST, D.BIG_HEAL_COST = 100, 5, 10, 18
D.BIG_HEAL_BELOW = 500      -- big heal when the target is below 50% health. TUNING ASSUMPTION
D.BIG_HEAL_MULT = 1800      -- a big heal heals 1.8x. TUNING ASSUMPTION
D.CASTER_COST = 8           -- mana per caster attack; out of mana = half damage. TUNING ASSUMPTION

-- Threat (design doc 4.2, 5): tanks generate 3x, pulling aggro above 110% of the tank's threat.
D.TANK_THREAT, D.OTHER_THREAT, D.AGGRO_MARGIN = 3000, 1000, 1100

-- Classes: armour type, speed, caster (uses mana to attack), and roles each spec gives.
D.CLASSES = {
  warrior = { armor = "plate",   speed = 10, caster = false },
  paladin = { armor = "plate",   speed = 8,  caster = false },
  hunter  = { armor = "mail",    speed = 11, caster = false },
  rogue   = { armor = "leather", speed = 12, caster = false },
  priest  = { armor = "cloth",   speed = 7,  caster = true },
  shaman  = { armor = "mail",    speed = 9,  caster = true },
  mage    = { armor = "cloth",   speed = 9,  caster = true },
  warlock = { armor = "cloth",   speed = 8,  caster = true },
  druid   = { armor = "leather", speed = 9,  caster = true },
}

-- Specs (design doc 4.3.1): role and passive id. Passives are simplified for the prototype.
D.SPECS = {
  warrior = { arms = "damage", fury = "damage", protection = "tank" },
  paladin = { holy = "healer", protection = "tank", retribution = "damage" },
  hunter  = { beastmastery = "damage", marksmanship = "damage", survival = "damage" },
  rogue   = { assassination = "damage", combat = "damage", subtlety = "damage" },
  priest  = { holy = "healer", discipline = "healer", shadow = "damage" },
  shaman  = { elemental = "damage", enhancement = "damage", restoration = "healer" },
  mage    = { arcane = "damage", fire = "damage", frost = "damage" },
  warlock = { affliction = "damage", demonology = "damage", destruction = "damage" },
  druid   = { balance = "damage", feral = "tank", restoration = "healer" },  -- feral as bear tank; cat = "feralcat"
}
D.SPECS.druid.feralcat = "damage"

-- Tactic cards (design doc 5).
D.TACTICS = {
  spread   = { area_single = true,  heal = 900,  dmg = 1000, threat = 1000, mana = 1000, taken = 1000 },
  stack    = { area_single = false, heal = 1150, dmg = 1000, threat = 1000, mana = 1000, taken = 1000 },
  burn     = { area_single = false, heal = 1000, dmg = 1150, threat = 1150, mana = 1200, taken = 1000 },
  playsafe = { area_single = false, heal = 1000, dmg = 900,  threat = 1000, mana = 1000, taken = 900 },
}

-- Consumables. Effects are TUNING ASSUMPTIONS (the design doc gives prices only).
D.CONSUMABLES = {
  food    = { hp = 50 },               -- +5% health
  elixirs = { power = 50 },            -- +5% power
  flasks  = { hp = 100, power = 100 }, -- +10% health and power
}
-- World buffs (design doc 8).
D.WORLD_BUFFS = {
  dragonslayer = { power = 100 },  -- +10% power
  songbloom    = { crit = 100 },   -- +10% crit chance
  warchief     = { hp = 150 },     -- +15% health
}

-- Modes: boss health and damage multipliers. The design doc's +40% / +90% assumed no gear
-- scaling; with gear levels 65 and 74, Tuning pass 1 needs +62% / +150% to hit the targets.
D.MODES = {
  normal = { hp = 1000, dmg = 1000 },
  heroic = { hp = 1620, dmg = 1300 },  -- Tuning pass 1 (2026-11-18): was 1400 / 1150
  mythic = { hp = 2500, dmg = 1700 },  -- Tuning pass 1 (2026-11-18): was 1900 / 1300
}

-- Ragnaroast (design doc 6.1). Numbers are TUNING ASSUMPTIONS unless noted.
D.BOSSES = {
  ragnaroast = {
    name = "Ragnaroast",
    hp = 8400,                 -- Normal health. Tuning pass 1: was 9000 (design doc), 8400 hits ~70%
    fire_immune = true,
    melee = 600,               -- hit on the current target each round (Tuning pass 1: was 280)
    splash = 450,              -- Magma Splash on one zone, every 2nd round (Tuning pass 1: was 200)
    throw_every = 4,           -- every 4 rounds: lava throw on the lowest-health melee (design doc)
    submerge_at = 10,          -- from round 10 he sinks and summons fire adds (design doc)
    submerge_rounds = 3,
    adds = 4, add_hp = 500, add_hit = 120,  -- Tuning pass 1: was 450 / 60
  },
}

D.MAX_ROUNDS = 20  -- round 21 is the enrage (design doc 5)
