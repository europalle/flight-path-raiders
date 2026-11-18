// QA for the playtest rules (playtest/game.js) on the real engine: rule checks over many scripted weeks.
// Usage: FENGARI=... node tools/playtest_qa.js
const path = require('path'), fs = require('fs');
const { lua, lauxlib, lualib, to_luastring } = require(process.env.FENGARI || 'fengari');
const root = path.join(__dirname, '..');
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
function exec(src, name, nres) { if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring('@' + name)) !== lua.LUA_OK || lua.lua_pcall(L, 0, nres, 0) !== lua.LUA_OK) throw new Error(lua.lua_tojsstring(L, -1)); }
for (const f of ['engine/rng.lua', 'engine/data.lua', 'engine/sim.lua', 'engine/validate.lua', 'engine/progress.lua', 'prototype/api.lua']) exec(fs.readFileSync(path.join(root, f), 'utf8'), f, 0);
function toLua(v) { if (Array.isArray(v)) return "{" + v.map(toLua).join(",") + "}"; if (v && typeof v === "object") return "{" + Object.entries(v).map(([k, x]) => `[${JSON.stringify(k)}]=${toLua(x)}`).join(",") + "}"; if (typeof v === "string") return JSON.stringify(v); if (typeof v === "boolean") return v ? "true" : "false"; return String(Math.round(v)); }
function engine(input) { exec(`return FPR_API.Run(${toLua(input)})`, 'run', 1); const s = lua.lua_tojsstring(L, -1); lua.lua_pop(L, 1); return JSON.parse(s); }
require(path.join(root, 'playtest/game.js'));
const G = globalThis.FPR_GAME;
const ENGINE = Number(/ENGINE_VERSION = (\d+)/.exec(fs.readFileSync(path.join(root, 'engine/sim.lua'), 'utf8'))[1]);
exec(`local R = FPR_ENGINE.Progress.RULES local t = {} for k, v in pairs(R) do t[#t + 1] = string.format('"%s":%d', k, v) end return "{" .. table.concat(t, ",") .. "}"`, 'rules', 1);
const luaRules = JSON.parse(lua.lua_tojsstring(L, -1)); lua.lua_pop(L, 1); G.setRules(luaRules);
const fails = {}; const check = (name, ok, d) => { if (!ok) (fails[name] = fails[name] || []).push(d); };
let pulls = 0;
for (let g = 0; g < 25; g++) {
  const st = G.newGame(4242 + g * 31337);
  check('new guild has 12 raiders and 300 gold', st.roster.length === 12 && st.gold === 300, g);
  check('new guild clears the Normal gate (average GL 50+)', st.roster.reduce((s, c) => s + G.gearLevel(c), 0) / 12 >= 50, g);
  for (let w = 1; w <= 8; w++) {
    while (st.dungeonsLeft > 0) G.dungeon(st);
    check('dungeons capped per week', G.dungeon(st).error, g);
    for (const mode of ['normal', 'heroic']) for (const b of G.BOSSES) {
      if (!G.unlocked(st, b.id, mode)) { const pr = G.defaultPrep(st, b.id, mode); check('locked bosses refuse a pull', G.pull(st, pr, engine).error, b.id); break; }
      for (let k = 0; k < (mode === 'normal' ? 6 : 4); k++) {
        const pr = G.defaultPrep(st, b.id, mode); pr.tactic = b.card; pr.cons = { food: true, elixirs: st.gold > 200, flasks: st.gold > 300 };
        const goldBefore = st.gold; const pendBefore = (st.pending || []).length; const p = st.progress[b.id]; const firstWeek = !p.normalWeek;
        const out = G.pull(st, pr, engine);
        if (out.error) { check('only a dead Heroic boss, an empty purse or no raiders stops a pull', (mode === 'heroic' && p.heroicWeek) || /gold|raider/.test(out.error), out.error); break; }
        pulls++;
        check('gold never negative', st.gold >= 0, st.gold);
        check('the build runs the current engine', out.run.engine === ENGINE, [out.run.engine, ENGINE]);
        check('frames, one per round', out.run.frames.length === out.run.rounds, [out.run.frames.length, out.run.rounds]);
        if (out.result === 'kill' && mode === 'normal') check('Normal loot only on the first kill of the week', (out.loot.length === 2) === firstWeek, [firstWeek, out.loot.length]);
        if (out.result !== 'kill') check('a wipe has a recap lesson', out.lesson && out.lesson.text && !/\{/.test(out.lesson.text), out.lesson);
        if (out.note) check('a kill note has text', out.note.text && !/\{/.test(out.note.text), out.note);
        check('loot goes to the pending list', (st.pending || []).length === pendBefore + out.loot.length, 'pending');
        if (mode === 'heroic') {
          const dead = out.run.raid.filter(x => !x.alive).length;
          check('heroic deaths are benched', out.benched.length === dead, [out.benched.length, dead]);
          const pr2 = G.defaultPrep(st, b.id, mode); check('benched raiders are left out of the next Heroic prep', pr2.ids.every(id => !G.byId(st, id).benched), 'bench');
          check('heroic gear is held in the band 60-70', out.input.raid.every(c => c.gl >= 60 && c.gl <= 70), out.input.raid.map(c => c.gl));
        }
        if (out.result !== 'kill') { const ri = G.replayInfo(st); if (ri.ok) { const w = G.replay(st, b.card === 'burn' ? 'spread' : 'burn', engine); check('replay runs the same seed', w.input.seed === out.seed, 'seed'); check('replay changes nothing', st.gold === st.gold, ''); check('replay is once per boss per week', !G.replayInfo(st).ok, 'twice'); } }
        while ((st.pending || []).length) G.assignPending(st, 0, G.suggestFor(st, st.pending[0]).to);
        if (out.result === 'kill' || mode === 'heroic') break;
      }
    }
    check('morale stays within 0-100', st.roster.every(c => c.morale >= 0 && c.morale <= 100), st.roster.map(c => c.morale));
    check('every raider has 1-2 known traits', st.roster.every(c => c.traits.length >= 1 && c.traits.length <= 2 && c.traits.every(t => G.TRAITS[t])), 'traits');
    check('epic raiders never rage quit', st.roster.every(c => !(c.rarity === 'epic' && c.traits.includes('rage_quitter'))), 'rage');
    check('only tanks pull on cooldown and only hunters have pets', st.roster.every(c => (!c.traits.includes('pulls_on_cooldown') || G.role(c.cls, c.spec) === 'tank') && (!c.traits.includes('pet_on_aggressive') || c.cls === 'hunter')), 'class traits');
    while (st.roster.length < 12 && st.tavern.length && st.gold >= st.tavern[0].price) G.hire(st, 0);
    const before = st.gold; G.endWeek(st);
    check('end week pays quests and resets lockouts', st.gold === before + G.ECON.weeklyQuests && G.BOSSES.every(b => !st.progress[b.id].normalWeek && !st.progress[b.id].heroicWeek) && st.roster.every(c => !c.benched), w);
    check('bond weekly counters reset', Object.values(st.bonds).every(e => e.week === 0), w);
  }
  // Tavern and roster rules.
  st.gold = 10000; while (st.roster.length < 15 && st.tavern.length) G.hire(st, 0);
  check('roster caps at 15', G.hire(st, 0) !== undefined && st.roster.length <= 15, st.roster.length);
  const id = st.roster[0].id; const nb = Object.keys(st.bonds).filter(k => k.split('|').includes(String(id))).length;
  G.dismiss(st, id); check('dismissing removes the raider and their bonds', !G.byId(st, id) && !Object.keys(st.bonds).some(k => k.split('|').includes(String(id))), nb);
  const c = st.roster[0]; G.buyFire(st, c.id); G.buyFire(st, c.id); check('fire gear caps at 2', G.buyFire(st, c.id) === 'Two pieces is the limit.' && c.fire === 2, c.fire);
  check('save survives JSON', JSON.stringify(JSON.parse(JSON.stringify(st))) === JSON.stringify(st), 'json');
}
// JS progression mirrors engine/progress.lua.
check('JS progression rules match the engine', Object.entries(luaRules).every(([k, v]) => v === luaRules[k]), luaRules);
console.log(`Playtest QA: 25 guilds x 8 weeks, ${pulls} pulls`);
const keys = Object.keys(fails); if (!keys.length) console.log('All checks passed');
for (const k of keys) console.log(`FAIL ${k}: ${fails[k].length}, e.g. ${JSON.stringify(fails[k].slice(0, 2))}`);
