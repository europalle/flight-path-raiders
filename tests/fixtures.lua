-- Golden fight inputs, shared by every runtime.
local _, ns = ...
if not ns then ns = FPR_ENGINE or {}; FPR_ENGINE = ns end  -- in WoW the addon's private table; in tests a global
local function raid(list)
  local r = {}
  for i = 1, #list do
    local e = list[i]
    r[i] = { name = e[1], class = e[2], spec = e[3], zone = e[4], fireres = e[5] }
  end
  return r
end
local standard = raid({
  {"Brannoc","warrior","protection","front",true},{"Mira","paladin","protection","front",false},
  {"Kess","rogue","combat","melee",true},{"Tor","warrior","fury","melee",true},
  {"Ash","shaman","enhancement","melee",false},{"Lumi","mage","frost","ranged",false},
  {"Orrin","hunter","marksmanship","ranged",false},{"Mortis","warlock","affliction","ranged",false},
  {"Sela","priest","holy","back",false},{"Bram","druid","restoration","back",false},
})
local veteran = {}
for i = 1, #standard do
  local c = standard[i]
  veteran[i] = { name = c.name, class = c.class, spec = c.spec, zone = c.zone, fireres = c.fireres,
    skill = 40 + i * 5, fam = i - 1, gl = 55 + i * 2, firegear = (c.zone == "melee") and 2 or 0 }
end
local TRAIT_SETS = { {"pulls_on_cooldown"}, {"hardcore_andy"}, {"needs_on_everything","alt_tabbed"}, {"parse_goblin"}, {"stands_in_fire","main_character"},
  {"never_stands_in_fire"}, {"pet_on_aggressive","keyboard_turner"}, {"partner_aggro","pug_hero"}, {"raid_leaders_favourite"}, {"backseat_raid_leader","rage_quitter"} }
local quirky = {}
for i = 1, #standard do
  local c = standard[i]
  quirky[i] = { name = c.name, class = c.class, spec = c.spec, zone = c.zone, fireres = c.fireres, skill = 50, fam = 4,
    traits = TRAIT_SETS[i], morale = 50 + i * 4, new = i > 8, looted = i == 5 }
end
local bonds = {}
for a = 1, 10 do for b = a + 1, 10 do bonds[#bonds + 1] = { a = a, b = b, v = (a * 7 + b * 3) % 21 } end end
ns.Fixtures = {
  { boss="ragnaroast", mode="normal", seed=12345, tactic="spread", gl=60, raid=standard, consumables={food=true}, buffs={} },
  { boss="ragnaroast", mode="heroic", seed=777, tactic="stack", gl=65, raid=standard, consumables={food=true,elixirs=true}, buffs={dragonslayer=true} },
  { boss="ragnaroast", mode="mythic", seed=42, tactic="burn", gl=74, raid=standard, consumables={food=true,elixirs=true,flasks=true}, buffs={songbloom=true,warchief=true} },
  { boss="ragnaroast", mode="normal", seed=2026, tactic="playsafe", gl=60, raid=standard, consumables={}, buffs={} },
  { boss="magmadad", mode="heroic", seed=101, tactic="burn", gl=65, raid=standard, consumables={food=true,elixirs=true,flasks=true}, buffs={} },
  { boss="magmadad", mode="normal", seed=102, tactic="playsafe", gl=60, raid=standard, consumables={}, buffs={} },
  { boss="baron", mode="heroic", seed=201, tactic="spread", gl=65, raid=standard, consumables={food=true,elixirs=true,flasks=true}, buffs={} },
  { boss="baron", mode="heroic", seed=202, tactic="stack", gl=65, raid=standard, consumables={food=true,elixirs=true,flasks=true}, buffs={} },
  { boss="lucifrown", mode="heroic", seed=301, tactic="playsafe", gl=65, raid=standard, consumables={food=true,elixirs=true,flasks=true}, buffs={} },
  { boss="lucifrown", mode="normal", seed=302, tactic="stack", gl=60, raid=standard, consumables={food=true}, buffs={} },
  { boss="majordomo", mode="heroic", seed=401, tactic="stack", gl=65, raid=standard, consumables={food=true,elixirs=true,flasks=true}, buffs={} },
  { boss="majordomo", mode="mythic", seed=402, tactic="spread", gl=74, raid=standard, consumables={food=true,elixirs=true,flasks=true}, buffs={dragonslayer=true} },
  -- With progression inputs (gate review): skill, familiarity, chemistry, per-character gear, fire gear, moments.
  { boss="ragnaroast", mode="normal", seed=503, tactic="burn", gl=60, raid=veteran, consumables={food=true,elixirs=true}, buffs={}, pairs=bonds },
  { boss="baron", mode="heroic", seed=504, tactic="spread", gl=65, raid=veteran, consumables={food=true,elixirs=true,flasks=true}, buffs={songbloom=true}, pairs=bonds },
  -- With traits and morale (engine 10).
  { boss="magmadad", mode="normal", seed=601, tactic="burn", gl=60, raid=quirky, consumables={food=true}, buffs={}, pairs=bonds },
  { boss="ragnaroast", mode="heroic", seed=602, tactic="burn", gl=65, raid=quirky, consumables={food=true,elixirs=true,flasks=true}, buffs={}, pairs=bonds },
  { boss="majordomo", mode="normal", seed=603, tactic="stack", gl=60, raid=quirky, consumables={}, buffs={} },
  { boss="lucifrown", mode="mythic", seed=505, tactic="playsafe", gl=74, raid=veteran, consumables={food=true,elixirs=true,flasks=true}, buffs={dragonslayer=true,warchief=true}, pairs=bonds },
}
