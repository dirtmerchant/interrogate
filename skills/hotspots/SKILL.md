---
name: hotspots
description: Step 5 of 7 in the architecture interrogation. Finds the load-bearing files and abstractions using import counts and git history.
disable-model-invocation: true
---

You are assessing the architecture of a codebase. This is step 5 of 7: find the load-bearing parts. You are in a fresh session, so start by reading the notes in `.interrogate/` (steps 01 to 04). If they are missing, stop and tell the user which step to run first.

## Task

Find the five files or abstractions that would break the most if they changed. Use measurements, then judgment.

The runner has already measured the repository at the assessed commit. Use these files in `.interrogate/metrics/` instead of running your own counts, and cite their rows:

- **Fan-in**: `fanin.tsv` gives, for each imported file or package directory, how many distinct files and directories import it. It comes from `imports.tsv`, which covers Python, JavaScript/TypeScript, Go, Java, and Kotlin only. `summary.json` lists the languages it doesn't cover. For those, count with search and mark the count estimated.
- **Churn**: `churn.tsv` gives commits and distinct authors per file in a 365-day window that ends at the assessed commit's date.
- **Co-change**: `cochange.tsv` lists file pairs that change in the same commits. Bulk commits are already excluded. Pairs that always change together across a module boundary are a hidden coupling.

Check `summary.json` first. If history is shallow or short, say so, and rely on fan-in.

The ranking is your judgment, not a formula. A file with high fan-in, high churn, and no tests is the worst case, but say why each of the five is on the list.

For each of the five, record:

- what it is, with `path:line`
- fan-in count and churn count
- what depends on it and what would break
- whether tests cover it (cite the test file, or say none found)
- risk: high fan-in with high churn and no tests is the worst case

## Rules

- Every number is either **measured** or **estimated**. A measured number cites the row it came from in `.interrogate/metrics/` (for example `.interrogate/metrics/churn.tsv:12`); those files are produced by the runner at the assessed commit, and you must not edit them. An estimated number says how you estimated it. If the metrics directory doesn't exist (an interactive session, or a target with no git history), every number is estimated: say so.
- Change nothing except files under `.interrogate/`.
- Show the numbers. Don't call a file load-bearing without a count behind it.
- Don't recompute what the metrics already give you. If you believe a measured number is wrong (for example, an import the regex missed), say so and give your estimate next to it.

## Output

Write the findings to `.interrogate/05-hotspots.md`, replacing any existing file: a ranked table of the five, a section on each, any hidden couplings from co-change, then **Open questions**.

End the file with this findings index, exactly in this form, one row per hotspot in rank order. The runner checks it, and it is how separate runs are compared. Use the file path or package directory as written in the metrics, the numbers from the metrics (or `-` if there is none), and `yes`, `partial`, or `no` for whether the numbers in that row are measured:

```
<!-- findings-index: hotspots -->
| rank | path | fanin | churn_window | measured |
| :- | :- | :- | :- | :- |
| 1 | app/service.py | 12 | 40 | yes |
```

Then reply with a summary of at most ten lines, and tell the user the next step: run `/clear`, then `/interrogate:critique`.
