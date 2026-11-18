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
    raid[i] = { name = "C" .. i, class = c, spec = s, zone = z, fireres = gen:int(3) == 1, firegear = gen:int(3) - 1,
      skill = gen:int(121) - 11, fam = gen:int(14) - 2 }  -- out-of-range values check the clamps
  end
  local pl = {}
  for k = 1, gen:int(12) - 1 do pl[#pl + 1] = { a = gen:int(10), b = gen:int(10), v = gen:int(25) - 2 } end
  local r = ns.Simulate({ pairs = pl, moments = gen:int(5) ~= 1, boss = "ragnaroast", mode = modes[gen:int(3)], seed = gen:next(),
    tactic = tactics[gen:int(4)], gl = 59 + gen:int(20),
    consumables = { food = gen:int(2) == 1, elixirs = gen:int(2) == 1, flasks = gen:int(2) == 1 },
    buffs = { dragonslayer = gen:int(3) == 1, songbloom = gen:int(3) == 1, warchief = gen:int(3) == 1 },
    raid = raid })
  acc = (acc * 31.0 + r.checksum) % 2147483647
  if r.result == "kill" then kills = kills + 1 end
end
-- A 12-week guild campaign through engine/progress.lua: recruits, bench, a quit, weekly reset.
local P = ns.Progress
if P then
  local g = P.NewGuild()
  local rar = { "common", "uncommon", "rare", "epic" }
  for i = 1, 13 do P.Recruit(g, rar[gen:int(4)]) end
  local base = {}
  for i = 1, 10 do local cl = classes[gen:int(9)]; base[i] = { class = cl, spec = specs[cl][gen:int(#specs[cl])] } end
  for w = 1, 12 do
    if w == 6 then P.Quit(g, g.members[gen:int(#g.members)].id); P.Recruit(g, "rare") end
    for pull = 1, 5 do
      local ids = {}
      local start = gen:int(#g.members - 9)
      for i = 1, 10 do ids[i] = g.members[start + i - 1].id end
      local f, pl = P.RaidFields(g, ids, "ragnaroast")
      local raid = {}
      for i = 1, 10 do
        local role = D.SPECS[base[i].class][base[i].spec]
        raid[i] = { name = "G" .. i, class = base[i].class, spec = base[i].spec,
          zone = zone_for[role] or "ranged", skill = f[i].skill, fam = f[i].fam }
      end
      local r = ns.Simulate({ boss = "ragnaroast", mode = "heroic", seed = gen:next(), tactic = "spread", gl = 65,
        consumables = { food = true }, buffs = {}, raid = raid, pairs = pl })
      acc = (acc * 31.0 + r.checksum) % 2147483647
      P.AfterPull(g, ids, "ragnaroast", r.result == "kill")
    end
    P.NewWeek(g)
  end
  for i = 1, #g.members do
    local m = g.members[i]
    acc = (acc * 31.0 + m.skill10 * 7 + (m.fam10.ragnaroast or 0)) % 2147483647
  end
end
return N .. " fights, " .. kills .. " kills, combined checksum " .. math.floor(acc)
