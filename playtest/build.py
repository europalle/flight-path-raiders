"""Builds playtest/index.html: the page with the engine and game rules (Lua), the Fengari bridge and the portraits embedded."""
import json, os
root = os.path.join(os.path.dirname(__file__), "..")
rd = lambda f: open(os.path.join(root, f)).read()
LUA = ["engine/rng.lua", "engine/data.lua", "engine/sim.lua", "engine/bosses.lua", "engine/validate.lua", "engine/progress.lua", "engine/game.lua"]
lua = [[f, rd(f)] for f in LUA]
page = rd("playtest/page.html")
page = page.replace("/*__LUA__*/[]", json.dumps(lua).replace("</", "<\\/"))
page = page.replace("/*__PORTRAITS__*/{}", rd("playtest/portraits.json"))
page = page.replace("/*__GAME__*/", rd("playtest/game_lua.js").replace("</script", "<\\/script"))
open(os.path.join(root, "playtest/index.html"), "w").write(page)
print("built playtest/index.html", len(page), "bytes")
