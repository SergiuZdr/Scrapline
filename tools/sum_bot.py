"""Sums split run_bot.gd outputs (--runs N --from K across processes): python3 tools/sum_bot.py 'shots/x/a_*.txt'"""
import re, sys, glob, collections
files = sorted(glob.glob(sys.argv[1]))
runs = won = illegal = 0
fights = 0.0
reasons = collections.Counter(); reached = collections.Counter(); lost = collections.Counter(); gate = collections.Counter()
scrap_sum = 0.0; scrap_runs = 0
for f in files:
    t = open(f).read()
    m = re.search(r"=== (\d+) bot runs", t)
    if not m:
        print("incomplete", f); continue
    n = int(m.group(1)); runs += n
    w = re.search(r"won (\d+) .*illegal actions (\d+)", t); won += int(w.group(1)); illegal += int(w.group(2))
    fights += float(re.search(r"([\d.]+) fights won", t).group(1)) * n
    for c, r in re.findall(r"^\s+(\d+)  (.+)$", t, re.M): reasons[r] += int(c)
    for a, rch, l, g in re.findall(r"act (\d+): reached (\d+), lost (\d+)(?:, at its gate (\d+))?", t):
        reached[a] += int(rch); lost[a] += int(l); gate[a] += int(g or 0)
    m = re.search(r"last gate: ([\d.]+) avg over (\d+)", t)
    if m: scrap_sum += float(m.group(1)) * int(m.group(2)); scrap_runs += int(m.group(2))
print(f"runs {runs} won {won} ({100*won/max(1,runs):.1f}%) illegal {illegal} fights/run {fights/max(1,runs):.1f}")
for r, c in reasons.most_common(): print("  ", c, r)
for a in sorted(reached): print(f"  act {a}: reached {reached[a]}, lost {lost[a]} ({100*lost[a]/max(1,reached[a]):.1f}%), at its gate {gate[a]}")
if scrap_runs: print(f"  scrap going into the last gate: {scrap_sum/scrap_runs:.1f} avg over {scrap_runs} runs")
