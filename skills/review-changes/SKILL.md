---
name: review-changes
description: Review a code change for bugs, security and data-loss risks, scale problems, missing tests, slowness and dead weight. Reads the connected code, not only the diff, and returns verified findings, each with a concrete failing case and the smallest fix. By default the review runs on Codex (gpt-6.2-sol), handed off from whatever agent calls it; `reviewer-provider=self` reviews in place. Changes no code and posts nothing. Use for "review my changes", "review this branch / commit / diff", checking your own work before calling it done, or when another skill needs a diff reviewed.
---

Review a change like the senior developer who gets paged when it breaks. The result is a list of findings: it changes no code and writes nowhere except the optional `out` file.

The caller can be a person or another skill (a PR reviewer, an implementer checking its own work). The steps don't depend on a particular agent or harness. Only the default reviewer names one, and it can be changed.

Speed matters: run independent commands in parallel, read each thing once, and hand big changes to parallel sub-agents.

## Inputs

All arguments are optional.

- **What to review**, one of:
  - `diff=<file>`: a ready-made diff, for example a PR's.
  - `range=<base>..<head>`: commits. Get the diff with `git diff <base>...<head>`.
  - nothing: the uncommitted changes (`git diff HEAD`). If there are none, the last commit.
- `dir=<path>`: the repo to read. Default: the current folder.
- `at=<ref>`: the commit whose code to read. Default: `<head>` for a range, the last commit when reviewing it, and the working tree otherwise.
- `intent=<text>`: what the change is meant to do. Otherwise, take it from the commit messages, the branch name, or the task the caller is on.
- `out=<path>`: also write the result as [JSON](#json-result) there.

**Reviewer.** Who does the review. The defaults apply to everyone; edit them here to change them.

- `reviewer-provider=<name>`: default `codex`. `self` means you do the review, whatever the other two say.
- `reviewer-model=<name>`: default `gpt-6.2-sol`.
- `reviewer-effort=<level>`: default `high`.

Each value comes from, in order: an argument to this run; the project's `AGENTS.md` or `CLAUDE.md`, if it sets `review-changes.reviewer-provider`, `review-changes.reviewer-model` or `review-changes.reviewer-effort`; the defaults above. If the reviewer isn't you, [hand off](#0-hand-off) the whole run.

**Reading code.** At a ref, read with `git -C <dir> show <ref>:<path>` and `git -C <dir> grep -n -e <pattern> <ref> -- <pathspec>`. Never check anything out. In the working tree, read and grep the files directly.

## Process

### 0. Hand off

Skip this step if `reviewer-provider` is `self`, or if you already are `reviewer-model`.

Otherwise, the whole review runs on the reviewer: one run of this skill there, with every argument the caller gave plus `reviewer-provider=self`, so it doesn't hand off again. Keep the same `dir`, never a separate worktree or clone, so the reviewer sees the same files, uncommitted edits included. Always give it an `out` (a file in the system temp dir if the caller gave none), and tell it to change no files except `out` and its temp files. Use the first route that works:

1. **A sub-agent on the reviewer.** If your harness can start a sub-agent on `reviewer-provider` / `reviewer-model` with `reviewer-effort`, start one there and wait for it.
2. **The provider's command-line tool.** For `codex`, if `codex` is on the PATH:
   ```bash
   codex exec -m <reviewer-model> -c model_reasoning_effort="<reviewer-effort>" \
     -s workspace-write -C <dir> --ephemeral \
     "Use the review-changes skill with <arguments>. Change no files except out and temp files."
   ```
   This needs this skill installed for Codex too. `workspace-write`, not `read-only`, because the run writes `out` and, on big changes, group diffs in the temp dir.
3. **Neither works** (the provider is off, the model doesn't exist, the tool fails, or `out` comes back missing or not valid JSON): stop and say why. Never switch to another model or provider without saying so. If the caller is a person, offer to review in this session instead. If it's another skill, return the failure to it.

Then read `out`, give the [output](#4-output) from it, and skip steps 1–3.

### 1. Scope

Get the diff. If it's empty, stop and say so.

Then write down three things every reviewer needs:
- **Intent:** what the change is meant to do, in one or two sentences.
- **Load:** the expected load, from the README or deploy config. Is it one person running a script, or many users and processes at once?
- **Tests:** where they live and what runs them.

### 2. Review

Skip files nobody should hand-review: lockfiles, generated code, vendored code, snapshots, and binaries.

**Small change** (about 400 changed lines or fewer in the reviewable files): review it yourself. A sub-agent's cold start costs more than it saves here.

**Bigger change:** split the reviewable files into groups of related files (same module or feature, around 300–600 changed lines each, at most 5 groups). Write each group's diff to its own file in the system temp dir. Spawn one sub-agent per group, all in the same turn, on your own model and effort (by this step, you are the reviewer). Give each one:
- `dir`, `at` and the read commands above;
- Intent, Load and Tests;
- its diff file and the list of its files (other files are context, not targets);
- what the other groups cover, so nothing falls between them. The group that changes a shared function or component also owns every caller the change didn't touch;
- the [review guide](#review-guide) and the [finding record](#finding-record), copied in full, since sub-agents can't see this file;
- the rule: read only, change nothing, and return only finding records.

If you can't spawn sub-agents (for example, you are one), review the groups yourself, one after another.

**Completion criterion:** every reviewable file has been read with its connected code: callers, callees, and tests.

### 3. Merge

Collect all findings. When two groups report the same root cause, keep one finding, at the root cause. Number them in order of severity: `bug`, `risk`, `nit`, `q`.

### 4. Output

Reply in very simple English: short sentences and everyday words. The reader may never have seen this code.

```
reviewed by <reviewer-provider>/<reviewer-model> (<reviewer-effort>)
What this change does: <two sentences>

1. src/auth.ts:42 bug: user can be null after .find(). Add a guard before .email.
   Case: login with an unknown email → .find() returns undefined → crash on .email.
2. ...

Verdict: fix 1 and 3 first.        (or: Verdict: Ship.)
Not checked: <one line, only if something mattered and you couldn't check it>
```

The `reviewed by` line is always the first line, with the provider, model and effort that actually did the review (with `self`, your own provider and model, never the word `self`).

With no findings: the `reviewed by` line and `What this change does:`, then `Looks good. Ship.` and one line on what you checked.

If `out` was given, also write the [JSON result](#json-result) there and print its path.

## Review guide

Order of importance: correct, safe, holds under load, tested, fast, lean.

**Understand first.** Read the diff, then the code it touches: the callers of every changed function, the functions it calls, and its tests. Trace the real flow: where data comes in, what is stored, and what goes out. When a signature, return value or behavior changes, grep **every** caller, because a change can break code it doesn't touch.

**Look for:**
1. **Bug:** a wrong result, a crash, or a missed edge case (empty, zero, last item, rounding, time zones). Also a caller broken by the change, or a fix applied in one caller while the shared function stays broken.
2. **Risk:** security holes (injection, weak randomness, secrets, missing checks on user input) and data loss (swallowed errors, writes in the wrong order, no transaction).
3. **Scale:** code that's fine for one user and wrong for many. Look for check-then-write races, the same work done by every process, memory or lists that only grow, a query per item, O(n²) on big input, and per-process state that has to be shared. Judge against Load.
4. **Missing test:** risky new logic (a branch, a parser, money, security, data writes, a bug fix) with no test that fails when it breaks. Ask for one good test, not coverage.
5. **Speed:** big slowdowns are problems. Small wins, such as work repeated in a hot loop, are nits.
6. **Lean:** code that shouldn't exist or should be smaller. Flag dead code, unused options and speculative features. Point to an existing helper the repo already has (name the path), or to the stdlib or platform when it already does the job. Flag a new dependency added for a few lines, an abstraction with one implementation, config nobody sets, near-copies that must change together, and a function doing several unrelated jobs.

**Check before you report:**
- Every finding needs a concrete case: this input or situation leads to this wrong result. No case, no finding.
- Re-read the lines and confirm: the caller exists, the value really can be empty, the code really is unused.
- A shortcut with a comment that names its limit is a decision, not a finding, unless Load already crosses that limit.
- Propose the smallest fix that works, and prefer fixes that delete code. Never add layers, frameworks or config the problem doesn't need.
- No style taste, no "consider", no vague worries.

**Severity:** a bug, data loss, or breaking at Load → `bug`. A security hole, a scale risk, or risky code without a test → `risk`. Lean and small speed wins → `nit`. A real doubt you couldn't settle by reading the code → `q`.

## Finding record

One per finding:

```
- path: src/auth.ts
  line: 42          # line in the reviewed version; for removed code, the old-file line with side LEFT
  side: RIGHT
  severity: bug     # bug | risk | nit | q
  case: login with an unknown email → .find() returns undefined → crash on .email
  problem: user can be null after `.find()`
  fix: add a guard before `.email`
```

`line` points at the root cause, even when that's outside the diff (for example, a caller the change broke). A finding about the change as a whole has `path` and `line` set to null.

If there's nothing to report, return `No findings.` and one line on what you checked.

## JSON result

```json
{
  "reviewer": "codex/gpt-6.2-sol (high)",
  "what_this_change_does": "Two sentences.",
  "verdict": "fix 1 first",
  "not_checked": null,
  "findings": [
    {"id": 1, "path": "src/auth.ts", "line": 42, "side": "RIGHT", "severity": "bug",
     "case": "...", "problem": "...", "fix": "..."}
  ]
}
```
