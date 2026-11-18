-- Flight Path Raiders: player skill, boss familiarity and chemistry between pulls.
-- Owned by Game Design and Tuning. Deterministic: whole numbers only, arrays only.
-- Values are stored in tenths (skill10 = 0-1000) so small gains add up without floats.
local _, ns = ...
ns = ns or FPR_ENGINE or {}
FPR_ENGINE = ns

local P = {}
ns.Progress = P

P.START_SKILL = { common = 20, rare = 40, epic = 55, legendary = 70 }  -- rarities as in design doc 4.5
P.RULES = {
  counted_pulls = 3,    -- only the first 3 pulls per boss per week teach anything
  skill_wipe = 6,       -- tenths of a skill point per counted pull
  skill_kill = 12,
  skill_soft = 700,     -- above skill 70, gains are halved
  fam_wipe = 3,         -- tenths of a familiarity point
  fam_kill = 6, 
  fam_cap = 100,        -- familiarity 10
  chem_pull = 4,        -- tenths of chemistry per pair per pull together
  chem_week = 15,       -- weekly cap per pair: 1.5 chemistry
  chem_cap = 200,       -- chemistry 20
}

local function idiv(a, b) return (a - a % b) / b end

-- A guild: members in join order, plus pair bonds keyed by "lowid|highid".
function P.NewGuild()
  return { members = {}, by_id = {}, bonds = {}, week = 1, next_id = 1 }
end

function P.Recruit(g, rarity, name)
  local id = g.next_id
  g.next_id = id + 1
  local m = { id = id, name = name or ("Raider " .. id), rarity = rarity,
              skill10 = (P.START_SKILL[rarity] or 20) * 10, fam10 = {}, pulls = {} }
  g.members[#g.members + 1] = m
  g.by_id[id] = m
  return m
end

local function key(a, b)
  if a > b then a, b = b, a end
  return a .. "|" .. b
end

function P.Bond(g, a, b)
  local e = g.bonds[key(a, b)]
  return e and e.v10 or 0
end

-- Leaving the guild: the character and every bond they had are gone.
function P.Quit(g, id)
  local keep = {}
  for i = 1, #g.members do
    if g.members[i].id ~= id then keep[#keep + 1] = g.members[i] end
  end
  g.members = keep
  g.by_id[id] = nil
  for i = 1, #keep do g.bonds[key(id, keep[i].id)] = nil end
end

function P.NewWeek(g)
  g.week = g.week + 1
  for i = 1, #g.members do g.members[i].pulls = {} end
  for _, e in pairs(g.bonds) do e.week = 0 end  -- order does not matter: every entry gets the same write
end

-- Builds the per-character fields and chemistry pairs Simulate needs for these raid slots.
function P.RaidFields(g, ids, boss)
  local out, pairs_list = {}, {}
  for i = 1, #ids do
    local m = g.by_id[ids[i]]
    out[i] = { skill = idiv(m.skill10, 10), fam = idiv(m.fam10[boss] or 0, 10) }
  end
  for i = 1, #ids do
    for j = i + 1, #ids do
      local v = idiv(P.Bond(g, ids[i], ids[j]), 10)
      if v > 0 then pairs_list[#pairs_list + 1] = { a = i, b = j, v = v } end
    end
  end
  return out, pairs_list
end

-- Call once after each pull with the ids of the ten who were in it.
function P.AfterPull(g, ids, boss, killed)
  local R = P.RULES
  for i = 1, #ids do
    local m = g.by_id[ids[i]]
    local n = (m.pulls[boss] or 0) + 1
    m.pulls[boss] = n
    if n <= R.counted_pulls then
      local gain = killed and R.skill_kill or R.skill_wipe
      if m.skill10 >= R.skill_soft then gain = idiv(gain, 2) end
      m.skill10 = m.skill10 + gain
      if m.skill10 > 1000 then m.skill10 = 1000 end
      local f = (m.fam10[boss] or 0) + (killed and R.fam_kill or R.fam_wipe)
      if f > R.fam_cap then f = R.fam_cap end
      m.fam10[boss] = f
    end
  end
  for i = 1, #ids do
    for j = i + 1, #ids do
      local k = key(ids[i], ids[j])
      local e = g.bonds[k]
      if not e then e = { v10 = 0, week = 0 }; g.bonds[k] = e end
      local room = R.chem_week - e.week
      local add = R.chem_pull
      if add > room then add = room end
      if add > R.chem_cap - e.v10 then add = R.chem_cap - e.v10 end
      if add > 0 then e.v10 = e.v10 + add; e.week = e.week + add end
    end
  end
end

return P
