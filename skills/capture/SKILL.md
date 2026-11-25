---
name: capture
description: Step 7 of 7 in the architecture interrogation. Turns the notes into ARCHITECTURE.md, a list of issues to file, and a proposed CLAUDE.md.
disable-model-invocation: true
---

You are finishing an architecture assessment. This is step 7 of 7: capture the result. You are in a fresh session, so start by reading every notes file in `.interrogate/` (steps 01 to 06). If any are missing, tell the user which, and continue with what exists.

## Task

Produce three files from the notes. Don't explore the codebase again, with one exception: before you write, check that a sample of at least ten of the `path:line` citations you plan to keep still point at what the notes say. Drop or fix any that don't, and say how many you checked.

1. **`ARCHITECTURE.md`** at the repository root. If one already exists, leave it alone and write `.interrogate/ARCHITECTURE.proposed.md` instead. Sections:
   - Overview: what the system is and its entry points
   - Modules and boundaries, with the dependency direction
   - Patterns: enforced and aspirational, kept separate
   - One request, end to end (from the trace)
   - Load-bearing parts
   - Known violations and risks, ranked
   - Open questions
   
   Write it for a new contributor. Keep the citations. State how and when this was produced, and that it is an assessment for the maintainers to review.

2. **`.interrogate/issues.md`**: one entry per violation or risk that someone should act on. For each: a title, the evidence with `path:line`, why it matters, severity, and a suggested scope. Describe the problem, not the fix. These are for the user to file; don't file them.

3. **`.interrogate/CLAUDE.proposed.md`**: only the conventions a new contributor or coding agent would get wrong without being told, such as a boundary that must not be crossed, a non-obvious build or test command, or a pattern that looks optional and isn't. Keep it under forty lines. Leave out anything a reader can see from the code. Don't write to `CLAUDE.md` itself: it changes how every later agent session behaves, so it gets its own review.

## Rules

- Change nothing except `ARCHITECTURE.md` and files under `.interrogate/`.
- Carry over nothing from the notes that lacks a citation.
- Don't commit, push, open pull requests, or file issues.

## Output

After writing the three files, reply with what you wrote, how many citations you checked and how many failed, and this suggested order for the user: one pull request for `ARCHITECTURE.md`, a separate one for `CLAUDE.md`, and issues filed from `issues.md`.
