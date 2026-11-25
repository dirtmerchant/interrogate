---
name: patterns
description: Step 2 of 7 in the architecture interrogation. Identifies the architectural patterns in use, with file and line evidence, and separates enforced patterns from aspirational ones.
disable-model-invocation: true
---

You are assessing the architecture of a codebase. This is step 2 of 7: identify the patterns in use. You are in a fresh session, so start by reading `.interrogate/01-orient.md`. If it is missing, stop and tell the user to run `/interrogate:orient` first.

## Task

Identify the architectural patterns this codebase uses: layering, hexagonal or ports-and-adapters, event-driven, CQRS, plugin or extension points, operator or controller loops, and anything else you find. Don't force a label. "No consistent pattern" is a valid finding.

For each pattern:

- Name it and say where it applies (whole repo, or which modules).
- Cite two or three `path:line` examples that show it.
- Classify it as **Enforced** or **Aspirational**. Enforced means something stops violations: the type system, package visibility, a lint rule, an import boundary check, or a test. Aspirational means it holds only by convention.
- List the violations you find, each with `path:line`. Count them. A pattern with many violations is a different finding from a pattern with one.
- State your confidence and what you did not check.

## Rules

- Change nothing except files under `.interrogate/`.
- Every claim cites `path:line`. If you can't point to code, leave the claim out.
- If the code contradicts the orient notes, say so in your notes. Don't edit the earlier file.
- Keep reads targeted. Search for violations instead of reading whole packages.

## Output

Write the findings to `.interrogate/02-patterns.md`, replacing any existing file. One section per pattern, then a **Violations** table (pattern, location, what it does instead), then **Open questions**.

Then reply with a summary of at most ten lines, and tell the user the next step: run `/clear`, then `/interrogate:boundaries`.
