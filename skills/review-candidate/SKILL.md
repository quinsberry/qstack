---
name: review-candidate
description: Review a technical interview transcription (.docx or .md) and produce a hire/no-hire recommendation for a specific candidate. Use when the user provides a path to a .docx or .md interview transcript plus a candidate name and asks to review, assess, or evaluate the candidate. Triggers include "review candidate", "assess this interview", "evaluate candidate from transcript".
---

# Review Candidate

Evaluate a technical interview transcript and produce a structured hire recommendation.

## Inputs

The user provides:
1. **Path** to a `.docx` or `.md` file containing the interview transcription.
2. **Candidate name** — used to locate that person's answers inside the transcript (a transcript may contain multiple speakers: interviewer, candidate, others).

If either is missing, ask for it before proceeding.

## Workflow

### 1. Get transcript text

Branch on the file extension:

- **`.md` (or `.txt`, plain text):** read it directly with the Read tool. No extraction needed.
- **`.docx`:** run the bundled extractor to convert to plain text:

  ```bash
  python3 "$CLAUDE_SKILL_DIR/scripts/extract_docx.py" "<path-to-docx>"
  ```

  (`$CLAUDE_SKILL_DIR` is this skill's directory. If not set, use the absolute path to `scripts/extract_docx.py` inside this skill.)

  The script prints the full text to stdout. If it errors (corrupt file, not a real `.docx`, password-protected), report the exact error and stop.

- **Anything else:** report the unsupported extension and ask the user to provide `.docx` or `.md`.

### 2. Identify the candidate's answers

Read the extracted text. Attribute lines to speakers:
- Match the provided **candidate name** against speaker labels (e.g. `John:`, `[John Doe]`, `John Doe -`).
- The other speaker(s) are interviewer(s). Their questions give context; the candidate's responses are what you grade.
- If the candidate name does not appear, say so and ask the user to confirm the exact label used in the transcript. Do not guess silently.

### 3. Assess

Evaluate ONLY on evidence in the transcript. Do not invent answers the candidate did not give. For each technical topic discussed (e.g. React, JavaScript, system design, CSS, testing), judge depth, correctness, and whether they reasoned from first principles vs. recited.

- If the candidate clearly demonstrated a skill → high rating, with a short technical paraphrase of what they showed.
- If a topic was raised but the candidate was vague/wrong → low rating with what was missing.
- If a topic was never covered → do not rate it; note coverage gaps in the internal summary.

**When using quote, translate it in english**

Be calibrated and honest. A "no" is a valid and useful outcome. Avoid grade inflation.

**Decision rules — the decision is about ROLE FIT, not "is this a good engineer in general":**

1. **Anchor to the role.** Find the role/title in the transcript (file name, metadata, or opening lines — e.g. "Fullstack React/Node.js Engineer"). Decompose it into core requirements. Grade fit against EACH core requirement, not against the candidate's strongest area.

2. **Role-critical gaps gate the decision.** If a core requirement of the role is effectively unmet (e.g. "Node" in a fullstack-Node role, but the candidate has ~zero Node depth), that pushes toward NO. Do NOT wave away an unmet core requirement as "learnable on the job" — learnability is a tie-breaker for *secondary* skills, never a substitute for a missing *core* one. Reserve "learnable on-project" for non-critical gaps only.

3. **First-principles vs experience-shaped.** Explicitly judge whether the candidate knows *why* things work or only *what* works on their projects. A candidate who delivers day-to-day but stalls on the "why" (e.g. can't explain why Redux needs immutability without being told) has a depth ceiling — surface this as a key signal, and it caps the level (rarely Senior).

4. **Capture interviewer-named screening criteria.** If the interviewer flags a topic as something the company specifically screens for (e.g. "they ask about algorithms/data structures here"), assess it and call out the result explicitly, even if coverage was thin. A missing named screen criterion is a finding, not an omission.

5. **Borderline → lean on role fit.** State "No (borderline)" or "Yes (borderline)" when close, and name the single deciding factor. When core-req gaps and fundamentals gaps both point the same way, do not inflate to YES on the strength of communication or one strong area.

6. **Communication caution.** Even when communication is strong, note any caution worth flagging (e.g. overly informal/casual tone for a formal setting). Strengths and cautions both belong in the Communication section.

### 4. Output

Produce the summary in EXACTLY this format:

```
## Decision: Strong Yes / Yes / No / Strong No
(Yes – meets qualifications for the position, proceed to PMI; No – not proficient in required skills, reject)

### Candidate level: Junior / Mid / Mid+ / Senior

### Communication skills

### Summary

**Internal:** <Frank, direct, NOT shared with the candidate. Keep it tight — no prose
paragraph. Use this exact structure:

Verdict:
<YES/NO + level> — <one-line deciding factor, role-fit-based>

Strengths:
<2–4 short bullets or a single comma-separated line>

Gaps:
<2–4 short bullets — the role-critical ones first>

Depth:
<one line: first-principles vs experience-shaped, and the level ceiling it implies>

Screen criteria:
<result for any interviewer-named screen, e.g. algorithms; omit if none named>

Be concise — this is a scannable internal note, not an essay.>

**External:** <Feedback shared WITH the candidate. Friendly, informal, encouraging but
honest — talk to them like a peer, not a formal report. Use this structure:

What was strong:
<2–4 short bullets, specific>

Where to level up:
<2–4 short bullets, each = the gap + a concrete next step (topic, practice, or resource)>

Bottom line:
<one warm, honest sentence>

Keep the tone light and human. Still no fabricated praise — be real.>

### Coding task (Describe the task and results)

### Technical Assessment

- **<e.g. React> — <0–10>:** <e.g. No deep knowledge of how React reconciliation works>
- **<Skill> — <0–10>:** <comment>
- ...
```
Required Technical Assessment skills: React, JS/TS fundamentals, Node/BFF, CI/CD / DevOps, Data structures & Algorithms, State management (Redux), Testing (unit/integration), System design, AI. Add any other skills that were actually probed in the interview.

Descision guidance:
Yes – meets qualifications for the position, proceed to PMI
No – not proficient in required skills, reject

Rating scale guidance (0–10):
- 0: No knowledge
- 1: some knowledge
- 2: basic knowledge
- 3: beginner
- 4: below average
- 5: average
- 6: above average
- 7: proficient
- 8: advanced
- 9: excelent
- 10: outstanding

Only include skills that were actually probed in the interview. Include an item for any role-core skill the title implies even when coverage was thin or the candidate had no experience (e.g. Node.js, Algorithms) — a low rating with "effectively no experience / critical gap for this role" is a valid and important item, not an omission. Where the title implies fundamentals (JavaScript fundamentals, TypeScript, Algorithms/data structures), assess them if at all touched.

End with one line stating the overall level AND the single biggest factor behind the decision — and make that factor role-fit-based (e.g. "Node gap + fundamentals gap don't match a fullstack req"), not a generic strength.
