-- Generates many random fights from the engine's own RNG (so every runtime builds identical
-- inputs) and folds every checksum into one number. Both runtimes must print the same line.
local ns = FPR_ENGINE
local D = ns.Data
local N = FPR_FUZZ_N or 2000
local gen = ns.NewRNG(99991)
local classes = { "warrior","paladin","hunter","rogue","priest","shaman","mage","warlock","druid" }
local specs = {}
for i = 1, #classes do
  local c = classes[i]
  local list = {}
  -- fixed order per class so every runtime walks the same list
  local order = {
    warrior={"arms","fury","protection"}, paladin={"holy","protection","retribution"},
    hunter={"beastmastery","marksmanship","survival"}, rogue={"assassination","combat","subtlety"},
    priest={"holy","discipline","shadow"}, shaman={"elemental","enhancement","restoration"},
    mage={"arcane","fire","frost"}, warlock={"affliction","demonology","destruction"},
    druid={"balance","feral","restoration","feralcat"} }
  specs[c] = order[c]
end
local tactics = { "spread","stack","burn","playsafe" }
local modes = { "normal","heroic","mythic" }
local zone_for = { tank="front", healer="back" }
local acc, kills = 7.0, 0
for f = 1, N do
  local raid = {}
  for i = 1, 10 do
    local c = classes[gen:int(9)]
    local s = specs[c][gen:int(#specs[c])]
    local role = D.SPECS[c][s]
    local z = zone_for[role] or ((gen:int(2) == 1) and "melee" or "ranged")
    raid[i] = { name = "C" .. i, class = c, spec = s, zone = z, fireres = gen:int(3) == 1, firegear = gen:int(3) - 1 }
  end
  local r = ns.Simulate({ boss = "ragnaroast", mode = modes[gen:int(3)], seed = gen:next(),
    tactic = tactics[gen:int(4)], gl = 59 + gen:int(20),
    consumables = { food = gen:int(2) == 1, elixirs = gen:int(2) == 1, flasks = gen:int(2) == 1 },
    buffs = { dragonslayer = gen:int(3) == 1, songbloom = gen:int(3) == 1, warchief = gen:int(3) == 1 },
    raid = raid })
  acc = (acc * 31.0 + r.checksum) % 2147483647
  if r.result == "kill" then kills = kills + 1 end
end
return N .. " fights, " .. kills .. " kills, combined checksum " .. math.floor(acc)
