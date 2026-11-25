---
name: orient
description: Step 1 of 7 in the architecture interrogation. Maps entry points, modules, build and deploy targets, and external dependencies, and flags where the docs and the code disagree.
disable-model-invocation: true
---

You are assessing the architecture of a codebase you have not seen before. This is step 1 of 7: get oriented. Later steps run in fresh sessions and know only what you write down, so the notes file is the deliverable.

## Task

Map this codebase from the code itself. READMEs and docs are claims to check, not sources.

Cover:

- **Entry points**: binaries, servers, CLIs, handlers, scheduled jobs. Where execution starts.
- **Top-level modules**: each package or directory that matters, with one line on its responsibility.
- **Build and deploy targets**: what gets built, how, and where it runs (Dockerfiles, CI config, IaC, manifests).
- **External dependencies**: datastores, queues, third-party APIs, identity providers. Note where each is configured.
- **Docs vs. code**: every place the documentation describes something the code does not do, or omits something it does.

## Rules

- Every number is either **measured** or **estimated**. A measured number cites the row it came from in `.interrogate/metrics/` (for example `.interrogate/metrics/churn.tsv:12`); those files are produced by the runner at the assessed commit, and you must not edit them. An estimated number says how you estimated it. If the metrics directory doesn't exist (an interactive session, or a target with no git history), every number is estimated: say so.
- Change nothing except files under `.interrogate/`. This is an assessment.
- Every claim cites `path:line`. If you can't point to code, leave the claim out.
- Mark each finding **Confirmed** (you read the code) or **Inferred** (from names or structure).
- Keep reads targeted. Use search to find things and read only what you need to confirm them.

## Output

Write the findings to `.interrogate/01-orient.md`, replacing any existing file. Use the five headings above, and end with an **Open questions** list for later steps.

Then reply with a summary of at most ten lines, and tell the user the next step: run `/clear`, then `/interrogate:patterns`.
