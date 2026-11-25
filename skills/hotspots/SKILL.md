---
name: hotspots
description: Step 5 of 7 in the architecture interrogation. Finds the load-bearing files and abstractions using import counts and git history.
disable-model-invocation: true
---

You are assessing the architecture of a codebase. This is step 5 of 7: find the load-bearing parts. You are in a fresh session, so start by reading the notes in `.interrogate/` (steps 01 to 04). If they are missing, stop and tell the user which step to run first.

## Task

Find the five files or abstractions that would break the most if they changed. Use measurements, then judgment.

Measure:

- **Fan-in**: how many files import or reference each candidate. Use the dependency table in the boundaries notes as a starting list, then count with search.
- **Churn**: which files change most often. Use this exact pipeline, which runs without a permission prompt:
  `git log --since="1 year ago" --format= --name-only | sort | uniq -c | sort -rn | head -40`
- **Co-change**: for the top candidates, which other files change in the same commits (`git log --format=%h --follow -- <path>` and then `git show --stat --format= <hash>` for a sample of commits). Files that always change together across a module boundary are a hidden coupling.

If this is not a git repository, or history is shallow, say so and rely on fan-in.

For each of the five, record:

- what it is, with `path:line`
- fan-in count and churn count
- what depends on it and what would break
- whether tests cover it (cite the test file, or say none found)
- risk: high fan-in with high churn and no tests is the worst case

## Rules

- Change nothing except files under `.interrogate/`.
- Show the numbers. Don't call a file load-bearing without a count behind it.
- Use only read-only git commands.

## Output

Write the findings to `.interrogate/05-hotspots.md`, replacing any existing file: a ranked table of the five, a section on each, any hidden couplings from co-change, then **Open questions**.

Then reply with a summary of at most ten lines, and tell the user the next step: run `/clear`, then `/interrogate:critique`.
