-- Replay record tests (engine/replay.lua). Every runtime must print the same lines, and none may say FAIL.
-- Round trips on every golden fight and 300 random fights; chunked loopback sync with shuffled and repeated
-- chunks; damaged records, another engine version and another record format; awkward names.
local ns = FPR_ENGINE
local R = ns.Replay
local out, fails = {}, 0
local function check(name, ok) out[#out + 1] = (ok and "ok   " or "FAIL ") .. name; if not ok then fails = fails + 1 end end
local function fight(input) local c = {} for k, v in pairs(input) do c[k] = v end c.frames = nil; c.trace = nil; return ns.Simulate(c) end

-- 1. Round trips: the decoded input gives the same fight, and the record verifies.
local inputs = {}
for i = 1, #ns.Fixtures do inputs[#inputs + 1] = ns.Fixtures[i] end
local gen = ns.NewRNG(4242)
local classes = { warrior = { "arms", "fury", "protection" }, paladin = { "holy", "protection", "retribution" }, hunter = { "beastmastery", "marksmanship", "survival" },
  rogue = { "assassination", "combat", "subtlety" }, priest = { "discipline", "holy", "shadow" }, shaman = { "elemental", "enhancement", "restoration" },
  mage = { "arcane", "fire", "frost" }, warlock = { "affliction", "demonology", "destruction" }, druid = { "balance", "feral", "feralcat", "restoration" } }
local cl = { "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" }
local bosses = { "magmadad", "baron", "lucifrown", "majordomo", "ragnaroast" }
local tactics = { "spread", "stack", "burn", "playsafe" }
local traitIds = {}
for k in pairs(ns.Data.TRAITS) do traitIds[#traitIds + 1] = k end
table.sort(traitIds)
for n = 1, 300 do
  local raid = {}
  for i = 1, gen:int(10) do
    local c = cl[gen:int(#cl)]
    local sp = classes[c][gen:int(#classes[c])]
    local tr = {}
    for _ = 1, gen:int(3) - 1 do tr[#tr + 1] = traitIds[gen:int(#traitIds)] end
    if #tr == 2 and tr[1] == tr[2] then tr[2] = nil end
    raid[i] = { name = "R" .. n .. "-" .. i, class = c, spec = sp, zone = ns.Data.ZONES[gen:int(4)], potion = gen:int(2) == 1, skill = gen:int(101) - 1,
      fam = gen:int(11) - 1, gl = 59 + gen:int(12), firegear = gen:int(3) - 1, morale = gen:int(101) - 1, traits = tr, new = gen:int(2) == 1 }
  end
  local pairs_ = {}
  if #raid >= 2 then pairs_[1] = { a = 1, b = 2, v = gen:int(20) } end
  inputs[#inputs + 1] = { boss = bosses[gen:int(5)], mode = gen:int(2) == 1 and "normal" or "heroic", seed = gen:int(2147483646), tactic = tactics[gen:int(4)],
    gl = 60 + gen:int(10), consumables = { food = gen:int(2) == 1, elixirs = gen:int(2) == 1 }, buffs = { songbloom = gen:int(2) == 1 }, raid = raid, pairs = pairs_ }
end
local trips, sizes, maxsize = 0, 0, 0
for i, input in ipairs(inputs) do
  local r = fight(input)
  local s = R.Encode(input, r)
  sizes = sizes + #s; if #s > maxsize then maxsize = #s end
  local rec, why = R.Decode(s)
  if rec then
    local r2 = fight(rec.input)
    if r2.checksum == r.checksum and r2.result == r.result and r2.rounds == r.rounds and R.Encode(rec.input, r2) == s then trips = trips + 1
    else out[#out + 1] = "  round trip " .. i .. " differs: " .. r.checksum .. " vs " .. r2.checksum end
  else out[#out + 1] = "  round trip " .. i .. ": " .. tostring(why) end
end
check("round trips: " .. trips .. " of " .. #inputs .. " records rebuild the same fight", trips == #inputs)
out[#out + 1] = "     record size: average " .. math.floor(sizes / #inputs) .. " bytes, largest " .. maxsize

-- 2. Verify: a good record passes (heroic records need inputs inside the gear band, so use normal ones).
local good = R.Encode(ns.Fixtures[1], fight(ns.Fixtures[1]))
local v, why = R.Verify(good, true)
check("a good record verifies, and playback frames are rebuilt", v ~= nil and #v.events > 0 and why and #why.frames == v.rounds)

-- 3. Chunked loopback sync: shuffled, with repeats, two records interleaved.
local s1 = R.Encode(inputs[20], fight(inputs[20]))
local s2 = R.Encode(inputs[21], fight(inputs[21]))
local c1, c2 = R.Chunk(s1), R.Chunk(s2)
local all = {}
for _, c in ipairs(c1) do all[#all + 1] = c end
for _, c in ipairs(c2) do all[#all + 1] = c end
all[#all + 1] = c1[1]; all[#all + 1] = c2[#c2]
local mix = ns.NewRNG(7)
for i = #all, 2, -1 do local j = mix:int(i); all[i], all[j] = all[j], all[i] end
local feed = R.Assembler()
local got = {}
for _, msg in ipairs(all) do local s = feed(msg); if s then got[#got + 1] = s end end
local okLen = true
for _, c in ipairs(c1) do if #c > 255 then okLen = false end end
check("chunks fit an addon message (255 bytes)", okLen)
check("loopback sync: both records arrive whole, once each, in any order", #got == 2 and ((got[1] == s1 and got[2] == s2) or (got[1] == s2 and got[2] == s1)))

-- 4. Bad input never crashes.
local damaged = string.sub(good, 1, 40) .. "zz|" .. string.sub(good, 44)
local d1, w1 = R.Decode(damaged)
check("a damaged record is refused with a reason", d1 == nil and type(w1) == "string")
local tampered = string.gsub(good, ",(%w+)$", function(c) return "," .. c .. "1" end)
local t1, w2 = R.Verify(tampered)
check("a record whose result was edited fails verification", t1 == nil and string.find(w2, "does not match", 1, true) ~= nil)
local other = string.gsub(good, "^FPR1|%w+|", "FPR1|zz|")
local o1, w3, orec = R.Decode(other)
check("a record from another engine version says so, and still reads", o1 == nil and string.find(w3, "made with engine", 1, true) ~= nil and orec and orec.input.boss == ns.Fixtures[1].boss)
local f1, w4 = R.Decode(string.gsub(good, "^FPR1", "FPR9"))
check("another record format is refused politely", f1 == nil and string.find(w4, "format 9", 1, true) ~= nil)
check("junk is refused", R.Decode("hello") == nil and R.Decode(nil) == nil and R.Decode("FPR1|") == nil)

-- 5. Names with the separators in them survive.
local odd = {}
for k, v in pairs(ns.Fixtures[1]) do odd[k] = v end
odd.raid = {}
for i, c in ipairs(ns.Fixtures[1].raid) do odd.raid[i] = { name = "Mr. 100%|/" .. i .. ",ok", class = c.class, spec = c.spec, zone = c.zone } end
local ro = R.Decode(R.Encode(odd, fight(odd)))
check("names with . , | / % in them come back exactly", ro and ro.input.raid[1].name == "Mr. 100%|/1,ok")

out[#out + 1] = fails == 0 and "replay: all passed" or ("replay: " .. fails .. " failed")
return table.concat(out, "\n")
