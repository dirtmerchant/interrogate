---
name: critique
description: Step 6 of 7 in the architecture interrogation. Reviews the design as a skeptical staff engineer and ranks what will hurt at scale, with a larger team, or under audit.
disable-model-invocation: true
---

You are assessing the architecture of a codebase. This is step 6 of 7: the critique. You are in a fresh session, so start by reading the notes in `.interrogate/` (steps 01 to 05). If they are missing, stop and tell the user which step to run first.

## Task

Review this codebase as a skeptical staff engineer deciding whether to adopt it. The earlier notes are your leads. Go back to the code to confirm anything you rely on.

Ask what breaks under each of these pressures:

- **10x load**: single points of contention, unbounded queries, synchronous calls in hot paths, state that cannot be partitioned.
- **10x team size**: boundaries that exist only by convention, shared mutable state, modules that every change has to touch, missing ownership.
- **A compliance or security audit**: authorization that is assumed and not enforced, secrets in config or code, missing audit trails, trust boundaries with no validation, dependencies with no pinning or provenance.
- **A year of change**: the hotspots from step 5, hidden couplings, and patterns that are aspirational and already eroding.

For each finding, record:

- the design decision, with `path:line`
- which pressure exposes it and what happens when it does
- severity: **High** (blocks adoption or needs redesign), **Medium** (costly but containable), **Low** (worth knowing)
- what evidence would change your mind

Also list what the design gets right, with the same standard of evidence. An assessment with no strengths is as suspect as one with no weaknesses.

## Rules

- Change nothing except files under `.interrogate/`.
- Don't list anything you can't point to in code. Generic advice that would apply to any repository is noise.
- Rank by severity. If everything is High, nothing is.

## Output

Write the findings to `.interrogate/06-critique.md`, replacing any existing file: findings ranked by severity, then strengths, then **What I did not assess**.

Then reply with a summary of at most ten lines, and tell the user the next step: run `/clear`, then `/interrogate:capture`.
