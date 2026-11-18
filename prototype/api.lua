-- Prototype bridge: runs fights and returns JSON strings for the browser page.
local _, ns = ...
ns = ns or FPR_ENGINE or {}
FPR_ENGINE = ns
local API = {}
FPR_API = API

local function esc(s)
  s = string.gsub(s, '\\', '\\\\')
  s = string.gsub(s, '"', '\\"')
  s = string.gsub(s, '\n', '\\n')
  return '"' .. s .. '"'
end
local function num(n) return string.format("%d", n) end

-- Playback frames (inputs.frames = {}): boss health, away flag, adds alive and raid health per round.
local function frames_json(frames)
  if not frames then return "" end
  local out = {}
  for i = 1, #frames do
    local f = frames[i]
    local hp = {}
    for j = 1, #f.hp do hp[j] = num(f.hp[j]) end
    out[i] = '{"b":' .. num(f.boss) .. ',"w":' .. (f.away and 'true' or 'false') .. ',"a":' .. num(f.adds) .. ',"h":[' .. table.concat(hp, ',') .. ']}'
  end
  return ',"frames":[' .. table.concat(out, ',') .. ']'
end

function API.Run(input)
  local r = ns.Simulate(input)
  local ev = {}
  for i = 1, #r.events do
    local e = r.events[i]
    ev[#ev + 1] = '{"r":' .. num(e.round) .. ',"c":' .. num(e.code) .. ',"a":' .. num(e.a) .. ',"b":' .. num(e.b) .. ',"t":' .. esc(e.text) .. '}'
  end
  local raid = {}
  for i = 1, #r.raid do
    local p = r.raid[i]
    raid[#raid + 1] = '{"name":' .. esc(p.name) .. ',"hp":' .. num(p.hp) .. ',"maxhp":' .. num(p.maxhp) ..
      ',"alive":' .. (p.alive and 'true' or 'false') .. ',"role":' .. esc(p.role) .. ',"mana":' .. num(p.mana) ..
      ',"dealt":' .. num(p.dealt) .. ',"healed":' .. num(p.healed) .. '}'
  end
  return '{"result":' .. esc(r.result) .. ',"rounds":' .. num(r.rounds) .. ',"checksum":' .. num(r.checksum) ..
    ',"engine":' .. num(r.engine) .. ',"bossHp":' .. num(r.boss_hp) .. ',"bossMax":' .. num(r.boss_maxhp) ..
    ',"survivors":' .. num(r.survivors) .. ',"events":[' .. table.concat(ev, ',') .. '],"raid":[' .. table.concat(raid, ',') .. ']' ..
    frames_json(input.frames) .. '}'
end

-- Runs n fights of the same raid with seeds derived from base seed; returns a JSON summary.
function API.Batch(input, n, from)
  local kills, wipes, enrages, krounds, deaths, survivors = 0, 0, 0, 0, 0, 0
  local cause = { [23] = 0, [24] = 0, [25] = 0, [26] = 0 }
  local base = input.seed
  for i = from, from + n - 1 do
    input.seed = ns.Seed(base, i)
    local r = ns.Simulate(input)
    if r.result == "kill" then kills = kills + 1; krounds = krounds + r.rounds
    elseif r.result == "wipe" then wipes = wipes + 1 else enrages = enrages + 1 end
    survivors = survivors + r.survivors
    for k = 1, #r.events do
      local e = r.events[k]
      if e.code == 31 then
        deaths = deaths + 1
        if cause[e.b] then cause[e.b] = cause[e.b] + 1 end
      end
    end
  end
  input.seed = base
  return '{"n":' .. num(n) .. ',"kills":' .. num(kills) .. ',"wipes":' .. num(wipes) .. ',"enrages":' .. num(enrages) ..
    ',"killRounds":' .. num(krounds) .. ',"deaths":' .. num(deaths) .. ',"survivors":' .. num(survivors) ..
    ',"throw":' .. num(cause[23]) .. ',"melee":' .. num(cause[24]) .. ',"splash":' .. num(cause[25]) .. ',"adds":' .. num(cause[26]) .. '}'
end

-- Plays a season with this raid as a brand-new guild (everyone starts at skill 30, no history):
-- `pulls` pulls a week for `weeks` weeks through engine/progress.lua. Returns a JSON list per week:
-- kills, and the raid's average skill, familiarity and chemistry after the week (in tenths).
function API.Season(input, weeks, pulls)
  local P = ns.Progress
  local g = P.NewGuild()
  local ids = {}
  for i = 1, #input.raid do ids[i] = P.Recruit(g, "uncommon").id end
  local base = input.seed
  local out = {}
  for w = 1, weeks do
    local k, good, bad = 0, 0, 0
    for p = 1, pulls do
      local f, pl = P.RaidFields(g, ids, input.boss)
      for i = 1, #input.raid do input.raid[i].skill = f[i].skill; input.raid[i].fam = f[i].fam end
      input.pairs = pl
      input.seed = ns.Seed(base, w * 100 + p)
      local r = ns.Simulate(input)
      if r.result == "kill" then k = k + 1 end
      for e = 1, #r.events do
        local c = r.events[e].code
        if r.events[e].round == 0 then
          if c == 40 or c == 41 or c == 42 then good = good + 1 elseif c >= 43 and c <= 46 then bad = bad + 1 end
        end
      end
      P.AfterPull(g, ids, input.boss, r.result == "kill")
    end
    local sk, fam, chem, np = 0, 0, 0, 0
    for i = 1, #ids do
      local m = g.by_id[ids[i]]
      sk = sk + m.skill10; fam = fam + (m.fam10[input.boss] or 0)
      for j = i + 1, #ids do chem = chem + P.Bond(g, ids[i], ids[j]); np = np + 1 end
    end
    local n = #ids
    out[#out + 1] = '{"w":' .. num(w) .. ',"kills":' .. num(k) .. ',"good":' .. num(good) .. ',"bad":' .. num(bad) ..
      ',"skill":' .. num((sk - sk % n) / n) .. ',"fam":' .. num((fam - fam % n) / n) ..
      ',"chem":' .. num(np > 0 and (chem - chem % np) / np or 0) .. '}'
    P.NewWeek(g)
  end
  input.seed = base
  input.pairs = nil
  for i = 1, #input.raid do input.raid[i].skill = nil; input.raid[i].fam = nil end
  return "[" .. table.concat(out, ",") .. "]"
end
