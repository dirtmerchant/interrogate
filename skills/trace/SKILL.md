---
name: trace
description: Step 4 of 7 in the architecture interrogation. Traces one real request end to end and records where validation, authn/authz, error handling, and retries happen or are missing.
disable-model-invocation: true
argument-hint: [feature or endpoint]
---

You are assessing the architecture of a codebase. This is step 4 of 7: trace one real path through the system. You are in a fresh session, so start by reading the notes in `.interrogate/` (steps 01 to 03). If they are missing, stop and tell the user which step to run first.

## Task

Feature to trace: $ARGUMENTS

If no feature is named above, choose the path that best represents the system's main purpose, using the entry points in the orient notes. Say which you chose and why.

Follow a single request from ingress to persistence and back. For every hop, record:

- the function or handler, with `path:line`
- what crosses the boundary (the data shape, and whether it is validated here)
- which trust boundary, if any, is crossed

Then answer each of these with evidence. For each one, say where it happens, and say plainly where it does not:

- **Input validation**: where is input checked, and is anything used before it is checked?
- **Authentication**: where is the caller's identity established?
- **Authorization**: where is the decision made that this caller may do this thing? Is it enforced at that point, or assumed by a later layer because an earlier one "should have" checked?
- **Error handling**: what happens when each hop fails? Are errors swallowed, wrapped, or leaked to the caller?
- **Retries and idempotency**: what retries, and is the retried operation safe to repeat?
- **Transactions and consistency**: where are the transaction boundaries, and what is left inconsistent if the request dies halfway?

## Rules

- Change nothing except files under `.interrogate/`.
- Every hop and every answer cites `path:line`. "Absent" is a finding; cite where you looked.
- Trace the code that runs, not the code the docs describe. Follow the actual calls.

## Output

Write the findings to `.interrogate/04-trace.md`, replacing any existing file: the feature traced, a numbered hop list, the six answers, then **Open questions**.

Then reply with a summary of at most ten lines, and tell the user the next step: run `/clear`, then `/interrogate:hotspots`.
