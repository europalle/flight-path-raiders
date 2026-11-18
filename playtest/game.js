// Flight Path Raiders playtest: the game rules around the combat engine (no DOM here, so Tuning can
// run it headless in node). The engine itself (Lua) decides every fight; this file is the guild, the
// economy, loot, weeks and the learning path. Numbers come from the design doc (sections 4.5, 8, 10)
// unless marked PLAYTEST, which are Tuning's choices for this build.
(function (root) {
  "use strict";

  const SPECS = {
    warrior: [["arms", "Arms", "damage"], ["fury", "Fury", "damage"], ["protection", "Protection", "tank"]],
    paladin: [["holy", "Holy", "healer"], ["protection", "Protection", "tank"], ["retribution", "Retribution", "damage"]],
    hunter: [["beastmastery", "Beast Mastery", "damage"], ["marksmanship", "Marksmanship", "damage"], ["survival", "Survival", "damage"]],
    rogue: [["assassination", "Assassination", "damage"], ["combat", "Combat", "damage"], ["subtlety", "Subtlety", "damage"]],
    priest: [["holy", "Holy", "healer"], ["discipline", "Discipline", "healer"], ["shadow", "Shadow", "damage"]],
    shaman: [["elemental", "Elemental", "damage"], ["enhancement", "Enhancement", "damage"], ["restoration", "Restoration", "healer"]],
    mage: [["arcane", "Arcane", "damage"], ["fire", "Fire", "damage"], ["frost", "Frost", "damage"]],
    warlock: [["affliction", "Affliction", "damage"], ["demonology", "Demonology", "damage"], ["destruction", "Destruction", "damage"]],
    druid: [["balance", "Balance", "damage"], ["feral", "Feral (bear)", "tank"], ["feralcat", "Feral (cat)", "damage"], ["restoration", "Restoration", "healer"]],
  };
  const CLASS_NAMES = { warrior: "Warrior", paladin: "Paladin", hunter: "Hunter", rogue: "Rogue", priest: "Priest", shaman: "Shaman", mage: "Mage", warlock: "Warlock", druid: "Druid" };
  const ARMOR = { warrior: "plate", paladin: "plate", hunter: "mail", shaman: "mail", rogue: "leather", druid: "leather", priest: "cloth", mage: "cloth", warlock: "cloth" };
  const MELEE = new Set(["warrior:arms", "warrior:fury", "paladin:retribution", "rogue:assassination", "rogue:combat", "rogue:subtlety", "shaman:enhancement", "druid:feralcat"]);
  // Races per class look (portrait 0 and 1), Alliance only with Classic rules (dwarf shamans per WoW: Forever).
  const RACES = { warrior: ["Human", "Dwarf"], paladin: ["Human", "Dwarf"], hunter: ["Night Elf", "Dwarf"], rogue: ["Human", "Gnome"],
    priest: ["Human", "Night Elf"], shaman: ["Dwarf", "Dwarf"], mage: ["Human", "Gnome"], warlock: ["Human", "Gnome"], druid: ["Night Elf", "Night Elf"] };
  const NAMES = ["Brannoc", "Mira", "Kess", "Tor", "Ash", "Lumi", "Orrin", "Mortis", "Sela", "Bram", "Ilo", "Fen", "Vey", "Rook", "Dax", "Wynn",
    "Thessa", "Grumli", "Pip", "Valen", "Odda", "Fizzwick", "Rhosyn", "Hask", "Nell", "Dorrin", "Quill", "Saffi", "Bolt", "Merrow", "Tamsin",
    "Hob", "Kaelen", "Briska", "Ulf", "Yara", "Gimble", "Ostra", "Penn", "Wix", "Corra", "Edda", "Larkin", "Moss", "Rurik", "Sprocket", "Tilly", "Vosk"];

  const RARITY = { common: { cost: 50, label: "Common" }, rare: { cost: 300, label: "Rare" }, epic: { cost: 1500, label: "Epic" } };
  const ECON = {
    startGold: 300, weeklyQuests: 300,                     // PLAYTEST: daily quests compressed into one weekly payout
    normalFirst: { gold: 40, dkp: 5 }, normalReclear: 5, heroicKill: { gold: 60, dkp: 15 },
    dungeon: { gold: [35, 45], perWeek: 8, itemChance: 35, itemLvl: [50, 56] },  // PLAYTEST: 8 runs a week, items 50-56
    cauldron: { food: 10, elixirs: 30, flasks: 75 }, potion: 15, worldBuff: 250, fireGear: 120,
    reroll: 25, rosterMax: 15, dismissBack: 25,             // dismiss returns 25% of the recruit price
    normalLoot: [56, 62], heroicLoot: [64, 70], heroicBand: [60, 70], startGear: [52, 56],
  };
  const MODES = { normal: { label: "Normal" }, heroic: { label: "Heroic" } };
  const CARDS = { spread: "Spread", stack: "Stack", burn: "Burn", playsafe: "Play Safe" };
  const CARD_TEXT = { spread: "Splash hits one character; healing -10%", stack: "Healing +15%; area hits land on everyone nearby",
    burn: "Damage +10%, threat +25%; heals cost 20% more mana", playsafe: "Damage -5%; everyone takes 15% less" };

  // Traits (design doc 4.4). Fight effects run in the engine; the guild effects (loot, morale, quitting) run here.
  const TRAITS = {
    pulls_on_cooldown: { name: "Pulls on Cooldown", text: "+20% damage and threat, but starts the pull before the healers finish drinking (healers at 60% mana)." },
    needs_on_everything: { name: "Needs on Everything", text: "15% chance to grab loot you gave someone else." },
    stands_in_fire: { name: "Stands in Fire", text: "Takes 25% more damage from boss mechanics." },
    never_stands_in_fire: { name: "Never Stands in Fire", text: "Immune to ground effects: Magma Splash, the Frown, someone else's bomb. Rare." },
    afk_on_trash: { name: "AFK on Trash", text: "Skips the trash gauntlet. (Trash arrives later; no effect in this build.)" },
    main_spec_loot_only: { name: "Main-Spec Loot Only", text: "Loses 3 morale whenever someone else gets gear." },
    raid_leaders_favourite: { name: "Raid Leader's Favourite", text: "+10 morale for everyone in the raid while present." },
    parse_goblin: { name: "Parse Goblin", text: "+15% damage, but ignores mechanics: 20% more mechanic damage." },
    alt_tabbed: { name: "Alt-Tabbed", text: "10% chance each round to do nothing at all." },
    partner_aggro: { name: "Partner Aggro", text: "20% chance per pull to log off after round 10. \"Sorry guys, gotta go.\"" },
    discord_lawyer: { name: "Discord Lawyer", text: "Loot drama happens twice as often." },
    rage_quitter: { name: "Rage Quitter", text: "On a wipe, 10% chance to quit the guild on the spot." },
    hardcore_andy: { name: "Hardcore Andy", text: "+10% health and power. Refuses Battle Res on principle." },
    backseat_raid_leader: { name: "Backseat Raid Leader", text: "Makes the tactic card 5% stronger; costs the raid 2 morale per pull." },
    keyboard_turner: { name: "Keyboard Turner", text: "-2 speed, but never pulls aggro." },
    main_character: { name: "Main Character Syndrome", text: "+10% power for the week after getting loot; others who wanted it lose 2 morale." },
    gear_score_elitist: { name: "Gear Score Elitist", text: "Loses 1 morale per pull for each raider below their gear level." },
    pug_hero: { name: "Pug Hero", text: "+10% power with at least two new recruits (joined in the last 2 weeks) in the raid." },
    pet_on_aggressive: { name: "Pet on Aggressive", text: "15% chance per pull to bring an extra pack for the first 3 rounds." },
  };
  const MORALE = { start: 70, kill: 3, loot: 6, wipe: 3, wipesCounted: 3, benched: 15, drift: 10, vibe: 80, low: 20 };  // Tuning pass 5: smaller steps so a winning raid hovers near 80 instead of living above it
  function rollTraits(st, cls, rarity, r0) {
    // Weighted by class and rarity (design doc 4.4): tanks pull, rogues need, hunters' pets wander; rage quitters are never epic.
    const isTank = r0 === "tank";
    const pool = [];
    for (const id of Object.keys(TRAITS)) {
      let w = 10;
      if (id === "pulls_on_cooldown") w = isTank ? 40 : 0;
      if (id === "needs_on_everything") w = cls === "rogue" ? 40 : 8;
      if (id === "pet_on_aggressive") w = cls === "hunter" ? 40 : 0;
      if (id === "never_stands_in_fire") w = rarity === "common" ? 0 : rarity === "rare" ? 4 : 12;
      if (id === "rage_quitter") w = rarity === "epic" || rarity === "legendary" ? 0 : 8;
      if (id === "keyboard_turner" && isTank) w = 0;
      pool.push([id, w]);
    }
    const out = []; const n = rint(st, 100) <= 35 ? 2 : 1;
    for (let k = 0; k < n; k++) {
      const total = pool.reduce((a, [id, w]) => a + (out.includes(id) ? 0 : w), 0);
      let x = rint(st, total);
      for (const [id, w] of pool) { if (out.includes(id)) continue; if (x <= w) { out.push(id); break; } x -= w; }
    }
    return out;
  }
  function moraleAdd(st, c, d, why, log) {
    const before = c.morale; c.morale = Math.max(0, Math.min(100, c.morale + d));
    if (log && c.morale !== before) log.push({ id: c.id, name: c.name, d: c.morale - before, why });
  }

  // Bosses: journal entries (found by seeing them), lines and lessons for the wipe recap.
  const BOSSES = [
    { id: "magmadad", name: "Magmadad", card: "burn",
      pull: "\"Hi raid, I'm Magmadad.\"", kill: "\"I'm not mad. I'm disappointed. And dead.\"",
      jokes: ["\"Why did the raid wipe? It couldn't handle the pressure. Like magma.\"", "\"I'd tell you a joke about pups, but you never finish them.\"", "\"Did you get my good side? Both of them are molten.\""],
      abilities: [
        { id: "pups", codes: [60], name: "Magma pups", text: "Three pups join the fight and pulse fire on everyone while they live." },
        { id: "revive", codes: [65], b: 0, name: "Walk it off, champ", text: "Dead pups get back up unless all three go down within a round of each other." },
        { id: "timeout", codes: [65], b: 1, name: "Timeout", text: "Kill all three pups together and they stay down. Only then does the raid turn on Magmadad." },
      ],
      loot: { weapon: ["Dad's Grill Spatula", "Molten Tongs of Supervision"], armor: ["Sensible Magma Sandals", "Cardigan of Mild Disappointment"], trinket: ["World's Okayest Dad Mug", "Pup Treat Pouch"] } },
    { id: "baron", name: "Baron Get-Down", card: "spread",
      pull: "\"Somebody's going to explode. Might as well be you.\"", kill: "\"I... got... down...\"",
      jokes: ["Raid leader: \"If you're the bomb, GET DOWN. Out of the group. Not into the healers.\""],
      abilities: [
        { id: "mark", codes: [61], name: "Living Bomb", text: "Every round from round 2, a non-tank becomes the bomb." },
        { id: "boom", codes: [62], name: "Get Down", text: "Next round the bomb goes off on everyone standing near the carrier." },
      ],
      loot: { weapon: ["Fuse-Lit Shortsword", "Baron's Detonator Baton"], armor: ["Blast-Proof Pantaloons", "Singed Dancing Shoes"], trinket: ["Ticking Pocketwatch", "Earplugs of the Baron"] } },
    { id: "lucifrown", name: "Lucifrown", card: "playsafe",
      pull: "\"Who brought decurse? Anyone at all?\"", kill: "\"Fine. Smile, then. See if I care.\"",
      jokes: ["Lucifrown frowns harder. Somebody forgot something."],
      abilities: [
        { id: "volley", codes: [1], name: "Shadow Volley", text: "Shadow damage on everyone, every round. Armor does nothing against it." },
        { id: "curse", codes: [66], name: "Curse of Frowning", text: "Every 3rd round a curse doubles mana costs for 3 rounds. A mage or druid decurses it in 1." },
        { id: "frown", codes: [68], name: "The Frown", text: "Every 3rd round he frowns at one zone of the raid. Hard." },
      ],
      loot: { weapon: ["Scepter of Mild Contempt", "Grumpy Rod"], armor: ["Robes of Resting Frown", "Furrowed Brow Helm"], trinket: ["Decurse Reminder Note", "Smiley Badge (Defaced)"] } },
    { id: "majordomo", name: "Majordomo Exhaustus", card: "stack",
      pull: "\"Fine. FINE. Interns! Deal with it.\"", kill: "Majordomo Exhaustus gives up, files a complaint and leaves a bonus chest.",
      jokes: ["\"I'll go and wake the boss. Again.\""],
      abilities: [
        { id: "interns", codes: [63], name: "Eight interns", text: "Eight interns fight first. They hit whoever is closest, which is everyone." },
        { id: "joins", codes: [64], name: "Fine. FINE.", text: "He joins only when every intern is down." },
      ],
      loot: { weapon: ["Clipboard of Authority", "Stapler of Smiting"], armor: ["Overtime Vestments", "Lanyard Mail"], trinket: ["Complaint Form 27-B", "Executive Stress Ball"] } },
    { id: "ragnaroast", name: "Ragnaroast", card: "burn",
      pull: "\"The trash is still out there. I can hear it.\"", kill: "\"Too soon... you have roasted me... too soon!\"",
      jokes: ["\"Your tank's gear is from a dungeon. A bad one.\"", "\"Is that your healer or a decorative candle?\"", "\"I've seen better positioning in a lava lamp.\""],
      abilities: [
        { id: "throw", codes: [23], name: "Into the lava", text: "Every 4 rounds he throws the lowest-health melee character into the lava. Fire Protection Potions cancel one throw each." },
        { id: "splash", codes: [25], name: "Magma Splash", text: "Fire on one zone every 2nd round." },
        { id: "submerge", codes: [20], name: "Sinks and sends adds", text: "From round 10 he sinks for 3 rounds and sends fire adds. Everything he does is fire." },
      ],
      loot: { weapon: ["Sulfurous Rolling Pin", "Roasting Spit of the Firelord"], armor: ["Oven Mitts of Might", "Crispy Chainmail"], trinket: ["Eye of Ragnaroast (Medium Rare)", "Marinade of Fury"] } },
  ];
  const BOSS = Object.fromEntries(BOSSES.map(b => [b.id, b]));

  // Lessons: the wipe recap picks the first lesson whose test matches, then shows the tier the raid has
  // reached: what happened, a raid leader clue, then the answer (design: learning path, 2026-11-18).
  const LESSONS = {
    magmadad: [
      { id: "card", test: f => f.revives > 0 && f.tactic !== "burn", t: [
        "The pups got back up {revives} times. Magmadad himself barely took damage.",
        "Raid leader: \"We keep killing pups one at a time and they just stand back up. We need to hit way harder, all at once.\"",
        "Use Burn: +10% damage gets all three pups down inside the window, and then they stay down." ] },
      { id: "dps", test: f => f.revives > 0, t: [
        "The pups got back up {revives} times even on Burn.",
        "Raid leader: \"Burn is right, we just don't have the damage. Food, elixirs, flasks?\"",
        "You're on the right card. More damage: elixirs and flasks, better gear from Normal kills, or more damage dealers." ] },
    ],
    baron: [
      { id: "card", test: f => f.bombZone > 0 && f.tactic !== "spread", t: [
        "The bomb went off in a crowd {bombZone} times and took {bombDeaths} people with it.",
        "Raid leader: \"If you're the bomb, GET DOWN. Out of the group. Not into the healers.\"",
        "Use Spread: the bomb carrier runs out and only they get hit." ] },
    ],
    lucifrown: [
      { id: "decurse", test: f => !f.decurser, t: [
        "Every curse lasted 3 rounds and doubled your mana costs. Your healers ran dry.",
        "Lucifrown: \"Who brought decurse? Anyone at all?\"",
        "Bring a mage or a druid: they decurse, and the curse lasts 1 round instead of 3." ] },
      { id: "card", test: f => f.tactic !== "playsafe", t: [
        "The Shadow Volley never stops. {volleyDeaths} died to it before the boss did.",
        "Raid leader: \"This is a marathon. We can't heal through all of this, can we take less of it?\"",
        "Use Play Safe: everyone takes 15% less, and the volley is the whole fight." ] },
    ],
    majordomo: [
      { id: "card", test: f => f.tactic !== "stack", t: [
        "The interns took {internRounds} rounds to clear before Majordomo even showed up.",
        "Raid leader: \"The interns are everywhere. Pull them together so every hit counts twice.\"",
        "Use Stack: the interns bunch up and every hit splashes onto another one. Healing is better too." ] },
    ],
    ragnaroast: [
      { id: "fire", test: f => f.fireDeaths >= 2 && f.fireGear < 6, t: [
        "{fireDeaths} died to fire: the lava, Magma Splash and the fire adds.",
        "Ragnaroast: \"Is that your healer or a decorative candle?\" Raid leader: \"We're melting. Literally.\"",
        "Fire resistance: Fire Whelp gear from the Tavern and Fire Protection Potions for the melee and tanks. Only here, though." ] },
      { id: "card", test: f => f.tactic !== "burn", t: [
        "The fire wasn't the problem. Ragnaroast was at {bossPct}% when the time was up, or close to it.",
        "Raid leader: \"He sinks at round 10. We need him low before he does.\"",
        "Use Burn: it's a race against the submerge and the enrage." ] },
    ],
  };
  const GENERIC = [
    { id: "tanks", test: f => f.result === "wipe" && f.tankDeaths >= 1 && f.healers < 2, t: [
      "Your tanks died and there weren't enough healers to keep up.",
      "Raid leader: \"Two healers minimum. Three if it hurts.\"",
      "Bring 2-3 healers. The game lets you try anything, but tanks without healers fold." ] },
    { id: "prep", test: f => f.mode === "heroic" && !(f.cons.elixirs && f.cons.flasks), t: [
      "Heroic is tuned for a raid that brings consumables. You didn't.",
      "Raid leader: \"Flasks. Elixirs. It's Heroic. Come on.\"",
      "Buy the cauldrons in prep: elixirs and flasks are worth 15-20 points on Heroic." ] },
    { id: "dps", test: f => f.result === "enrage", t: [
      "The boss was at {bossPct}% when the clock ran out.",
      "Raid leader: \"We're close. A little more damage and it's dead.\"",
      "More damage: consumables, gear from earlier bosses, or swap a healer for a damage dealer if you're surviving easily." ] },
    { id: "deaths", test: f => true, t: [
      "Too many people died: {deaths} in total.",
      "Raid leader: \"Check who's dying to what in the log. That's the fight telling you something.\"",
      "Check the journal for this boss: each one has one main answer, and the recap points at it as you learn." ] },
  ];
  // Death and moment codes in the engine log (engine/sim.lua).
  const CAUSE = { 23: "lava throw", 24: "boss melee", 25: "Magma Splash", 26: "adds", 62: "bomb", 67: "Shadow Volley", 68: "the Frown" };

  // Small seeded RNG for game-side rolls (loot, tavern, names), saved with the game.
  function rngNext(st) { st.rng = (st.rng * 16807) % 2147483647; return st.rng; }
  function rint(st, n) { return 1 + (rngNext(st) % n); }      // 1..n
  function rrange(st, a, b) { return a + (rngNext(st) % (b - a + 1)); }
  function pick(st, list) { return list[rngNext(st) % list.length]; }

  function role(cls, spec) { return SPECS[cls].find(s => s[0] === spec)[2]; }
  function specName(cls, spec) { return SPECS[cls].find(s => s[0] === spec)[1]; }
  function defaultZone(c) {
    const r = role(c.cls, c.spec);
    if (r === "tank") return "front"; if (r === "healer") return "back";
    return MELEE.has(c.cls + ":" + c.spec) ? "melee" : "ranged";
  }
  function gearLevel(c) { return Math.round((c.gear.weapon.lvl + c.gear.armor.lvl + c.gear.trinket.lvl) / 3); }
  function canWear(c, item) { return item.slot !== "armor" || item.type === ARMOR[c.cls]; }

  function freshName(st) {
    const used = new Set(st.roster.map(c => c.name).concat(st.tavern ? st.tavern.map(o => o.name) : []));
    for (let i = 0; i < 60; i++) { const n = pick(st, NAMES); if (!used.has(n)) return n; }
    return "Raider " + st.nextId;
  }
  function makeChar(st, cls, spec, rarity, lvlRange) {
    const look = rngNext(st) % 2;
    const c = { id: st.nextId++, name: freshName(st), cls, spec, look, race: RACES[cls][look], rarity,
      gear: {}, fire: 0, benched: false, joined: st.week,
      skill10: ({ common: 20, rare: 40, epic: 55, legendary: 70 })[rarity] * 10, fam10: {}, pulls: {},
      traits: rollTraits(st, cls, rarity, role(cls, spec)), morale: MORALE.start, looted: false };
    const [a, b] = lvlRange || ECON.startGear;
    c.gear.weapon = { name: "Starter " + (role(cls, spec) === "healer" ? "Staff" : "Weapon"), slot: "weapon", lvl: rrange(st, a, b), q: "common" };
    c.gear.armor = { name: "Hand-me-down " + ARMOR[cls][0].toUpperCase() + ARMOR[cls].slice(1), slot: "armor", type: ARMOR[cls], lvl: rrange(st, a, b), q: "common" };
    c.gear.trinket = { name: "Lucky Rabbit's Foot", slot: "trinket", lvl: rrange(st, a, b), q: "common" };
    return c;
  }

  function newGame(seed) {
    const st = { seed: seed, rng: (seed % 2147483646) + 1, week: 1, gold: ECON.startGold, dkp: 0, nextId: 1,
      roster: [], bonds: {}, buffs: {}, journal: {}, lessons: {}, progress: {}, history: [], loot: [], dungeonsLeft: ECON.dungeon.perWeek,
      rerolls: 0, replays: {}, pulls: 0, news: [], score: { kills: 0, wipes: 0, rounds: 0 }, bestScore: 0, v: 2 };
    // A sensible but uneven starting guild: 2 tanks, 3 healers, 7 damage dealers, mostly common.
    const start = [["warrior", "protection", "rare"], ["paladin", "protection", "common"], ["priest", "holy", "rare"], ["shaman", "restoration", "common"],
      ["druid", "restoration", "common"], ["rogue", "combat", "common"], ["warrior", "fury", "common"], ["hunter", "marksmanship", "rare"],
      ["warlock", "affliction", "common"], ["priest", "shadow", "common"], ["hunter", "beastmastery", "common"], ["paladin", "retribution", "common"]];
    for (const [c, s, r] of start) st.roster.push(makeChar(st, c, s, r));
    for (const b of BOSSES) st.progress[b.id] = { normalKills: 0, heroicKills: 0, normalWeek: false, heroicWeek: false, heroicWipes: 0, pulls: 0, wipes: 0 };
    rollTavern(st);
    st.news.push("Week 1. Your guild has 12 raiders, 300 gold and a raid to clear. Start with Magmadad on Normal.");
    return st;
  }

  function rollTavern(st) {
    st.tavern = [];
    const classes = Object.keys(SPECS);
    for (let i = 0; i < 5; i++) {
      let cls = pick(st, classes);
      if (cls === "warlock" && rint(st, 100) > 25) cls = pick(st, classes.filter(c => c !== "warlock")); // warlocks are rare
      const spec = pick(st, SPECS[cls])[0];
      const r = rint(st, 100); const rarity = r <= 70 ? "common" : r <= 95 ? "rare" : "epic";
      const c = makeChar(st, cls, spec, rarity, [ECON.startGear[0] - 2, ECON.startGear[1] - 2]);
      c.price = RARITY[rarity].cost;
      st.tavern.push(c);
    }
  }

  // ---- Progression (mirrors engine/progress.lua; the rules are read from the engine at start-up). ----
  let RULES = { counted_pulls: 3, skill_wipe: 6, skill_kill: 12, skill_soft: 700, fam_wipe: 3, fam_kill: 6, fam_cap: 100, chem_pull: 4, chem_week: 15, chem_cap: 200 };
  function setRules(r) { RULES = Object.assign({}, RULES, r); }
  const bondKey = (a, b) => a < b ? a + "|" + b : b + "|" + a;
  function bond(st, a, b) { const e = st.bonds[bondKey(a, b)]; return e ? e.v10 : 0; }
  function afterPull(st, ids, boss, killed) {
    for (const id of ids) {
      const m = byId(st, id); const n = (m.pulls[boss] || 0) + 1; m.pulls[boss] = n;
      if (n <= RULES.counted_pulls) {
        let gain = killed ? RULES.skill_kill : RULES.skill_wipe;
        if (m.skill10 >= RULES.skill_soft) gain = Math.floor(gain / 2);
        m.skill10 = Math.min(1000, m.skill10 + gain);
        m.fam10[boss] = Math.min(RULES.fam_cap, (m.fam10[boss] || 0) + (killed ? RULES.fam_kill : RULES.fam_wipe));
      }
    }
    for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) {
      const k = bondKey(ids[i], ids[j]); const e = st.bonds[k] || (st.bonds[k] = { v10: 0, week: 0 });
      const add = Math.max(0, Math.min(RULES.chem_pull, RULES.chem_week - e.week, RULES.chem_cap - e.v10));
      e.v10 += add; e.week += add;
    }
  }
  function byId(st, id) { return st.roster.find(c => c.id === id); }
  function famAvg(st, ids, boss) { if (!ids.length) return 0; return ids.reduce((s, id) => s + ((byId(st, id) || { fam10: {} }).fam10[boss] || 0), 0) / ids.length / 10; }
  function cohesion(st, ids) { let s = 0, n = 0; for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) { s += bond(st, ids[i], ids[j]); n++; } return n ? s / n / 10 : 0; }

  // Heroic score this week (design doc 11): +1,000 a kill, -150 a wipe, -50 per benched raider, +5 per round under 20 at each kill.
  function heroicScore(st) {
    const sc = st.score || { kills: 0, wipes: 0, rounds: 0 };
    return sc.kills * 1000 - sc.wipes * 150 - st.roster.filter(c => c.benched).length * 50 + sc.rounds * 5;
  }
  // ---- Availability ----
  function unlocked(st, boss, mode) {
    const i = BOSSES.findIndex(b => b.id === boss);
    if (mode === "normal") return i === 0 || st.progress[BOSSES[i - 1].id].normalKills > 0;
    // Heroic: attuned by a Normal Ragnaroast kill (design 10.7, shortened for the playtest), then in order.
    if (st.progress.ragnaroast.normalKills === 0) return false;
    // Director, 2026-11-18: the lockout runs in order; each Heroic boss opens once the one before is down this week.
    return i === 0 || st.progress[BOSSES[i - 1].id].heroicWeek;
  }
  function heroicOpen(st) { return st.progress.ragnaroast.normalKills > 0; }

  // ---- Prep and pull ----
  function defaultPrep(st, boss, mode) {
    const avail = st.roster.filter(c => !(mode === "heroic" && c.benched));
    const pickRole = (r, n) => avail.filter(c => role(c.cls, c.spec) === r).sort((a, b) => gearLevel(b) - gearLevel(a)).slice(0, n);
    let ids = pickRole("tank", 2).concat(pickRole("healer", 3));
    const dps = avail.filter(c => role(c.cls, c.spec) === "damage").sort((a, b) => gearLevel(b) - gearLevel(a));
    ids = ids.concat(dps.slice(0, 10 - ids.length));
    if (ids.length < 10) ids = ids.concat(avail.filter(c => !ids.includes(c)).slice(0, 10 - ids.length));
    const prep = { boss, mode, ids: ids.map(c => c.id), zones: {}, tactic: "spread", cons: { food: false, elixirs: false, flasks: false },
      potions: {}, fireOn: {}, buffs: {} };
    for (const c of ids) { prep.zones[c.id] = defaultZone(c); prep.fireOn[c.id] = 0; }
    const last = st.lastPrep && st.lastPrep[boss + ":" + mode];
    if (last) { prep.tactic = last.tactic; prep.cons = Object.assign({}, last.cons); }
    return prep;
  }
  function prepCost(st, prep) {
    const hasMage = prep.ids.some(id => byId(st, id).cls === "mage");
    let g = 0; const items = [];
    if (prep.cons.food) { const p = hasMage ? 0 : ECON.cauldron.food; g += p; items.push(["Food cauldron" + (hasMage ? " (the mage made the table)" : ""), p]); }
    if (prep.cons.elixirs) { g += ECON.cauldron.elixirs; items.push(["Elixir cauldron", ECON.cauldron.elixirs]); }
    if (prep.cons.flasks) { g += ECON.cauldron.flasks; items.push(["Flask cauldron", ECON.cauldron.flasks]); }
    const pots = prep.ids.filter(id => prep.potions[id]).length;
    if (pots) { g += pots * ECON.potion; items.push([pots + " Fire Protection Potion" + (pots > 1 ? "s" : ""), pots * ECON.potion]); }
    for (const b of ["dragonslayer", "songbloom", "warchief"]) if (prep.buffs[b] && !st.buffs[b]) { g += ECON.worldBuff; items.push([WB[b], ECON.worldBuff]); }
    return { gold: g, items };
  }
  const WB = { dragonslayer: "Dragonslayer's Roar", songbloom: "Songbloom Blessing", warchief: "Spirit of the Warchief's Rival" };

  function problems(st, prep) {
    const out = [];
    const p = st.progress[prep.boss];
    if (!unlocked(st, prep.boss, prep.mode)) out.push("Locked: kill the boss before it first" + (prep.mode === "heroic" ? " (and Ragnaroast on Normal for Heroic)" : "") + ".");
    if (prep.mode === "heroic" && p.heroicWeek) out.push(BOSS[prep.boss].name + " is already dead on Heroic this week. The lockout resets next week.");
    if (prep.ids.length < 1) out.push("Pick at least one raider.");
    if (prep.ids.length > 10) out.push("Raids take 10.");
    if (prep.mode === "heroic" && prep.ids.some(id => byId(st, id).benched)) out.push("A benched raider can't come to Heroic this week.");
    const cost = prepCost(st, prep).gold;
    if (cost > st.gold) out.push("Not enough gold for this prep (" + cost + " needed).");
    return out;
  }
  function warnings(st, prep) {
    const roles = prep.ids.map(id => { const c = byId(st, id); return role(c.cls, c.spec); });
    const w = [];
    const t = roles.filter(r => r === "tank").length, h = roles.filter(r => r === "healer").length;
    if (prep.ids.length < 10) w.push("Only " + prep.ids.length + " raiders. You can pull, but it's hard.");
    if (t < 2) w.push(t === 0 ? "No tank. Bold." : "Only one tank.");
    if (h < 2) w.push(h === 0 ? "No healers." : "Only one healer.");
    for (const id of prep.ids) {
      const c = byId(st, id); const z = prep.zones[id]; const r = role(c.cls, c.spec);
      if (MELEE.has(c.cls + ":" + c.spec) && z !== "melee") w.push(c.name + " fights in melee but stands in " + z + ": half damage.");
      if (r === "tank" && z !== "front") w.push(c.name + " is a tank outside Front: half damage, and the boss may not stay on them.");
    }
    return w;
  }

  function seedFor(st, prep) {
    let h = (st.seed % 100000) * 7 + st.week * 131 + BOSSES.findIndex(b => b.id === prep.boss) * 17 + (prep.mode === "heroic" ? 5 : 0) + st.pulls * 977;
    h = h % 2147483646; return h + 1;
  }
  function buildInput(st, prep, seed) {
    const raid = prep.ids.map(id => {
      const c = byId(st, id); let gl = gearLevel(c);
      if (prep.mode === "heroic") gl = Math.min(ECON.heroicBand[1], Math.max(ECON.heroicBand[0], gl));
      return { name: c.name, class: c.cls, spec: c.spec, zone: prep.zones[id], potion: !!prep.potions[id], firegear: Math.min(c.fire, prep.fireOn[id] || 0),
        skill: Math.floor(c.skill10 / 10), fam: Math.floor((c.fam10[prep.boss] || 0) / 10), gl,
        traits: c.traits.slice(0, 2), morale: c.morale, new: st.week - c.joined < 2, looted: !!c.looted };
    });
    const pairs = [];
    for (let i = 0; i < prep.ids.length; i++) for (let j = i + 1; j < prep.ids.length; j++) {
      const v = Math.floor(bond(st, prep.ids[i], prep.ids[j]) / 10); if (v > 0) pairs.push({ a: i + 1, b: j + 1, v });
    }
    const buffs = {}; for (const b of ["dragonslayer", "songbloom", "warchief"]) buffs[b] = !!(st.buffs[b] || prep.buffs[b]);
    return { boss: prep.boss, mode: prep.mode, seed, tactic: prep.tactic, gl: 60, consumables: Object.assign({}, prep.cons), buffs, raid, pairs };
  }

  function facts(st, prep, input, r) {
    const ev = r.events;
    const deathsBy = {}; let deaths = 0;
    for (const e of ev) if (e.c === 31) { deaths++; deathsBy[e.b] = (deathsBy[e.b] || 0) + 1; }
    const tankDeaths = ev.filter(e => e.c === 31 && r.raid[e.a - 1] && r.raid[e.a - 1].role === "tank").length;
    const healers = input.raid.filter(c => role(c.class, c.spec) === "healer").length;
    const firstIntern = ev.find(e => e.c === 63), joined = ev.find(e => e.c === 64);
    return { result: r.result, tactic: prep.tactic, mode: prep.mode, cons: prep.cons, deaths, tankDeaths, healers,
      revives: ev.filter(e => e.c === 65 && e.b === 0).length,
      bombZone: ev.filter(e => e.c === 62 && e.b > 1).length, bombDeaths: deathsBy[62] || 0,
      decurser: input.raid.some(c => c.class === "mage" || c.class === "druid"),
      volleyDeaths: deathsBy[67] || 0,
      internRounds: joined ? joined.r - 1 : (firstIntern ? r.rounds : 0),
      fireDeaths: (deathsBy[23] || 0) + (deathsBy[25] || 0) + (deathsBy[26] || 0),
      fireGear: input.raid.reduce((s, c) => s + (c.firegear || 0), 0),
      bossPct: Math.round(100 * r.bossHp / r.bossMax) };
  }
  function fill(t, f) { return t.replace(/\{(\w+)\}/g, (_, k) => f[k]); }
  function lessonFor(st, prep, f, onKill) {
    // On a kill only the boss's own lessons count ("you won, but..."), so Normal teaches even when it goes well.
    const list = onKill ? (LESSONS[prep.boss] || []).filter(l => l.id !== "dps") : (LESSONS[prep.boss] || []).concat(GENERIC);
    const L = list.find(l => l.test(f));
    if (!L) return null;
    const key = prep.boss + ":" + L.id;
    const seen = (st.lessons[key] || 0) + 1; st.lessons[key] = seen;
    const fam = famAvg(st, prep.ids, prep.boss);
    // Tier: whichever is further along, how often this lesson came up or how well the raid knows the boss.
    const tier = Math.min(2, Math.max(seen >= 4 ? 2 : seen >= 2 ? 1 : 0, fam >= 6 ? 2 : fam >= 3 ? 1 : 0));
    return { id: L.id, tier, text: fill(L.t[tier], f), seen, next: tier < 2 ? (tier === 0 ? "More will make sense as your raid learns this fight." : "Your raid is close to working it out.") : "" };
  }

  function makeItem(st, boss, mode) {
    const slot = pick(st, ["weapon", "armor", "trinket"]);
    const [a, b] = mode === "heroic" ? ECON.heroicLoot : ECON.normalLoot;
    const it = { name: pick(st, BOSS[boss].loot[slot]), slot, lvl: rrange(st, a, b), q: "epic", from: BOSS[boss].name + " (" + MODES[mode].label + ")" };
    if (slot === "armor") it.type = pick(st, ["plate", "mail", "leather", "cloth"]);
    return it;
  }
  function suggest(st, item, ids) {
    let best = null, gain = 0;
    for (const id of ids) {
      const c = byId(st, id); if (!c || !canWear(c, item)) continue;
      const g = item.lvl - c.gear[item.slot].lvl;
      if (g > gain) { gain = g; best = c.id; }
    }
    return best ? { to: best, gain } : { to: "sell", gain: 0 };
  }
  function sellValue(item) { return Math.max(1, Math.round(item.lvl / 4)); }

  function journalFind(st, boss, r) {
    const j = st.journal[boss] || (st.journal[boss] = {});
    const found = [];
    for (const a of BOSS[boss].abilities) {
      if (j[a.id]) continue;
      if (r.events.some(e => a.codes.includes(e.c) && (a.b === undefined || e.b === a.b))) { j[a.id] = st.week; found.push(a.name); }
    }
    return found;
  }

  // Runs the pull through the engine and applies everything that follows. engine(input) returns the parsed result.
  function pull(st, prep, engine) {
    prep.ids = prep.ids.filter(id => byId(st, id));  // someone may have quit since this plan was made
    const bad = problems(st, prep); if (bad.length) return { error: bad[0] };
    const cost = prepCost(st, prep);
    st.gold -= cost.gold;
    for (const b of ["dragonslayer", "songbloom", "warchief"]) if (prep.buffs[b]) st.buffs[b] = true;
    const seed = seedFor(st, prep); st.pulls++;
    const input = buildInput(st, prep, seed);
    const r = engine(Object.assign({}, input, { frames: [] }));
    const killed = r.result === "kill";
    const p = st.progress[prep.boss];
    const out = { boss: prep.boss, mode: prep.mode, result: r.result, run: r, input, seed, spent: cost.gold, gold: 0, dkp: 0, loot: [], benched: [], repair: 0 };
    p.pulls++;
    if (killed) {
      if (prep.mode === "normal") {
        if (!p.normalWeek) { p.normalWeek = true; out.gold += ECON.normalFirst.gold; out.dkp += ECON.normalFirst.dkp; out.loot = [makeItem(st, prep.boss, "normal"), makeItem(st, prep.boss, "normal")]; out.lockout = true; }
        else { out.gold += ECON.normalReclear; out.reclear = true; }
        p.normalKills++;
      } else {
        out.gold += ECON.heroicKill.gold; out.dkp += ECON.heroicKill.dkp; out.loot = [makeItem(st, prep.boss, "heroic"), makeItem(st, prep.boss, "heroic")]; p.heroicKills++; p.heroicWeek = true;
        st.score.kills++; st.score.rounds += Math.max(0, 20 - r.rounds);
      }
    } else { p.wipes++; if (prep.mode === "heroic") { p.heroicWipes++; st.score.wipes++; } }
    // Repairs: 1 gold per 5 gear levels per death, x1.5 on a wipe. The first wipe per boss each week is free (learning path).
    const dead = r.raid.map((x, i) => x.alive ? null : prep.ids[i]).filter(x => x !== null);
    let rep = dead.reduce((s, id) => s + Math.round(gearLevel(byId(st, id)) / 5), 0);
    if (!killed) rep = Math.round(rep * 1.5);
    const freeKey = prep.boss + ":" + prep.mode;
    if (!killed && !(st.freeWipe || {})[freeKey]) { st.freeWipe = st.freeWipe || {}; st.freeWipe[freeKey] = true; out.repairWaived = rep; rep = 0; }
    out.repair = rep; st.gold = Math.max(0, st.gold - rep);
    if (!killed) { for (const b in st.buffs) if (st.buffs[b]) out.buffsLost = true; st.buffs = {}; }
    // Heroic: whoever died is benched for the rest of the lockout (design 4.5).
    if (prep.mode === "heroic") for (const id of dead) { const c = byId(st, id); c.benched = true; out.benched.push(c.name); }
    st.gold += out.gold; st.dkp += out.dkp;
    const before = prep.ids.map(id => ({ id, skill: byId(st, id).skill10, fam: byId(st, id).fam10[prep.boss] || 0 }));
    const cohBefore = cohesion(st, prep.ids);
    afterPull(st, prep.ids, prep.boss, killed);
    out.growth = { skill: before.reduce((s, b) => s + byId(st, b.id).skill10 - b.skill, 0) / before.length / 10,
      fam: before.reduce((s, b) => s + (byId(st, b.id).fam10[prep.boss] || 0) - b.fam, 0) / before.length / 10,
      chem: cohesion(st, prep.ids) - cohBefore, counted: before.some(b => (byId(st, b.id).pulls[prep.boss] || 0) <= RULES.counted_pulls) };
    // Morale and guild traits (design doc 4.4).
    const ml = []; out.morale = ml; out.quit = [];
    const inRaid = prep.ids.map(id => byId(st, id));
    // Only the first few wipes on a boss each week sting: after that everyone knew it would be a long night.
    for (const c of inRaid) {
      if (killed) moraleAdd(st, c, MORALE.kill, "kill", ml);
      else if ((c.pulls[prep.boss] || 0) <= MORALE.wipesCounted) moraleAdd(st, c, -MORALE.wipe, "wipe", ml);
    }
    if (prep.mode === "heroic") for (const id of dead) moraleAdd(st, byId(st, id), -MORALE.benched, "benched", ml);
    if (inRaid.some(c => c.traits.includes("backseat_raid_leader"))) for (const c of inRaid) if (!c.traits.includes("backseat_raid_leader")) moraleAdd(st, c, -2, "backseat raid leading", ml);
    for (const c of inRaid) if (c.traits.includes("gear_score_elitist")) {
      const below = inRaid.filter(x => x !== c && gearLevel(x) < gearLevel(c)).length; if (below) moraleAdd(st, c, -below, "carrying " + below + " undergeared raiders", ml);
    }
    if (!killed) for (const c of inRaid) {
      if (c.traits.includes("rage_quitter") && rint(st, 100) <= 10) {
        out.quit.push(c.name); dismissFree(st, c.id);
      }
    }
    out.found = journalFind(st, prep.boss, r);
    out.facts = facts(st, prep, input, r);
    if (!killed) { out.lesson = lessonFor(st, prep, out.facts, false); out.joke = pick(st, BOSS[prep.boss].jokes); }
    else if (out.facts.deaths >= 2 || prep.tactic !== BOSS[prep.boss].card) out.note = lessonFor(st, prep, out.facts, true);
    out.loot = out.loot.map(it => Object.assign(it, { assign: suggest(st, it, prep.ids).to, eligible: prep.ids.slice() }));
    st.pending = (st.pending || []).concat(out.loot);
    st.lastPrep = st.lastPrep || {}; st.lastPrep[prep.boss + ":" + prep.mode] = { tactic: prep.tactic, cons: Object.assign({}, prep.cons) };
    st.lastPull = { input, prep: JSON.parse(JSON.stringify(prep)), result: r.result, bossPct: Math.round(100 * r.bossHp / r.bossMax) };
    st.history.unshift({ week: st.week, boss: prep.boss, mode: prep.mode, result: r.result, rounds: r.rounds, tactic: prep.tactic });
    st.history = st.history.slice(0, 40);
    return out;
  }

  // Replay: the exact same pull with one change, no rewards (learning path). Once per boss per week, from familiarity 1.
  function replayInfo(st) {
    const lp = st.lastPull; if (!lp || lp.result === "kill") return { ok: false };
    const ids = lp.prep.ids; const fam = famAvg(st, ids, lp.prep.boss); const used = st.replays[lp.prep.boss + ":" + st.week];
    return { ok: !used, fam, used: !!used };  // gate review: replay is open from the first wipe
  }
  function replay(st, card, engine) {
    const info = replayInfo(st); if (!info.ok) return { error: "Replay isn't available." };
    st.replays[st.lastPull.prep.boss + ":" + st.week] = true;
    const input = Object.assign({}, st.lastPull.input, { tactic: card, frames: [] });
    return { run: engine(input), input, card };
  }

  function assign(st, item, to) {
    if (to === "sell") { st.gold += sellValue(item); return item.name + " sold for " + sellValue(item) + " gold."; }
    let c = byId(st, Number(to)); if (!c || !canWear(c, item)) return "Can't equip that.";
    let note = "";
    const group = (item.eligible || []).map(id => byId(st, id)).filter(Boolean);
    // Needs on Everything: someone else in the pull grabs it first.
    const needer = group.find(x => x !== c && x.traits.includes("needs_on_everything") && canWear(x, item) && rint(st, 1000) <= 150);
    if (needer) { note = " " + needer.name + " rolled Need on it first. Of course they did."; c = needer; }
    // Loot drama: 10% per item, twice as often with a Discord Lawyer around.
    const lawyer = group.some(x => x.traits.includes("discord_lawyer"));
    if (rint(st, 100) <= (lawyer ? 20 : 10)) {
      const others = group.filter(x => x !== c && canWear(x, item));
      if (others.length) { const o = others[rint(st, others.length) - 1]; moraleAdd(st, o, -5, "loot drama"); note += " Loot drama in Discord: " + o.name + " is upset (-5 morale)."; }
    }
    moraleAdd(st, c, MORALE.loot, "loot");
    for (const x of group) if (x !== c && x.traits.includes("main_spec_loot_only")) moraleAdd(st, x, -3, "someone else got gear");
    if (c.traits.includes("main_character")) {
      c.looted = true;
      for (const x of group) if (x !== c && canWear(x, item) && item.lvl > x.gear[item.slot].lvl) moraleAdd(st, x, -2, "wanted it");
    }
    const old = c.gear[item.slot]; c.gear[item.slot] = { name: item.name, slot: item.slot, type: item.type, lvl: item.lvl, q: item.q };
    return c.name + " equips " + item.name + " (" + old.lvl + " to " + item.lvl + ")." + note;
  }

  // Loot waiting for a decision. Boss loot goes to someone who was in the pull (Bind on Pickup).
  function assignPending(st, i, to) {
    const it = (st.pending || [])[i]; if (!it) return "";
    const msg = assign(st, it, to); if (msg !== "Can't equip that.") st.pending.splice(i, 1); return msg;
  }
  function suggestFor(st, it) { return suggest(st, it, (it.eligible || []).filter(id => byId(st, id))); }
  function dungeon(st) {
    if (st.dungeonsLeft <= 0) return { error: "No dungeon runs left this week." };
    st.dungeonsLeft--;
    const gold = rrange(st, ECON.dungeon.gold[0], ECON.dungeon.gold[1]); st.gold += gold;
    const out = { gold };
    if (rint(st, 100) <= ECON.dungeon.itemChance) {
      const slot = pick(st, ["weapon", "armor", "trinket"]);
      const it = { name: pick(st, { weapon: ["Scarlet Monotony Mace", "Deadmines Pickaxe", "Ratchet's Wrench"], armor: ["Robes of the Monotonous", "Gnomeregan Hand-me-downs", "Smoky Jerkin"], trinket: ["Lucky Coin", "Murloc Fin Charm", "Bent Spoon of Insight"] }[slot]),
        slot, lvl: rrange(st, ECON.dungeon.itemLvl[0], ECON.dungeon.itemLvl[1]), q: "rare", from: "Dungeon" };
      if (slot === "armor") it.type = pick(st, ["plate", "mail", "leather", "cloth"]);
      it.assign = suggest(st, it, st.roster.map(c => c.id)).to; it.eligible = st.roster.map(c => c.id);
      out.item = it; st.pending = (st.pending || []).concat([it]);
    }
    return out;
  }

  function hire(st, i) {
    const o = st.tavern[i]; if (!o) return "Gone.";
    if (st.roster.length >= ECON.rosterMax) return "Roster full (15). Dismiss someone first.";
    if (st.gold < o.price) return "Not enough gold.";
    st.gold -= o.price; o.joined = st.week; delete o.price; st.roster.push(o); st.tavern.splice(i, 1);
    return o.name + " joins the guild.";
  }
  function reroll(st) {
    const cost = ECON.reroll * Math.pow(2, st.rerolls);
    if (st.gold < cost) return "Not enough gold.";
    st.gold -= cost; st.rerolls++; rollTavern(st); return "New faces at the Tavern.";
  }
  function dismissFree(st, id) {  // quitting: no gold back, bonds gone
    st.roster = st.roster.filter(x => x.id !== id);
    for (const k of Object.keys(st.bonds)) if (k.split("|").includes(String(id))) delete st.bonds[k];
  }
  function dismiss(st, id) {
    const c = byId(st, id); if (!c) return "";
    st.gold += Math.round(RARITY[c.rarity].cost * ECON.dismissBack / 100);
    st.roster = st.roster.filter(x => x.id !== id);
    for (const k of Object.keys(st.bonds)) if (k.split("|").includes(String(id))) delete st.bonds[k];
    return c.name + " leaves the guild, and takes every friendship with them.";
  }
  function buyFire(st, id) {
    const c = byId(st, id); if (c.fire >= 2) return "Two pieces is the limit."; if (st.gold < ECON.fireGear) return "Not enough gold.";
    st.gold -= ECON.fireGear; c.fire++; return c.name + " gets a Fire Whelp piece (" + c.fire + " of 2).";
  }
  function respec(st, id, spec) {
    const c = byId(st, id); const cost = 60;  // PLAYTEST: flat respec price
    if (st.gold < cost) return "Not enough gold."; st.gold -= cost; c.spec = spec; return c.name + " is now " + specName(c.cls, spec) + ".";
  }

  function endWeek(st) {
    st.week++; st.gold += ECON.weeklyQuests; st.dungeonsLeft = ECON.dungeon.perWeek; st.rerolls = 0; st.buffs = {}; st.freeWipe = {};
    const quits = [];
    for (const c of st.roster.slice()) {
      if (c.morale < MORALE.low && rint(st, 100) <= 50) { quits.push(c.name); dismissFree(st, c.id); continue; }
      c.morale += c.morale > MORALE.start ? -Math.min(MORALE.drift, c.morale - MORALE.start) : Math.min(MORALE.drift, MORALE.start - c.morale);
    }
    for (const c of st.roster) { c.benched = false; c.pulls = {}; c.looted = false; }
    for (const k in st.bonds) st.bonds[k].week = 0;
    for (const b of BOSSES) { st.progress[b.id].normalWeek = false; st.progress[b.id].heroicWeek = false; st.progress[b.id].heroicWipes = 0; }
    if (st.score.kills || st.score.wipes) st.bestScore = Math.max(st.bestScore || 0, heroicScore(st));
    st.score = { kills: 0, wipes: 0, rounds: 0 };
    rollTavern(st);
    return "Week " + st.week + ". Lockouts reset, benched raiders are back, +" + ECON.weeklyQuests + " gold from the week's quests." +
      (quits.length ? " Morale got too low: " + quits.join(" and ") + " left the guild." : "");
  }

  root.FPR_GAME = { TRAITS, MORALE, SPECS, CLASS_NAMES, ARMOR, BOSSES, BOSS, CARDS, CARD_TEXT, MODES, ECON, RARITY, WB, CAUSE, LESSONS,
    newGame, setRules, heroicScore, role, specName, defaultZone, gearLevel, canWear, unlocked, heroicOpen, defaultPrep, prepCost, problems, warnings,
    pull, replayInfo, replay, assign, assignPending, suggestFor, dungeon, hire, reroll, dismiss, buyFire, respec, endWeek, famAvg, cohesion, bond, byId, sellValue };
})(typeof window !== "undefined" ? window : globalThis);
