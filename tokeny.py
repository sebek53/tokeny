"""Liczy tokeny zuzyte przez Claude Code (z logow w ~/.claude/projects)."""
import json
from collections import defaultdict
from pathlib import Path

KEYS = ["input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"]

per_day = defaultdict(lambda: defaultdict(int))
seen = set()
for f in (Path.home() / ".claude" / "projects").rglob("*.jsonl"):
    for line in f.open(encoding="utf-8", errors="ignore"):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        msg = d.get("message") if isinstance(d, dict) else None
        usage = msg.get("usage") if isinstance(msg, dict) else None
        if not usage:
            continue
        mid = msg.get("id")
        if mid in seen:  # ten sam komunikat bywa zapisany kilka razy
            continue
        seen.add(mid)
        day = d.get("timestamp", "????")[:10]
        for k in KEYS:
            per_day[day][k] += usage.get(k) or 0

total = defaultdict(int)
print(f"{'dzien':<12}{'wejscie':>12}{'wyjscie':>12}{'cache zapis':>14}{'cache odczyt':>14}")
for day in sorted(per_day):
    v = per_day[day]
    print(f"{day:<12}" + "".join(f"{v[k]:>{w},}" for k, w in zip(KEYS, (12, 12, 14, 14))))
    for k in KEYS:
        total[k] += v[k]
print("-" * 64)
print(f"{'RAZEM':<12}" + "".join(f"{total[k]:>{w},}" for k, w in zip(KEYS, (12, 12, 14, 14))))
input("\nEnter = zamknij")
