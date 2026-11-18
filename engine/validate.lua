-- Flight Path Raiders: input checks for the combat engine (gate review, 2026-11-18).
-- Structural checks always run inside Simulate, so a malformed record can never crash a client:
-- unknown boss, mode, tactic, class, spec or zone, bad types, raids above 10. Strict mode adds the
-- range checks a ranked verifier needs (skill, familiarity, fire gear, chemistry pairs, gear band).
-- Verifiers call ns.Verify(record), which never throws.
local _, ns = ...
ns = ns or FPR_ENGINE or {}
FPR_ENGINE = ns

local function int(v) return type(v) == "number" and v == math.floor(v) end
local function in_range(v, lo, hi) return int(v) and v >= lo and v <= hi end

function ns.Validate(inputs, strict)
  local D = ns.Data
  if type(inputs) ~= "table" then return false, "inputs must be a table" end
  if not D.BOSSES[inputs.boss] then return false, "unknown boss" end
  if not D.MODES[inputs.mode] then return false, "unknown mode" end
  if not D.TACTICS[inputs.tactic] then return false, "unknown tactic" end
  if not in_range(inputs.seed, 1, 2147483646) then return false, "seed must be a whole number from 1 to 2147483646" end
  if inputs.gl ~= nil and not in_range(inputs.gl, 1, 100) then return false, "gear level must be 1-100" end
  local raid = inputs.raid
  if type(raid) ~= "table" or #raid < 1 or #raid > 10 then return false, "a raid has 1 to 10 characters" end
  local zones = {}
  for i = 1, #D.ZONES do zones[D.ZONES[i]] = true end
  for i = 1, #raid do
    local c = raid[i]
    if type(c) ~= "table" then return false, "character " .. i .. " is not a table" end
    if not D.CLASSES[c.class] then return false, "character " .. i .. ": unknown class" end
    if not D.SPECS[c.class][c.spec] then return false, "character " .. i .. ": unknown spec" end
    if not zones[c.zone] then return false, "character " .. i .. ": unknown zone" end
    if c.gl ~= nil and not in_range(c.gl, 1, 100) then return false, "character " .. i .. ": gear level must be 1-100" end
    for _, k in ipairs({ "skill", "fam", "firegear" }) do
      if c[k] ~= nil and type(c[k]) ~= "number" then return false, "character " .. i .. ": " .. k .. " must be a number" end
    end
    if strict then
      if c.skill ~= nil and not in_range(c.skill, 0, 100) then return false, "character " .. i .. ": skill must be 0-100" end
      if c.fam ~= nil and not in_range(c.fam, 0, D.FAMILIARITY.cap) then return false, "character " .. i .. ": familiarity out of range" end
      if c.firegear ~= nil and not in_range(c.firegear, 0, 2) then return false, "character " .. i .. ": fire gear must be 0-2" end
      local band = D.MODES[inputs.mode].band
      if band and c.gl ~= nil and (c.gl < band[1] or c.gl > band[2]) then return false, "character " .. i .. ": gear level outside the " .. inputs.mode .. " band" end
    end
  end
  if inputs.pairs ~= nil then
    if type(inputs.pairs) ~= "table" then return false, "pairs must be a list" end
    if strict then
      local seen = {}
      for k = 1, #inputs.pairs do
        local e = inputs.pairs[k]
        if type(e) ~= "table" or not in_range(e.a, 1, #raid) or not in_range(e.b, 1, #raid) or e.a == e.b then return false, "pair " .. k .. " names bad slots" end
        if not in_range(e.v, 0, D.CHEMISTRY.cap) then return false, "pair " .. k .. ": chemistry out of range" end
        local key = (e.a < e.b) and (e.a * 16 + e.b) or (e.b * 16 + e.a)
        if seen[key] then return false, "pair " .. k .. " is a duplicate" end
        seen[key] = true
      end
    end
  end
  return true
end

-- For verifying someone else's record: strict checks, then the fight, never an error.
function ns.Verify(record)
  local ok, err = ns.Validate(record, true)
  if not ok then return nil, err end
  local okr, r = pcall(ns.Simulate, record)
  if not okr then return nil, "engine error: " .. tostring(r) end
  return r
end
