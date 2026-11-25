---
name: patterns
description: Step 2 of 7 in the architecture interrogation. Identifies the architectural patterns in use, with file and line evidence, and separates enforced patterns from aspirational ones.
disable-model-invocation: true
---

You are assessing the architecture of a codebase. This is step 2 of 7: identify the patterns in use. You are in a fresh session, so start by reading `.interrogate/01-orient.md`. If it is missing, stop and tell the user to run `/interrogate:orient` first.

## Task

Identify the architectural patterns this codebase uses: layering, hexagonal or ports-and-adapters, event-driven, CQRS, plugin or extension points, operator or controller loops, and anything else you find. Don't force a label. "No consistent pattern" is a valid finding.

Start from `.interrogate/metrics/enforcement.tsv`. The runner lists there the configuration it found that can enforce an architectural rule: import-linter contracts, dependency-cruiser and ESLint import rules, ArchUnit tests, Go `internal/` packages, Java modules, Bazel visibility, and CODEOWNERS. A row means the configuration exists at the assessed commit. Read it to see what it actually checks, and whether CI runs it if you can tell. A mechanism with no row may still exist (a custom test, a type-level boundary), so look for those too.

For each pattern:

- Name it and say where it applies (whole repo, or which modules).
- Cite two or three `path:line` examples that show it.
- Classify it as **Enforced** or **Aspirational**. Enforced means something stops violations: the type system, package visibility, a lint rule, an import boundary check, or a test. Aspirational means it holds only by convention. An Enforced claim cites the mechanism: an `enforcement.tsv` row or the code that does the enforcing.
- Use `.interrogate/metrics/imports.tsv` to find violations of a layering or boundary pattern: each row is an import with its `path:line`.
- List the violations you find, each with `path:line`. Count them. A pattern with many violations is a different finding from a pattern with one.
- State your confidence and what you did not check.

## Rules

- Every number is either **measured** or **estimated**. A measured number cites the row it came from in `.interrogate/metrics/` (for example `.interrogate/metrics/churn.tsv:12`); those files are produced by the runner at the assessed commit, and you must not edit them. An estimated number says how you estimated it. If the metrics directory doesn't exist (an interactive session, or a target with no git history), every number is estimated: say so.
- Change nothing except files under `.interrogate/`.
- Every claim cites `path:line`. If you can't point to code, leave the claim out.
- If the code contradicts the orient notes, say so in your notes. Don't edit the earlier file.
- Keep reads targeted. Search for violations instead of reading whole packages.

## Output

Write the findings to `.interrogate/02-patterns.md`, replacing any existing file. One section per pattern, then a **Violations** table (pattern, location, what it does instead), then **Open questions**.

End the file with this findings index, exactly in this form, one row per pattern. The runner checks it, and it is how separate runs are compared. `status` is `Enforced` or `Aspirational`; `violations` is the number you counted (0 if none):

```
<!-- findings-index: patterns -->
| pattern | scope | status | violations |
| :- | :- | :- | :- |
| Layered architecture | app/ | Aspirational | 3 |
```

If you found no consistent pattern, write one row with the pattern `No consistent pattern`, the scope `whole repo`, the status `Aspirational`, and 0 violations.

Then reply with a summary of at most ten lines, and tell the user the next step: run `/clear`, then `/interrogate:boundaries`.
