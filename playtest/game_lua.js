// The game rules for the playtest page and the headless tools, backed by engine/game.lua through Fengari.
// Same method names as the old playtest/game.js, so the page, the bot and QA did not change shape.
// The Lua state (FPR_STATE) is the real one. The JS `st` object is a read-only mirror, refreshed after
// every call that can change it. Write to the game only through these methods.
(function (root) {
  function create(fengari, sources) {
    const { lua, lauxlib, lualib, to_luastring } = fengari;
    const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
    function exec(src, name, nres) {
      if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring('@' + name)) !== lua.LUA_OK || lua.lua_pcall(L, 0, nres, 0) !== lua.LUA_OK) {
        const msg = lua.lua_tojsstring(L, -1); lua.lua_pop(L, 1); throw new Error(msg);
      }
    }
    for (const [name, src] of sources) exec(src, name, 0);
    exec(`local G = FPR_ENGINE.Game
      function FPR_CALL(name, mutates, ...)
        local ret = G[name](FPR_STATE, ...)
        return { r = ret, st = mutates and FPR_STATE or nil }
      end
      function FPR_SET(st) FPR_STATE = st end`, 'shim', 0);
    // Lua table to JS value, walking the stack directly (much faster in Fengari than building JSON text).
    // A table is an array when its keys are exactly 1..n; an empty table becomes [] (norm() fixes the maps).
    function toJs(idx) {
      const t = lua.lua_type(L, idx);
      if (t === lua.LUA_TNUMBER) return lua.lua_tonumber(L, idx);
      if (t === lua.LUA_TSTRING) return lua.lua_tojsstring(L, idx);
      if (t === lua.LUA_TBOOLEAN) return lua.lua_toboolean(L, idx);
      if (t !== lua.LUA_TTABLE) return null;
      if (idx < 0) idx = lua.lua_gettop(L) + idx + 1;
      const n = lua.lua_rawlen(L, idx);
      const obj = {}; let count = 0;
      lua.lua_pushnil(L);
      while (lua.lua_next(L, idx) !== 0) {
        const vt = lua.lua_type(L, -1);
        if (vt !== lua.LUA_TFUNCTION) {
          const k = lua.lua_type(L, -2) === lua.LUA_TNUMBER ? String(lua.lua_tonumber(L, -2)) : lua.lua_tojsstring(L, -2);
          obj[k] = toJs(-1); count++;
        }
        lua.lua_pop(L, 1);
      }
      if (count === n) { const a = new Array(n); for (let i = 0; i < n; i++) a[i] = obj[String(i + 1)]; return a; }
      return obj;
    }
    function toLua(v) {
      if (v === null || v === undefined) return "nil";
      if (Array.isArray(v)) return "{" + v.map(toLua).join(",") + "}";
      if (typeof v === "object") return "{" + Object.entries(v).filter(([, x]) => x !== undefined && x !== null).map(([k, x]) => `[${JSON.stringify(k)}]=${toLua(x)}`).join(",") + "}";
      if (typeof v === "string") return JSON.stringify(v).replace(/\\u([0-9a-fA-F]{4})/g, "\\u{$1}");  // Lua 5.3 escapes; WoW never sees this path
      if (typeof v === "boolean") return v ? "true" : "false";
      return Number.isInteger(v) ? String(v) : String(v);
    }
    function ret(src) { exec("return " + src, 'call', 1); const v = toJs(-1); lua.lua_pop(L, 1); return v; }
    let mirror = null;
    function refresh(st) {
      if (!mirror) mirror = {};
      for (const k of Object.keys(mirror)) delete mirror[k];
      Object.assign(mirror, st);
      return mirror;
    }
    // Lua's encoder writes an empty table as []; fix the few maps that start empty.
    function norm(st) {
      for (const k of ["bonds", "buffs", "journal", "lessons", "lessonWipes", "lessonTier", "replays", "freeWipe", "lastPrep"]) if (Array.isArray(st[k])) st[k] = {};
      for (const c of st.roster.concat(st.tavern || [])) { if (Array.isArray(c.fam10)) c.fam10 = {}; if (Array.isArray(c.pulls)) c.pulls = {}; }
      for (const b in st.journal) if (Array.isArray(st.journal[b])) st.journal[b] = {};
      return st;
    }
    const call = (name, ...args) => { const o = ret(`FPR_CALL(${JSON.stringify(name)}, true${args.map(a => "," + toLua(a)).join("")})`); refresh(norm(o.st)); return o.r; };
    const query = (name, ...args) => ret(`FPR_CALL(${JSON.stringify(name)}, false${args.map(a => "," + toLua(a)).join("")})`).r;
    const S = ret("FPR_ENGINE.Game.Static()");
    const BOSS = {}; S.BOSSES.forEach(b => BOSS[b.id] = b);
    const LESSONS = {}; for (const b in S.ANSWERS) LESSONS[b] = Object.entries(S.ANSWERS[b]).map(([id, a]) => ({ id, t: ["", "", a] }));
    const SPEC = (cls, spec) => S.SPECS[cls].find(s => s[0] === spec);
    const MELEE = new Set(["warrior:arms", "warrior:fury", "paladin:retribution", "rogue:assassination", "rogue:combat", "rogue:subtlety", "shaman:enhancement", "druid:feralcat"]);
    const G = {
      SPECS: S.SPECS, CLASS_NAMES: S.CLASS_NAMES, ARMOR: S.ARMOR, RARITY: S.RARITY, ECON: S.ECON, MODES: S.MODES, CARDS: S.CARDS, CARD_ORDER: S.CARD_ORDER,
      CARD_TEXT: S.CARD_TEXT, WB: S.WB, TRAITS: S.TRAITS, MORALE: S.MORALE, BOSSES: S.BOSSES, BOSS, LESSONS,
      lua: src => ret(src),
      // Pure helpers, done here on the mirror (no Lua round trip).
      byId: (st, id) => st.roster.find(c => c.id === Number(id)),
      role: (cls, spec) => SPEC(cls, spec)[2],
      specName: (cls, spec) => SPEC(cls, spec)[1],
      defaultZone: c => { const r = SPEC(c.cls, c.spec)[2]; return r === "tank" ? "front" : r === "healer" ? "back" : MELEE.has(c.cls + ":" + c.spec) ? "melee" : "ranged"; },
      gearLevel: c => Math.floor((c.gear.weapon.lvl + c.gear.armor.lvl + c.gear.trinket.lvl) / 3 + 0.5),
      canWear: (c, item) => item.slot !== "armor" || item.type === S.ARMOR[c.cls],
      sellValue: item => Math.max(1, Math.floor(item.lvl / 4 + 0.5)),
      // Load a saved game (or any state) into Lua.
      load: st => { exec(`FPR_SET(${toLua(st)})`, 'load', 0); return refresh(norm(ret("FPR_STATE"))); },
      newGame: seed => { exec(`FPR_STATE = FPR_ENGINE.Game.NewGame(${Math.floor(seed)})`, 'new', 0); return refresh(norm(ret("FPR_STATE"))); },
      setRules: r => exec(`local R = FPR_ENGINE.Progress.RULES ${Object.entries(r).map(([k, v]) => `R[${JSON.stringify(k)}] = ${Math.round(v)}`).join(" ")}`, 'rules', 0),
      // Reads that need the Lua state.
      unlocked: (st, boss, mode) => query("unlocked", boss, mode),
      heroicOpen: st => query("heroicOpen"),
      heroicScore: st => query("heroicScore"),
      cohesion: (st, ids) => query("cohesion", ids),
      famAvg: (st, ids, boss) => query("famAvg", ids, boss),
      bond: (st, a, b) => query("bond", a, b),
      defaultPrep: (st, boss, mode) => { const p = query("DefaultPrep", boss, mode); for (const k of ["zones", "potions", "fireOn", "buffs"]) if (Array.isArray(p[k])) p[k] = {}; return p; },
      prepCost: (st, prep) => query("PrepCost", prep),
      problems: (st, prep) => query("Problems", prep) || [],
      warnings: (st, prep) => query("Warnings", prep) || [],
      replayInfo: st => query("ReplayInfo"),
      suggestFor: (st, item) => ({ to: query("SuggestFor", item) }),
      // Changes.
      pull: (st, prep) => call("Pull", prep),
      replay: (st, card) => call("Replay", card),
      assignPending: (st, i, to) => call("AssignPending", i + 1, to),
      dungeon: st => call("Dungeon"),
      hire: (st, i) => call("Hire", i + 1),
      reroll: st => call("Reroll"),
      rerollCost: st => query("RerollCost"),
      dismiss: (st, id) => call("Dismiss", id),
      buyFire: (st, id) => call("BuyFire", id),
      respec: (st, id, spec) => call("Respec", id, spec),
      endWeek: st => call("EndWeek"),
      rebuild: rec => ret(`FPR_ENGINE.Game.Rebuild(${toLua(rec)})`),
    };
    return G;
  }
  root.FPR_GAME_LUA = create;
})(typeof window !== "undefined" ? window : globalThis);
