-- Flight Path Raiders: balance data for the prototype.
-- Owned by Game Tuning & Balancing. Every percentage is per-mille (150 = 15.0%).
-- Values marked "TUNING ASSUMPTION" are not in the design doc yet and are first guesses.
local _, ns = ...
if not ns then ns = FPR_ENGINE or {}; FPR_ENGINE = ns end  -- in WoW the addon's private table; in tests a global

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
D.GL_STEP = 15  -- Tuning pass 2: was 20

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

-- Per-spec power multipliers (Tuning pass 2, 2026-11-18). Beast Mastery includes the pet.
-- Retribution brings Blessing of Kings to the raid, so its own power sits a little lower.
D.SPEC_POWER = {
  ["hunter:beastmastery"] = 1040, ["paladin:retribution"] = 1000, ["paladin:holy"] = 1350,
  ["rogue:combat"] = 1070, ["rogue:subtlety"] = 1070, ["warrior:fury"] = 1060, ["druid:feralcat"] = 1060,
}

-- Specs that fight in melee: half damage outside the Melee zone (meeting 2026-11-18).
D.MELEE_SPECS = {
  ["warrior:arms"] = true, ["warrior:fury"] = true, ["paladin:retribution"] = true,
  ["rogue:assassination"] = true, ["rogue:combat"] = true, ["rogue:subtlety"] = true,
  ["shaman:enhancement"] = true, ["druid:feralcat"] = true,
}

-- Tactic cards (design doc 5).
D.TACTICS = {
  spread   = { area_single = true,  heal = 900,  dmg = 1000, threat = 1000, mana = 1000, taken = 1000 },
  stack    = { area_single = false, heal = 1150, dmg = 1000, threat = 1000, mana = 1000, taken = 1000 },
  burn     = { area_single = false, heal = 1000, dmg = 1100, threat = 1250, mana = 1200, taken = 1000 },  -- meeting: was dmg 1150, threat 1150
  playsafe = { area_single = false, heal = 1000, dmg = 950,  threat = 1000, mana = 1000, taken = 850 },  -- meeting: was dmg 900, taken 900
}

-- Consumables. Effects are TUNING ASSUMPTIONS (the design doc gives prices only).
D.CONSUMABLES = {
  food    = { hp = 50, power = 30 },   -- +5% health, +3% power (pass 3)
  elixirs = { power = 50 },            -- +5% power
  flasks  = { hp = 100, power = 100 }, -- +10% health and power
}
-- World buffs (design doc 8).
D.WORLD_BUFFS = {
  dragonslayer = { power = 100 },  -- +10% power
  songbloom    = { crit = 100 },   -- +10% crit chance
  warchief     = { hp = 100, power = 50 },  -- +10% health, +5% power (pass 3)
}

-- Modes: boss health and damage multipliers. The design doc's +40% / +90% assumed no gear
-- scaling; with gear levels 65 and 74, Tuning pass 1 needs +62% / +150% to hit the targets.
D.MODES = {
  -- throw = lava throw damage as per-mille of max health (meeting 2026-11-18)
  normal = { hp = 1000, dmg = 750,  throw = 700 },  -- pass 3: Normal fire is softer (dmg was 1000)
  heroic = { hp = 1400, dmg = 1300, throw = 750, band = { 60, 70 } },  -- pass 4: targets now for a "typical" raid (skill 50, fam 5, chem 8)
  mythic = { hp = 2035, dmg = 1700, throw = 800, band = { 68, 80 } },  -- pass 4: typical raid, was 1950
}

-- Ragnaroast (design doc 6.1). Numbers are TUNING ASSUMPTIONS unless noted.
D.BOSSES = {
  ragnaroast = {
    name = "Ragnaroast",
    hp = 10200,                -- Normal health. Pass 1: 8400; pass 2 (meeting rules): 10200 hits ~70%
    fire_immune = true,
    melee = 600,               -- hit on the current target each round (Tuning pass 1: was 280)
    splash = 1100,             -- Magma Splash (fire) on one zone, every 2nd round (pass 3: was 450)
    throw_every = 4,           -- every 4 rounds: lava throw on the lowest-health melee (design doc)
    submerge_at = 10,          -- from round 10 he sinks and summons fire adds (design doc)
    submerge_rounds = 3,
    adds = 4, add_hp = 500, add_hit = 220,  -- fire adds (pass 3: hits were 120)
  },
  -- The other four Molten Bore bosses (design doc 6.1, engine v6). Each favours a different card.
  magmadad = {                 -- favours Burn: kill all three pups inside the window
    name = "Magmadad", hp = 8000, fire_immune = true, melee = 600,
    pups = 3, add_hp = 450, add_hit = 80, add_aoe = true, pup_window = 1, add_name = "a magma pup",
    normal_hp = 1100, normal_dmg = 1400,   -- Normal is the classroom (gate review): right card about 75% for a fresh guild
  },
  baron = {                    -- favours Spread: the bomb only hits its carrier when the raid is spread
    name = "Baron Get-Down", hp = 11500, fire_immune = true, melee = 600, bomb = 620, bomb_others = 600, normal_hp = 1000, normal_dmg = 1600,
  },
  lucifrown = {                -- favours Play Safe: constant magic damage on a curse-starved mana bar
    name = "Lucifrown", hp = 8800, melee = 550, volley = 120, frown = 500,
    curse_every = 3, curse_rounds = 3, decursed_rounds = 1, frown_stack = 300, normal_hp = 1150, normal_dmg = 1300,
  },
  majordomo = {                -- favours Stack: eight interns spread damage over everyone
    name = "Majordomo Exhaustus", hp = 7000, melee = 650,
    interns = 8, add_hp = 800, add_hit = 180, add_fire = false, add_name = "an intern", stack_splash = 450, normal_hp = 1080, normal_dmg = 1300,
    defeat = "Majordomo Exhaustus gives up, files a complaint and leaves a bonus chest.",
  },
}

-- Fire resistance (Tuning pass 3). Each gear piece: +60 resistance and -3% power. Paladin aura or
-- shaman totem: +40 for the raid (they don't stack). Every 10 resistance cuts fire damage by 3.5%,
-- capped at 60%. Fire = lava throw, Magma Splash, fire adds; fire ignores armour.
D.FIRE = { piece = 60, piece_power = 30, aura = 40, per_point = 35, cap = 600 }
D.BOSS_CRIT, D.BOSS_CRIT_MULT = 100, 1500   -- boss hits crit 10% for 1.5x (pass 3)
D.TANK_HEAL_PRIORITY = 150                   -- healers treat tanks as 15% lower (pass 3)

-- Player skill, boss familiarity, chemistry and raid moments (2026-11-18). Per-mille values.
D.SKILL = { power = 20, dodge = 80, threat = 100 }          -- at skill 100: +2% power, 8% dodge, -10% threat
D.FAMILIARITY = { cap = 10, per_point = 6, power = 2 }      -- at 10: 6% less mechanic damage and +2% power on that boss
D.CHEMISTRY = { cap = 20, power = 20, tank_heal = 3 }       -- full cohesion: +2% power; bond 20: +6% heals on that tank
D.MOMENTS = { chance = 350, good_base = 10, bad_base = 5,   -- 35% of pulls get one moment
  pep_power = 15, zone_power = 400, zone_rounds = 6, zone_threat = 500, clutch_saves = 1, clutch_hp = 300, lucky_crit = 40,
  repair_power = 300, coffee_rounds = 3, early_rounds = 2, early_hit = 1500 }

-- Traits (design doc 4.4) and morale. Per-mille unless noted. Tuning pass 5 (2026-11-18).
-- In-fight traits live here; guild traits (loot, quitting, morale changes) live in the game layer.
D.TRAITS = {
  pulls_on_cooldown      = { power = 200, healer_mana = 600 },        -- +20% damage and threat; healers start at 60% mana
  needs_on_everything    = { steal = 150 },                           -- game: 15% chance to take an item meant for someone else
  stands_in_fire         = { taken = 250 },                           -- +25% damage from boss mechanics
  never_stands_in_fire   = {},                                        -- immune to ground effects (Magma Splash, the Frown, someone else's bomb)
  afk_on_trash           = {},                                        -- skips the trash gauntlet (arrives with trash in production)
  main_spec_loot_only    = { morale = 3 },                            -- game: -3 morale when anyone else gets gear
  raid_leaders_favourite = { morale = 10 },                           -- +10 morale for everyone while present
  parse_goblin           = { power = 150, taken = 200 },              -- +15% damage, +20% mechanic damage
  alt_tabbed             = { chance = 100 },                          -- 10% chance per round to do nothing
  partner_aggro          = { chance = 200, after = 10 },              -- 20% per fight: leaves after round 10
  discord_lawyer         = { drama = 2 },                             -- game: loot drama twice as often
  rage_quitter           = { chance = 100 },                          -- game: 10% chance to quit on a wipe (common and rare only)
  hardcore_andy          = { stats = 100 },                           -- +10% health and power; refuses Battle Res
  backseat_raid_leader   = { card = 50, morale = 2 },                 -- tactic card 5% stronger; game: -2 morale to the raid per pull
  keyboard_turner        = { speed = 2 },                             -- -2 speed, never pulls aggro
  main_character         = { power = 100, morale = 2 },               -- +10% power after getting loot this week; game: others who wanted it -2 morale
  gear_score_elitist     = { morale = 1 },                            -- game: -1 morale per pull for each raider below their gear level
  pug_hero               = { power = 100, new = 2 },                  -- +10% power with 2+ new recruits in the raid
  pet_on_aggressive      = { chance = 150, rounds = 3, hit = 200 },   -- hunters: 15% per pull, an extra pack hits for 3 rounds
}
D.MORALE = { start = 70, vibe_at = 80, vibe_power = 50, kill = 5, loot = 10, wipe = 5, benched = 15, drift = 10, quit_below = 20, quit_chance = 500 }

D.MAX_ROUNDS = 20  -- round 21 is the enrage (design doc 5)
