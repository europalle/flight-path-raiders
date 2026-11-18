-- Flight Path Raiders: seeded random number generator (Park-Miller).
-- Plain arithmetic only, so Lua 5.1 (WoW), newer Luas and JavaScript give identical numbers.
local _, ns = ...
ns = ns or FPR_ENGINE or {}
FPR_ENGINE = ns

local M = 2147483647
-- The product 16807 * x needs up to 46 bits. Fengari (the browser's Lua) stores whole numbers
-- as 32-bit integers, so the multiplication is done in floating point, which holds every
-- value below 2^53 exactly in all runtimes. Results are floored back to whole numbers.
local A = 16807.0
local floor = math.floor

local RNG = {}
RNG.__index = RNG

function ns.NewRNG(seed)
  local s = floor(seed) % M
  if s <= 0 then s = s + M - 1 end
  return setmetatable({ x = s + 0.0 }, RNG)
end

-- Next raw value in 1 .. M-1.
function RNG:next()
  self.x = (A * self.x) % M
  return floor(self.x)
end

-- Whole number from 1 to n.
function RNG:int(n)
  return floor(1 + self:next() % n)
end

-- True with a chance given in per-mille (0 to 1000).
function RNG:chance(permille)
  return self:int(1000) <= permille
end

-- Build a seed from a few whole numbers (week, boss, mode, attempt...).
function ns.Seed(a, b, c, d)
  local h = 1234567.0
  local parts = { a or 0, b or 0, c or 0, d or 0 }
  for i = 1, 4 do
    h = (h * 31.0 + (parts[i] % M)) % M
  end
  return floor(h)
end
