-- Flight Path Raiders: the game rules around the combat engine. The guild, the Tavern, prep, pulls,
-- loot, weeks, the learning path, the journal, traits and morale. One source of truth: the addon runs
-- this file in WoW, the playtest page runs it in the browser (Fengari), and Tuning and QA run it headless.
-- Portability: runs on Lua 5.1 (WoW, LuaJIT) and 5.3 (Fengari). Every number that ends up in text or a
-- table key goes through math.floor, so Fengari never prints "37.0". Numbers come from the design doc
-- (4.4, 4.5, 8, 10) unless marked PLAYTEST, which are Tuning's choices for the slice.
local _, ns = ...
if not ns then ns = FPR_ENGINE or {}; FPR_ENGINE = ns end
local G = {}
ns.Game = G
local floor = math.floor
local function round(x) return floor(x + 0.5) end
local function K(id) return tostring(id) end  -- map keys for raider ids are strings (saves and JSON agree)

-- ---------------------------------------------------------------- data
G.SPECS = {
  warrior = { { "arms", "Arms", "damage" }, { "fury", "Fury", "damage" }, { "protection", "Protection", "tank" } },
  paladin = { { "holy", "Holy", "healer" }, { "protection", "Protection", "tank" }, { "retribution", "Retribution", "damage" } },
  hunter = { { "beastmastery", "Beast Mastery", "damage" }, { "marksmanship", "Marksmanship", "damage" }, { "survival", "Survival", "damage" } },
  rogue = { { "assassination", "Assassination", "damage" }, { "combat", "Combat", "damage" }, { "subtlety", "Subtlety", "damage" } },
  priest = { { "holy", "Holy", "healer" }, { "discipline", "Discipline", "healer" }, { "shadow", "Shadow", "damage" } },
  shaman = { { "elemental", "Elemental", "damage" }, { "enhancement", "Enhancement", "damage" }, { "restoration", "Restoration", "healer" } },
  mage = { { "arcane", "Arcane", "damage" }, { "fire", "Fire", "damage" }, { "frost", "Frost", "damage" } },
  warlock = { { "affliction", "Affliction", "damage" }, { "demonology", "Demonology", "damage" }, { "destruction", "Destruction", "damage" } },
  druid = { { "balance", "Balance", "damage" }, { "feral", "Feral (bear)", "tank" }, { "feralcat", "Feral (cat)", "damage" }, { "restoration", "Restoration", "healer" } },
}
G.CLASS_ORDER = { "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" }
G.CLASS_NAMES = { warrior = "Warrior", paladin = "Paladin", hunter = "Hunter", rogue = "Rogue", priest = "Priest", shaman = "Shaman", mage = "Mage", warlock = "Warlock", druid = "Druid" }
G.ARMOR = { warrior = "plate", paladin = "plate", hunter = "mail", shaman = "mail", rogue = "leather", druid = "leather", priest = "cloth", mage = "cloth", warlock = "cloth" }
local MELEE = { ["warrior:arms"] = true, ["warrior:fury"] = true, ["paladin:retribution"] = true, ["rogue:assassination"] = true,
  ["rogue:combat"] = true, ["rogue:subtlety"] = true, ["shaman:enhancement"] = true, ["druid:feralcat"] = true }
-- Races per class look (portrait 0 and 1), Alliance only with Classic rules (dwarf shamans per WoW: Forever).
G.RACES = { warrior = { "Human", "Dwarf" }, paladin = { "Human", "Dwarf" }, hunter = { "Night Elf", "Dwarf" }, rogue = { "Human", "Gnome" },
  priest = { "Human", "Night Elf" }, shaman = { "Dwarf", "Dwarf" }, mage = { "Human", "Gnome" }, warlock = { "Human", "Gnome" }, druid = { "Night Elf", "Night Elf" } }
local NAMES = { "Brannoc", "Mira", "Kess", "Tor", "Ash", "Lumi", "Orrin", "Mortis", "Sela", "Bram", "Ilo", "Fen", "Vey", "Rook", "Dax", "Wynn",
  "Thessa", "Grumli", "Pip", "Valen", "Odda", "Fizzwick", "Rhosyn", "Hask", "Nell", "Dorrin", "Quill", "Saffi", "Bolt", "Merrow", "Tamsin",
  "Hob", "Kaelen", "Briska", "Ulf", "Yara", "Gimble", "Ostra", "Penn", "Wix", "Corra", "Edda", "Larkin", "Moss", "Rurik", "Sprocket", "Tilly", "Vosk" }

G.RARITY = { common = { cost = 50, label = "Common" }, rare = { cost = 300, label = "Rare" }, epic = { cost = 1500, label = "Epic" }, legendary = { cost = 8000, label = "Legendary" } }
G.ECON = {
  startGold = 300, weeklyQuests = 300,                     -- PLAYTEST: daily quests compressed into one weekly payout
  normalFirst = { gold = 40, dkp = 5 }, normalReclear = 5, heroicKill = { gold = 60, dkp = 15 },
  dungeon = { gold = { 35, 45 }, perWeek = 8, itemChance = 35, itemLvl = { 50, 56 } },  -- PLAYTEST
  cauldron = { food = 10, elixirs = 30, flasks = 75 }, potion = 15, worldBuff = 250, fireGear = 120,
  reroll = 25, rosterMax = 15, dismissBack = 25, respec = 60,
  normalLoot = { 56, 62 }, heroicLoot = { 64, 70 }, heroicBand = { 60, 70 }, startGear = { 52, 56 },
}
G.MODES = { normal = { label = "Normal" }, heroic = { label = "Heroic" } }
G.CARD_ORDER = { "spread", "stack", "burn", "playsafe" }
G.CARDS = { spread = "Spread", stack = "Stack", burn = "Burn", playsafe = "Play Safe" }
G.CARD_TEXT = { spread = "Splash hits one character; healing -10%", stack = "Healing +15%; area hits land on everyone nearby",
  burn = "Damage +10%, threat +25%; heals cost 20% more mana", playsafe = "Damage -5%; everyone takes 15% less" }
G.WB_ORDER = { "dragonslayer", "songbloom", "warchief" }
G.WB = { dragonslayer = "Dragonslayer's Roar", songbloom = "Songbloom Blessing", warchief = "Spirit of the Warchief's Rival" }

-- Traits (design doc 4.4): names and player-facing text. Fight effects and numbers live in data.lua.
G.TRAIT_ORDER = { "pulls_on_cooldown", "needs_on_everything", "stands_in_fire", "never_stands_in_fire", "afk_on_trash", "main_spec_loot_only",
  "raid_leaders_favourite", "parse_goblin", "alt_tabbed", "partner_aggro", "discord_lawyer", "rage_quitter", "hardcore_andy",
  "backseat_raid_leader", "keyboard_turner", "main_character", "gear_score_elitist", "pug_hero", "pet_on_aggressive" }
G.TRAITS = {
  pulls_on_cooldown = { name = "Pulls on Cooldown", text = "+20% damage and threat, but starts the pull before the healers finish drinking (healers at 60% mana)." },
  needs_on_everything = { name = "Needs on Everything", text = "15% chance to grab loot you gave someone else." },
  stands_in_fire = { name = "Stands in Fire", text = "Takes 25% more damage from boss mechanics." },
  never_stands_in_fire = { name = "Never Stands in Fire", text = "Immune to ground effects: Magma Splash, the Frown, someone else's bomb. Rare." },
  afk_on_trash = { name = "AFK on Trash", text = "Skips the trash gauntlet. (Trash arrives in production; no effect yet.)" },
  main_spec_loot_only = { name = "Main-Spec Loot Only", text = "Loses 3 morale whenever someone else gets gear." },
  raid_leaders_favourite = { name = "Raid Leader's Favourite", text = "+10 morale for everyone in the raid while present." },
  parse_goblin = { name = "Parse Goblin", text = "+15% damage, but ignores mechanics: 20% more mechanic damage." },
  alt_tabbed = { name = "Alt-Tabbed", text = "10% chance each round to do nothing at all." },
  partner_aggro = { name = "Partner Aggro", text = "20% chance per pull to log off after round 10. \"Sorry guys, gotta go.\"" },
  discord_lawyer = { name = "Discord Lawyer", text = "Loot drama happens twice as often." },
  rage_quitter = { name = "Rage Quitter", text = "On a wipe, 10% chance to quit the guild on the spot." },
  hardcore_andy = { name = "Hardcore Andy", text = "+10% health and power. Refuses Battle Res on principle." },
  backseat_raid_leader = { name = "Backseat Raid Leader", text = "Makes the tactic card 5% stronger; costs the raid 2 morale per pull." },
  keyboard_turner = { name = "Keyboard Turner", text = "-2 speed, but never pulls aggro." },
  main_character = { name = "Main Character Syndrome", text = "+10% power for the week after getting loot; others who wanted it lose 2 morale." },
  gear_score_elitist = { name = "Gear Score Elitist", text = "Loses 1 morale per pull for each raider below their gear level." },
  pug_hero = { name = "Pug Hero", text = "+10% power with at least two new recruits (joined in the last 2 weeks) in the raid." },
  pet_on_aggressive = { name = "Pet on Aggressive", text = "15% chance per pull to bring an extra pack for the first 3 rounds." },
}
-- Tuning pass 5: smaller steps so a winning raid hovers near 80 instead of living above it.
G.MORALE = { start = 70, kill = 3, loot = 6, wipe = 3, wipesCounted = 3, benched = 15, drift = 10, vibe = 80, low = 20 }

-- Bosses: journal entries (found by seeing them), lines and loot.
G.BOSSES = {
  { id = "magmadad", name = "Magmadad", card = "burn",
    pull = "\"Hi raid, I'm Magmadad.\"", kill = "\"I'm not mad. I'm disappointed. And dead.\"",
    jokes = { "\"Why did the raid wipe? It couldn't handle the pressure. Like magma.\"", "\"I'd tell you a joke about pups, but you never finish them.\"", "\"Did you get my good side? Both of them are molten.\"" },
    abilities = {
      { id = "pups", codes = { 60 }, name = "Magma pups", text = "Three pups join the fight and pulse fire on everyone while they live." },
      { id = "revive", codes = { 65 }, b = 0, name = "Walk it off, champ", text = "Dead pups get back up unless all three go down within a round of each other." },
      { id = "timeout", codes = { 65 }, b = 1, name = "Timeout", text = "Kill all three pups together and they stay down. Only then does the raid turn on Magmadad." },
    },
    loot = { weapon = { "Dad's Grill Spatula", "Molten Tongs of Supervision" }, armor = { "Sensible Magma Sandals", "Cardigan of Mild Disappointment" }, trinket = { "World's Okayest Dad Mug", "Pup Treat Pouch" } } },
  { id = "baron", name = "Baron Get-Down", card = "spread",
    pull = "\"Somebody's going to explode. Might as well be you.\"", kill = "\"I... got... down...\"",
    jokes = { "Raid leader: \"If you're the bomb, GET DOWN. Out of the group. Not into the healers.\"" },
    abilities = {
      { id = "mark", codes = { 61 }, name = "Living Bomb", text = "Every round from round 2, a non-tank becomes the bomb." },
      { id = "boom", codes = { 62 }, name = "Get Down", text = "Next round the bomb goes off on everyone standing near the carrier." },
    },
    loot = { weapon = { "Fuse-Lit Shortsword", "Baron's Detonator Baton" }, armor = { "Blast-Proof Pantaloons", "Singed Dancing Shoes" }, trinket = { "Ticking Pocketwatch", "Earplugs of the Baron" } } },
  { id = "lucifrown", name = "Lucifrown", card = "playsafe",
    pull = "\"Who brought decurse? Anyone at all?\"", kill = "\"Fine. Smile, then. See if I care.\"",
    jokes = { "Lucifrown frowns harder. Somebody forgot something." },
    abilities = {
      { id = "volley", codes = { 1 }, name = "Shadow Volley", text = "Shadow damage on everyone, every round. Armor does nothing against it." },
      { id = "curse", codes = { 66 }, name = "Curse of Frowning", text = "Every 3rd round a curse doubles mana costs for 3 rounds. A mage or druid decurses it in 1." },
      { id = "frown", codes = { 68 }, name = "The Frown", text = "Every 3rd round he frowns at one zone of the raid. Hard." },
    },
    loot = { weapon = { "Scepter of Mild Contempt", "Grumpy Rod" }, armor = { "Robes of Resting Frown", "Furrowed Brow Helm" }, trinket = { "Decurse Reminder Note", "Smiley Badge (Defaced)" } } },
  { id = "majordomo", name = "Majordomo Exhaustus", card = "stack",
    pull = "\"Fine. FINE. Interns! Deal with it.\"", kill = "Majordomo Exhaustus gives up, files a complaint and leaves a bonus chest.",
    jokes = { "\"I'll go and wake the boss. Again.\"" },
    abilities = {
      { id = "interns", codes = { 63 }, name = "Eight interns", text = "Eight interns fight first. They hit whoever is closest, which is everyone." },
      { id = "joins", codes = { 64 }, name = "Fine. FINE.", text = "He joins only when every intern is down." },
    },
    loot = { weapon = { "Clipboard of Authority", "Stapler of Smiting" }, armor = { "Overtime Vestments", "Lanyard Mail" }, trinket = { "Complaint Form 27-B", "Executive Stress Ball" } } },
  { id = "ragnaroast", name = "Ragnaroast", card = "burn",
    pull = "\"The trash is still out there. I can hear it.\"", kill = "\"Too soon... you have roasted me... too soon!\"",
    jokes = { "\"Your tank's gear is from a dungeon. A bad one.\"", "\"Is that your healer or a decorative candle?\"", "\"I've seen better positioning in a lava lamp.\"" },
    abilities = {
      { id = "throw", codes = { 23 }, name = "Into the lava", text = "Every 4 rounds he throws the lowest-health melee character into the lava. Fire Protection Potions cancel one throw each." },
      { id = "splash", codes = { 25 }, name = "Magma Splash", text = "Fire on one zone every 2nd round." },
      { id = "submerge", codes = { 20 }, name = "Sinks and sends adds", text = "From round 10 he sinks for 3 rounds and sends fire adds. Everything he does is fire." },
    },
    loot = { weapon = { "Sulfurous Rolling Pin", "Roasting Spit of the Firelord" }, armor = { "Oven Mitts of Might", "Crispy Chainmail" }, trinket = { "Eye of Ragnaroast (Medium Rare)", "Marinade of Fury" } } },
}
G.BOSS = {}
for i = 1, #G.BOSSES do G.BOSS[G.BOSSES[i].id] = G.BOSSES[i]; G.BOSSES[i].index = i end

-- Lessons: the recap picks the first lesson whose test matches, then shows the tier the raid has reached:
-- what happened, a raid leader clue, then the answer (design doc 3.1).
G.LESSONS = {
  magmadad = {
    { id = "card", test = function(f) return f.revives > 0 and f.tactic ~= "burn" end, t = {
      "The pups got back up {revives} times. Magmadad himself barely took damage.",
      "Raid leader: \"We keep killing pups one at a time and they just stand back up. We need to hit way harder, all at once.\"",
      "Use Burn: +10% damage gets all three pups down inside the window, and then they stay down." } },
    { id = "dps", test = function(f) return f.revives > 0 end, t = {
      "The pups got back up {revives} times even on Burn.",
      "Raid leader: \"Burn is right, we just don't have the damage. Food, elixirs, flasks?\"",
      "You're on the right card. More damage: elixirs and flasks, better gear from Normal kills, or more damage dealers." } },
  },
  baron = {
    { id = "card", test = function(f) return f.bombZone > 0 and f.tactic ~= "spread" end, t = {
      "The bomb went off in a crowd {bombZone} times and took {bombDeaths} people with it.",
      "Raid leader: \"If you're the bomb, GET DOWN. Out of the group. Not into the healers.\"",
      "Use Spread: the bomb carrier runs out and only they get hit." } },
  },
  lucifrown = {
    { id = "decurse", test = function(f) return not f.decurser end, t = {
      "Every curse lasted 3 rounds and doubled your mana costs. Your healers ran dry.",
      "Lucifrown: \"Who brought decurse? Anyone at all?\"",
      "Bring a mage or a druid: they decurse, and the curse lasts 1 round instead of 3." } },
    { id = "card", test = function(f) return f.tactic ~= "playsafe" end, t = {
      "The Shadow Volley never stops. {volleyDeaths} died to it before the boss did.",
      "Raid leader: \"This is a marathon. We can't heal through all of this, can we take less of it?\"",
      "Use Play Safe: everyone takes 15% less, and the volley is the whole fight." } },
  },
  majordomo = {
    { id = "card", test = function(f) return f.tactic ~= "stack" end, t = {
      "The interns took {internRounds} rounds to clear before Majordomo even showed up.",
      "Raid leader: \"The interns are everywhere. Pull them together so every hit counts twice.\"",
      "Use Stack: the interns bunch up and every hit splashes onto another one. Healing is better too." } },
  },
  ragnaroast = {
    { id = "fire", test = function(f) return f.fireDeaths >= 2 and f.fireGear < 6 end, t = {
      "{fireDeaths} died to fire: the lava, Magma Splash and the fire adds.",
      "Ragnaroast: \"Is that your healer or a decorative candle?\" Raid leader: \"We're melting. Literally.\"",
      "Fire resistance: Fire Whelp gear from the Tavern and Fire Protection Potions for the melee and tanks. Only here, though." } },
    { id = "card", test = function(f) return f.tactic ~= "burn" end, t = {
      "The fire wasn't the problem. Ragnaroast was at {bossPct}% when the time was up, or close to it.",
      "Raid leader: \"He sinks at round 10. We need him low before he does.\"",
      "Use Burn: it's a race against the submerge and the enrage." } },
  },
}
local GENERIC = {
  { id = "tanks", test = function(f) return f.result == "wipe" and f.tankDeaths >= 1 and f.healers < 2 end, t = {
    "Your tanks died and there weren't enough healers to keep up.",
    "Raid leader: \"Two healers minimum. Three if it hurts.\"",
    "Bring 2-3 healers. The game lets you try anything, but tanks without healers fold." } },
  { id = "prep", test = function(f) return f.mode == "heroic" and not (f.cons.elixirs and f.cons.flasks) end, t = {
    "Heroic is tuned for a raid that brings consumables. You didn't.",
    "Raid leader: \"Flasks. Elixirs. It's Heroic. Come on.\"",
    "Buy the cauldrons in prep: elixirs and flasks are worth 15-20 points on Heroic." } },
  { id = "dps", test = function(f) return f.result == "enrage" end, t = {
    "The boss was at {bossPct}% when the clock ran out.",
    "Raid leader: \"We're close. A little more damage and it's dead.\"",
    "More damage: consumables, gear from earlier bosses, or swap a healer for a damage dealer if you're surviving easily." } },
  { id = "deaths", test = function(f) return true end, t = {
    "Too many people died: {deaths} in total.",
    "Raid leader: \"Check who's dying to what in the log. That's the fight telling you something.\"",
    "Check the journal for this boss: each one has one main answer, and the recap points at it as you learn." } },
}
G.CAUSE = { [23] = "lava throw", [24] = "boss melee", [25] = "Magma Splash", [26] = "adds", [62] = "bomb", [67] = "Shadow Volley", [68] = "the Frown" }

-- ---------------------------------------------------------------- small helpers
local function contains(list, v) for i = 1, #list do if list[i] == v then return true end end return false end
local function filter(list, fn) local out = {} for i = 1, #list do if fn(list[i]) then out[#out + 1] = list[i] end end return out end
local function copy(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = copy(v) end return o end
G.copy = copy

-- Game-side seeded RNG (loot, Tavern, names), saved with the game. Floats keep Fengari's 32-bit integers safe.
local function rngNext(st) st.rng = floor((st.rng * 16807.0) % 2147483647); return st.rng end
local function rint(st, n) return 1 + (rngNext(st) % n) end             -- 1..n
local function rrange(st, a, b) return a + (rngNext(st) % (b - a + 1)) end
local function pick(st, list) return list[1 + (rngNext(st) % #list)] end

function G.role(cls, spec) local s = G.SPECS[cls] for i = 1, #s do if s[i][1] == spec then return s[i][3] end end end
function G.specName(cls, spec) local s = G.SPECS[cls] for i = 1, #s do if s[i][1] == spec then return s[i][2] end end end
function G.defaultZone(c)
  local r = G.role(c.cls, c.spec)
  if r == "tank" then return "front" elseif r == "healer" then return "back" end
  return MELEE[c.cls .. ":" .. c.spec] and "melee" or "ranged"
end
function G.isMeleeSpec(c) return MELEE[c.cls .. ":" .. c.spec] and true or false end
function G.gearLevel(c) return round((c.gear.weapon.lvl + c.gear.armor.lvl + c.gear.trinket.lvl) / 3) end
function G.canWear(c, item) return item.slot ~= "armor" or item.type == G.ARMOR[c.cls] end
function G.byId(st, id) for i = 1, #st.roster do if st.roster[i].id == id then return st.roster[i] end end end
local byId = G.byId
function G.sellValue(item) local v = round(item.lvl / 4) if v < 1 then v = 1 end return v end

local function rollTraits(st, cls, rarity, r0)
  -- Weighted by class and rarity (design doc 4.4): tanks pull, rogues need, hunters' pets wander; rage quitters are never epic.
  local isTank = r0 == "tank"
  local pool = {}
  for i = 1, #G.TRAIT_ORDER do
    local id, w = G.TRAIT_ORDER[i], 10
    if id == "pulls_on_cooldown" then w = isTank and 40 or 0 end
    if id == "needs_on_everything" then w = (cls == "rogue") and 40 or 8 end
    if id == "pet_on_aggressive" then w = (cls == "hunter") and 40 or 0 end
    if id == "never_stands_in_fire" then w = (rarity == "common") and 0 or ((rarity == "rare") and 4 or 12) end
    if id == "rage_quitter" then w = (rarity == "epic" or rarity == "legendary") and 0 or 8 end
    if id == "keyboard_turner" and isTank then w = 0 end
    pool[#pool + 1] = { id, w }
  end
  local out = {}
  local n = (rint(st, 100) <= 35) and 2 or 1
  for _ = 1, n do
    local total = 0
    for i = 1, #pool do if not contains(out, pool[i][1]) then total = total + pool[i][2] end end
    local x = rint(st, total)
    for i = 1, #pool do
      local id, w = pool[i][1], pool[i][2]
      if not contains(out, id) then
        if x <= w then out[#out + 1] = id; break end
        x = x - w
      end
    end
  end
  return out
end
local function moraleAdd(c, d, why, log)
  local before = c.morale
  c.morale = c.morale + d
  if c.morale < 0 then c.morale = 0 elseif c.morale > 100 then c.morale = 100 end
  if log and c.morale ~= before then log[#log + 1] = { id = c.id, name = c.name, d = c.morale - before, why = why } end
end

local function freshName(st)
  local used = {}
  for i = 1, #st.roster do used[st.roster[i].name] = true end
  for i = 1, #(st.tavern or {}) do used[st.tavern[i].name] = true end
  for _ = 1, 60 do local n = pick(st, NAMES) if not used[n] then return n end end
  return "Raider " .. st.nextId
end
local function makeChar(st, cls, spec, rarity, lo, hi)
  local look = rngNext(st) % 2
  local name = freshName(st)                               -- order matters: the same rolls as the JS build
  local traits = rollTraits(st, cls, rarity, G.role(cls, spec))
  local c = { id = st.nextId, name = name, cls = cls, spec = spec, look = look, race = G.RACES[cls][look + 1], rarity = rarity,
    gear = {}, fire = 0, benched = false, joined = st.week,
    skill10 = ({ common = 20, rare = 40, epic = 55, legendary = 70 })[rarity] * 10, fam10 = {}, pulls = {},
    traits = traits, morale = G.MORALE.start, looted = false }
  st.nextId = st.nextId + 1
  lo, hi = lo or G.ECON.startGear[1], hi or G.ECON.startGear[2]
  local armor = G.ARMOR[cls]
  c.gear.weapon = { name = "Starter " .. ((G.role(cls, spec) == "healer") and "Staff" or "Weapon"), slot = "weapon", lvl = rrange(st, lo, hi), q = "common" }
  c.gear.armor = { name = "Hand-me-down " .. string.upper(string.sub(armor, 1, 1)) .. string.sub(armor, 2), slot = "armor", type = armor, lvl = rrange(st, lo, hi), q = "common" }
  c.gear.trinket = { name = "Lucky Rabbit's Foot", slot = "trinket", lvl = rrange(st, lo, hi), q = "common" }
  return c
end

local function rollTavern(st)
  st.tavern = {}
  for _ = 1, 5 do
    local cls = pick(st, G.CLASS_ORDER)
    if cls == "warlock" and rint(st, 100) > 25 then  -- warlocks are rare (design doc 4.5)
      cls = pick(st, filter(G.CLASS_ORDER, function(x) return x ~= "warlock" end))
    end
    local spec = pick(st, G.SPECS[cls])[1]
    local r = rint(st, 100)
    local rarity = (r <= 70) and "common" or ((r <= 95) and "rare" or "epic")
    local c = makeChar(st, cls, spec, rarity, G.ECON.startGear[1] - 2, G.ECON.startGear[2] - 2)
    c.price = G.RARITY[rarity].cost
    st.tavern[#st.tavern + 1] = c
  end
end

function G.NewGame(seed)
  local st = { v = 3, seed = seed, rng = (seed % 2147483646) + 1, week = 1, gold = G.ECON.startGold, dkp = 0, nextId = 1,
    roster = {}, bonds = {}, buffs = {}, journal = {}, lessons = {}, progress = {}, history = {}, pending = {}, dungeonsLeft = G.ECON.dungeon.perWeek,
    rerolls = 0, replays = {}, pulls = 0, news = {}, score = { kills = 0, wipes = 0, rounds = 0 }, bestScore = 0, freeWipe = {}, lastPrep = {} }
  -- A sensible but uneven starting guild: 2 tanks, 3 healers, 7 damage dealers, mostly common.
  local start = { { "warrior", "protection", "rare" }, { "paladin", "protection", "common" }, { "priest", "holy", "rare" }, { "shaman", "restoration", "common" },
    { "druid", "restoration", "common" }, { "rogue", "combat", "common" }, { "warrior", "fury", "common" }, { "hunter", "marksmanship", "rare" },
    { "warlock", "affliction", "common" }, { "priest", "shadow", "common" }, { "hunter", "beastmastery", "common" }, { "paladin", "retribution", "common" } }
  for i = 1, #start do st.roster[#st.roster + 1] = makeChar(st, start[i][1], start[i][2], start[i][3]) end
  for i = 1, #G.BOSSES do st.progress[G.BOSSES[i].id] = { normalKills = 0, heroicKills = 0, normalWeek = false, heroicWeek = false, heroicWipes = 0, pulls = 0, wipes = 0 } end
  rollTavern(st)
  st.news[#st.news + 1] = "Week 1. Your guild has 12 raiders, 300 gold and a raid to clear. Start with Magmadad on Normal."
  return st
end

-- ---------------------------------------------------------------- progression (engine/progress.lua's rules)
local function R() return ns.Progress.RULES end
local function bondKey(a, b) if a < b then return a .. "|" .. b end return b .. "|" .. a end
function G.bond(st, a, b) local e = st.bonds[bondKey(a, b)] return e and e.v10 or 0 end
local function afterPull(st, ids, boss, killed)
  local RU = R()
  for i = 1, #ids do
    local m = byId(st, ids[i])
    local n = (m.pulls[boss] or 0) + 1
    m.pulls[boss] = n
    if n <= RU.counted_pulls then
      local gain = killed and RU.skill_kill or RU.skill_wipe
      if m.skill10 >= RU.skill_soft then gain = floor(gain / 2) end
      m.skill10 = math.min(1000, m.skill10 + gain)
      m.fam10[boss] = math.min(RU.fam_cap, (m.fam10[boss] or 0) + (killed and RU.fam_kill or RU.fam_wipe))
    end
  end
  for i = 1, #ids do
    for j = i + 1, #ids do
      local k = bondKey(ids[i], ids[j])
      local e = st.bonds[k]
      if not e then e = { v10 = 0, week = 0 }; st.bonds[k] = e end
      local add = math.max(0, math.min(RU.chem_pull, RU.chem_week - e.week, RU.chem_cap - e.v10))
      e.v10 = e.v10 + add; e.week = e.week + add
    end
  end
end
function G.famAvg(st, ids, boss)
  if #ids == 0 then return 0 end
  local s = 0
  for i = 1, #ids do local c = byId(st, ids[i]) s = s + ((c and c.fam10[boss]) or 0) end
  return s / #ids / 10
end
function G.cohesion(st, ids)
  local s, n = 0, 0
  for i = 1, #ids do for j = i + 1, #ids do s = s + G.bond(st, ids[i], ids[j]); n = n + 1 end end
  return (n > 0) and (s / n / 10) or 0
end
-- Heroic score this week (design doc 11): +1,000 a kill, -150 a wipe, -50 per benched raider, +5 per round under 20.
function G.heroicScore(st)
  local sc = st.score
  local benched = 0
  for i = 1, #st.roster do if st.roster[i].benched then benched = benched + 1 end end
  return sc.kills * 1000 - sc.wipes * 150 - benched * 50 + sc.rounds * 5
end

-- ---------------------------------------------------------------- availability and prep
function G.unlocked(st, boss, mode)
  local i = G.BOSS[boss].index
  if mode == "normal" then return i == 1 or st.progress[G.BOSSES[i - 1].id].normalKills > 0 end
  -- Heroic: attuned by a Normal Ragnaroast kill (design doc 10.7, shortened for the slice), then in order each week.
  if st.progress.ragnaroast.normalKills == 0 then return false end
  return i == 1 or st.progress[G.BOSSES[i - 1].id].heroicWeek
end
function G.heroicOpen(st) return st.progress.ragnaroast.normalKills > 0 end

local function sortedBy(list, key)  -- stable and runtime-independent: ties broken by id
  local t = {}
  for i = 1, #list do t[i] = list[i] end
  table.sort(t, function(a, b) local ka, kb = key(a), key(b) if ka ~= kb then return ka > kb end return a.id < b.id end)
  return t
end
function G.DefaultPrep(st, boss, mode)
  local avail = filter(st.roster, function(c) return not (mode == "heroic" and c.benched) end)
  local function pickRole(r, n)
    local l = sortedBy(filter(avail, function(c) return G.role(c.cls, c.spec) == r end), G.gearLevel)
    local out = {} for i = 1, math.min(n, #l) do out[i] = l[i] end return out
  end
  local chosen = {}
  local function add(c) if #chosen < 10 and not contains(chosen, c) then chosen[#chosen + 1] = c end end
  local t, h = pickRole("tank", 2), pickRole("healer", 3)
  for i = 1, #t do add(t[i]) end
  for i = 1, #h do add(h[i]) end
  local dps = sortedBy(filter(avail, function(c) return G.role(c.cls, c.spec) == "damage" end), G.gearLevel)
  for i = 1, #dps do add(dps[i]) end
  for i = 1, #avail do add(avail[i]) end
  local prep = { boss = boss, mode = mode, ids = {}, zones = {}, tactic = "spread", cons = { food = false, elixirs = false, flasks = false },
    potions = {}, fireOn = {}, buffs = {} }
  for i = 1, #chosen do
    local c = chosen[i]
    prep.ids[i] = c.id; prep.zones[K(c.id)] = G.defaultZone(c); prep.fireOn[K(c.id)] = 0
  end
  local last = st.lastPrep[boss .. ":" .. mode]
  if last then prep.tactic = last.tactic; prep.cons = copy(last.cons) end
  return prep
end
function G.PrepCost(st, prep)
  local hasMage = false
  for i = 1, #prep.ids do local c = byId(st, prep.ids[i]) if c and c.cls == "mage" then hasMage = true end end
  local g, items = 0, {}
  local E = G.ECON
  if prep.cons.food then local p = hasMage and 0 or E.cauldron.food; g = g + p; items[#items + 1] = { "Food cauldron" .. (hasMage and " (the mage made the table)" or ""), p } end
  if prep.cons.elixirs then g = g + E.cauldron.elixirs; items[#items + 1] = { "Elixir cauldron", E.cauldron.elixirs } end
  if prep.cons.flasks then g = g + E.cauldron.flasks; items[#items + 1] = { "Flask cauldron", E.cauldron.flasks } end
  local pots = 0
  for i = 1, #prep.ids do if prep.potions[K(prep.ids[i])] then pots = pots + 1 end end
  if pots > 0 then g = g + pots * E.potion; items[#items + 1] = { pots .. " Fire Protection Potion" .. ((pots > 1) and "s" or ""), pots * E.potion } end
  for i = 1, #G.WB_ORDER do
    local b = G.WB_ORDER[i]
    if prep.buffs[b] and not st.buffs[b] then g = g + E.worldBuff; items[#items + 1] = { G.WB[b], E.worldBuff } end
  end
  return { gold = g, items = items }
end
function G.Problems(st, prep)
  local out = {}
  local p = st.progress[prep.boss]
  if not G.unlocked(st, prep.boss, prep.mode) then out[#out + 1] = "Locked: kill the boss before it first" .. ((prep.mode == "heroic") and " (and Ragnaroast on Normal for Heroic)" or "") .. "." end
  if prep.mode == "heroic" and p.heroicWeek then out[#out + 1] = G.BOSS[prep.boss].name .. " is already dead on Heroic this week. The lockout resets next week." end
  if #prep.ids < 1 then out[#out + 1] = "Pick at least one raider." end
  if #prep.ids > 10 then out[#out + 1] = "Raids take 10." end
  if prep.mode == "heroic" then
    for i = 1, #prep.ids do local c = byId(st, prep.ids[i]) if c and c.benched then out[#out + 1] = "A benched raider can't come to Heroic this week."; break end end
  end
  local cost = G.PrepCost(st, prep).gold
  if cost > st.gold then out[#out + 1] = "Not enough gold for this prep (" .. cost .. " needed)." end
  return out
end
function G.Warnings(st, prep)
  local w = {}
  local t, h = 0, 0
  for i = 1, #prep.ids do
    local c = byId(st, prep.ids[i])
    local r = G.role(c.cls, c.spec)
    if r == "tank" then t = t + 1 elseif r == "healer" then h = h + 1 end
  end
  if #prep.ids < 10 then w[#w + 1] = "Only " .. #prep.ids .. " raiders. You can pull, but it's hard." end
  if t < 2 then w[#w + 1] = (t == 0) and "No tank. Bold." or "Only one tank." end
  if h < 2 then w[#w + 1] = (h == 0) and "No healers." or "Only one healer." end
  for i = 1, #prep.ids do
    local c = byId(st, prep.ids[i])
    local z = prep.zones[K(c.id)]
    if G.isMeleeSpec(c) and z ~= "melee" then w[#w + 1] = c.name .. " fights in melee but stands in " .. z .. ": half damage." end
    if G.role(c.cls, c.spec) == "tank" and z ~= "front" then w[#w + 1] = c.name .. " is a tank outside Front: half damage, and the boss may not stay on them." end
  end
  return w
end

local function seedFor(st, prep)
  local h = (st.seed % 100000) * 7 + st.week * 131 + (G.BOSS[prep.boss].index - 1) * 17 + ((prep.mode == "heroic") and 5 or 0) + st.pulls * 977
  return (h % 2147483646) + 1
end
local function buildInput(st, prep, seed)
  local raid = {}
  for i = 1, #prep.ids do
    local c = byId(st, prep.ids[i])
    local gl = G.gearLevel(c)
    if prep.mode == "heroic" then gl = math.min(G.ECON.heroicBand[2], math.max(G.ECON.heroicBand[1], gl)) end  -- the ranked band
    local tr = {}
    for k = 1, math.min(2, #c.traits) do tr[k] = c.traits[k] end
    raid[i] = { name = c.name, class = c.cls, spec = c.spec, zone = prep.zones[K(c.id)], potion = prep.potions[K(c.id)] and true or false,
      firegear = math.min(c.fire, prep.fireOn[K(c.id)] or 0), skill = floor(c.skill10 / 10), fam = floor((c.fam10[prep.boss] or 0) / 10), gl = gl,
      traits = tr, morale = c.morale, new = (st.week - c.joined) < 2, looted = c.looted and true or false }
  end
  local pairs_ = {}
  for i = 1, #prep.ids do
    for j = i + 1, #prep.ids do
      local v = floor(G.bond(st, prep.ids[i], prep.ids[j]) / 10)
      if v > 0 then pairs_[#pairs_ + 1] = { a = i, b = j, v = v } end
    end
  end
  local buffs = {}
  for i = 1, #G.WB_ORDER do local b = G.WB_ORDER[i] buffs[b] = (st.buffs[b] or prep.buffs[b]) and true or false end
  return { boss = prep.boss, mode = prep.mode, seed = seed, tactic = prep.tactic, gl = 60, consumables = copy(prep.cons), buffs = buffs, raid = raid, pairs = pairs_ }
end

-- A compact, JSON-friendly copy of an engine result (the shape prototype/api.lua uses).
function G.Summary(r, frames)
  local ev, raid, fr = {}, {}, {}
  for i = 1, #r.events do local e = r.events[i] ev[i] = { r = e.round, c = e.code, a = e.a, b = e.b, t = e.text } end
  for i = 1, #r.raid do local p = r.raid[i] raid[i] = { name = p.name, hp = p.hp, maxhp = p.maxhp, alive = p.alive, role = p.role, mana = p.mana, dealt = p.dealt, healed = p.healed } end
  for i = 1, #(frames or {}) do local f = frames[i] local h = {} for j = 1, #f.hp do h[j] = f.hp[j] end fr[i] = { b = f.boss, w = f.away, a = f.adds, h = h } end
  return { result = r.result, rounds = r.rounds, checksum = r.checksum, engine = r.engine, bossHp = r.boss_hp, bossMax = r.boss_maxhp,
    survivors = r.survivors, events = ev, raid = raid, frames = fr }
end

local function facts(prep, input, s)
  local deathsBy, deaths, tankDeaths = {}, 0, 0
  local revives, bombZone, firstIntern, joined = 0, 0, nil, nil
  for i = 1, #s.events do
    local e = s.events[i]
    if e.c == 31 then
      deaths = deaths + 1; deathsBy[e.b] = (deathsBy[e.b] or 0) + 1
      if s.raid[e.a] and s.raid[e.a].role == "tank" then tankDeaths = tankDeaths + 1 end
    end
    if e.c == 65 and e.b == 0 then revives = revives + 1 end
    if e.c == 62 and e.b > 1 then bombZone = bombZone + 1 end
    if e.c == 63 and not firstIntern then firstIntern = e end
    if e.c == 64 and not joined then joined = e end
  end
  local healers, decurser, fireGear = 0, false, 0
  for i = 1, #input.raid do
    local c = input.raid[i]
    if G.role(c.class, c.spec) == "healer" then healers = healers + 1 end
    if c.class == "mage" or c.class == "druid" then decurser = true end
    fireGear = fireGear + (c.firegear or 0)
  end
  return { result = s.result, tactic = prep.tactic, mode = prep.mode, cons = prep.cons, deaths = deaths, tankDeaths = tankDeaths, healers = healers,
    revives = revives, bombZone = bombZone, bombDeaths = deathsBy[62] or 0, decurser = decurser, volleyDeaths = deathsBy[67] or 0,
    internRounds = joined and (joined.r - 1) or (firstIntern and s.rounds or 0),
    fireDeaths = (deathsBy[23] or 0) + (deathsBy[25] or 0) + (deathsBy[26] or 0), fireGear = fireGear,
    bossPct = round(100 * s.bossHp / s.bossMax) }
end
local function fill(t, f) return (string.gsub(t, "{(%w+)}", function(k) return tostring(f[k]) end)) end
local function lessonFor(st, prep, f, onKill)
  -- On a kill only the boss's own lessons count ("you won, but..."), so Normal teaches even when it goes well.
  local list = {}
  for _, l in ipairs(G.LESSONS[prep.boss] or {}) do if not (onKill and l.id == "dps") then list[#list + 1] = l end end
  if not onKill then for _, l in ipairs(GENERIC) do list[#list + 1] = l end end
  local L
  for i = 1, #list do if list[i].test(f) then L = list[i]; break end end
  if not L then return nil end
  local key = prep.boss .. ":" .. L.id
  local seen = (st.lessons[key] or 0) + 1
  st.lessons[key] = seen
  local fam = G.famAvg(st, prep.ids, prep.boss)
  -- Tier: whichever is further along, how often this lesson came up or how well the raid knows the boss.
  local bySeen = (seen >= 4) and 2 or ((seen >= 2) and 1 or 0)
  local byFam = (fam >= 6) and 2 or ((fam >= 3) and 1 or 0)
  local tier = math.min(2, math.max(bySeen, byFam))
  return { id = L.id, tier = tier, text = fill(L.t[tier + 1], f), seen = seen,
    next = (tier == 0) and "More will make sense as your raid learns this fight." or ((tier == 1) and "Your raid is close to working it out." or "") }
end

local function makeItem(st, boss, mode)
  local slot = pick(st, { "weapon", "armor", "trinket" })
  local band = (mode == "heroic") and G.ECON.heroicLoot or G.ECON.normalLoot
  local it = { name = pick(st, G.BOSS[boss].loot[slot]), slot = slot, lvl = rrange(st, band[1], band[2]), q = "epic", from = G.BOSS[boss].name .. " (" .. G.MODES[mode].label .. ")" }
  if slot == "armor" then it.type = pick(st, { "plate", "mail", "leather", "cloth" }) end
  return it
end
local function suggest(st, item, ids)
  local best, gain = nil, 0
  for i = 1, #ids do
    local c = byId(st, ids[i])
    if c and G.canWear(c, item) then
      local g = item.lvl - c.gear[item.slot].lvl
      if g > gain then gain = g; best = c.id end
    end
  end
  if best then return best, gain end
  return "sell", 0
end
function G.SuggestFor(st, item) return (suggest(st, item, item.eligible or {})) end

local function journalFind(st, boss, s)
  local j = st.journal[boss]
  if not j then j = {}; st.journal[boss] = j end
  local found = {}
  for _, a in ipairs(G.BOSS[boss].abilities) do
    if not j[a.id] then
      for i = 1, #s.events do
        local e = s.events[i]
        if contains(a.codes, e.c) and (a.b == nil or e.b == a.b) then j[a.id] = st.week; found[#found + 1] = a.name; break end
      end
    end
  end
  return found
end

local function dismissFree(st, id)  -- quitting: no gold back, bonds gone
  st.roster = filter(st.roster, function(x) return x.id ~= id end)
  local drop = {}
  for k in pairs(st.bonds) do
    local a, b = string.match(k, "^(%d+)|(%d+)$")
    if tonumber(a) == id or tonumber(b) == id then drop[#drop + 1] = k end
  end
  for i = 1, #drop do st.bonds[drop[i]] = nil end
end

-- ---------------------------------------------------------------- the pull
-- Runs the pull through the engine and applies everything that follows. Returns `out` (or { error = ... }).
function G.Pull(st, prep)
  prep.ids = filter(prep.ids, function(id) return byId(st, id) ~= nil end)  -- someone may have quit since the plan was made
  local bad = G.Problems(st, prep)
  if #bad > 0 then return { error = bad[1] } end
  local cost = G.PrepCost(st, prep)
  st.gold = st.gold - cost.gold
  for _, b in ipairs(G.WB_ORDER) do if prep.buffs[b] then st.buffs[b] = true end end
  local seed = seedFor(st, prep)
  st.pulls = st.pulls + 1
  local input = buildInput(st, prep, seed)
  local frames = {}
  local run = copy(input); run.frames = frames
  local s = G.Summary(ns.Simulate(run), frames)
  local killed = s.result == "kill"
  local p = st.progress[prep.boss]
  local E = G.ECON
  local out = { boss = prep.boss, mode = prep.mode, result = s.result, run = s, input = input, seed = seed, spent = cost.gold,
    gold = 0, dkp = 0, loot = {}, benched = {}, repair = 0, quit = {}, morale = {} }
  p.pulls = p.pulls + 1
  if killed then
    if prep.mode == "normal" then
      if not p.normalWeek then
        p.normalWeek = true; out.gold = out.gold + E.normalFirst.gold; out.dkp = out.dkp + E.normalFirst.dkp
        out.loot = { makeItem(st, prep.boss, "normal"), makeItem(st, prep.boss, "normal") }; out.lockout = true
      else
        out.gold = out.gold + E.normalReclear; out.reclear = true
      end
      p.normalKills = p.normalKills + 1
    else
      out.gold = out.gold + E.heroicKill.gold; out.dkp = out.dkp + E.heroicKill.dkp
      out.loot = { makeItem(st, prep.boss, "heroic"), makeItem(st, prep.boss, "heroic") }
      p.heroicKills = p.heroicKills + 1; p.heroicWeek = true
      st.score.kills = st.score.kills + 1; st.score.rounds = st.score.rounds + math.max(0, 20 - s.rounds)
    end
  else
    p.wipes = p.wipes + 1
    if prep.mode == "heroic" then p.heroicWipes = p.heroicWipes + 1; st.score.wipes = st.score.wipes + 1 end
  end
  -- Repairs: 1 gold per 5 gear levels per death, x1.5 on a wipe. The first wipe per boss each week is free (learning path).
  local dead = {}
  for i = 1, #s.raid do if not s.raid[i].alive then dead[#dead + 1] = prep.ids[i] end end
  local rep = 0
  for i = 1, #dead do rep = rep + round(G.gearLevel(byId(st, dead[i])) / 5) end
  if not killed then rep = round(rep * 1.5) end
  local freeKey = prep.boss .. ":" .. prep.mode
  if not killed and not st.freeWipe[freeKey] then st.freeWipe[freeKey] = true; out.repairWaived = rep; rep = 0 end
  out.repair = rep
  st.gold = math.max(0, st.gold - rep)
  if not killed then
    for _, b in ipairs(G.WB_ORDER) do if st.buffs[b] then out.buffsLost = true end end
    st.buffs = {}
  end
  -- Heroic: whoever died is benched for the rest of the lockout (design doc 4.5).
  if prep.mode == "heroic" then
    for i = 1, #dead do local c = byId(st, dead[i]) c.benched = true; out.benched[#out.benched + 1] = c.name end
  end
  st.gold = st.gold + out.gold; st.dkp = st.dkp + out.dkp
  -- Getting better.
  local beforeSkill, beforeFam = 0, 0
  for i = 1, #prep.ids do local c = byId(st, prep.ids[i]) beforeSkill = beforeSkill + c.skill10; beforeFam = beforeFam + (c.fam10[prep.boss] or 0) end
  local cohBefore = G.cohesion(st, prep.ids)
  afterPull(st, prep.ids, prep.boss, killed)
  local afterSkill, afterFam, counted = 0, 0, false
  for i = 1, #prep.ids do
    local c = byId(st, prep.ids[i])
    afterSkill = afterSkill + c.skill10; afterFam = afterFam + (c.fam10[prep.boss] or 0)
    if (c.pulls[prep.boss] or 0) <= R().counted_pulls then counted = true end
  end
  local n = #prep.ids
  out.growth = { skill = (afterSkill - beforeSkill) / n / 10, fam = (afterFam - beforeFam) / n / 10, chem = G.cohesion(st, prep.ids) - cohBefore, counted = counted }
  -- Morale and guild traits (design doc 4.4).
  local ml = out.morale
  local inRaid = {}
  for i = 1, #prep.ids do inRaid[i] = byId(st, prep.ids[i]) end
  for _, c in ipairs(inRaid) do  -- only the first few wipes on a boss each week sting
    if killed then moraleAdd(c, G.MORALE.kill, "kill", ml)
    elseif (c.pulls[prep.boss] or 0) <= G.MORALE.wipesCounted then moraleAdd(c, -G.MORALE.wipe, "wipe", ml) end
  end
  if prep.mode == "heroic" then for i = 1, #dead do moraleAdd(byId(st, dead[i]), -G.MORALE.benched, "benched", ml) end end
  local backseat = false
  for _, c in ipairs(inRaid) do if contains(c.traits, "backseat_raid_leader") then backseat = true end end
  if backseat then for _, c in ipairs(inRaid) do if not contains(c.traits, "backseat_raid_leader") then moraleAdd(c, -2, "backseat raid leading", ml) end end end
  for _, c in ipairs(inRaid) do
    if contains(c.traits, "gear_score_elitist") then
      local below = 0
      for _, x in ipairs(inRaid) do if x ~= c and G.gearLevel(x) < G.gearLevel(c) then below = below + 1 end end
      if below > 0 then moraleAdd(c, -below, "carrying " .. below .. " undergeared raiders", ml) end
    end
  end
  if not killed then
    for _, c in ipairs(inRaid) do
      if contains(c.traits, "rage_quitter") and rint(st, 100) <= 10 then out.quit[#out.quit + 1] = c.name; dismissFree(st, c.id) end
    end
  end
  out.found = journalFind(st, prep.boss, s)
  out.facts = facts(prep, input, s)
  if not killed then out.lesson = lessonFor(st, prep, out.facts, false); out.joke = pick(st, G.BOSS[prep.boss].jokes)
  elseif out.facts.deaths >= 2 or prep.tactic ~= G.BOSS[prep.boss].card then out.note = lessonFor(st, prep, out.facts, true) end
  for _, it in ipairs(out.loot) do
    it.eligible = {}
    for i = 1, #prep.ids do it.eligible[i] = prep.ids[i] end
    it.assign = suggest(st, it, prep.ids)
    st.pending[#st.pending + 1] = it
  end
  st.lastPrep[prep.boss .. ":" .. prep.mode] = { tactic = prep.tactic, cons = copy(prep.cons) }
  st.lastPull = { input = input, prep = copy(prep), result = s.result, bossPct = round(100 * s.bossHp / s.bossMax) }
  table.insert(st.history, 1, { week = st.week, boss = prep.boss, mode = prep.mode, result = s.result, rounds = s.rounds, tactic = prep.tactic })
  while #st.history > 40 do table.remove(st.history) end
  return out
end

-- Replay: the exact same pull with one change, no rewards (learning path). Once per boss per week, from the first wipe.
function G.ReplayInfo(st)
  local lp = st.lastPull
  if not lp or lp.result == "kill" then return { ok = false } end
  local used = st.replays[lp.prep.boss .. ":" .. st.week]
  return { ok = not used, used = used and true or false, fam = G.famAvg(st, lp.prep.ids, lp.prep.boss) }
end
function G.Replay(st, card)
  if not G.ReplayInfo(st).ok then return { error = "Replay isn't available." } end
  st.replays[st.lastPull.prep.boss .. ":" .. st.week] = true
  local input = copy(st.lastPull.input)
  input.tactic = card
  local frames = {}
  input.frames = frames
  local s = G.Summary(ns.Simulate(input), frames)
  input.frames = nil
  return { run = s, input = input, card = card }
end

-- ---------------------------------------------------------------- loot, dungeons, roster
function G.Assign(st, item, to)
  if to == "sell" then st.gold = st.gold + G.sellValue(item); return item.name .. " sold for " .. G.sellValue(item) .. " gold." end
  local c = byId(st, tonumber(to))
  if not c or not G.canWear(c, item) then return "Can't equip that." end
  local note = ""
  local group = {}
  for _, id in ipairs(item.eligible or {}) do local x = byId(st, id) if x then group[#group + 1] = x end end
  -- Needs on Everything: someone else in the pull grabs it first.
  for _, x in ipairs(group) do
    if x ~= c and contains(x.traits, "needs_on_everything") and G.canWear(x, item) and rint(st, 1000) <= 150 then
      note = " " .. x.name .. " rolled Need on it first. Of course they did."; c = x; break
    end
  end
  -- Loot drama: 10% per item, twice as often with a Discord Lawyer around.
  local lawyer = false
  for _, x in ipairs(group) do if contains(x.traits, "discord_lawyer") then lawyer = true end end
  if rint(st, 100) <= (lawyer and 20 or 10) then
    local others = filter(group, function(x) return x ~= c and G.canWear(x, item) end)
    if #others > 0 then
      local o = others[rint(st, #others)]
      moraleAdd(o, -5, "loot drama")
      note = note .. " Loot drama in Discord: " .. o.name .. " is upset (-5 morale)."
    end
  end
  moraleAdd(c, G.MORALE.loot, "loot")
  for _, x in ipairs(group) do if x ~= c and contains(x.traits, "main_spec_loot_only") then moraleAdd(x, -3, "someone else got gear") end end
  if contains(c.traits, "main_character") then
    c.looted = true
    for _, x in ipairs(group) do if x ~= c and G.canWear(x, item) and item.lvl > x.gear[item.slot].lvl then moraleAdd(x, -2, "wanted it") end end
  end
  local old = c.gear[item.slot]
  c.gear[item.slot] = { name = item.name, slot = item.slot, type = item.type, lvl = item.lvl, q = item.q }
  return c.name .. " equips " .. item.name .. " (" .. old.lvl .. " to " .. item.lvl .. ")." .. note
end
-- Loot waiting for a decision. Boss loot goes to someone who was in the pull (Bind on Pickup).
function G.AssignPending(st, i, to)
  local it = st.pending[i]
  if not it then return "" end
  local msg = G.Assign(st, it, to)
  if msg ~= "Can't equip that." then table.remove(st.pending, i) end
  return msg
end
function G.Dungeon(st)
  if st.dungeonsLeft <= 0 then return { error = "No dungeon runs left this week." } end
  st.dungeonsLeft = st.dungeonsLeft - 1
  local D = G.ECON.dungeon
  local gold = rrange(st, D.gold[1], D.gold[2])
  st.gold = st.gold + gold
  local out = { gold = gold }
  if rint(st, 100) <= D.itemChance then
    local slot = pick(st, { "weapon", "armor", "trinket" })
    local names = { weapon = { "Scarlet Monotony Mace", "Deadmines Pickaxe", "Ratchet's Wrench" }, armor = { "Robes of the Monotonous", "Gnomeregan Hand-me-downs", "Smoky Jerkin" },
      trinket = { "Lucky Coin", "Murloc Fin Charm", "Bent Spoon of Insight" } }
    local it = { name = pick(st, names[slot]), slot = slot, lvl = rrange(st, D.itemLvl[1], D.itemLvl[2]), q = "rare", from = "Dungeon" }
    if slot == "armor" then it.type = pick(st, { "plate", "mail", "leather", "cloth" }) end
    it.eligible = {}
    for i = 1, #st.roster do it.eligible[i] = st.roster[i].id end
    it.assign = suggest(st, it, it.eligible)
    out.item = it
    st.pending[#st.pending + 1] = it
  end
  return out
end
function G.Hire(st, i)
  local o = st.tavern[i]
  if not o then return "Gone." end
  if #st.roster >= G.ECON.rosterMax then return "Roster full (15). Dismiss someone first." end
  if st.gold < o.price then return "Not enough gold." end
  st.gold = st.gold - o.price; o.joined = st.week; o.price = nil
  st.roster[#st.roster + 1] = o
  table.remove(st.tavern, i)
  return o.name .. " joins the guild."
end
function G.Reroll(st)
  local cost = G.ECON.reroll * (2 ^ st.rerolls)
  cost = floor(cost)
  if st.gold < cost then return "Not enough gold." end
  st.gold = st.gold - cost; st.rerolls = st.rerolls + 1
  rollTavern(st)
  return "New faces at the Tavern."
end
function G.RerollCost(st) return floor(G.ECON.reroll * (2 ^ st.rerolls)) end
function G.Dismiss(st, id)
  local c = byId(st, id)
  if not c then return "" end
  st.gold = st.gold + round(G.RARITY[c.rarity].cost * G.ECON.dismissBack / 100)
  dismissFree(st, id)
  return c.name .. " leaves the guild, and takes every friendship with them."
end
function G.BuyFire(st, id)
  local c = byId(st, id)
  if c.fire >= 2 then return "Two pieces is the limit." end
  if st.gold < G.ECON.fireGear then return "Not enough gold." end
  st.gold = st.gold - G.ECON.fireGear; c.fire = c.fire + 1
  return c.name .. " gets a Fire Whelp piece (" .. c.fire .. " of 2)."
end
function G.Respec(st, id, spec)
  local c = byId(st, id)
  if st.gold < G.ECON.respec then return "Not enough gold." end
  st.gold = st.gold - G.ECON.respec; c.spec = spec
  return c.name .. " is now " .. G.specName(c.cls, spec) .. " (" .. G.ECON.respec .. " gold)."
end

function G.EndWeek(st)
  if st.score.kills > 0 or st.score.wipes > 0 then st.bestScore = math.max(st.bestScore, G.heroicScore(st)) end
  st.week = st.week + 1; st.gold = st.gold + G.ECON.weeklyQuests; st.dungeonsLeft = G.ECON.dungeon.perWeek; st.rerolls = 0
  st.buffs = {}; st.freeWipe = {}
  local quits = {}
  local snapshot = {}
  for i = 1, #st.roster do snapshot[i] = st.roster[i] end
  for _, c in ipairs(snapshot) do
    if c.morale < G.MORALE.low and rint(st, 100) <= 50 then
      quits[#quits + 1] = c.name; dismissFree(st, c.id)
    elseif c.morale > G.MORALE.start then c.morale = c.morale - math.min(G.MORALE.drift, c.morale - G.MORALE.start)
    else c.morale = c.morale + math.min(G.MORALE.drift, G.MORALE.start - c.morale) end
  end
  for _, c in ipairs(st.roster) do c.benched = false; c.pulls = {}; c.looted = false end
  for _, e in pairs(st.bonds) do e.week = 0 end
  for _, b in ipairs(G.BOSSES) do local p = st.progress[b.id] p.normalWeek = false; p.heroicWeek = false; p.heroicWipes = 0 end
  st.score = { kills = 0, wipes = 0, rounds = 0 }
  rollTavern(st)
  local msg = "Week " .. st.week .. ". Lockouts reset, benched raiders are back, +" .. G.ECON.weeklyQuests .. " gold from the week's quests."
  if #quits > 0 then msg = msg .. " Morale got too low: " .. table.concat(quits, " and ") .. " left the guild." end
  st.news[#st.news + 1] = msg
  while #st.news > 20 do table.remove(st.news, 1) end
  return msg
end

-- ---------------------------------------------------------------- JSON (for the playtest page and tests)
local function isArray(t)
  local n = #t
  if n == 0 then return next(t) == nil end
  local c = 0
  for _ in pairs(t) do c = c + 1 end
  return c == n
end
local function esc(s)
  if not string.find(s, "[%z\1-\31\\\"]") then return "\"" .. s .. "\"" end
  s = string.gsub(s, "\\", "\\\\"); s = string.gsub(s, "\"", "\\\""); s = string.gsub(s, "\n", "\\n")
  s = string.gsub(s, "[%z\1-\31]", function(ch) return string.format("\\u%04x", string.byte(ch)) end)
  return "\"" .. s .. "\""
end
local function enc(v)
  local t = type(v)
  if t == "table" then
    local parts = {}
    if isArray(v) then
      for i = 1, #v do parts[i] = enc(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, val in pairs(v) do  -- key order is whatever pairs gives: JSON objects are unordered
      if type(val) ~= "function" then parts[#parts + 1] = esc(type(k) == "number" and string.format("%d", k) or tostring(k)) .. ":" .. enc(val) end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "string" then return esc(v)
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "0" end
    if v == floor(v) and v > -1e15 and v < 1e15 then return string.format("%d", v) end
    return string.format("%.6g", v)
  elseif t == "boolean" then return v and "true" or "false" end
  return "null"
end
function G.ToJSON(v) return enc(v) end
-- Data the page needs (no functions).
function G.Static()
  local journalAnswers = {}
  for boss, list in pairs(G.LESSONS) do
    journalAnswers[boss] = {}
    for i = 1, #list do journalAnswers[boss][list[i].id] = list[i].t[3] end
  end
  return { SPECS = G.SPECS, CLASS_NAMES = G.CLASS_NAMES, ARMOR = G.ARMOR, RARITY = G.RARITY, ECON = G.ECON, MODES = G.MODES, CARDS = G.CARDS,
    CARD_ORDER = G.CARD_ORDER, CARD_TEXT = G.CARD_TEXT, WB = G.WB, WB_ORDER = G.WB_ORDER, TRAITS = G.TRAITS, MORALE = G.MORALE,
    BOSSES = G.BOSSES, ANSWERS = journalAnswers }
end

return G
