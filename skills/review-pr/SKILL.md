---
name: review-pr
description: Review a GitHub PR, draft terse threaded comments, and post them only after you approve.
disable-model-invocation: true
---

Review a GitHub PR along two axes, draft one terse comment per finding, show every draft, and post them as inline threads **only after explicit approval**.

The **gate** is the spine: nothing reaches the PR until you approve the full set. Every step before it produces drafts; only the last step writes to GitHub.

Use `gh` for all GitHub reads and writes. Review runs off the fetched diff — never clone the repo for a local copy. If a local clone of this repo already exists and you want its files for context, ask first, then switch it to the PR branch only on approval. Never delete a repo.

## Process

### 1. Pin the PR

Take the PR the user names (URL, `owner/repo#123`, or a number in the current repo). Fetch its diff, commits, and description:

- `gh pr diff <ref>` — the diff to review.
- `gh pr view <ref> --json title,body,commits,headRefName,url,author`.

Also fetch every existing comment, for [step 4.5](#45-dedupe-against-existing-comments) only:

- **Inline threads** — `gh api graphql` on `pullRequest.reviewThreads` for `isResolved`, `isOutdated`, `path`, `line`, and each comment's `databaseId`, `author`, `body`, `url`. REST doesn't expose resolved state.
- **Review bodies** — `gh api repos/{owner}/{repo}/pulls/{n}/reviews --paginate`.
- **Conversation comments** — `gh api repos/{owner}/{repo}/issues/{n}/comments --paginate`.

Drop comments by the PR author. Their replies are not findings. Keep everyone else's, including bots and your own earlier comments.

Confirm the diff is non-empty before going further. Empty diff or bad ref fails here.

### 2. Find the spec source

Locate what the PR was supposed to implement, in order:

1. Issue references in the PR title, body or commits (`XXX-0000`, `Closes #45`) — fetch via `gh issue view`.
2. A path the user passed.
3. A PRD/spec file under `docs/`, `specs/`, or matching the branch name. (optionally)

If nothing turns up, ask. If the user says there's no spec, skip the Spec axis and note it.

### 3. Review along two axes

Review blind: don't read the existing comments here, so your findings stay independent of what others raised.

Examine **every changed hunk** against both:

- **Standards** — repo standards (`CONTRIBUTING.md`, `CODING_STANDARDS.md`, lint config) plus the [smell baseline](#smell-baseline). Skip anything tooling already enforces. A documented repo standard overrides the baseline.
- **Spec** — does the diff implement what the spec/issue asked? Flag: (a) missing/partial requirements, (b) scope creep, (c) requirements implemented wrong.

**Completion criterion:** every changed file accounted for against both axes — not a sampled subset.

### 4. Draft comments

Turn each finding into one draft comment in the [terse format](#comment-format), anchored to `path` + `line`. Keep the axis in mind but write the comment plainly — the author doesn't care which pass found it.

**Completion criterion:** every finding from step 3 has exactly one draft comment with a real file and line.

### 4.5. Dedupe against existing comments

Match each draft against the comments fetched in step 1. A draft matches when it raises the **same problem** as an existing comment:

- **Inline thread** — same `path`, line within ±3, same problem (your judgement).
- **Review body / conversation comment** — same problem, by content alone.

Thread state:
- **Resolved** — a match suppresses the draft. Someone already decided on it.
- **Outdated** — a match suppresses the draft only if the flagged code still has the same problem in the current diff. Otherwise keep the draft as new.

Partial overlap (same problem, different fix) counts as a match. Exception: if your severity is higher (theirs `nit:`, yours `bug:`), keep the draft as a **reply** to their inline thread, or as a new thread if the match was a review body or conversation comment.

**Completion criterion:** every draft is marked `new`, `reply → <comment url>`, or `omitted → <comment url>`.

### 5. Gate — show all, get approval

Present every `new` and `reply` draft as a numbered list grouped by file, each showing `path:line`, severity, and body. Mark replies with the thread they answer. Post **nothing** yet.

Below it, show the omitted drafts as a separate list numbered `O1`, `O2`…, each with its draft and a link to the existing comment it matched. If every draft was omitted, say **No new findings.** above the list.

Then ask the user to approve, edit, or drop each comment or the whole set, and to `un-omit On` any omitted draft. An un-omitted draft becomes a reply on its matched inline thread, or a new thread if it matched a review body or conversation comment. Wait for an explicit reply. Revise and re-show if they edit. Do not advance to step 6 until they approve.

### 6. Post as threads

Post only the approved comments as **inline review threads** so each lands on its diff line:

1. Create a pending review on the PR.
2. Add each approved comment to its `path` + `line`.
3. Submit the review as `COMMENT` (not approve/request-changes unless the user says so).

`gh api` route: `POST /repos/{owner}/{repo}/pulls/{n}/reviews` with a `comments` array (`path`, `line`, `body`, `side`).

Then post each approved reply on its own: `POST /repos/{owner}/{repo}/pulls/{n}/comments/{comment_id}/replies` with `body`. Replies can't join the review batch.

Skip the review if no new threads were approved, so you never submit an empty review. If nothing at all was approved, post nothing. Report the posted count, the review URL, and each reply URL.

## Comment format

One line per finding. Location, problem, fix. No throat-clearing, no restating what the line does, no hedging.

`path:line: <severity> <problem>. <fix>.`

Severity prefix:
- `bug:` — broken behavior, will cause an incident
- `risk:` — works but fragile (race, missing null check, swallowed error)
- `nit:` — style, naming, micro-optimization; author can ignore
- `q:` — genuine question, not a suggestion

Keep exact line numbers, symbol names in backticks, a concrete fix, and the *why* when the fix isn't obvious. If unsure whether something is wrong, make it a `q:`.

Example: `auth.ts:42: bug: user can be null after .find(). Add guard before .email.`

**Auto-clarity:** for security findings (CVE-class) and architectural disagreements, drop terse mode — write a full paragraph with rationale, then resume terse for the rest.

## Smell baseline

A fixed set of Fowler code smells that applies even when the repo documents nothing. Each is a judgement call ("possible Feature Envy"), never a hard violation. Reads *what it is* → *how to fix*:

- **Mysterious Name** — a name that doesn't reveal what it does or holds. → rename; if no honest name comes, the design's murky.
- **Duplicated Code** — the same logic shape in more than one hunk. → extract, call from both.
- **Feature Envy** — a method reaching into another object's data more than its own. → move it onto the data it envies.
- **Data Clumps** — the same fields travelling together. → bundle into one type.
- **Primitive Obsession** — a primitive standing in for a domain concept. → give the concept its own type.
- **Repeated Switches** — the same switch on the same type recurring. → polymorphism, or one shared map.
- **Shotgun Surgery** — one change forcing scattered edits. → gather what changes together.
- **Divergent Change** — one module edited for several unrelated reasons. → split by reason.
- **Speculative Generality** — abstraction added for needs the spec doesn't have. → delete, inline back.
- **Message Chains** — long `a.b().c().d()` the caller shouldn't depend on. → hide behind one method.
- **Middle Man** — a class that mostly just delegates. → cut it, call the real target.
- **Refused Bequest** — a subclass ignoring most of what it inherits. → use composition.
