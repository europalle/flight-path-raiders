-- Plays three short seasons of the game rules (engine/game.lua) with a fixed policy and returns one line
-- per week: gold, DKP, game RNG, combined fight checksum, roster size and total morale. Lua 5.1, LuaJIT
-- and Fengari must print the same lines (tests/check.sh); tests/golden_game.txt holds the saved ones.
local G = FPR_ENGINE.Game
local lines = {}
for season = 1, 3 do
  local st = G.NewGame(season * 104729, { level = 60 })
  for w = 1, 6 do
    local sum = 0
    for d = 1, 8 do G.Dungeon(st); if d < 7 then G.NewDay(st) end end
    if #st.roster < 12 and #st.tavern > 0 then G.Hire(st, 1) end
    for _, mode in ipairs({ "normal", "heroic" }) do
      for _, b in ipairs(G.BOSSES) do
        if not G.unlocked(st, b.id, mode) then break end
        local tries = 0
        repeat
          tries = tries + 1
          local prep = G.DefaultPrep(st, b.id, mode)
          prep.tactic = (tries == 1 and season == 2) and "spread" or b.card
          prep.cons = { food = true, elixirs = st.gold > 200, flasks = st.gold > 400 }
          local out = G.Pull(st, prep)
          if out.error then break end
          sum = math.floor((sum + out.run.checksum * 1.0) % 2147483647)  -- floats: Fengari integers are 32-bit
          if out.result ~= "kill" and out.run then G.Replay(st, "burn") end
          while #st.pending > 0 do G.AssignPending(st, 1, G.SuggestFor(st, st.pending[1])) end
        until out.result == "kill" or tries >= 3
        if not st.progress[b.id][mode .. "Week"] then break end
      end
    end
    local morale = 0
    for _, c in ipairs(st.roster) do morale = morale + c.morale end
    lines[#lines + 1] = string.format("s%d w%d gold %d dkp %d rng %d fights %d roster %d morale %d", season, w, st.gold, st.dkp, st.rng, sum, #st.roster, morale)
    G.EndWeek(st)
  end
end
return table.concat(lines, "\n")
