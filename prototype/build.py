"""Builds prototype/index.html: the page template with the engine's Lua files embedded."""
import json, os
root = os.path.join(os.path.dirname(__file__), "..")
files = ["engine/rng.lua", "engine/data.lua", "engine/sim.lua", "prototype/api.lua"]
srcs = [open(os.path.join(root, f)).read() for f in files]
page = open(os.path.join(root, "prototype/page.html")).read()
blob = json.dumps(srcs).replace("</", "<\\/")
open(os.path.join(root, "prototype/index.html"), "w").write(page.replace("/*__LUA__*/[]", blob))
print("built prototype/index.html", sum(len(s) for s in srcs), "bytes of Lua")
