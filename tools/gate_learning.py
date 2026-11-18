"""Phase 3 gate check 6 (learning path): runs the smart bot (knows every answer) and the learner bot
(knows only what recaps tell it) on the same 40 guilds for 10 weeks, and reports the share of guilds
where the learner's first Heroic Ragnaroast kill is within 2 weeks of the smart bot's. Pass: 70% or more.
The recap side of the check (no answer before two wipes on that lesson) runs in tools/playtest_qa.js.
Usage: FENGARI=... python3 tools/gate_learning.py"""
import json, os, subprocess, sys, tempfile
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
weeks = {}
for style in ("smart", "learner"):
    f = os.path.join(tempfile.mkdtemp(), "kw.json")
    subprocess.run(["node", os.path.join(ROOT, "tools/playtest_bot.js"), "40", "10", style], env={**os.environ, "FPR_KILLWEEKS": f}, check=True, capture_output=True)
    weeks[style] = json.load(open(f))
s, l = weeks["smart"], weeks["learner"]
ok = sum(1 for g in range(40) if str(g) in l and (str(g) not in s or l[str(g)] <= s[str(g)] + 2))
print(f"Learner first kills Heroic Ragnaroast within 2 weeks of the smart bot in {ok}/40 guilds ({100 * ok // 40}%), by week 10. Gate: 70%.")
sys.exit(0 if ok * 100 >= 70 * 40 else 1)
