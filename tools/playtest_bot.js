// Tuning: plays the playtest build headless with a simple "learning" bot and reports week-by-week progress.
// Usage: FENGARI=... node tools/playtest_bot.js [guilds] [weeks] [style]
// style: learner (follows the recap once it names the answer), smart (knows every answer), stubborn (always Spread)
const path = require('path'), fs = require('fs');
const { lua, lauxlib, lualib, to_luastring } = require(process.env.FENGARI || 'fengari');
const root = path.join(__dirname, '..');
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
function exec(src, name, nres) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring('@' + name)) !== lua.LUA_OK || lua.lua_pcall(L, 0, nres, 0) !== lua.LUA_OK)
    throw new Error(lua.lua_tojsstring(L, -1));
}
for (const f of ['engine/rng.lua', 'engine/data.lua', 'engine/sim.lua', 'engine/validate.lua', 'engine/progress.lua', 'prototype/api.lua']) exec(fs.readFileSync(path.join(root, f), 'utf8'), f, 0);
function toLua(v) {
  if (Array.isArray(v)) return "{" + v.map(toLua).join(",") + "}";
  if (v && typeof v === "object") return "{" + Object.entries(v).map(([k, x]) => `[${JSON.stringify(k)}]=${toLua(x)}`).join(",") + "}";
  if (typeof v === "string") return JSON.stringify(v);
  if (typeof v === "boolean") return v ? "true" : "false";
  return String(Math.round(v));
}
function engine(input) { exec(`return FPR_API.Run(${toLua(input)})`, 'run', 1); const s = lua.lua_tojsstring(L, -1); lua.lua_pop(L, 1); return JSON.parse(s); }
require(path.join(root, 'playtest/game.js'));
const G = globalThis.FPR_GAME;
const guilds = Number(process.argv[2] || 20), weeks = Number(process.argv[3] || 10), style = process.argv[4] || 'learner';
const NIGHT = 10;  // pulls per week the bot is willing to spend on Normal progress
const stats = []; const firstNormal = {}, firstHeroic = {};
for (const b of G.BOSSES) { firstNormal[b.id] = []; firstHeroic[b.id] = []; }
let scores = [], totalGold = [], totalGL = [], moraleEnd = [], quits = 0, rosterEnd = [], wipes = 0, pullsAll = 0, tierSeen = [0, 0, 0];
for (let g = 0; g < guilds; g++) {
  const st = G.newGame(1000 + g * 7919);
  const known = {};  // boss -> card the bot believes is right
  const knowFire = { v: false };
  for (let w = 1; w <= weeks; w++) {
    const clear = () => { while ((st.pending || []).length) G.assignPending(st, 0, G.suggestFor(st, st.pending[0]).to); };
    while (st.dungeonsLeft > 0) { G.dungeon(st); clear(); }
    // Keep the roster topped up like a real player would: hire the cheapest useful recruit when below 12.
    while (st.roster.length < 12 && st.tavern.length) {
      const i = st.tavern.reduce((b, o, k) => (o.price < st.tavern[b].price ? k : b), 0);
      if (st.gold < st.tavern[i].price) break; G.hire(st, i);
    }
    let budget = NIGHT;
    for (const mode of ['normal', 'heroic']) {
      for (const b of G.BOSSES) {
        if (!G.unlocked(st, b.id, mode)) break;
        const p = st.progress[b.id];
        if (mode === 'normal' && p.normalWeek) continue;
        if (mode === 'heroic' && p.heroicWeek) continue;
        let done = false, tries = 0;
        while (!done && (mode === 'heroic' ? tries < 4 && st.roster.filter(c => !c.benched).length >= 8 : budget > 0)) {
          tries++;
          const prep = G.defaultPrep(st, b.id, mode);
          prep.tactic = style === 'smart' ? b.card : style === 'stubborn' ? 'spread' : (known[b.id] || ['spread', 'stack', 'burn', 'playsafe'][(st.pulls + g) % 4]);
          const rich = st.gold > (mode === 'heroic' ? 150 : 250);
          prep.cons = { food: true, elixirs: rich, flasks: rich && (mode === 'heroic' || st.gold > 500) };
          if (b.id === 'ragnaroast' && (style === 'smart' || knowFire.v)) {
            for (const id of prep.ids) { const c = G.byId(st, id); const z = prep.zones[id];
              if ((z === 'melee' || z === 'front') && c.fire < 2 && st.gold > 400) G.buyFire(st, id);
              prep.fireOn[id] = c.fire; prep.potions[id] = (z === 'melee' || z === 'front') && st.gold > 200; }
          }
          if (b.id === 'lucifrown' && (style === 'smart' || known.decurse) && !prep.ids.some(id => ['mage', 'druid'].includes(G.byId(st, id).cls))) {
            // hire a mage or druid if the tavern has one
            const i = st.tavern.findIndex(o => o.cls === 'mage' || o.cls === 'druid');
            if (i >= 0 && st.roster.length < 15 && st.gold >= st.tavern[i].price) G.hire(st, i);
            const dec = st.roster.find(c => ['mage', 'druid'].includes(c.cls) && !prep.ids.includes(c.id) && !(mode === 'heroic' && c.benched));
            if (dec) { const out = prep.ids.findIndex(id => G.role(G.byId(st, id).cls, G.byId(st, id).spec) === 'damage'); if (out >= 0) { prep.ids[out] = dec.id; prep.zones[dec.id] = G.defaultZone(dec); prep.fireOn[dec.id] = 0; } }
          }
          if (G.problems(st, prep).length) { prep.cons = { food: true, elixirs: false, flasks: false }; prep.potions = {}; }
          if (G.problems(st, prep).length) break;
          const out = G.pull(st, prep, engine); pullsAll++; if (mode === 'normal') budget--;
          clear();
          if (out.note) { tierSeen[out.note.tier]++; if (out.note.tier === 2) { if (out.note.id === 'card') known[b.id] = b.card; if (out.note.id === 'fire') knowFire.v = true; if (out.note.id === 'decurse') known.decurse = true; } }
          if (out.result === 'kill') {
            done = true;
            const arr = mode === 'normal' ? firstNormal[b.id] : firstHeroic[b.id];
            if ((mode === 'normal' ? p.normalKills : p.heroicKills) === 1) arr.push(w);
          } else {
            wipes++; tierSeen[out.lesson.tier]++;
            if (out.lesson.tier === 2) { if (out.lesson.id === 'card') known[b.id] = b.card; if (out.lesson.id === 'fire') knowFire.v = true; if (out.lesson.id === 'decurse') known.decurse = true; }
          }
        }
        if (!done) break;  // stuck: stop this week's run in this mode
      }
    }
    if (w === weeks) { moraleEnd.push(st.roster.reduce((a, c) => a + c.morale, 0) / st.roster.length); rosterEnd.push(st.roster.length); totalGold.push(st.gold); totalGL.push(st.roster.reduce((s, c) => s + G.gearLevel(c), 0) / st.roster.length); }
    if (w > weeks - 3) scores.push(G.heroicScore(st));
    G.endWeek(st);
  }
}
const fmt = arr => arr.length ? `week ${(arr.reduce((a, b) => a + b, 0) / arr.length).toFixed(1)} (${Math.round(100 * arr.length / guilds)}% of guilds)` : 'never';
console.log(`${guilds} guilds, ${weeks} weeks, bot: ${style}`);
for (const b of G.BOSSES) console.log(`  ${b.name.padEnd(20)} first Normal kill ${fmt(firstNormal[b.id]).padEnd(28)} first Heroic kill ${fmt(firstHeroic[b.id])}`);
console.log(`  pulls ${pullsAll}, wipes ${wipes}; recap tiers shown: what ${tierSeen[0]}, clue ${tierSeen[1]}, answer ${tierSeen[2]}`);
console.log(`  Heroic score per week, last 3 weeks: ${Math.round(scores.reduce((a, b) => a + b, 0) / scores.length)}`);
console.log(`  end: average morale ${(moraleEnd.reduce((a, b) => a + b, 0) / guilds).toFixed(0)}, roster ${(rosterEnd.reduce((a, b) => a + b, 0) / guilds).toFixed(1)} raiders`);
console.log(`  end: gold ${Math.round(totalGold.reduce((a, b) => a + b, 0) / guilds)}, roster gear level ${(totalGL.reduce((a, b) => a + b, 0) / guilds).toFixed(1)}`);
