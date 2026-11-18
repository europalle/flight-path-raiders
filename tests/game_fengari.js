// Runs tests/game_run.lua in Fengari (the browser's Lua) and prints its lines.
const path = require('path'), fs = require('fs');
const { lua, lauxlib, lualib, to_luastring } = require(process.env.FENGARI || 'fengari');
const root = path.join(__dirname, '..');
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
function run(file, nres) {
  if (lauxlib.luaL_loadbuffer(L, fs.readFileSync(path.join(root, file)), null, to_luastring('@' + file)) !== lua.LUA_OK ||
      lua.lua_pcall(L, 0, nres, 0) !== lua.LUA_OK) throw new Error(lua.lua_tojsstring(L, -1));
}
for (const f of ['engine/rng.lua', 'engine/data.lua', 'engine/sim.lua', 'engine/bosses.lua', 'engine/validate.lua', 'engine/progress.lua', 'engine/game.lua']) run(f, 0);
run('tests/game_run.lua', 1);
console.log(lua.lua_tojsstring(L, -1));
