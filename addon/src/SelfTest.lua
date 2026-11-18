-- /fpr selftest: runs the golden fights and the fuzz run inside the client and compares them with the
-- results every other runtime gives (tests/golden.txt, baked in as ns.GOLDEN by tools/build_addon.py).
local _, ns = ...

-- Lua 5.1 can't yield through pcall, so inside the coroutine errors are caught by coroutine.resume instead.
local function call(protect, fn, ...)
  if protect then return pcall(fn, ...) end
  return true, fn(...)
end
local function run(protect)
  local Print = ns.Core.Print
  local t0 = debugprofilestop()
  local ok, golden = call(protect, ns.SelfTest.golden)
  if not ok then return Print("|cffff6060SELFTEST FAILED|r: the engine raised an error: " .. tostring(golden)) end
  local t1 = debugprofilestop()
  local okf, fuzz = call(protect, ns.SelfTest.fuzz, 2000)
  if not okf then return Print("|cffff6060SELFTEST FAILED|r: the fuzz run raised an error: " .. tostring(fuzz)) end
  local t2 = debugprofilestop()
  local got = "engine " .. ns.ENGINE_VERSION .. "\n" .. golden .. "\n" .. fuzz
  local n = ns.SelfTest.fights or 0
  ns.lastSelfTestOk = got == ns.GOLDEN
  ns.lastSelfTest = ns.lastSelfTestOk and ("Passed, engine " .. ns.ENGINE_VERSION) or "Failed: see chat"
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

-- In the client the self-test runs a few dozen fights per frame (about 2,000 in all), so the game never
-- stalls for more than a frame. sync = true runs it in one go (headless tests).
function ns.SelfTestRun(sync)
  if sync then return run(true) end
  if ns.selfTestRunning then return end
  ns.selfTestRunning = true
  ns.lastSelfTest = "Running..."
  ns.Core.Print("selftest running: about 2,000 fights, a few seconds")
  local co = coroutine.create(function()
    ns.SelfTest.yield = coroutine.yield
    local r = run(false)
    ns.SelfTest.yield = nil
    return r
  end)
  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", function(self)
    local ok, err = coroutine.resume(co)
    if not ok then ns.Core.Print("|cffff6060SELFTEST FAILED|r: " .. tostring(err)); ns.lastSelfTest = "Failed: see chat"; ns.lastSelfTestOk = false end
    if not ok or coroutine.status(co) == "dead" then
      self:SetScript("OnUpdate", nil); ns.selfTestRunning = false; ns.SelfTest.yield = nil
      if ns.Board and ns.Board.Render then ns.Board.Render() end
    end
  end)
end
