---
name: generate-staged-commit
description: >
    Write a Conventional Commits message for the currently staged changes.
    Reads the staged diff and recent git log so the message matches the
    repo's conventions, and outputs it ready to paste without committing.
    Use whenever the user asks for a commit message, wants to know what to
    call their staged changes, or says /generate-staged-commit, even if
    they don't mention Conventional Commits.
---

Write commit messages terse and exact. Conventional Commits format. No fluff. Why over what.

## Process

1. Run `git diff --cached --stat`, then `git diff --cached`. Describe only what is staged — unstaged work is not part of this commit. If nothing is staged, say so and stop.
2. Run `git log --oneline -20` to pick up the repo's conventions: scope naming, capitalization after the colon, emoji use. Follow them over the defaults below.
3. If the staged changes are unrelated (e.g. a bug fix plus an unrelated refactor), say so and suggest splitting them before writing a single message.
4. Take the _why_ from the conversation context. The diff shows what changed, not why — if the reason isn't known, omit the body rather than invent one.

## Rules

**Subject line:**

- `<type>(<scope>): <imperative summary>` — `<scope>` optional
- Types: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, `build`, `ci`, `style`, `revert`
- Imperative mood: "add", "fix", "remove" — not "added", "adds", "adding"
- ≤50 chars when possible, hard cap 72
- No trailing period
- Match project convention for capitalization after the colon

**Body (only if needed):**

- Skip entirely when subject is self-explanatory
- Add body only for: non-obvious _why_, breaking changes, migration notes, linked issues
- Wrap at 72 chars
- Bullets `-` not `*`
- Reference issues/PRs at end: `Closes #42`, `Refs #17`

**What NEVER goes in:**

- "This commit does X", "I", "we", "now", "currently" — the diff says what
- "Generated with Claude Code" or any AI attribution — unless the user's own rule requires an `Assisted-by`/AI-attribution trailer, then add it as a trailer
- Emoji (unless project convention requires)
- Restating the file name when scope already says it

## Examples

Diff: new endpoint for user profile with body explaining the why

- ❌ "feat: add a new endpoint to get user profile information from the database"
- ✅

    ```
    feat(api): add GET /users/:id/profile

    Mobile client needs profile data without the full user payload
    to reduce LTE bandwidth on cold-launch screens.

    Closes #128
    ```

Diff: breaking API change

- ✅

    ```
    feat(api)!: rename /v1/orders to /v1/checkout

    BREAKING CHANGE: clients on /v1/orders must migrate to /v1/checkout
    before 2026-06-01. Old route returns 410 after that date.
    ```

## Auto-Clarity

Always include body for: breaking changes, security fixes, data migrations, anything reverting a prior commit. Never compress these into subject-only — future debuggers need the context.

## Boundaries

Only generates the commit message. Does not run `git commit`, does not stage files, does not amend. Output the message as a code block ready to paste.
