#!/usr/bin/env python3
"""Fill MarketplaceId values in MonetizationConfig.luau from a plain key/id list.

Twenty-eight hand-edits is exactly where a typo silently sells the wrong thing, so this does the
edit and refuses anything it cannot prove:

  - a key that is not in the config          -> error, nothing written
  - an id that is not a positive integer      -> error, nothing written
  - the same id pointed at two items          -> error, nothing written
  - the same key listed twice                 -> error, nothing written
  - an entry that already has a different id  -> error unless --overwrite

Nothing is written unless every line passes. A partial application is worse than none: you would
not know which half landed.

Usage
-----
    python tools/apply_marketplace_ids.py ids.txt
    python tools/apply_marketplace_ids.py ids.txt --dry-run
    cat ids.txt | python tools/apply_marketplace_ids.py -

Input format -- one per line, config key then id, blank lines and # comments ignored:

    DoubleCash 123456789
    StoragePlus 987654321
    RobuxUpgradeMagnetStrength 456789123
"""

import argparse
import re
import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parent.parent / "src" / "shared" / "Config" / "MonetizationConfig.luau"

# An entry is `Id = "Thing",` followed within a few lines by `MarketplaceId = <n>,`. Captured
# together so a key can only ever be matched to the MarketplaceId inside its own block.
ENTRY = re.compile(
    r'Id = "(?P<key>\w+)",\s*\n(?P<indent>\s*)MarketplaceId = (?P<id>\d+),',
)


def parse_pairs(text: str) -> list[tuple[str, int, int]]:
    """Return (key, id, line_number). Raises ValueError on anything malformed."""
    pairs = []
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        # Tolerate commas, colons and equals between the two halves: people paste from all sorts.
        parts = re.split(r"[\s,:=]+", line)
        if len(parts) != 2:
            raise ValueError(f"line {number}: expected `Key 12345`, got {raw.strip()!r}")
        key, value = parts
        if not value.isdigit() or int(value) <= 0:
            raise ValueError(f"line {number}: {value!r} is not a positive integer id")
        pairs.append((key, int(value), number))
    return pairs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="file of `Key 12345` lines, or - for stdin")
    parser.add_argument("--dry-run", action="store_true", help="report, write nothing")
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="allow replacing an id that is already set to something else",
    )
    args = parser.parse_args()

    text = sys.stdin.read() if args.source == "-" else Path(args.source).read_text(encoding="utf-8")
    source = CONFIG.read_text(encoding="utf-8")

    known = {m.group("key"): int(m.group("id")) for m in ENTRY.finditer(source)}
    if not known:
        print(f"error: found no entries in {CONFIG}", file=sys.stderr)
        return 2

    try:
        pairs = parse_pairs(text)
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    problems: list[str] = []
    seen_keys: dict[str, int] = {}
    seen_ids: dict[int, str] = {}

    for key, new_id, number in pairs:
        if key not in known:
            near = ", ".join(sorted(k for k in known if k.lower().startswith(key[:6].lower()))) or "none"
            problems.append(f"line {number}: unknown key {key!r} (similar: {near})")
            continue
        if key in seen_keys:
            problems.append(f"line {number}: {key} listed twice (also line {seen_keys[key]})")
            continue
        if new_id in seen_ids and seen_ids[new_id] != key:
            problems.append(
                f"line {number}: id {new_id} already used for {seen_ids[new_id]} -- "
                "two items sharing an id charges people for the wrong thing"
            )
            continue
        current = known[key]
        if current not in (0, new_id) and not args.overwrite:
            problems.append(
                f"line {number}: {key} already has id {current}; pass --overwrite to replace it"
            )
            continue
        seen_keys[key] = number
        seen_ids[new_id] = key

    if problems:
        print("Refusing to write. Fix these first:\n", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        return 1

    wanted = {key: new_id for key, new_id, _ in pairs}

    def replace(match: re.Match) -> str:
        key = match.group("key")
        if key not in wanted:
            return match.group(0)
        return f'Id = "{key}",\n{match.group("indent")}MarketplaceId = {wanted[key]},'

    updated, _ = ENTRY.subn(replace, source)

    changed = [k for k, v in wanted.items() if known[k] != v]
    unchanged = [k for k in wanted if known[k] == wanted[k]]
    remaining = sorted(k for k, v in known.items() if v == 0 and k not in wanted)

    for key in sorted(changed):
        print(f"  set   {key} = {wanted[key]}")
    for key in sorted(unchanged):
        print(f"  same  {key} = {wanted[key]} (already correct)")

    if args.dry_run:
        print(f"\ndry run: {len(changed)} would change, {len(remaining)} still at 0")
        return 0

    if changed:
        CONFIG.write_text(updated, encoding="utf-8")
    print(f"\n{len(changed)} updated, {len(remaining)} still at 0")
    if remaining:
        print("still needed: " + ", ".join(remaining))
    return 0


if __name__ == "__main__":
    sys.exit(main())
