# Agent execution rules

> The root `CLAUDE.md` is tracked repository guidance: what this repo is and how it is built.
> This file covers how an agent runs things here without fooling itself. Human contribution workflow
> lives in `CONTRIBUTING.md`. Claude Code loads this file alongside the root one, and `GEMINI.md`
> imports it. `AGENTS.md` does not: it is a symlink to the root `CLAUDE.md` (check-portability
> check 5). Every rule below was measured on macOS on 2026-10-09. Re-measure a rule before you
> trust it on another machine.

## Running the gates

- **Use bash ≥ 4, never `/bin/bash`.** macOS ships bash 3.2, and three gates and the kernel
  validator do not parse under it: `check-portability.sh`, `check-placeholder-count.sh`,
  `check-vocabulary-schema.sh` and `validate-kernel.sh`. The validator's shebang is
  `#!/usr/bin/env bash`, so its documented `./reference/validate-kernel.sh` invocation reaches 3.2
  on a stock `PATH`. Each fails `bash -n` with exit 2 on a `case … ;;` inside a `$(…)` command
  substitution; the same `case` outside `$(…)` parses. Run directly, each exits 2, but behind a
  pipe the run reads rc 0. Linux CI runs bash 5, so the failure is local-only. On this machine
  bash 5 is `/opt/local/bin/bash` (MacPorts). Run the dual-shell suites under `zsh` too.
- **Bound a run with `gtimeout`, never `timeout`.** GNU coreutils installs prefixed on macOS, so
  bare `timeout` does not exist and the command exits 127. Give `check-doc-claims.sh` at least 600s:
  it executes every suite it pins a total for.
- **Never put a time bound on `reference/test/check-doc-claims.test.sh`.** It sets
  `trap cleanup EXIT INT TERM`, and its cleanup does not exit. A TERM therefore resumes the script
  partway through an assertion, and the run then prints a well-formed `passed=N failed=M` with
  invented failures. Run it unbounded, in the background, and read the summary.
- **Run suites one at a time.** Suites mutate tracked files while they run, and
  `fence-isolation.test.sh` is not safe to run concurrently. After any run you killed, check
  `git status`: an untouched file in the diff is a stranded mutation, not your edit.
- **Read the fence gate's counts line, not only `PASS`.** On 2026-10-09 it printed
  `files=27 fences=92 run=86 skipped=6 known-open=3` under bash and `known-open=5` under zsh. The
  six skips are `refactor` f02–f04, `remember` f04, `tasks` f03 and `skills/reseed` f03. A
  different skip list is a finding, even when the gate says PASS.
- **A suite edit moves pinned prose.** `check-doc-claims.sh` runs each suite and compares its total
  against `CONTRIBUTING.md` and `docs/verification.md`. Move those totals in the same commit, and
  measure the new total rather than predicting it.

## Tool output you cannot take at face value

- **`grep` in the agent's shell is a function (ugrep), not `/usr/bin/grep`.** `grep -P` works there
  and fails for users, so verify portability claims with `/usr/bin/grep`.
- **git output goes through a filtering proxy.** `git log` can hide merge commits. `git diff` can
  drop lines, or claim that differing files are identical. Use `rtk proxy git diff`,
  `git rev-parse` and `git rev-list --count`.
- **Large tool output is compressed silently.** A `[N items compressed to M …]` trailer means words
  and digits were dropped. Re-read the content in `sed -n 'A,Bp'` slices of a few dozen lines, and
  print any number you will quote with a one-line `printf`.
- **Paths with spaces or non-ASCII characters break naive scans.** 234 tracked filenames contain
  spaces, all of them under `methodology/`, so use `-z` and NUL delimiters.
  `git ls-files` quotes non-ASCII paths unless you pass `git -c core.quotePath=false`.
- **An empty result is not proof of absence.** Pair every "no hits" with a positive control: the
  same command, shown finding a known match.

## Git and pull requests

- Branch from `develop` and open the PR against `develop` (`CONTRIBUTING.md`). Always pass the repo
  and base explicitly: `gh pr create --repo crichalchemist/arscontexta --base develop`. Without
  `gh repo set-default`, `gh` on a fork resolves to `upstream` (agenticnotetaking). This clone has
  `remote.origin.gh-resolved=base`, so here it resolves to `origin`, but a fresh clone will not.
- Do not add a `Co-Authored-By` trailer, or any other trailer naming an agent, to a commit message.
- Push tags by name. An `upstream` remote exists, and bare `git push --tags` does not ask which
  remote you mean.
- Move a version only with `scripts/bump-version.sh`, never by hand.
