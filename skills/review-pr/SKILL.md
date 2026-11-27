---
name: review-pr
description: Review a GitHub PR, draft terse inline comments, and post them only after the user approves. The code review itself is done by the review-changes skill; this skill adds the GitHub side (fetching the PR, anchoring to diff lines, skipping problems other reviewers already raised, posting). Use for /review-pr <pr>, "review this PR", "leave review comments on #123".
---

Review a GitHub PR: draft one terse comment per finding, show every draft, and post them as inline threads **only after explicit approval**.

The **gate** is the spine: nothing reaches the PR until the user approves the full set. Every step before it produces drafts; only step 7 writes to GitHub.

The code review itself is done by the **`review-changes`** skill, from this same repo. If it isn't installed, stop and say so.

Speed matters: run independent commands in parallel and fetch each thing once. Nothing here depends on a particular agent, model or harness.

## Modes

Read the mode from the arguments:

- **Full** (default), `/review-pr <pr>`: steps 1–7. Review, show the gate, and post once the user approves.
- **Drafts only**, `/review-pr <pr> drafts-only [out=<path>]`: steps 1–5, then write the [drafts file](#drafts-file) to `out` (default: a new file in the system temp dir), print its path, and stop. Never ask a question and never post. On a problem that would need a question (no PR found, bad ref), stop and say why. This mode is for a caller that runs the review in another agent or model and keeps the gate for itself.
- **Post**, `/review-pr post <drafts file>`: skip the review and run step 7 for the drafts marked `"approved": true` in the file. The caller owns the approval. If the PR's head has moved past the file's `sha`, say so before posting. The comments still land on the reviewed commit.

## Reviewer

Optional in any mode: `reviewer-provider=<name>`, `reviewer-model=<name>` and `reviewer-effort=<level>`. Pass the ones given to `review-changes`, which owns the defaults and runs the review on that model. If it reports that the reviewer couldn't be reached, stop and tell the user. Never fall back to another model without asking.

## Process

### 1. Pin the PR

Take the PR the user names (URL, `owner/repo#123`, or a number in the current repo). With none named, use the current branch's PR (`gh pr view`); with none there either, ask.

In parallel:

- `gh pr view <ref> --json number,title,body,url,author,headRefOid,baseRefName,headRefName,files,closingIssuesReferences`
- `gh pr diff <ref>`, saved to a file in the system temp dir. If it fails because the diff is too big, build the file from `gh api repos/{owner}/{repo}/pulls/{n}/files --paginate`, which returns a `patch` for each file.

Pin `headRefOid` as **SHA**. Every read and the final post use it, so a push mid-review can't shift line numbers. Fail here on a bad ref or an empty diff.

### 2. Get the code

Reviewing the diff alone misses most real bugs, so the review needs the code at SHA. Pick the fastest source:

- **Local clone.** If the current folder is a clone of the PR's repo, run `git fetch <remote> pull/<n>/head`, where `<remote>` points at the base repo, and confirm `FETCH_HEAD` equals SHA. Don't check anything out; the user's working tree stays untouched.
- **Temp clone.** Otherwise, `gh repo clone {owner}/{repo} <tmp> -- --depth=1 -q`, then `git -C <tmp> fetch --depth=1 origin pull/<n>/head`. Put `<tmp>` in the system temp dir, and delete it when the run ends: after step 7, after writing the drafts file, or when the user aborts. Delete nothing else.

Write **Intent** in one or two sentences, from the PR title, the body and any linked issue (`gh issue view` if the body is thin).

### 3. Review

Run the `review-changes` skill with:

```
diff=<diff file> dir=<clone> at=<SHA> intent="<Intent>" out=<findings.json in the temp dir>
```

Add any [reviewer](#reviewer) arguments that were given. Show the `reviewer` from `findings.json` at the gate, and copy it into the drafts file.

The review is **blind**: don't look at the existing PR comments until step 5, so the findings stay independent.

### 4. Draft and anchor

Turn each finding in `findings.json` into one draft in the [comment format](#comment-format): `path:line: <severity> <problem>. <fix>.`

GitHub only accepts an inline comment on a line inside the diff, and one bad line fails the whole review. So check every anchor against the diff:
- an added or context line → its new-file line number, `side: RIGHT`;
- a deleted line → its old-file line number, `side: LEFT`;
- a line outside every hunk → move it to the nearest hunk line in that file showing the same problem. If there isn't one (for example, a caller in an unchanged file breaks), or the finding has no path, it becomes a **summary** draft for the review body.

**Completion criterion:** every finding has exactly one draft, either inline on a line that's in the diff, or a summary.

### 5. Dedupe against existing comments

Now fetch the existing comments, in parallel:

- **Inline threads:** `gh api graphql` on `pullRequest.reviewThreads(first:100)` for `path`, `line`, `originalLine` (outdated threads have no `line`), and each comment's `databaseId`, `author`, `body`, `url`. This includes resolved and outdated threads.
- **Review bodies:** `gh api repos/{owner}/{repo}/pulls/{n}/reviews --paginate`.
- **Conversation comments:** `gh api repos/{owner}/{repo}/issues/{n}/comments --paginate`.

Drop comments by the PR author; their replies aren't findings. Keep everyone else's, including bots and your own earlier comments.

A draft matches when it raises the **same problem** as an existing comment:
- **Inline thread:** same `path`, line within ±3, and the same problem (your judgement).
- **Review body or conversation comment:** the same problem, judged by content alone.

A match suppresses the draft whatever the thread's state: open, resolved (someone already decided on it), or outdated (the author was told and still left the problem in).

A partial overlap counts as a match: the same problem with a different fix, a different severity, or different wording. A problem someone already raised never gets a new comment or an automatic reply. The author has seen it once, and a second comment is noise. Only the user can bring a matched draft back, at the gate.

**Completion criterion:** every draft is marked `new` or `omitted → <comment url>`.

### 6. Gate: show all, get approval

In drafts-only mode, write the [drafts file](#drafts-file) instead and stop here.

Open with `What this change does:` from the review.

Then present every `new` draft as a numbered list grouped by file, in the [comment format](#comment-format). List summary drafts last, under **Review body**. Post **nothing** yet.

Below that, list the omitted drafts as `O1`, `O2`…, each with its draft and a link to the comment it matched. If every draft was omitted, say **No new findings.** above the list. If there were no findings at all, say `Looks good.` and add the review's line on what it checked.

End with the review's `Not checked:` line, if it has one.

Ask the user to approve, edit, or drop each comment or the whole set, and to `un-omit On` any omitted draft. An un-omitted draft becomes a reply on its matched inline thread, or a new thread if it matched a review body or a conversation comment. A reply targets the thread's **first** comment (its `databaseId`), because GitHub can't reply to a reply. Wait for an explicit reply. If they edit, revise and show the list again. Don't go on to step 7 until they approve.

### 7. Post as threads

Post only what was approved, as **one review**:

```bash
gh api repos/{owner}/{repo}/pulls/{n}/reviews --method POST --input - <<'EOF'
{"commit_id": "<SHA>", "event": "COMMENT", "body": "<approved summary drafts, or empty>",
 "comments": [{"path": "src/a.ts", "line": 42, "side": "RIGHT", "body": "bug: ..."}]}
EOF
```

- Each comment `body` drops the `path:line:` prefix, since the thread already sits on that line.
- Submit as `COMMENT`. Use approve or request-changes only if the user says so.
- Then post each un-omitted reply on its own, since replies can't join the review: `POST repos/{owner}/{repo}/pulls/{n}/comments/{first_comment_id}/replies` with `body`.
- Skip the review if it would have no comments and no body. If nothing was approved, post nothing.

In post mode, the approved drafts come from the file: `new` ones go into the review, and approved `omitted` ones are posted as replies to `reply_to`. If `reply_to` is null, they become new threads.

Report the number of comments posted, the review URL, and each reply URL. Delete the temp clone and temp files if you made them.

## Drafts file

The hand-off between drafts-only and post mode. It's JSON, so any caller can read it, show it, edit `body`, and set `approved`:

```json
{
  "pr": "https://github.com/owner/repo/pull/123",
  "sha": "<SHA>",
  "reviewer": "codex/gpt-6.2-sol (high)",
  "what_this_change_does": "Two sentences.",
  "not_checked": "One line, or null.",
  "drafts": [
    {"id": 1, "status": "new", "path": "src/auth.ts", "line": 42, "side": "RIGHT",
     "severity": "bug", "case": "unknown email → crash on .email",
     "body": "auth.ts:42: bug: user can be null after .find(). Add guard before .email.",
     "approved": false},
    {"id": 2, "status": "new", "path": null, "line": null, "side": null,
     "severity": "bug", "case": "...", "body": "Review-body finding.", "approved": false},
    {"id": "O1", "status": "omitted", "path": "src/db.ts", "line": 10, "side": "RIGHT",
     "severity": "risk", "case": "...", "body": "...",
     "matched_url": "<existing comment url>", "reply_to": 123456789, "approved": false}
  ]
}
```

A draft with `path: null` is a summary draft for the review body. `reply_to` is the `databaseId` of the matched thread's first comment, or null when the match was a review body or a conversation comment. Every draft starts with `"approved": false`.

## Comment format

One line per finding. Location, problem, fix. No throat-clearing, no restating what the line does, no hedging.

`path:line: <severity> <problem>. <fix>.`

Severity prefix:
- `bug:` broken behavior that will cause an incident
- `risk:` works but is fragile (race, missing null check, swallowed error)
- `nit:` style, naming, micro-optimization; the author can ignore it
- `q:` a genuine question, not a suggestion

Keep exact line numbers, symbol names in backticks, a concrete fix, and the *why* when the fix isn't obvious. If unsure whether something is wrong, make it a `q:`.

Example: `auth.ts:42: bug: user can be null after .find(). Add guard before .email.`

**Auto-clarity:** for security findings (CVE-class) and architectural disagreements, drop terse mode. Write a full paragraph with the rationale, then go back to terse for the rest.
