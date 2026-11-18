-- Golden fight inputs, shared by every runtime.
local _, ns = ...
ns = ns or FPR_ENGINE or {}
FPR_ENGINE = ns
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
ns.Fixtures = {
  { boss="ragnaroast", mode="normal", seed=12345, tactic="spread", gl=60, raid=standard, consumables={food=true}, buffs={} },
  { boss="ragnaroast", mode="heroic", seed=777, tactic="stack", gl=65, raid=standard, consumables={food=true,elixirs=true}, buffs={dragonslayer=true} },
  { boss="ragnaroast", mode="mythic", seed=42, tactic="burn", gl=74, raid=standard, consumables={food=true,elixirs=true,flasks=true}, buffs={songbloom=true,warchief=true} },
  { boss="ragnaroast", mode="normal", seed=2026, tactic="playsafe", gl=60, raid=standard, consumables={}, buffs={} },
}
