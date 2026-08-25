#!/bin/bash
# check-skillevaluator.sh -- does this plugin pass NVIDIA skillevaluator's Tier 1 gate?
#
# Tier 1 is the static + security tier: schema, version, security, pii, license,
# code-integrity, unicode, quality, lint. It is the only tier that gates an exit code.
# Tier 2 (dedup) and Tier 3 (live agent eval) are explicitly NOT run here -- Tier 2 needs an
# embedding provider and Tier 3 spends real money per invocation.
#
# WHY A WRAPPER EXISTS AT ALL. Three settings this gate depends on cannot be expressed in
# any file skillevaluator discovers on its own:
#   1. --policy is never auto-discovered. validators/policy.py::resolve_policy() takes the
#      path explicitly, and SKILLEVALUATOR_PROFILE names only a profile bundled INSIDE the
#      installed package directory. A repo-local policy is inert without this script.
#   2. --llm/--llm-verify default to OFF (--no-llm), so a plain `skillevaluator validate .`
#      silently skips the second pass this repo depends on -- see below.
#   3. The provider must be one skillevaluator will actually forward. Its
#      validators/security.py::_skillspector_child_env() hands credentials to skillspector for
#      anthropic, bedrock and openai by name, and for nv_build and openai-compatible through a
#      fall-through that maps them onto OPENAI_API_KEY/OPENAI_BASE_URL. Every OTHER value --
#      claude_cli, codex_cli, gemini_cli, ollama -- is rewritten to "openai" with NO credential
#      and fails closed. `claude_cli` works when you invoke `skillspector scan` YOURSELF; it can
#      never work through this gate, and it cannot satisfy --llm-verify at all (see below).
#
# TWO SEPARATE LLM CONSUMERS, and conflating them wastes hours:
#   * skillspector's own analyzers, chosen by SKILLSPECTOR_PROVIDER. Left unset, skillspector
#     defaults to NVIDIA's endpoint -- it is an NVIDIA tool -- so an OPENAI_API_KEY alone does
#     nothing.
#   * skillevaluator's OWN verifier (inference/client.py::LLMClient, reached by --llm-verify) and
#     the Tier 2 dedup judge, chosen by SKILL_EVAL_LLM_PROVIDER. This one has no CLI providers at
#     all. The downgrade-to-INFO this gate depends on happens HERE, not inside skillspector.
# Setting the two consistently is what this script does; nv_build satisfies both from one key.
#
# WHY --llm-verify IS PASSED, AND WHAT IT HAS NOT YET DONE. skillspector's static pass
# flags 13 HIGH findings against this repo under its agentic-risk taxonomy --
# Self-Modification (RA1), Memory Manipulation (MP3), Direct Prompt Extraction (P6),
# Chaining Abuse (TM2), Agent Config Directory Access (AS1). This repo is a GENERATOR whose
# entire purpose is writing skills, seeding memory and editing agent config, so its correct
# behaviour and the taxonomy are describing the same acts. Several match on prose asserting
# the OPPOSITE of the risk: skills/reseed/SKILL.md is flagged Memory Manipulation for the
# line "**PRESERVE self/memory/ entirely.** Never modify".
#
# The wrong fix is a policy entry downgrading SECURITY.* -- that yields a permanently green
# run that has stopped measuring anything. The intended one is
# validators/security.py::_verify_findings_with_llm(), reached by --llm-verify: it re-reads
# each finding in context and downgrades to INFO only those an LLM rates false_positive at
# HIGH confidence. Findings it rates true_positive or uncertain keep their severity and still
# fail this gate. So a missing key is CANNOT CONCLUDE below and never PASS -- the security
# verdict has not been reached, and "we could not check" must never read as "clean".
#
# MEASURED 2026-08-25, AND IT QUALIFIES THE PARAGRAPH ABOVE: the downgrade is not reaching
# every skill, and the report does not say which. When a skill's skillspector report fails
# the consistency check below, the stage returns at validators/security.py:554 --
# mark_scan_incomplete() -- one line BEFORE _process_skillspector_cli_result() would add
# that skill's findings. They are dropped silently. A one-skill probe against skills/ask
# (LOW band, mismatched) yielded SCHEMA findings only and zero SECURITY, while a whole-repo
# run yields SECURITY findings in quantity -- from the skills that did validate.
#
# So a populated SECURITY list is NOT evidence that every skill was scanned, and the
# per-skill split is invisible in the output. This is the partial-coverage sibling of the
# absent-scanner problem this gate was built for: not findings=0 reported as clean, but
# findings>0 reported as complete. It is why incomplete_scans outranks the finding count in
# the parser below even when findings look plentiful.
#
# THE KNOWN BLOCKER, and why it is not ours to fix. That early return fires on
# security.py:675: skillspector's risk_assessment.recommendation must equal
# f(severity), where LOW maps to SAFE. skillspector emits CAUTION whenever its own analysis
# is incomplete, and for THIS repo it always is -- not from a failed analyzer (with a live
# model all 26 report completed/not_applicable and limitations is empty) but from
# reference_unresolved ledger exceptions: 32 in skills/ask/SKILL.md alone, against
# ops/derivation.md, methodology.md, kernel.yaml. Those are generated-vault paths that
# intentionally do not exist in a generator repo. The mismatch is an add_error(), NOT a
# finding, so severity_overrides cannot reach it -- policy applies to findings only.
# Pinning an older tool pair does not help either: the incompleteness comes from this repo's
# own reference structure. Until skillspector separates "incomplete" from "cautionary", this
# gate reports CANNOT CONCLUDE, which is the honest verdict rather than a broken one.
#
# READ THE ERROR FROM results[].legacy.errors, NOT results[].errors. The latter key is
# absent, so a parser looking there prints "no errors" beside passed=false.
#
# EXIT CODES follow the sibling gates: 0 PASS, 1 FAIL (real gating findings), 2 CANNOT
# CONCLUDE (a precondition is missing, so no verdict exists). The distinction matters here
# more than anywhere else in reference/: a Tier 1 run whose scanners never executed prints a
# red panel that is visually identical to a real finding, and reports findings=0 while
# claiming failure. Absence must not be reported as either PASS or FAIL.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT" || { echo "check-skillevaluator: cannot cd to repo root '$ROOT'" >&2; exit 2; }

POLICY="${POLICY:-reference/skillevaluator-policy.yaml}"
# nv_build is skillevaluator's own default and needs one credential to satisfy both consumers.
PROVIDER="${SKILLEVALUATOR_PROVIDER:-nv_build}"

echo "=== check-skillevaluator ==="
echo "property: Tier 1 reports no CRITICAL/HIGH finding, with every scanner having actually run"
echo "scope:    Tier 1 only (schema, security, pii, license, code-integrity, unicode, quality, lint)"
echo "NOT checked: Tier 2 dedup and Tier 3 live evaluation -- both need a provider and Tier 3 costs money"
echo

die2() { printf '  CANNOT CONCLUDE: %s\n' "$1"; echo; echo "SKILLEVALUATOR: CANNOT CONCLUDE"; exit 2; }

command -v skillevaluator >/dev/null 2>&1 \
  || die2 "skillevaluator is not on PATH -- install with 'uv tool install skillevaluator'"
command -v python3 >/dev/null 2>&1 \
  || die2 "python3 is not on PATH -- needed to read the JSON report; the CLI panel is not parseable"
[ -f "$POLICY" ] || die2 "policy file '$POLICY' is missing -- without it the SECRET/SCHEMA overlay silently does not apply"

# The two external scanners. Neither is a python dependency of skillevaluator, so both are
# absent on a fresh machine, and a missing one produces findings=0 with passed=False -- a
# shape indistinguishable from a real failure in the rendered panel.
command -v skillspector >/dev/null 2>&1 \
  || die2 "skillspector is not on PATH -- Security Scan would report 0 findings while claiming to fail. Install: uv tool install git+https://github.com/NVIDIA/skillspector.git"
command -v gitleaks >/dev/null 2>&1 \
  || die2 "gitleaks is not on PATH -- Secrets Detection would report 0 findings while claiming to fail. Install: brew install gitleaks"

# A missing credential is CANNOT CONCLUDE, never FAIL: without the verifier the 13 known
# SECURITY false positives stay HIGH, and reporting that as a real failure would be a lie of
# the same kind as reporting an uninstalled scanner's findings=0 as clean.
case "$PROVIDER" in
  nv_build)  [ -n "${NVIDIA_API_KEY:-}" ]    || die2 "provider nv_build but NVIDIA_API_KEY is unset -- get one free at build.nvidia.com. Without it --llm-verify cannot run and no security verdict exists" ;;
  anthropic) [ -n "${ANTHROPIC_API_KEY:-}" ] || die2 "provider anthropic but ANTHROPIC_API_KEY is unset -- see above" ;;
  openai)    [ -n "${OPENAI_API_KEY:-}" ]    || die2 "provider openai but OPENAI_API_KEY is unset -- see above" ;;
  bedrock)   [ -n "${AWS_ACCESS_KEY_ID:-}" ] || die2 "provider bedrock but AWS_ACCESS_KEY_ID is unset -- see above" ;;
  openai-compatible)
    [ -n "${SKILL_EVAL_LLM_BASE_URL:-}" ] || die2 "provider openai-compatible but SKILL_EVAL_LLM_BASE_URL is unset (e.g. a local llama-server at http://127.0.0.1:8091/v1)"
    [ -n "${SKILL_EVAL_LLM_MODEL:-}" ]    || die2 "provider openai-compatible but SKILL_EVAL_LLM_MODEL is unset -- resolve_llm_provider() raises without it"
    [ -n "${SKILL_EVAL_LLM_API_KEY:-}" ]  || die2 "provider openai-compatible but SKILL_EVAL_LLM_API_KEY is unset -- any non-empty string works for a local server" ;;
  *) die2 "provider '$PROVIDER' is not forwarded to skillspector. Use nv_build, anthropic, openai, bedrock, or openai-compatible. CLI providers (claude_cli, codex_cli, gemini_cli) and ollama are silently rewritten to 'openai' with no credential and fail closed" ;;
esac

export SKILL_EVAL_LLM_PROVIDER="$PROVIDER"
# openai-compatible must NOT be named in SKILLSPECTOR_PROVIDER: it is absent from
# _SKILLSPECTOR_EXPLICIT_PROVIDER_ENV, so naming it takes the fail-closed branch. Leaving it
# unset lets _skillspector_child_env() fall through and map it onto OPENAI_BASE_URL instead.
if [ "$PROVIDER" != "openai-compatible" ]; then
  export SKILLSPECTOR_PROVIDER="$PROVIDER"
else
  unset SKILLSPECTOR_PROVIDER
fi

# Pin the model. skillevaluator overrides SKILLSPECTOR_MODEL from its own provider default
# (nv_build -> nvidia/nemotron-3-nano-30b-a3b), so this is not what makes the gate work --
# it makes the invocation reproducible and states the version the findings were measured
# against. It also documents the trap for anyone copying this to run skillspector DIRECTLY:
# skillspector's own default was z-ai/glm-5.2, which reached end of life on 2026-08-21 and
# now returns HTTP 410. Every LLM analyzer then fails, skillspector logs "LLM stage degraded
# ... report reflects static analysis only", and still writes a normal-looking report. A
# model name that has quietly died is this repo's dominant failure class wearing a vendor's
# clothes, which is why the degradation is asserted after the run rather than assumed away.
export SKILLSPECTOR_MODEL="${SKILLSPECTOR_MODEL:-nvidia/nemotron-3-nano-30b-a3b}"

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

echo "  running Tier 1 (provider=$PROVIDER, policy=$POLICY, --llm --llm-verify) ..."
skillevaluator validate . --tiers 1 --policy "$POLICY" --llm --llm-verify \
  -r json -o "$OUT" >"$OUT/run.log" 2>&1
rc=$?

# `set -e` is deliberately off: rc=1 is the tool's normal way of reporting findings, and the
# findings are exactly what this gate exists to read. Only an unreadable report is fatal.
# Fail loud on a degraded LLM stage. skillspector downgrades to static-only on an unusable
# model and keeps going; the report that lands is structurally valid and says nothing about
# it. Checked positively -- a grep that matches nothing is what a clean run looks like, so
# the absence below is only meaningful because run.log is known non-empty.
[ -s "$OUT/run.log" ] || die2 "skillevaluator wrote no log to $OUT/run.log -- cannot tell whether the LLM stage ran at all"
if /usr/bin/grep -qE 'LLM stage degraded|has reached its end of life' "$OUT/run.log"; then
  die2 "the LLM analyzers degraded to static-only -- the report is not an LLM-backed verdict:
$(/usr/bin/grep -m2 -oE "LLM stage degraded[^\"]*|The model '[^']*' has reached its end of life[^\"]*" "$OUT/run.log" | sed 's/^/    /')
  Pin a live model with SKILLSPECTOR_MODEL=<model>; list them with 'skillevaluator models'."
fi

REPORT="$(ls -1 "$OUT"/*.json 2>/dev/null | head -1)"
[ -n "$REPORT" ] || die2 "skillevaluator exited $rc and wrote no JSON report to $OUT -- see the tail below
$(tail -5 "$OUT/run.log" 2>/dev/null | sed 's/^/    /')"

# Everything below reads the JSON, never the rendered panel. The panel prints a red row for a
# scanner that never ran, with a severity tally of all zeros beside it.
python3 - "$REPORT" <<'PY'
import json, sys, collections

with open(sys.argv[1]) as fh:
    report = json.load(fh)

incomplete = report.get("incomplete_scans") or []
gating = collections.Counter()
other = collections.Counter()

for result in report.get("results", []):
    for finding in result.get("findings") or []:
        key = "%s.%s" % (finding.get("category"), finding.get("check_name"))
        if finding.get("severity") in ("critical", "high"):
            gating[key] += 1
        else:
            other[key] += 1

print("  overall_status: %s" % report.get("overall_status"))
print("  findings: %d gating (critical/high), %d non-gating" % (sum(gating.values()), sum(other.values())))

if other:
    print("  non-gating (reported, does not fail this gate):")
    for key, n in other.most_common():
        print("    %3d  %s" % (n, key))

# An incomplete scan is neither PASS nor FAIL: the check did not happen. Reporting it as
# either is the mistake this whole gate is shaped around, so it outranks the finding count.
if incomplete:
    print("  CANNOT CONCLUDE: these scanners did not complete: %s" % ", ".join(incomplete))
    print("  A scanner that did not run reports findings=0 and passed=False -- identical to a real")
    print("  failure in the CLI panel, and identical to a clean result in the finding count.")
    print("")
    print("SKILLEVALUATOR: CANNOT CONCLUDE")
    sys.exit(2)

if gating:
    print("  gating findings:")
    for key, n in gating.most_common():
        print("    %3d  %s" % (n, key))
    print("")
    print("SKILLEVALUATOR: FAIL")
    sys.exit(1)

print("  PASS no CRITICAL/HIGH findings, and every scanner completed")
print("")
print("SKILLEVALUATOR: PASS")
sys.exit(0)
PY
exit $?
