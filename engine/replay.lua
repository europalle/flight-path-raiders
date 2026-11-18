-- Flight Path Raiders: replay records. A record is a fight's input plus the result it gave, packed into
-- a short string that saves keep and players can send each other. Logs are never stored: playback rebuilds
-- them by running the input again, and the checksum proves the rebuild matches (design doc 6.1).
--
-- Format, version 1:   FPR1|<engine>|<boss>,<mode>,<tactic>,<seed>,<gl>,<cons>,<buffs>|<raid>|<pairs>|<result>
--   raid:   characters joined by "/", each  name,class,spec,zone,flags,firegear,skill,fam,gl,morale,traits
--   pairs:  a.b.v joined by "/"           result: k|w|e (kill, wipe, enrage), rounds, checksum
-- Numbers are base 36. Classes, specs, tactics and traits are indexes into the engine's own sorted
-- tables, which is why a record names its engine version: a record from another engine can be read but
-- not verified. Names escape % | / , . with %XX.
-- Chunks for addon messages: FPRc:<id>:<part>:<of>:<data>, at most 250 bytes each.
local _, ns = ...
if not ns then ns = FPR_ENGINE or {}; FPR_ENGINE = ns end
local R = {}
ns.Replay = R
R.VERSION = 1
R.CHUNK = 220

local floor = math.floor
local DIG = "0123456789abcdefghijklmnopqrstuvwxyz"
local function b36(n)
  if type(n) ~= "number" or n ~= floor(n) or n < 0 then error("FPR: replay numbers must be whole and not negative", 0) end
  if n == 0 then return "0" end
  local s = ""
  while n > 0 do local d = n % 36; s = string.sub(DIG, d + 1, d + 1) .. s; n = floor(n / 36) end
  return s
end
local function n36(s) local v = tonumber(s, 36); if not v then error("FPR: bad number in record", 0) end return v end
-- Optional fields keep "not set" apart from 0, so a rebuilt input is the same input, not just an equivalent one.
local function o36(n) if n == nil then return "" end return b36(n) end
local function on36(s) if s == nil or s == "" then return nil end return n36(s) end
local function esc(s) return (string.gsub(s, "[%%|/,%.]", function(c) return string.format("%%%02X", string.byte(c)) end)) end
local function unesc(s) return (string.gsub(s, "%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end
local function split(s, sep)
  local out, start = {}, 1
  if s == "" then return out end
  while true do
    local i = string.find(s, sep, start, true)
    if not i then out[#out + 1] = string.sub(s, start); return out end
    out[#out + 1] = string.sub(s, start, i - 1); start = i + 1
  end
end
local function sortedKeys(t) local k = {} for key in pairs(t) do k[#k + 1] = key end table.sort(k) return k end
local function index(list) local m = {} for i = 1, #list do m[list[i]] = i - 1 end return m end
local function tables()
  local D = ns.Data
  local T = { classes = sortedKeys(D.CLASSES), tactics = sortedKeys(D.TACTICS), traits = sortedKeys(D.TRAITS), bosses = sortedKeys(D.BOSSES), modes = sortedKeys(D.MODES), specs = {} }
  for _, c in ipairs(T.classes) do T.specs[c] = sortedKeys(D.SPECS[c]) end
  T.zones = D.ZONES
  return T
end
local CONS = { "food", "elixirs", "flasks" }
local BUFFS = { "dragonslayer", "songbloom", "warchief" }
local function bits(t, names) local v = 0 for i = 1, #names do if t and t[names[i]] then v = v + 2 ^ (i - 1) end end return floor(v) end
local function unbits(v, names) local t = {} for i = 1, #names do t[names[i]] = floor(v / 2 ^ (i - 1)) % 2 == 1 end return t end

-- input: the fight input (frames and trace are ignored). result: what ns.Simulate returned (optional).
function R.Encode(input, result)
  local T = tables()
  local ci, ti, tri, bi, mi, zi = index(T.classes), index(T.tactics), index(T.traits), index(T.bosses), index(T.modes), index(T.zones)
  local head = table.concat({ b36(bi[input.boss]), b36(mi[input.mode]), b36(ti[input.tactic]), b36(input.seed), b36(input.gl or 60),
    b36(bits(input.consumables, CONS)), b36(bits(input.buffs, BUFFS)), input.moments == false and "0" or "" }, ",")
  local raid = {}
  for i, c in ipairs(input.raid) do
    local tr = {}
    for k, t in ipairs(c.traits or {}) do tr[k] = b36(tri[t]) end
    local flags = ((c.potion or c.fireres) and 1 or 0) + (c.new and 2 or 0) + (c.looted and 4 or 0) + (c.traits and 8 or 0)
    raid[i] = table.concat({ esc(c.name or ("Raider " .. i)), b36(ci[c.class]), b36(index(T.specs[c.class])[c.spec]), b36(zi[c.zone] or 0), b36(flags),
      o36(c.firegear), o36(c.skill), o36(c.fam), o36(c.gl), o36(c.morale), table.concat(tr, ".") }, ",")
  end
  local pr = {}
  for i, e in ipairs(input.pairs or {}) do pr[i] = b36(e.a) .. "." .. b36(e.b) .. "." .. b36(e.v) end
  local res = ""
  if result then res = ({ kill = "k", wipe = "w", enrage = "e" })[result.result] .. "," .. b36(result.rounds) .. "," .. b36(result.checksum) end
  return "FPR" .. R.VERSION .. "|" .. b36(result and result.engine or ns.ENGINE_VERSION) .. "|" .. head .. "|" .. table.concat(raid, "/") .. "|" .. table.concat(pr, "/") .. "|" .. res
end

-- Returns rec ({ input, engine, result = { result, rounds, checksum } }) or nil, why.
-- A record from another engine version decodes (rec is returned third) but cannot be verified here.
function R.Decode(s)
  if type(s) ~= "string" then return nil, "not a record" end
  local ver = string.match(s, "^FPR(%d+)|")
  if not ver then return nil, "not a Flight Path Raiders record" end
  if tonumber(ver) ~= R.VERSION then return nil, "record format " .. ver .. " is not supported by this version of the addon (it reads format " .. R.VERSION .. ")" end
  local ok, rec = pcall(function()
    local T = tables()
    local f = split(s, "|")
    if #f ~= 6 then error("FPR: a record has 6 parts", 0) end
    local h = split(f[3], ",")
    local input = { boss = T.bosses[n36(h[1]) + 1], mode = T.modes[n36(h[2]) + 1], tactic = T.tactics[n36(h[3]) + 1], seed = n36(h[4]), gl = n36(h[5]),
      consumables = unbits(n36(h[6]), CONS), buffs = unbits(n36(h[7]), BUFFS), raid = {}, pairs = {} }
    if h[8] == "0" then input.moments = false end
    for i, e in ipairs(split(f[4], "/")) do
      local c = split(e, ",")
      local cls = T.classes[n36(c[2]) + 1]
      local flags = n36(c[5])
      local traits = nil
      if floor(flags / 8) % 2 == 1 then
        traits = {}
        for _, t in ipairs(split(c[11] or "", ".")) do traits[#traits + 1] = T.traits[n36(t) + 1] end
      end
      input.raid[i] = { name = unesc(c[1]), class = cls, spec = cls and T.specs[cls][n36(c[3]) + 1], zone = T.zones[n36(c[4]) + 1],
        potion = flags % 2 == 1, new = floor(flags / 2) % 2 == 1, looted = floor(flags / 4) % 2 == 1,
        firegear = on36(c[6]), skill = on36(c[7]), fam = on36(c[8]), gl = on36(c[9]), morale = on36(c[10]), traits = traits }
    end
    for i, e in ipairs(split(f[5], "/")) do local p = split(e, "."); input.pairs[i] = { a = n36(p[1]), b = n36(p[2]), v = n36(p[3]) } end
    local result
    if f[6] ~= "" then
      local r = split(f[6], ",")
      result = { result = ({ k = "kill", w = "wipe", e = "enrage" })[r[1]], rounds = n36(r[2]), checksum = n36(r[3]) }
    end
    return { input = input, engine = n36(f[2]), result = result }
  end)
  if not ok then return nil, "damaged record: " .. tostring(rec) end
  if rec.engine ~= ns.ENGINE_VERSION then
    return nil, "made with engine " .. rec.engine .. "; this client runs engine " .. ns.ENGINE_VERSION .. ", so it can't be checked here", rec
  end
  return rec
end

-- Decodes, runs the fight again and compares. Returns the rebuilt result (with frames when asked) or nil, why.
function R.Verify(s, withFrames)
  local rec, why = R.Decode(s)
  if not rec then return nil, why end
  local input = rec.input
  if withFrames then input.frames = {} end
  local r, err = ns.Verify(input)
  if not r then return nil, err end
  if rec.result and (r.checksum ~= rec.result.checksum or r.result ~= rec.result.result or r.rounds ~= rec.result.rounds) then
    return nil, "the fight does not match its record (checksum " .. r.checksum .. ", record says " .. rec.result.checksum .. ")"
  end
  return r, input
end

-- Chunks for addon messages, and an assembler that takes them in any order, with repeats.
local function hash(s)
  local h = 5381.0  -- floats: Fengari's integers are 32-bit
  for i = 1, #s do h = (h * 33.0 + string.byte(s, i)) % 2147483647 end
  return floor(h)
end
function R.Chunk(s)
  local id = b36(hash(s))
  local n = math.max(1, math.ceil(#s / R.CHUNK))
  local out = {}
  for i = 1, n do out[i] = "FPRc:" .. id .. ":" .. b36(i) .. ":" .. b36(n) .. ":" .. string.sub(s, (i - 1) * R.CHUNK + 1, i * R.CHUNK) end
  return out
end
function R.Assembler()
  local parts, done = {}, {}
  return function(msg)
    local id, i, n, data = string.match(msg, "^FPRc:(%w+):(%w+):(%w+):(.*)$")
    if not id or done[id] then return nil end  -- repeats of a record already delivered are dropped
    i, n = n36(i), n36(n)
    local p = parts[id]
    if not p then p = { n = n, have = 0 }; parts[id] = p end
    if not p[i] then p[i] = data; p.have = p.have + 1 end
    if p.have == p.n then
      local s = table.concat(p, "", 1, p.n)
      parts[id] = nil
      if b36(hash(s)) ~= id then return nil, "chunks did not add up" end
      done[id] = true
      return s
    end
  end
end
