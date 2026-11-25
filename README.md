# interrogate

A Claude Code plugin for assessing the architecture of a codebase you haven't seen before.

It runs seven steps, each in a fresh context window. Every finding has to cite `path:line`, and the steps separate what the code enforces from what it only claims.

> **Status: 0.1.0, not yet run end to end.** The plugin and marketplace manifests pass `claude plugin validate`, and the runner's argument handling, dry run, resume, and failure paths are tested. No step has been run against a model yet. Expect to adjust the prompts after the first real run, and please open an issue with what you find.

## Contents

- [Why seven steps](#why-seven-steps)
- [Quick start](#quick-start)
- [The steps](#the-steps)
- [What gets written](#what-gets-written)
- [Running unattended](#running-unattended)
- [Running interactively](#running-interactively)
- [What it is allowed to do](#what-it-is-allowed-to-do)
- [After the run](#after-the-run)
- [What the record establishes](#what-the-record-establishes)
- [Repeatability](#repeatability)
- [Changing the prompts](#changing-the-prompts)
- [Limits](#limits)
- [Sources](#sources)

## Why seven steps

Asking Claude Code "what's the architecture of this repo?" in one prompt gets you a summary of the README. Three things go wrong:

1. **Context fills up.** Reading a whole codebase in one session crowds out the question. Anthropic's guidance is that output quality drops as the window fills.
2. **Claims go unchecked.** Without a rule that every claim cites a file and line, you can't tell what was read from what was guessed.
3. **Stated and real architecture blur together.** Most repositories claim a pattern. Whether anything enforces it is a separate question, and the violations are the useful part.

So each step here has a narrow question, starts with an empty context, reads the notes left by the earlier steps, and writes its own notes for the later ones. The notes files carry the state. The conversation doesn't have to.

## Quick start

You need [Claude Code](https://code.claude.com/docs) installed and signed in, `git`, and `jq`. macOS 15 and later ship `jq` at `/usr/bin/jq`; elsewhere install it with your package manager.

```bash
git clone https://github.com/dirtmerchant/interrogate.git
interrogate/bin/interrogate /path/to/repo-to-assess
```

That runs all seven steps and leaves you with `ARCHITECTURE.md` in the target repository and the working notes in `.interrogate/`.

To see what it would run without spending anything:

```bash
interrogate/bin/interrogate --dry-run /path/to/repo-to-assess
```

## The steps

| # | Command | Question it answers |
| :- | :- | :- |
| 1 | `/interrogate:orient` | What is here, where does it start, what does it depend on, and where do the docs disagree with the code? |
| 2 | `/interrogate:patterns` | Which architectural patterns are in use, and is each one enforced or only aspirational? |
| 3 | `/interrogate:boundaries` | Which modules depend on which, are there cycles, and does anything reach across a layer? |
| 4 | `/interrogate:trace [feature]` | For one real request, where do validation, authentication, authorization, error handling, and retries happen, and where are they missing? |
| 5 | `/interrogate:hotspots` | Which five files or abstractions would break the most if changed? |
| 6 | `/interrogate:critique` | What will hurt at 10x load, 10x team size, under an audit, or after a year of change? |
| 7 | `/interrogate:capture` | Turn the notes into deliverables. |

Notes on individual steps:

- **Patterns** counts something as *enforced* only if a mechanism stops violations: the type system, package visibility, a lint rule, an import check, or a test. Everything else is *aspirational*, and its violations are listed and counted. It starts from the enforcement mechanisms the runner found (`metrics/enforcement.tsv`), and an Enforced claim must cite one.
- **Boundaries** starts from the import table the runner extracted (`metrics/imports.tsv`). It is a wide sweep, so it starts one subagent per top-level package to check and complete that table. Each subagent explores in its own context and returns a short table. The main session then spot-checks at least three of the reported edges.
- **Trace** takes an optional argument, such as `/interrogate:trace checkout flow`. With no argument it picks the path that best represents the system and says why. It asks specifically whether authorization is enforced where the decision is made, or assumed by a later layer.
- **Hotspots** ranks from the runner's fan-in, churn, and co-change measurements rather than counting for itself. The ranking is still the model's judgment. In a repository with no history or a shallow clone it says so and falls back to fan-in.
- **Critique** has to rank by severity, say what evidence would change each finding, and list what the design gets right to the same standard.
- **Capture** doesn't explore again. It does re-check at least ten citations before writing and reports how many failed.

## What gets written

Everything goes in the repository being assessed:

```
target-repo/
├── ARCHITECTURE.md                  # step 7, the deliverable
└── .interrogate/
    ├── 01-orient.md
    ├── 02-patterns.md
    ├── 03-boundaries.md
    ├── 04-trace.md
    ├── 05-hotspots.md
    ├── 06-critique.md
    ├── issues.md                    # step 7, one entry per finding worth filing
    ├── CLAUDE.proposed.md           # step 7, conventions an agent would get wrong
    ├── run.json                     # written by the runner: the record of the run
    ├── citations.json               # written by the runner: does each citation resolve?
    └── metrics/                     # written by the runner: measurements at the commit
        ├── files.tsv  churn.tsv  cochange.tsv
        ├── imports.tsv  fanin.tsv  enforcement.tsv
        └── summary.json
```

With `--run-dir .interrogate/runs/a`, the same layout goes in `.interrogate/runs/a/` instead (see [Repeatability](#repeatability)).

If the target already has an `ARCHITECTURE.md`, step 7 leaves it alone and writes `.interrogate/ARCHITECTURE.proposed.md` instead.

Step 7 never writes `CLAUDE.md`. That file changes how every later Claude Code session behaves in the repository, so the proposal is kept separate for its own review.

Whether you commit `.interrogate/` is up to you. Add it to `.gitignore` if you only want the final document.

### Measurements

Before the first step, the runner runs `bin/measure`, which measures the target at the pinned commit. It needs no model. It reads git's object store at that commit, not the working tree, so the same commit always gives byte-identical files, on any machine and on any day.

| File | What it holds | How |
| :- | :- | :- |
| `files.tsv` | Language and line count per file | `git ls-tree` and `git diff --numstat` against the empty tree. Binary files show `-` |
| `churn.tsv` | Commits and distinct authors per file | `git log --no-merges`, in a 365-day window that **ends at the commit's date**, not today. Author emails are counted, never written. Renames aren't followed |
| `cochange.tsv` | File pairs that change in the same commits | The same window. Commits touching more than 50 files are skipped; pairs need 3 shared commits |
| `imports.tsv` | One row per import statement, with its line, resolved target, and `internal`, `external`, or `unresolved` | Regular expressions for Python, JavaScript/TypeScript, Go, Java, and Kotlin |
| `fanin.tsv` | Distinct importing files and directories per imported file or package | From `imports.tsv` |
| `enforcement.tsv` | Configuration that can enforce an architectural rule | import-linter, dependency-cruiser, ESLint import rules, ArchUnit, Java modules, Go `internal/`, Bazel visibility, CODEOWNERS |
| `summary.json` | The window, history depth, per-language coverage, each method's limits, and a hash of each file | |

The steps cite measurements as `.interrogate/metrics/churn.tsv:12`, where line 1 is the header. `check-citations` resolves those rows, and also the short forms `metrics/churn.tsv:12` and `churn.tsv:12`, which models tend to write, but only when no file by that name exists in the code. Every number in the notes is labelled **measured**, citing a row, or **estimated**, saying how.

The measurements are inputs, not findings. What they mean is still the model's judgment and yours. Their limits:

- **Imports are a heuristic.** They miss dynamic imports, tsconfig path aliases, re-exports, and Python namespace packages, and can match import-like text in strings or comments. Languages other than the five above aren't measured. `summary.json` lists them with file counts, so a gap shows up as a gap, not as zero.
- **Enforcement is configuration found, not enforcement proven.** Whether CI runs a check isn't visible from the tree.
- **History is whatever the clone has.** A shallow clone is flagged in `summary.json`.

You can run it yourself, for example before an interactive session:

```bash
bin/measure /path/to/repo-to-assess        # writes .interrogate/metrics/
```

### The run record

`run.json`, `citations.json`, and `metrics/` are written by `bin/interrogate`, never by the model. The model is denied write access to all three, and the runner checks their hashes before and after every step and stops if any changed.

`run.json` (`schema_version: 1`) records:

- **What was assessed:** the target path, the commit SHA at the start, and whether the tree was dirty. A non-git target is recorded as such, with no commit.
- **What did the assessing:** this plugin's version and commit, a SHA-256 of each `SKILL.md`, and the Claude Code version.
- **Where the code went:** the provider (`anthropic`, `bedrock`, `google-cloud`, `foundry`, or `other`), the endpoint host, and the region, each with the setting it came from. Values that can't be determined are recorded as unknown, with the reason. Only host names, regions, and variable names are written: never credentials, tokens, or full URLs.
- **Under what permissions:** the permission mode, and the exact allow and deny lists for each step.
- **Each step:** start and end time, exit status, session ID, cost, the model the session actually ran on (from the session itself, not the alias requested), any tool calls that were denied, and a SHA-256 of every file it wrote under `.interrogate/`. `ARCHITECTURE.md` is hashed once a step writes it.
- **Each citation check:** counts, and the hash of the `citations.json` it produced.

`citations.json` lists every `path:line` and `path:line-line` citation in the notes, with `pass`, `fail`, or `skip` and a reason (`file missing at commit …`, `line 40 out of range (file has 7 lines)`). Citations resolve against the recorded commit, or the working tree for a non-git target.

A finding in the notes is not evidence. The cited code at the recorded commit is the evidence, and the finding points to it. A `pass` means the pointer resolves: the file exists and the lines are in range. It does not mean the cited lines support the claim. That needs a human reviewer.

You can run the check yourself, without a model:

```bash
bin/check-citations /path/to/repo-to-assess        # exits 1 if any citation fails
```

How citations are recognized, and where that goes wrong:

- **Recognized:** a run of path characters containing a `/` or a `.`, or a well-known extensionless name (`Makefile`, `Dockerfile`, and similar), then `:line` or `:line-line`. A trailing `:column` is ignored. Citations of the notes themselves (`.interrogate/…`) are skipped.
- **Not recognized (missed):** paths with spaces, GitHub-style `path#L12-L20`, ranges written with an en dash, prose like "line 12 of `foo.go`", a citation split across a line break, and extensionless files not on the list.
- **Recognized wrongly (false failures):** `host.tld:port` written without a scheme, and dotted names followed by a number, such as `node.js:18`. These fail as "file missing", so they show up rather than pass silently. URLs with a scheme, version numbers, IP addresses, and times are excluded.

## Running unattended

```
Usage: interrogate [options] [target-dir]

  --steps a,b,c      Run only these steps, in the order given.
  --feature "text"   Feature or endpoint for the trace step.
  --force            Re-run steps whose notes already exist.
  --commit           Commit the notes after each step.
  --trust-project    Load the target's own Claude Code settings, hooks, and MCP servers.
  --model name       Model to request for every step. run.json records the model actually used.
  --allow-dirty      Run even though the target has uncommitted changes.
  --require-provider name
                     Refuse to start unless the provider is anthropic, bedrock,
                     google-cloud, foundry, or other.
  --no-verify        Don't run check-citations after each step.
  --trust-notes      Accept notes files that are tracked in the target's git history.
  --effort level     Effort level for every step: low, medium, high, xhigh, or max.
  --run-dir dir      Write this run's notes, metrics, and record to dir (inside the target).
  --dry-run          Print the commands without running them.
  --verify           Run nothing. Recheck the hashes in run.json.
```

The runner starts a new `claude -p` process for each step. A new process has an empty context window, so this is the unattended equivalent of running `/clear` between steps.

Examples:

```bash
# Full run, choosing what step 4 traces
bin/interrogate --feature "user login" ~/src/some-service

# Resume after an interruption: finished steps are skipped
bin/interrogate ~/src/some-service

# Redo the critique and the write-up after editing the notes by hand
bin/interrogate --steps critique,capture --force ~/src/some-service

# Commit each step's notes as it finishes
bin/interrogate --commit ~/src/some-service

# Only run if the code would go to Amazon Bedrock
bin/interrogate --require-provider bedrock ~/src/some-service

# Later: has anything in the record changed since the run?
bin/interrogate --verify ~/src/some-service
```

Behavior worth knowing:

- **Pinned to a commit.** The runner records the target's `HEAD` at the start. If the tree has uncommitted changes (outside `.interrogate/`), it refuses to run unless you pass `--allow-dirty`, and records that the tree was dirty. With `--allow-dirty`, citations still resolve against the commit, not your edits.
- **Resume.** A step is skipped when its notes file exists and is non-empty. `--force` overrides that. Resume refuses if `HEAD` is no longer the commit in `run.json`, so notes from two revisions are never mixed. The runner's own `--commit` commits are the one exception. To assess a new revision, move `.interrogate/` aside and start again.
- **Notes from git history.** If a notes file (or `run.json`) is tracked in the target's git history in a commit the runner didn't make, resume won't treat it as a finished step: a committed notes file may not come from an assessment at all. Re-run that step with `--force`, or pass `--trust-notes` to accept it. The acceptance is recorded.
- **Citation check.** After every step, and once at the start for notes kept from an earlier run, the runner runs `bin/check-citations`. If any citation fails to resolve, the run stops. Fix the notes or re-run the step with `--force`; `--no-verify` skips the check, and `run.json` records that it was skipped.
- **Failure.** If `claude` exits non-zero or reports an error, or a step finishes without writing its notes, the runner records the step and stops. Later steps don't run.
- **Provider gate.** `--require-provider` reads the environment and the `env` blocks of the settings files Claude Code would load, works out the provider, and refuses to start, before any session and before any code is read, if it doesn't match or can't be determined. The detection is printed at the start of every run. It is a static reading. Server-managed settings and macOS configuration profiles aren't visible to it, so after each step the runner also compares it with the provider the session reported and stops on a mismatch. That reported field is not documented by Claude Code, so treat the cross-check as a backstop.
- **`--verify`.** Recomputes the SHA-256 of every file `run.json` recorded and reports `OK`, `CHANGED`, or `MISSING` for each. It runs no model and needs no network. Editing a notes file by hand between steps is allowed, and `--verify` will then report it as changed, which is the point.
- **`--commit`.** Commits `.interrogate/` and `ARCHITECTURE.md` after each step with the message `interrogate: <step>`. If the current branch is `main` or `master`, it first switches to a new branch named `interrogate/assessment`. It never pushes.
- **Cost.** Seven sessions, one of which fans out to subagents. On a large repository this is not cheap. Use `--steps` to run part of it, and `--model` to choose a cheaper model for a first pass.
- **Measurements first.** Before the first step, `bin/measure` writes `metrics/` for the pinned commit. On resume, the existing measurements are kept if they still match `run.json`.
- **Session notes.** Each step gets a short appended system prompt, recorded in `run.json`: run one simple command per Bash call (`dontAsk` denies loops, variables, and `$(…)`, and early runs gave up on Bash after one denial), cite full paths rather than bare file names, the form for citing a measurement, and, with `--run-dir`, where the notes are. It describes how the run is set up. It doesn't change what a step assesses.
- **Findings index.** The patterns and hotspots notes end with a fixed-format table (see [Repeatability](#repeatability)). `check-citations` validates it, and a missing or malformed index stops the run like a broken citation.
- **Output.** Each step runs with `--output-format stream-json`, which is how the runner gets the session ID, cost, and the model the session ran on. Tool calls are echoed as one-line progress, and the step's final reply is printed when it finishes.
- **Bash.** The scripts avoid Bash 4 features, so they run on the Bash 3.2 that ships with macOS. They need `git` and `jq`.

## Running interactively

Use this when you want to read each step's findings and steer before the next one.

Load the plugin for one session:

```bash
cd /path/to/repo-to-assess
claude --plugin-dir /path/to/interrogate
```

Or install it so it is available in every session:

```
/plugin marketplace add dirtmerchant/interrogate
/plugin install interrogate@interrogate
```

Then run the steps in order, with `/clear` between them:

```
/interrogate:orient
/clear
/interrogate:patterns
/clear
/interrogate:boundaries
/clear
/interrogate:trace checkout flow
/clear
/interrogate:hotspots
/clear
/interrogate:critique
/clear
/interrogate:capture
```

Each step ends by naming the next command. Claude can't run `/clear` itself, so that part is yours. If you skip it, the files read in earlier steps stay in context and crowd out the current one.

Two things differ from the unattended runner:

- **Permissions are whatever your session uses.** Start in the default mode and approve the one notes-file write per step. Plan mode blocks that write, so the step can't save its findings.
- **The target's Claude Code settings load as usual**, after the normal trust prompt.
- **No run record.** `run.json` comes from the runner, so an interactive session leaves only the notes. You can still check the citations with `bin/check-citations`, which resolves against `HEAD`.
- **No measurements unless you make them.** Run `bin/measure` first if you want measured numbers. Otherwise the steps estimate, and say so.

You can edit a notes file between steps. Later steps treat the notes as leads to verify, and step 7 builds only from what the notes contain.

The skills are marked `disable-model-invocation`, so Claude never starts one on its own.

## What it is allowed to do

The unattended runner passes `--permission-mode dontAsk` with a one-rule allow list. In that mode Claude Code denies anything that would otherwise ask for approval, so the limits below are enforced by Claude Code, not requested in a prompt.

| Action | Allowed |
| :- | :- |
| Read and search files in the target | Yes |
| Claude Code's built-in read-only shell commands (`ls`, `cat`, `grep`, `find`, `sort`, read-only `git`, and similar) | Yes, with no rule from the runner |
| `git log`, `git show`, `git ls-files`, `git blame`, `git shortlog`, and the churn pipeline in step 5 | Yes, as built-in read-only commands |
| `git log --output=<file>`, `git show --output=<file>` | No |
| Write files under `.interrogate/` | Yes: `Edit(/.interrogate/**)` |
| Write `.interrogate/run.json`, `.interrogate/citations.json`, or anything in `.interrogate/metrics/` | No: explicit deny rules; only the runner writes them |
| Write `ARCHITECTURE.md` | Step 7 only, and only if the file didn't exist when the run started. Otherwise it is denied, and step 7 writes `.interrogate/ARCHITECTURE.proposed.md` |
| Write anywhere else, run other shell commands, fetch from the network | No |

The runner adds no Bash rules. With Claude Code 2.1.332 in `dontAsk` mode and no allow rules, every git command step 5 uses, and its `sort | uniq -c | sort -rn | head` pipeline, ran as built-in read-only commands, and the `--output=<file>` forms were denied. Earlier versions of the runner allowed `Bash(git log *)` and `Bash(git show *)`, which approved those `--output` forms. Claude Code decides what counts as read-only, and that can change between versions: `run.json` records the version, and anything a future version stops treating as read-only is denied, not allowed. Commands the model builds with `$(…)` substitution, or with a file argument to `uniq`, are denied too, and `run.json` lists each denied call.

The runner also passes `--setting-sources user` by default. A `claude -p` run shows no workspace trust dialog, so without that flag the target repository's own hooks and `.mcp.json` servers would run on your machine unprompted. A repository you are assessing for the first time is one you haven't vetted. Pass `--trust-project` only when you trust the target.

Permission rules are not a sandbox. For a repository you don't trust at all, run the whole thing in a container or VM as well.

## After the run

The plugin stops at files. It doesn't commit to your default branch, push, open pull requests, or file issues. A suggested order:

1. **Read `ARCHITECTURE.md` yourself.** It is a model's assessment. Every citation in it resolved (see `.interrogate/citations.json`), but whether each cited line supports its claim is for you to check: open a sample and read them.
2. **Open one pull request with `ARCHITECTURE.md`.** Maintainers who know the code disputing the findings is the real review of the assessment.
3. **Review `.interrogate/CLAUDE.proposed.md`.** If you adopt it, open a separate pull request.
4. **File issues from `.interrogate/issues.md`.** Each entry has a title, evidence, severity, and suggested scope. It describes the problem and leaves the fix open.
5. **Fix findings later**, one pull request per issue, each in its own session.

## What the record establishes

The output is a reviewable record of one architecture review, tied to the commit it reviewed, with citations that resolve. In a regulated setting, an assessor tends to ask four things of an artifact like this. Here is where each stands:

| Question | Status |
| :- | :- |
| Is it tied to what was assessed? | **Yes.** `run.json` records the commit, whether the tree was dirty, and the plugin version and prompt hashes. Citations resolve against that commit. Resume refuses to mix revisions. |
| Could it have been altered? | **Partly.** The model can't write the run record, and `--verify` detects files that changed after the run. But `run.json` is unsigned, so anyone who can edit a notes file can also edit its recorded hash. That makes it a check against accidents, not a tamper-proof record. |
| Can it be verified without trusting the tool? | **Partly.** `check-citations` and `--verify` are short shell scripts that use only `git`, `jq`, and `shasum`, and need no model. The citation check confirms that a citation points at real lines. Whether those lines support the finding is a human reviewer's call. |
| Where did the source code go? | **Recorded, with stated limits.** The provider, endpoint host, and region are recorded, and `--require-provider` can refuse to start. Detection reads the environment and the settings files the runner can see. Server-managed settings and macOS configuration profiles are invisible to it and are listed as not read. |

What the record does not establish:

- **That a finding is correct.** The model's findings are claims. The evidence is the cited code.
- **A control assessment.** This reviews architecture, not whether a control objective is met.
- **That it is tamper-proof.** Not yet.

Planned work, not in this release: signing or attesting `run.json`, a record of the human review, one directory per run, and findings with stable IDs.

## Repeatability

A model doesn't give the same answer twice. `claude -p` has no temperature or seed setting (checked against `claude --help` for 2.1.332), so the runner can't make a step deterministic. What it does instead is pin everything else, then measure the variance that's left.

**Pinned, and recorded in `run.json`:**

- the commit, and the tree at it
- the measurements, which are byte-identical for a commit
- the skill prompts, by hash
- the model: pass a full model ID such as `claude-opus-5-5`. An alias such as `opus` gets a warning, because it resolves to whatever model is current. Each step records the model it actually ran on, and flags a suspected fallback to another model.
- the effort level, with `--effort`

**Not pinned:** the model's sampling. Two runs can read different files, cite different lines, and rank differently.

**Measuring the variance.** Run the same steps into separate directories, then compare:

```bash
bin/interrogate --run-dir .interrogate/runs/a --model claude-opus-5-5 --effort medium ~/src/svc
bin/interrogate --run-dir .interrogate/runs/b --model claude-opus-5-5 --effort medium ~/src/svc
bin/interrogate --run-dir .interrogate/runs/c --model claude-opus-5-5 --effort medium ~/src/svc
bin/compare-runs ~/src/svc/.interrogate/runs/{a,b,c}
```

`compare-runs` needs no model. It refuses runs of different commits, warns about differing prompts, models, or effort, and reports:

- **per step:** how far the runs cite the same files (Jaccard) and the same lines (overlapping ranges), and which files every run cited or only one did
- **hotspots:** overlap of the ranked lists, and whether shared items are in the same order
- **patterns:** which patterns every run found, and whether they agree on Enforced or Aspirational

It reads the comparison from the **findings index** at the end of the patterns and hotspots notes, a fixed-format table the steps are told to write and `check-citations` validates:

```
<!-- findings-index: hotspots -->
| rank | path | fanin | churn_window | measured |
```

```
<!-- findings-index: patterns -->
| pattern | scope | status | violations |
```

Patterns are matched across runs by name, ignoring case and punctuation. There are no stable finding IDs yet.

**How to read it.** Agreement means the runs pointed at the same code, not that they are right. A finding every run produced is more likely to reflect the code than the sampling. A finding only one run produced is a lead to check, not a conclusion. For anything going to an assessor, run at least three times and report the agreement with the findings.

**What one test showed.** On a 14-file scripted fixture, three hotspots runs with the same inputs, model, and effort ranked the same five files in the same order, and 90% of their citations overlapped at line level (72% at file level). The fixture's measured numbers nearly force that ranking, so this shows that pinned inputs carry through to the output. It doesn't predict agreement on a real codebase, where judgment does more of the work.

## Changing the prompts

Each step is one Markdown file at `skills/<step>/SKILL.md`: YAML frontmatter, then the prompt. Edit the prompt, then run `/reload-plugins` in an open session, or just re-run the runner.

Check your edits with:

```bash
claude plugin validate .
```

If you add a step, also add it to `ALL_STEPS` and `note_for` in `bin/interrogate`, and have the previous step name it as the next command. Keep the findings index format in the patterns and hotspots prompts as it is: `check-citations` and `compare-runs` parse it.

Ideas that fit the same shape: a data-model step, a test-strategy step, or a dependency and supply-chain step that asks what is pinned and what has provenance.

## Limits

- **It reads code. It doesn't run it.** Nothing is built, executed, or tested, so runtime behavior, performance, and configuration that only exists in a deployed environment are out of view.
- **Citations can point at the wrong thing.** The runner checks that every citation resolves to real lines at the recorded commit. It can't check that those lines say what the finding claims. Step 7 also re-reads a sample of ten.
- **Very large or monorepo codebases** may need the steps pointed at one service at a time. Run the tool from that service's directory.
- **Findings vary between runs.** Treat a single run as one reviewer's opinion, and use `--run-dir` and `bin/compare-runs` to see how much they vary. See [Repeatability](#repeatability).
- **Measurements are partial.** Imports are measured for five language families by pattern matching, and configuration found is not proof of enforcement. See [Measurements](#measurements).
- **Not yet validated end to end.** Orient, patterns, boundaries, trace, and hotspots have been run against a model, on small fixtures. Critique and capture haven't been yet.
- **Provider detection is static.** It sees the environment and the settings files it can read, not server-managed settings or MDM profiles. See [the run record](#the-run-record).

## Sources

The prompts apply Anthropic's published Claude Code guidance to architecture assessment. The wording is this project's, and Anthropic has not reviewed or endorsed it.

- [Best practices](https://code.claude.com/docs/en/best-practices): explore before changing anything, manage context, ask for evidence
- [Common workflows](https://code.claude.com/docs/en/common-workflows): understanding a new codebase
- [Prompt library](https://code.claude.com/docs/en/prompt-library)
- [Run Claude Code programmatically](https://code.claude.com/docs/en/headless): `claude -p` and its flags
- [Permissions](https://code.claude.com/docs/en/permissions): rule syntax, `dontAsk`, read-only commands, and what runs in an untrusted folder
- [Environment variables](https://code.claude.com/docs/en/env-vars) and [settings](https://code.claude.com/docs/en/settings): how provider, endpoint, and region are chosen, and settings precedence
- Provider setup: [Amazon Bedrock](https://code.claude.com/docs/en/amazon-bedrock), [Google Cloud](https://code.claude.com/docs/en/google-vertex-ai), [Microsoft Foundry](https://code.claude.com/docs/en/microsoft-foundry), [LLM gateways](https://code.claude.com/docs/en/llm-gateway)
- [Create a plugin](https://code.claude.com/docs/en/plugins/create)
