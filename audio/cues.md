# Sound cues (vertical slice)

Audio, 2026-11-19. Issue #12. Code: `addon/src/Audio.lua`.

Every cue uses WoW's own sound kit (`PlaySound(SOUNDKIT.X, "SFX")`), so there is nothing to license and the player's own SFX volume and mute apply. Each cue lists a fallback name, because sound kit names differ between clients; an unknown name is silent, never an error. Which names exist in WoW: Forever is **verify at install**.

Accessibility rule: no cue is the only way to learn something. Everything a sound says is also on screen, in text. Sounds can be turned off in Settings, separately from the game's own sound.

| Cue | When | Sound kit (fallback) | What it tells you | Also on screen |
|---|---|---|---|---|
| open | The board opens | IG_MAINMENU_OPEN | The board is up | The board |
| close | The board closes | IG_MAINMENU_CLOSE | It's gone | |
| tab | Tab or page change | IG_CHARACTER_INFO_TAB | You moved | Selected tab |
| pick | A tactic card or consumable is switched on | IG_MAINMENU_OPTION_CHECKBOX_ON | Choice taken | Selected style and tick |
| bench | A raider is taken out of the raid in prep | IG_MAINMENU_OPTION_CHECKBOX_OFF | Raider benched | Raider moves to the bench |
| pull | Pull is pressed | READY_CHECK | The fight starts | Playback screen |
| windup | A boss wind-up in playback: lava throw, bomb mark, the Frown | RAID_WARNING | Something big is coming | Log line, coloured |
| kill | Results after a kill | LEVELUPSOUND (LEVEL_UP) | You won | "Kill in round N" |
| wipe | Results after a wipe or the enrage | IG_QUEST_FAILED (IG_PLAYER_INVITE_DECLINE) | You lost | "Wipe in round N" and the recap |
| loot | The loot window opens | LOOT_WINDOW_COIN_SOUND | Loot to hand out | The loot window |
| assign | An item is given or sold | IG_BACKPACK_COIN_SELECT (LOOT_WINDOW_COIN_SOUND) | Done | Chat line and the item leaves the window |

Not in the slice: our own music and stings. If we ever ship our own sounds, they need a licence check (Legal, #14) and must stay short and quiet: people use the board while flying, often with their own music on.
