-- Runs the fuzz fights (tests/selftest.lua) and returns the combined checksum line.
return FPR_ENGINE.SelfTest.fuzz(FPR_FUZZ_N or 2000)
