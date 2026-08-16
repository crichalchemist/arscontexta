#!/bin/bash
# migrate-note-lifecycle.test.sh — the one-time migration's only coverage.
#
# WHY THIS EXISTS: the superseded plan's normalizer read a description through
# frontmatter_field, which STRIPS BALANCED QUOTES, then wrote the value back
# unquoted. Against the field vault that rewrites 1776 files without their
# quotes and produces invalid YAML on the 473 carrying a colon inside the
# value, while its progress counter reads as plausible forward motion.
#
# The fixture named "colon" below is that exact case.
#
# The script is always invoked as `bash "$SCRIPT"` here, matching how CLAUDE.md
# and the plan spell every invocation. The suite itself runs under both shells,
# so the harness is exercised twice; the subject is bash-only by design, the
# same call `guard-failure.test.sh` makes and for the same reason.
set -u
HERE=$(cd "$(dirname "$0")" && pwd -P)
SCRIPT="$HERE/../migrate-note-lifecycle.sh"
pass=0; fail=0
assert() { # assert <actual> <expected> <label>
  if [ "$1" = "$2" ]; then pass=$((pass+1))
  else fail=$((fail+1)); printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$3" "$2" "$1"; fi
}
mkvault() { # mkvault -> prints a fresh vault dir
  d=$(mktemp -d); mkdir -p "$d/nodes"; printf '%s' "$d"
}
note() { # note <vault> <name> <frontmatter-body>
  printf -- '---\n%s\n---\n\nBody.\n' "$3" > "$1/nodes/$2.md"
}
desc() { # desc <vault> <name> -> the raw description line, verbatim
  awk 'NR==1&&$0=="---"{f=1;next} f&&/^---$/{exit} f&&/^description:/{print;exit}' "$1/nodes/$2.md"
}
statusline() { # statusline <vault> <name>
  awk 'NR==1&&$0=="---"{f=1;next} f&&/^---$/{exit} f&&/^status:/{print;exit}' "$1/nodes/$2.md"
}

# ---------------------------------------------------------------- description
V=$(mkvault)
note "$V" quoted   'description: "A quoted one."
type: insight'
note "$V" colon    'description: "Ratio: two to one."
type: insight'
note "$V" bare     'description: A bare one.
type: insight'
note "$V" ellipsis 'description: "Trailing dots..."
type: insight'
note "$V" empty    'description: "."
type: insight'
note "$V" nostatus 'description: "Already clean"
type: insight'
note "$V" hasstatus 'description: "Already clean"
status: active
type: insight'
note "$V" wasopen 'description: "Already clean"
status: open
type: insight'
# The legacy-status table runs against every note in the vault and the plan's
# suite asserted nothing about it. A lookup table that maps nothing is
# indistinguishable from a corpus that needed no mapping.
note "$V" legacyclosed 'description: "Already clean"
status: closed
type: insight'
note "$V" legacyverified 'description: "Already clean"
status: verified
type: insight'
note "$V" legacyinvestigating 'description: "Already clean"
status: investigating
type: insight'

bash "$SCRIPT" "$V" --apply >/dev/null 2>&1

assert "$(desc "$V" quoted)"   'description: "A quoted one"'      'quoted: period stripped, quotes kept'
assert "$(desc "$V" colon)"    'description: "Ratio: two to one"' 'colon: quotes kept — the 473-note case'
assert "$(desc "$V" bare)"     'description: A bare one'          'bare: stays bare'
assert "$(desc "$V" ellipsis)" 'description: "Trailing dots..."'  'ellipsis: untouched'
assert "$(desc "$V" empty)"    'description: "."'                 'would-be-empty: refused, unchanged'

# --------------------------------------------------------------------- status
assert "$(statusline "$V" nostatus)"  'status: active'            'statusless: backfilled to active'
assert "$(statusline "$V" hasstatus)" 'status: active'            'already-stamped: untouched'
# hasstatus and nostatus expect the same value for OPPOSITE reasons — one was
# written, one was left alone. wasopen is the discriminator: a script that
# ignores existing status and always writes `active` passes both above and
# fails here.
assert "$(statusline "$V" wasopen)"   'status: open'              'existing non-active status: untouched'
# statusline() reads the FIRST status: line, so an unconditional backfill that
# appends a second one below it leaves the assertion above green. Count them.
statuscount() { # statuscount <vault> <name>
  awk 'NR==1&&$0=="---"{f=1;next} f&&/^---$/{exit} f&&/^status:/{n++} END{print n+0}' "$1/nodes/$2.md"
}
assert "$(statuscount "$V" wasopen)"  '1'                         'existing status: exactly one status line, none appended below'

# ------------------------------------------------------------- legacy mapping
assert "$(statusline "$V" legacyclosed)"        'status: archived' 'legacy closed -> archived'
assert "$(statusline "$V" legacyverified)"      'status: active'   'legacy verified -> active'
assert "$(statusline "$V" legacyinvestigating)" 'status: open'     'legacy investigating -> open'

# ---------------------------------------------------------------- idempotency
V2=$(mkvault)
note "$V2" a 'description: "One."
type: insight'
note "$V2" b 'description: Two.
type: insight'
bash "$SCRIPT" "$V2" --apply >/dev/null 2>&1
snap=$(mktemp -d); cp -R "$V2/nodes" "$snap/"
bash "$SCRIPT" "$V2" --apply >/dev/null 2>&1
assert "$(diff -r "$snap/nodes" "$V2/nodes" >/dev/null 2>&1 && echo same || echo differs)" 'same' \
  'idempotent: a second --apply changes nothing'

# ------------------------------------------------------- counter decomposition
# One file per change kind, so a report that attributes every change to one
# counter cannot pass. A single total would agree with the wrong decomposition.
V3=$(mkvault)
note "$V3" onlystrip 'description: "Strip me."
status: active
type: insight'
note "$V3" onlystamp 'description: "No status here"
type: insight'
note "$V3" onlymap 'description: "No period here"
status: closed
type: insight'
note "$V3" untouched 'description: "Nothing to do"
status: active
type: insight'
rep=$(bash "$SCRIPT" "$V3" --apply 2>/dev/null | tr -s ' ')
assert "$(printf '%s' "$rep" | sed -n 's/.*changed: \([0-9]*\).*/\1/p')" '3' 'report: 3 files changed'
assert "$(printf '%s' "$rep" | sed -n 's/.*stripped: \([0-9]*\).*/\1/p')" '1' 'report: stripped decomposed'
assert "$(printf '%s' "$rep" | sed -n 's/.*stamped: \([0-9]*\).*/\1/p')"  '1' 'report: stamped decomposed'
assert "$(printf '%s' "$rep" | sed -n 's/.*mapped: \([0-9]*\).*/\1/p')"   '1' 'report: mapped decomposed'

# ---------------------------------------------------------------- preconditions
# Fail loud is a global constraint: exit 0 with empty output is this repo's
# documented failure mode, so the two ways this script can be handed nothing
# must both be loud rather than a clean no-op.
V4=$(mkvault)   # nodes/ exists but is empty
bash "$SCRIPT" "$V4" --apply >/dev/null 2>&1
assert "$?" '1' 'empty nodes/: exits 1 rather than reporting a clean zero'
V5=$(mktemp -d) # no nodes/ at all
bash "$SCRIPT" "$V5" --apply >/dev/null 2>&1
assert "$?" '1' 'missing nodes/: exits 1'

# -------------------------------------------------------------- refusal is loud
# The frontmatter guard shipped in a form that refused EVERY well-formed file
# (awk's `exit 0` in a rule falls through to END, whose exit code wins), and the
# script still printed a report and exited 0. A refusal must be distinguishable
# from a corpus with nothing to do.
V7=$(mkvault)
note "$V7" ok 'description: "Fine."
type: insight'
printf 'no frontmatter here\n' > "$V7/nodes/bad.md"
bash "$SCRIPT" "$V7" --apply >/dev/null 2>&1
assert "$?" '2' 'refused file: exits 2, distinct from the exit 1 for a wrong tree'
assert "$(desc "$V7" ok)" 'description: "Fine"' 'a refusal does not abort the files that were fine'

# ------------------------------------- unclosed frontmatter must be refused
# The closing-delimiter half of has_frontmatter had NO fixture: a reviewer
# replaced the whole guard with a leading-`---`-only check and the suite stayed
# green. Without a closing delimiter every body line is still inside the
# frontmatter state, so a BODY line beginning `status:` or `description:` gets
# rewritten. This fixture carries both.
V8=$(mkvault)
printf -- '---\ndescription: "Opens but never closes."\ntype: insight\n\nstatus: closed\ndescription: "Body line with a period."\n' > "$V8/nodes/unclosed.md"
cp "$V8/nodes/unclosed.md" "$V8/unclosed.orig"
bash "$SCRIPT" "$V8" --apply >/dev/null 2>&1
assert "$?" '2' 'unclosed frontmatter: refused with exit 2'
assert "$(cmp -s "$V8/unclosed.orig" "$V8/nodes/unclosed.md" && echo same || echo differs)" 'same' \
  'unclosed frontmatter: file left byte-identical, body lines NOT rewritten'

# ----------------------------- a multi-line scalar must not be edited mid-value
# `description: "A ratio of two.` continued on the next line is a value whose
# period is INTERIOR. Stripping it edits the middle of the value and exits 0.
V9=$(mkvault)
note "$V9" fine 'description: "Fine."
type: insight'
printf -- '---\ndescription: "A ratio of two.\n  And more here."\ntype: insight\n---\n\nBody.\n' > "$V9/nodes/multiline.md"
cp "$V9/nodes/multiline.md" "$V9/ml.orig"
bash "$SCRIPT" "$V9" --apply >/dev/null 2>&1
assert "$?" '2' 'multi-line quoted description: refused with exit 2'
assert "$(cmp -s "$V9/ml.orig" "$V9/nodes/multiline.md" && echo same || echo differs)" 'same' \
  'multi-line quoted description: interior period NOT stripped'
assert "$(desc "$V9" fine)" 'description: "Fine"' 'one refusal does not stop the other files'

# ------------------------------------------------------ file mode is preserved
# mktemp creates 0600 and mv carries that mode onto the target. git records only
# the executable bit, so this corruption is invisible in a diff review: it was
# found by stat'ing the migrated copy, not by reading any diff.
V10=$(mkvault)
note "$V10" mode 'description: "Mode me."
type: insight'
chmod 644 "$V10/nodes/mode.md"
bash "$SCRIPT" "$V10" --apply >/dev/null 2>&1
assert "$(stat -f '%OLp' "$V10/nodes/mode.md" 2>/dev/null || stat -c '%a' "$V10/nodes/mode.md" 2>/dev/null)" \
  '644' 'file mode preserved across the rewrite'

# ------------------------------------------------------------------- dry run
V6=$(mkvault)
note "$V6" d 'description: "Dry."
type: insight'
before=$(desc "$V6" d)
bash "$SCRIPT" "$V6" >/dev/null 2>&1
assert "$(desc "$V6" d)" "$before" 'dry run writes nothing'

printf 'migrate-note-lifecycle: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
