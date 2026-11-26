---
name: work-history
description: Export everything the current user worked on (issue tracker, code host, wiki, ITSM, local git), sanitize it, and write a work inventory plus a seniority/area analysis to ~/Downloads. Use for "/work-history", "update my work history", "what level is my work", "resume evidence". Args - "full" forces a rebuild; default is incremental.
---

# Work History Export

Builds evidence of the user's level and areas of work. All decisions below are settled, so don't re-ask them. Ask only if a source is unreachable or the user passes new instructions.

## Settled decisions

| Topic | Decision |
|---|---|
| Purpose | Resume bullets, interview STAR stories, and LLM input later |
| Time range | Whole tenure, with dates kept. Mark tickets created before the user's first real activity as `(inherited)`. |
| Sources | Issue tracker (assigned now, ever assigned, reported, epics), code host (authored PRs with diff stats; reviews of others as **counts only**), wiki pages created or contributed, ITSM incidents, local git logs. **Slack excluded.** |
| Sanitization | **Heavy.** Remove people, ticket keys, repo names, app IDs, URLs, hostnames, emails, incident/change/KB numbers, company name, internal product names. Business numbers become orders of magnitude. Public third-party tech and vendor names stay (they're the integration evidence). |
| Placeholders | Stable across runs: `Platform P`, `Product A`... each with a short generic description. The real-to-placeholder mapping stays private. |
| Employment framing | "large US retailer (Fortune 500), platform team". No employment status. |
| Outputs | `~/Downloads/work-history-inventory.md` (evidence), `~/Downloads/work-history-analysis.md` (ratings, matrix, trajectory, STAR stories, resume bullets, caveats), `~/Downloads/work-history-runbook.md` (copy of this skill) |
| Private state | `~/.work-history-private/` (chmod 700): `mapping.json`, `raw/`, `build_inventory.py`, `leak_check.py`, `stats.json`, `out/`. Never copy it anywhere else. |
| Evidence depth | Titles, metadata and descriptions (tracker/PR/wiki), plus PR diff stats. Don't read diffs. |
| Leak check | An automated grep must reach 0 hits, then the user skims the files manually before sharing |
| Re-run | Incremental by default (items newer than `mapping.json.last_run`, merged into raw). `full` re-exports everything. |

## Identity: resolved at runtime, never hard-coded

- Code host: `gh api user` (or the GitHub MCP `get_me`)
- Tracker: Jira MCP `get_current_user`; JQL with `currentUser()`
- Wiki: CQL with `currentUser()`
- ITSM: ServiceNow MCP `whoami`

Discover project keys and repo sets from the results, not from this file.

## Work-type tags

`feature`, `third-party-integration`, `internal-api-integration`, `migration/upgrade`, `bug-fix`, `prod-incident`, `infra/CI-CD/devops`, `testing/quality`, `architecture/design`, `observability/on-call`, `security/auth/access`, `tooling/DX/AI-tooling`, `docs/process`, `performance`, `mentoring/review` (counts only).

## Level rubric (per initiative, always with evidence)

- **L1 Task**: executed a defined ticket.
- **L2 Feature owner**: owned a feature across several tickets and made the design calls.
- **L3 End-to-end lead**: design doc, then tickets, implementation and release, coordinating others.
- **L4 Cross-team/platform**: affects many apps or teams (platform migrations, shared libraries, org-wide pipelines).

Signals to cite: design-doc authorship, reporter vs assignee counts, PR count, repo count, other assignees on the epic, release and rollback ownership, status (done vs proposed vs in progress). Don't overstate: call in-progress work in progress.

## Procedure

1. **Setup.** `mkdir -p ~/.work-history-private/{raw,out} && chmod 700 ~/.work-history-private`. Read `mapping.json` if present (`last_run`, placeholders, people, terms).
2. **Gather in parallel.** Use background agents, all read-only on the services. Each writes into `raw/`:
   - **Tracker → `raw/jira.jsonl` + `raw/jira-epics.md`**
     - JQL union: `assignee = currentUser()`, `assignee was currentUser()`, `reporter = currentUser()`. Add `AND updated >= <last_run>` when incremental.
     - The server caps results at 100 per call, so page with `startAt`.
     - Fields per issue: key, project, type, status, created/resolved, reporter, assignee, relation (assigned/reported/both/was-assigned), parent, epic link plus epic summary, labels, summary, and description truncated to ~800 characters.
     - For epics: list the children and their assignees.
   - **Code host → `raw/github-authored.jsonl`, `raw/github-reviewed.jsonl`, `raw/github-issues.jsonl`**
     - Search `is:pr author:<login>`. For each PR, get diff stats from `repos/O/R/pulls/N` (additions, deletions, changed_files, merged).
     - Search `is:pr reviewed-by:<login> -author:<login>`; keep metadata only.
   - **Wiki → `raw/confluence.md`**
     - CQL `creator = currentUser() AND type = page` union `contributor = currentUser() AND type = page`.
     - Per page: created/modified dates, version count, ancestors, created-by-user flag, and a 4-6 sentence factual summary (problem, decision, tech, scope, user's role).
     - Use the format `### <Section><n>. <title>` then `- id N | created DATE by NAME (user: YES/NO) | last modified DATE ...`. Sections: A = migration plan series, B = design/architecture, C = release/UAT, D = contributed only.
   - **ITSM → `raw/servicenow.md`**
     - Incidents assigned to, resolved by, or opened by the user, in all states.
     - Format: `## INCxxxx — title` then `- Opened: DATE ... | State: X`, then a summary.
   - **Local git → `raw/local-git.md`** (run directly, no agent)
     - For each repo under the workspace root, run `git log --all --since=<start> -i --author=<surname>` and write a `## <repo> (<n> commits)` block followed by `date subject` lines.
     - This covers code from before the move to the current code host.
3. **Update the mapping.** Add any new people (reporter/assignee fields, review authors, names inside wiki or ITSM text), new internal product, app or team terms, and new placeholder assignments to `mapping.json`. Never reuse a placeholder for a different product. Set `last_run` to today.
4. **Classify and build the inventory.**
   - Run `python3 -I ~/.work-history-private/build_inventory.py ~/.work-history-private ~/.work-history-private/out/work-history-inventory.md`.
   - The script holds the initiative regex rules, so they contain real terms and must stay private. Extend the rules for new initiatives.
   - Sub-tasks inherit their parent's initiative.
   - Repo-import PRs (bulk moves into a monorepo) and reverts are excluded from line totals.
   - Reviews are bucketed by repo into product placeholders.
   - If the script is missing (new machine), rebuild it from this spec. Output layout: context, totals, placeholder legend, then one section per initiative (median-date order) with a table `Date | Source | Role | Status | Summary | Tags | Size`, then review counts by area and by quarter.
5. **Write the analysis by hand** to `out/work-history-analysis.md`. Sections:
   1. Headline numbers
   2. The rubric
   3. Initiatives rated (`# | Initiative | When | Level | Evidence`)
   4. Work-type matrix with evidence strength
   5. Third-party integrations list
   6. Trajectory by quarter, plus an overall read with honest gaps
   7. STAR story candidates
   8. Draft resume bullets
   9. Caveats

   On incremental runs, re-rate only the initiatives that changed and append new ones.
6. **Leak check.**
   - Run `python3 -I ~/.work-history-private/leak_check.py ~/.work-history-private out/*.md`.
   - Fix every hit (in mapping terms or by rewording) and re-run until `LEAK HITS: 0`.
   - The generic patterns in the checker: company name, `APP\d+`, ticket-key patterns, `INC/CHG/KB` numbers, emails, URLs, internal product and team names, every person in `mapping.json.people`.
7. **Publish.** `cp ~/.work-history-private/out/work-history-*.md ~/Downloads/` and `cp ~/.claude/skills/work-history/SKILL.md ~/Downloads/work-history-runbook.md`.
   - On macOS the Write tool can fail with EPERM on `~/Downloads` (privacy protection), but `cp` through Bash works.
8. **Report.** Give the user the counts, the leak-check result, the top 3 findings and any data gaps. Remind them to skim the files manually before sharing.

## Gotchas

- Tracker Server/DC: `account_id` is null, so use `currentUser()` in JQL. The 100-result cap needs paging.
- `reviewed-by` without `-author:` counts self-reviews. Always exclude them.
- Keyword classifiers misfire on substrings (`vite` inside `invite`), so use word boundaries and check every section's rows.
- Big line counts usually mean imports, build migrations or lockfiles. Say so rather than presenting them as authored code.
- Generic phrases that match a product name (e.g. a product literally named after its function) trip the leak check, so use a neutral synonym.
- Contributed wiki pages: date them by last-modified, not by creation (someone else created them, sometimes years earlier).
