// Runs the golden fights in Fengari (the browser's Lua) and prints the same lines as tests/run.lua.
const path = require('path'), fs = require('fs');
const { lua, lauxlib, lualib, to_luastring } = require(process.env.FENGARI || 'fengari');
const root = path.join(__dirname, '..');
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
function run(file, nres) {
  const src = fs.readFileSync(path.join(root, file));
  if (lauxlib.luaL_loadbuffer(L, src, null, to_luastring('@' + file)) !== lua.LUA_OK ||
      lua.lua_pcall(L, 0, nres, 0) !== lua.LUA_OK) {
    throw new Error(lua.lua_tojsstring(L, -1));
  }
}
for (const f of ['engine/rng.lua', 'engine/data.lua', 'engine/sim.lua', 'engine/validate.lua', 'tests/fixtures.lua']) run(f, 0);
run('tests/run.lua', 1);
console.log(lua.lua_tojsstring(L, -1));
