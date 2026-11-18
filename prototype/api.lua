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
      ',"alive":' .. (p.alive and 'true' or 'false') .. ',"role":' .. esc(p.role) .. ',"mana":' .. num(p.mana) .. '}'
  end
  return '{"result":' .. esc(r.result) .. ',"rounds":' .. num(r.rounds) .. ',"checksum":' .. num(r.checksum) ..
    ',"engine":' .. num(r.engine) .. ',"bossHp":' .. num(r.boss_hp) .. ',"bossMax":' .. num(r.boss_maxhp) ..
    ',"survivors":' .. num(r.survivors) .. ',"events":[' .. table.concat(ev, ',') .. '],"raid":[' .. table.concat(raid, ',') .. ']}'
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
