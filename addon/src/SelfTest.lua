-- /fpr selftest: runs the golden fights and the fuzz run inside the client and compares them with the
-- results every other runtime gives (tests/golden.txt, baked in as ns.GOLDEN by tools/build_addon.py).
local _, ns = ...

function ns.SelfTestRun()
  local Print = ns.Core.Print
  local t0 = debugprofilestop()
  local ok, golden = pcall(ns.SelfTest.golden)
  if not ok then return Print("|cffff6060SELFTEST FAILED|r: the engine raised an error: " .. tostring(golden)) end
  local t1 = debugprofilestop()
  local okf, fuzz = pcall(ns.SelfTest.fuzz, 2000)
  if not okf then return Print("|cffff6060SELFTEST FAILED|r: the fuzz run raised an error: " .. tostring(fuzz)) end
  local t2 = debugprofilestop()
  local got = "engine " .. ns.ENGINE_VERSION .. "\n" .. golden .. "\n" .. fuzz
  local n = ns.SelfTest.fights or 0
  if got == ns.GOLDEN then
    Print(string.format("|cff60ff60selftest passed|r: engine %d, %d golden fights and the fuzz run match every other runtime. %.1f ms per fight.",
      ns.ENGINE_VERSION, #ns.Fixtures, (t2 - t0) / (#ns.Fixtures + 2000 + 60)))
  else
    Print("|cffff6060SELFTEST FAILED|r: results differ from the other runtimes. First lines:")
    Print("expected: " .. string.sub(ns.GOLDEN, 1, 120))
    Print("got: " .. string.sub(got, 1, 120))
  end
  return got == ns.GOLDEN
end
