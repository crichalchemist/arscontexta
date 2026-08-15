#!/usr/bin/env python3
"""Surgical field editor for the bare-list YAML queue.

Ported 2026-08-15 from the field vault's ops/lib/queue_edit.py (v2), with the vault's
dialect reversed to canonical vocabulary per the backport rules: its `extract` is this
repo's `reduce`, and its concrete queue path is the caller's business — this file takes
whatever path it is handed.

WHY THIS EXISTS, AND WHY IT IS NOT A YAML ROUND-TRIP
----------------------------------------------------
The live queue file is a BARE LIST of task mappings — there is no `tasks:` key.
Two things follow, and missing either is why the queue write path was silently dead:

  1. jq cannot read it at all (it is YAML, not JSON), so `queue_edit` with a jq
     filter no-ops against the JSON tombstone the vault migrated away from.
  2. Every legacy filter said `.tasks[]`, which does not exist here even after a
     format fix. Format and schema drifted SEPARATELY; a path-only fix looks
     sufficient and is not.

A load+dump round-trip is not acceptable: measured 2026-08-11 in the field vault on
its live 439,861-byte queue, `yaml.safe_load` + `safe_dump` rewrote 277 lines across
43 hunks (6267 -> 6076 lines) purely by re-wrapping folded scalars. That is the defect
recorded in the vault's observation
`queue-yaml-python-round-trip-produces-non-surgical-full-file-reformat`.

So this edits LINES. Every byte outside a changed field is preserved exactly.

FILE SHAPE THIS RELIES ON
-------------------------
    - id: bird-pearls          <- block starts at column 0 with "- "
      type: reduce             <- fields at indent 2
      completed_phases:        <- list field
      - reduce                 <- items at indent 2, prefixed "- "
      note: 'long value that may
        fold onto continuation lines at indent 4+'

A field's lines run from its `  key:` line up to the next indent-2 key (a line
matching `^  [^ -]`), the next block (`^- `), or EOF. Folded continuations sit at
indent 4+ and are consumed with their key.

USAGE
    queue_edit.py FILE --where k=v [--where k2=v2] --set f=v [--set f2=v2]
    queue_edit.py FILE --where k=v --append listfield=value
    queue_edit.py FILE --add-task k=v [k2=v2 ...]

Exits non-zero and writes to stderr if a --where matches nothing: a queue write that
silently matches zero tasks is the failure mode this whole file exists to end.
Prints the number of blocks changed to stdout.
"""
import argparse
import re
import sys

import yaml

BLOCK_RE = re.compile(r"^- ")
KEY_RE = re.compile(r"^  ([^\s-][^:]*):")       # indent-2 key, never a "- " list item
BLOCK_KEY_RE = re.compile(r"^- ([^\s-][^:]*):")  # the block's FIRST field rides the "- " line
NEXT_KEY_RE = re.compile(r"^  [^\s-]")           # boundary: next indent-2 key


def scalar(value):
    """Render one value the way PyYAML would, so quoting stays correct per-value.

    Dumped as a single-key mapping on purpose: `safe_dump` on a BARE scalar emits a
    `...` document-end marker ("TESTVALUE\\n...\\n"), which silently turns every write
    into two lines and corrupts the block. Measured 2026-08-12 — the first test caught it.
    """
    return yaml.safe_dump({"_": value}, default_flow_style=False,
                          width=10**6, allow_unicode=True).strip().split("_:", 1)[1].strip()


def blocks(lines):
    """Yield (start, end) line indices for each top-level task block."""
    starts = [i for i, l in enumerate(lines) if BLOCK_RE.match(l)]
    for n, s in enumerate(starts):
        yield s, (starts[n + 1] if n + 1 < len(starts) else len(lines))


def field_span(lines, start, end, key):
    """Return (first, last) line indices of `key` within a block, or None."""
    for i in range(start, end):
        m = (BLOCK_KEY_RE if i == start else KEY_RE).match(lines[i])
        if m and m.group(1).strip() == key:
            j = i + 1
            while j < end and not NEXT_KEY_RE.match(lines[j]) and not BLOCK_RE.match(lines[j]):
                j += 1
            return i, j
    return None


def get_field(lines, start, end, key):
    """Value of `key` in this block, or None. Dedents so PyYAML sees a bare mapping."""
    span = field_span(lines, start, end, key)
    if not span:
        return None
    chunk = list(lines[span[0]:span[1]])
    chunk[0] = "  " + chunk[0][2:]          # "- id: x" and "  id: x" both -> "  id: x"
    raw = "\n".join(l[2:] if l.startswith("  ") else l for l in chunk)
    try:
        loaded = yaml.safe_load(raw)
    except yaml.YAMLError:
        return None
    return loaded.get(key) if isinstance(loaded, dict) else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--where", action="append", default=[], metavar="KEY=VALUE")
    ap.add_argument("--set", action="append", default=[], dest="sets", metavar="FIELD=VALUE")
    ap.add_argument("--append", action="append", default=[], dest="appends", metavar="FIELD=VALUE")
    ap.add_argument("--add-task", nargs="+", default=None, metavar="KEY=VALUE")
    a = ap.parse_args()

    def kv(pairs):
        out = []
        for p in pairs:
            if "=" not in p:
                sys.exit(f"error: queue_edit: expected KEY=VALUE, got {p!r}")
            k, v = p.split("=", 1)
            out.append((k.strip(), v))
        return out

    text = open(a.file, encoding="utf-8").read()
    trailing_nl = text.endswith("\n")
    lines = text.splitlines()

    if a.add_task:
        pairs = kv(a.add_task)
        new = [f"- {pairs[0][0]}: {scalar(pairs[0][1])}"]
        new += [f"  {k}: {scalar(v)}" for k, v in pairs[1:]]
        lines += new
        changed = 1
    else:
        wants = kv(a.where)
        if not wants:
            sys.exit("error: queue_edit: --where is required (refusing to edit every task)")
        changed = 0
        # Work back-to-front so earlier spans stay valid as later ones resize.
        for start, end in reversed(list(blocks(lines))):
            if not all(str(get_field(lines, start, end, k)) == v for k, v in wants):
                continue
            changed += 1
            for k, v in kv(a.sets):
                span = field_span(lines, start, end, k)
                # A field sitting on the block's "- " line must keep that prefix, or the
                # block silently merges into its predecessor.
                prefix = "- " if span and span[0] == start else "  "
                new_line = f"{prefix}{k}: {scalar(v)}"
                if span:
                    lines[span[0]:span[1]] = [new_line]
                else:
                    lines.insert(end, new_line)
                end = end - ((span[1] - span[0]) if span else 0) + 1
            for k, v in kv(a.appends):
                span = field_span(lines, start, end, k)
                if span:
                    lines.insert(span[1], f"  - {scalar(v)}")
                else:
                    lines[end:end] = [f"  {k}:", f"  - {scalar(v)}"]
                end += 1 if span else 2

    if changed == 0:
        sys.exit(f"error: queue_edit: no task matched {a.where} in {a.file} — nothing written")

    sys.stdout.write("\n".join(lines) + ("\n" if trailing_nl else ""))
    # Report the match count: a write matching more tasks than intended is as much a
    # defect as one matching none, and only the caller knows which number is right.
    print(f"queue_edit: {changed} task(s) updated", file=sys.stderr)


if __name__ == "__main__":
    main()
