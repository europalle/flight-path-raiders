#!/usr/bin/env bash
# Cross-runtime check: the golden fights and 2000 fuzz fights must give identical results in
# standard Lua 5.1 (what WoW embeds), LuaJIT and Fengari (the browser). A change to the golden results
# fails unless ENGINE_VERSION changed too; then refresh with tests/check.sh --update. The game rules
# (engine/game.lua) play three scripted seasons with the same three-runtime check (tests/golden_game.txt).
# Needs: pip install lupa; npm install fengari@0.1.5 (set FENGARI to its path if not global).
set -e
cd "$(dirname "$0")/.."
ENGINE='["engine/rng.lua","engine/data.lua","engine/sim.lua", "engine/bosses.lua","engine/validate.lua","engine/progress.lua", "engine/replay.lua","tests/selftest.lua"]'
run_lupa() {  # $1 = lupa module, $2 = test file
python3 - "$1" "$2" <<PY
import importlib, sys, json
L = importlib.import_module("lupa." + sys.argv[1]).LuaRuntime()
for f in json.loads('$ENGINE') + (["tests/fixtures.lua"] if sys.argv[2] in ("tests/run.lua", "tests/replay_test.lua") else []) + (["engine/game.lua"] if sys.argv[2] == "tests/game_run.lua" else []): L.execute(open(f).read())
print(L.execute(open(sys.argv[2]).read()))
PY
}
version=$(grep -o 'ENGINE_VERSION = [0-9]*' engine/sim.lua | grep -o '[0-9]*$')
g51=$(run_lupa lua51 tests/run.lua);   gjit=$(run_lupa luajit21 tests/run.lua);   gfen=$(node tests/run_fengari.js)
f51=$(run_lupa lua51 tests/fuzz.lua);  fjit=$(run_lupa luajit21 tests/fuzz.lua);  ffen=$(node tests/fuzz_fengari.js)
[ "$g51" == "$gjit" ] && [ "$g51" == "$gfen" ] || { echo "MISMATCH golden fights between Lua 5.1, LuaJIT and Fengari"; exit 1; }
[ "$f51" == "$fjit" ] && [ "$f51" == "$ffen" ] || { echo "MISMATCH fuzz fights between Lua 5.1, LuaJIT and Fengari"; exit 1; }
# The game rules (engine/game.lua): three scripted seasons must agree across runtimes and match tests/golden_game.txt.
s51=$(run_lupa lua51 tests/game_run.lua); sjit=$(run_lupa luajit21 tests/game_run.lua); sfen=$(node tests/game_fengari.js)
[ "$s51" == "$sjit" ] && [ "$s51" == "$sfen" ] || { echo "MISMATCH game rules between Lua 5.1, LuaJIT and Fengari"; exit 1; }
# Replay records (engine/replay.lua): same lines in every runtime, and nothing failing.
r51=$(run_lupa lua51 tests/replay_test.lua); rjit=$(run_lupa luajit21 tests/replay_test.lua); rfen=$(node tests/replay_fengari.js)
[ "$r51" == "$rjit" ] && [ "$r51" == "$rfen" ] || { echo "MISMATCH replay records between Lua 5.1, LuaJIT and Fengari"; exit 1; }
echo "$r51" | grep -q "^FAIL" && { echo "$r51"; echo "FAIL: replay records"; exit 1; }
golden="engine $version
$g51
$f51"
if [ "$1" == "--update" ]; then echo "$golden" > tests/golden.txt; echo "$s51" > tests/golden_game.txt; echo "Saved golden results for engine $version and the game rules"; exit 0; fi
if [ "$s51" != "$(cat tests/golden_game.txt 2>/dev/null)" ]; then
  echo "FAIL: the game rules (or the fights under them) give new season results. If intended, run tests/check.sh --update."; exit 1
fi
saved_version=$(head -1 tests/golden.txt | grep -o '[0-9]*$' || echo 0)
if [ "$golden" != "$(cat tests/golden.txt)" ] && [ "$(echo "$golden" | tail -n +2)" == "$(tail -n +2 tests/golden.txt)" ]; then
  echo "NOTE: engine $version gives the same results as engine $saved_version; run tests/check.sh --update to record the new version"
elif [ "$golden" != "$(cat tests/golden.txt)" ]; then
  if [ "$saved_version" == "$version" ]; then
    echo "FAIL: fight results changed but ENGINE_VERSION is still $version. Bump it in engine/sim.lua, then run tests/check.sh --update."; exit 1
  fi
  echo "FAIL: engine $version gives new results (saved: engine $saved_version). If intended, run tests/check.sh --update."; exit 1
fi
echo "OK: engine $version, Lua 5.1, LuaJIT and Fengari agree on $(echo "$g51" | wc -l) golden fights, the fuzz run and $(echo "$s51" | wc -l) weeks of scripted seasons and the replay record tests, and match the saved results"
