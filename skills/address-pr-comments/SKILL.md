---
name: address-pr-comments
description: Address GitHub PR review comments one by one with an approval workflow. All work happens locally; replies are posted only after the user approves them. Use when the user asks to address, review, or handle PR comments or feedback, e.g. `/address-pr-comments <pr_url>`.
---

# Address PR Comments

Usage: `/address-pr-comments [pr_url]`

Work through every open review comment on a PR locally, one at a time, with the user's approval at each step. Nothing is posted to the PR until all comments are handled and the user approves the replies.

Use the `gh` CLI for all GitHub access. Never clone, delete, or reset a repo without explicit user approval.

## Step 0: Find the PR and the local repo

1. **PR:** if the user passed a PR URL (or number), use it. Otherwise use the PR for the current branch: `gh pr view --json number,url,headRefName,baseRefName`. If there is none, ask the user.
2. **Local repo:** if the current directory is a clone of the PR's repo, use it. Otherwise ask the user where the local clone is. Do not clone it yourself without approval.
3. **Branch:** make sure the PR's head branch is checked out and up to date with the remote. If there are uncommitted changes or the branch has diverged, stop and ask.

## Step 1: Collect the comments

Fetch all three kinds of feedback:

- **Inline review threads**, with resolution state (GraphQL `reviewThreads` gives `isResolved`, `isOutdated`, and each thread's comments):
  ```sh
  gh api graphql -f query='
    query($owner:String!,$repo:String!,$pr:Int!){
      repository(owner:$owner,name:$repo){
        pullRequest(number:$pr){
          reviewThreads(first:100){
            nodes{ id isResolved isOutdated path line
              comments(first:50){ nodes{ databaseId author{login} body } } }
          }
        }
      }
    }' -F owner=OWNER -F repo=REPO -F pr=NUMBER
  ```
- **Review summaries:** `gh api repos/OWNER/REPO/pulls/NUMBER/reviews` (skip empty bodies).
- **Conversation comments:** `gh api repos/OWNER/REPO/issues/NUMBER/comments`.

Skip resolved threads. Include outdated threads, but say they are outdated. Show the user a short numbered list of what will be addressed before starting.

## Step 2: Address comments one by one (local only)

Do NOT post anything to the PR, commit, or push during this step.

For each comment:
1. Show the comment: author, file and line, and the full thread.
2. Give your opinion (agree / disagree / partially agree) and why.
3. Propose how to address it: a code change, or a reply-only answer if no change is needed.
4. Wait for the user's approval before changing anything.
5. If approved, make the change locally and move on to the next comment.
6. If not approved, discuss alternatives and wait for the user's direction.
7. Do NOT skip ahead. Each comment needs explicit approval.

Keep a running note of what was done for each comment, for use in the replies.

## Step 3: Draft and post replies

Only after ALL comments have been addressed:
1. Draft a reply for each comment, based on what was done or decided.
2. Show all drafted replies together for the user to review and edit.
3. After the user approves, post each reply in the thread of its original comment:
   - inline thread: `gh api repos/OWNER/REPO/pulls/NUMBER/comments/COMMENT_ID/replies -f body=...`
   - review summary or conversation comment: `gh pr comment NUMBER --body ...`, quoting the comment being answered.
4. Do not resolve threads. The reviewer resolves them.

## Step 4: Commit and push

After the replies are posted:
1. Show the full local diff and stage the changes (`git add` only the files changed while addressing comments).
2. With the changes staged, use the `generate-staged-commit` skill to write the commit message.
3. Show the message and commit only after the user approves it.
4. Ask before pushing, then push to the PR's head branch.
