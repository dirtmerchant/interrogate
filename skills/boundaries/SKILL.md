---
name: boundaries
description: Step 3 of 7 in the architecture interrogation. Uses subagents to map module boundaries, dependency direction, cycles, and layer violations.
disable-model-invocation: true
---

You are assessing the architecture of a codebase. This is step 3 of 7: map boundaries and dependencies. You are in a fresh session, so start by reading `.interrogate/01-orient.md` and `.interrogate/02-patterns.md`. If either is missing, stop and tell the user which step to run first.

## Task

Map which modules depend on which, and whether the direction of those dependencies matches the layering the patterns notes describe.

The runner has already extracted imports at the assessed commit: `.interrogate/metrics/imports.tsv` has one row per import statement in Python, JavaScript/TypeScript, Go, Java, and Kotlin, with its `path:line`, the resolved file or package, and whether it is internal, external, or unresolved. `fanin.tsv` aggregates it. Use these as the baseline edge table. Your job is to check and complete it, not to rebuild it.

This is a wide sweep, so delegate it. Start one subagent per top-level package or module (use the list in the orient notes; group very small ones). Ask each subagent to report, for its package only:

- whether the package's rows in `imports.tsv` are right: spot-check a few, and list any `unresolved` rows it can resolve and any imports the regex missed (dynamic imports, path aliases, re-exports, languages it doesn't cover), each with `path:line` and marked estimated
- which other internal packages it imports, with one `path:line` example per edge
- which external systems it talks to directly
- what it exports that other packages use
- anything that looks like a reach across a boundary, such as importing another module's internals

Tell each subagent to return a short table and no file contents. Then combine the reports yourself:

- **Dependency table**: one row per edge (from, to, example location), marking each edge measured (from `imports.tsv`) or estimated (found by a subagent).
- **Cycles**: every import cycle, with the edges that form it.
- **Direction violations**: every place a lower layer reaches into a higher one, or a module bypasses another's public surface.
- **Shared kernel**: packages nearly everything depends on.

Spot-check at least three of the edges the subagents report by reading the cited line yourself.

## Rules

- Every number is either **measured** or **estimated**. A measured number cites the row it came from in `.interrogate/metrics/` (for example `.interrogate/metrics/churn.tsv:12`); those files are produced by the runner at the assessed commit, and you must not edit them. An estimated number says how you estimated it. If the metrics directory doesn't exist (an interactive session, or a target with no git history), every number is estimated: say so.
- Change nothing except files under `.interrogate/`.
- Every edge and violation cites `path:line`.
- If the code contradicts earlier notes, say so in your notes. Don't edit the earlier files.

## Output

Write the findings to `.interrogate/03-boundaries.md`, replacing any existing file. Use the four headings above, then **Open questions**.

Then reply with a summary of at most ten lines, and tell the user the next step: run `/clear`, then `/interrogate:trace <feature>`.
