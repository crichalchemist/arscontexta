#!/usr/bin/env python3
"""Build styles/STE/DictionaryFull.yml from the ASD-STE100 spec PDF.

Source is a TAGGED PDF, so structure comes from the authored structure tree:
  opendataloader-pdf -f markdown --use-struct-tree \
    --markdown-page-separator '@@PAGE:%page-number%@@' -o PG ASD-STE100_ISSUE9.pdf

Dictionary body is p149-433. p48 is Part 1's verb table and p131-143 is the
dictionary's own introduction (worked examples that duplicate body entries);
both are excluded by page range, not by row shape.
"""
import re, sys, collections

SRC, LO, HI = 'PG/ASD-STE100_ISSUE9.md', 149, 433
OUT = sys.argv[1] if len(sys.argv) > 1 else 'DictionaryFull.yml'

def bare(s):
    return re.sub(r'\s+', ' ', re.sub(r'\s*\([^)]*\)\s*$', '', s.strip())).strip()

def is_alt(s):
    """col2 is an ALTERNATIVE (uppercase headword) rather than a MEANING."""
    b = re.sub(r'\s*\([^)]*\)', '', s).strip()
    return bool(b) and b == b.upper() and any(ch.isalpha() for ch in b)

pg, rows = 0, []
for line in open(SRC, encoding='utf-8'):
    m = re.match(r'@@PAGE:(\d+)@@', line.strip())
    if m:
        pg = int(m.group(1)); continue
    if not (LO <= pg <= HI) or not line.startswith('|') or line.startswith('|---'):
        continue
    c = [x.strip() for x in line.strip().strip('|').split('|')]
    if len(c) == 4 and not c[0].startswith('Word'):
        rows.append(c)
if not rows:
    sys.exit("FATAL: 0 rows parsed - extraction or page range is wrong")

entries, cur = [], None
for w, alt, _ste, _non in rows:
    if w:
        cur = {'word': w, 'approved': w[0].isupper(), 'alts': []}
        entries.append(cur)
    if cur and is_alt(alt):
        cur['alts'].append(re.sub(r'\s+', ' ', alt))

approved_bare = {bare(e['word']).lower() for e in entries if e['approved']}
cand = [e for e in entries if not e['approved'] and e['alts']]

merged = collections.OrderedDict()
for e in cand:
    merged.setdefault(bare(e['word']).lower(), []).extend(e['alts'])

# upstream: never swap a word STE itself approves (POS-ambiguous, unlintable)
collisions = sorted(k for k in merged if k in approved_bare)
swap = collections.OrderedDict(
    (k, v) for k, v in sorted(merged.items()) if k not in approved_bare)

def key_re(k):                      # hard-wrapped source: spaces must be \s+
    # escape each token SEPARATELY - re.escape() on the whole string escapes the
    # space first, and a later sub then yields `word\\s+word`, a regex that matches
    # a literal backslash and never fires.
    return r'\s+'.join(re.escape(tok) for tok in k.split())

with open(OUT, 'w', encoding='utf-8') as f:
    f.write("# ASD-STE100 Issue 9 approved-alternative rule.\n"
            "# GENERATED - do not edit. Rebuild with build-dict.py.\n"
            "# Derived from the ASD-STE100 specification, (c) ASD. NOT REDISTRIBUTABLE.\n"
            f"# {len(swap)} entries. {len(collisions)} POS-ambiguous words excluded.\n"
            "extends: substitution\n"
            "message: \"STE: use '%s' instead of '%s'.\"\n"
            "level: error\nignorecase: true\nswap:\n")
    for k, alts in swap.items():
        seen = list(dict.fromkeys(alts))
        # single-quote the key: YAML 1.1 coerces bare true/false/on/off/yes/no
        # to booleans, and backslash is literal inside single quotes.
        f.write(f"  '{key_re(k)}': \"{' or '.join(seen).replace(chr(34), '')}\"\n")

print(f"rows parsed           : {len(rows)}")
print(f"headwords             : {len(entries)}")
print(f"non-approved w/ alts  : {len(cand)}  -> {len(merged)} unique keys")
print(f"EXCLUDED (POS clash)  : {len(collisions)}")
print(f"WRITTEN               : {len(swap)} swap entries -> {OUT}")
