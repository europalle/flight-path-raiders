-- Runs the golden fights and prints one line each: result, rounds, checksum.
local ns = FPR_ENGINE
local out = {}
for i = 1, #ns.Fixtures do
  local r = ns.Simulate(ns.Fixtures[i])
  out[#out + 1] = i .. " " .. r.result .. " " .. r.rounds .. " " .. r.checksum .. " " .. #r.events
end
return table.concat(out, "\n")
