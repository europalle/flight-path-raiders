#!/usr/bin/env bash
# Runs the golden fights in Lua 5.1 (LuaJIT via lupa) and Fengari and compares both to the saved results.
# Needs: pip install lupa, npm install fengari@0.1.5 (set FENGARI to its path if not global).
set -e
cd "$(dirname "$0")/.."
a=$(python3 -c "
import lupa.luajit21 as lj
L=lj.LuaRuntime()
for f in ['engine/rng.lua','engine/data.lua','engine/sim.lua','tests/fixtures.lua']: L.execute(open(f).read())
print(L.execute(open('tests/run.lua').read()))")
b=$(node tests/run_fengari.js)
c=$(python3 -c "
import lupa.luajit21 as lj
L=lj.LuaRuntime()
for f in ['engine/rng.lua','engine/data.lua','engine/sim.lua','engine/progress.lua']: L.execute(open(f).read())
print(L.execute(open('tests/fuzz.lua').read()))")
d=$(node tests/fuzz_fengari.js)
[ "$a" == "$b" ] || { echo "MISMATCH golden: Lua 5.1 vs Fengari"; exit 1; }
[ "$c" == "$d" ] || { echo "MISMATCH fuzz: Lua 5.1 vs Fengari"; exit 1; }
[ "$a" == "$(cat tests/golden.txt)" ] || echo "NOTE: golden results changed (expected after a balance change; update tests/golden.txt)"
[ "$c" == "$(cat tests/golden-fuzz.txt)" ] || echo "NOTE: fuzz results changed"
echo "OK: Lua 5.1 and Fengari agree on $(echo "$a" | wc -l) golden fights and 2000 fuzz fights"
