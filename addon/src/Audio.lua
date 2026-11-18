-- Flight Path Raiders: sound cues (audio/cues.md). Every cue uses the game's own sound kit, so there is
-- nothing to license and the player's SFX volume applies. Each cue lists names to try in order, because
-- sound kit names differ between clients; a name the client doesn't know is skipped, so a missing sound
-- is silence, never an error. No cue carries information on its own: the same thing is always on screen.
-- Settings: "Sounds" on or off (default on).
local _, ns = ...
local Audio = {}
ns.Audio = Audio

Audio.CUES = {
  open     = { "IG_MAINMENU_OPEN" },
  close    = { "IG_MAINMENU_CLOSE" },
  tab      = { "IG_CHARACTER_INFO_TAB" },
  pick     = { "IG_MAINMENU_OPTION_CHECKBOX_ON" },
  bench    = { "IG_MAINMENU_OPTION_CHECKBOX_OFF" },
  pull     = { "READY_CHECK" },
  windup   = { "RAID_WARNING" },
  kill     = { "LEVELUPSOUND", "LEVEL_UP" },
  wipe     = { "IG_QUEST_FAILED", "IG_PLAYER_INVITE_DECLINE" },
  loot     = { "LOOT_WINDOW_COIN_SOUND" },
  assign   = { "IG_BACKPACK_COIN_SELECT", "LOOT_WINDOW_COIN_SOUND" },
}
Audio.played = {}  -- the last cues, newest last (for the headless tests)

function Audio.Play(cue)
  if ns.db and ns.db.settings.sound == false then return end
  local names = Audio.CUES[cue]
  if not names then return end
  Audio.played[#Audio.played + 1] = cue
  if #Audio.played > 20 then table.remove(Audio.played, 1) end
  if not (PlaySound and SOUNDKIT) then return end
  for _, n in ipairs(names) do
    local id = SOUNDKIT[n]
    if type(id) == "number" then pcall(PlaySound, id, "SFX"); return end
  end
end
