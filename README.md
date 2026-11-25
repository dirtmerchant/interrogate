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

You need [Claude Code](https://code.claude.com/docs) installed and signed in, and `git`.

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

- **Patterns** counts something as *enforced* only if a mechanism stops violations: the type system, package visibility, a lint rule, an import check, or a test. Everything else is *aspirational*, and its violations are listed and counted.
- **Boundaries** is a wide sweep, so it starts one subagent per top-level package. Each subagent explores in its own context and returns a short table. The main session then spot-checks at least three of the reported edges.
- **Trace** takes an optional argument, such as `/interrogate:trace checkout flow`. With no argument it picks the path that best represents the system and says why. It asks specifically whether authorization is enforced where the decision is made, or assumed by a later layer.
- **Hotspots** uses fan-in counts and git history (churn and co-change). In a repository with no history or a shallow clone it says so and falls back to fan-in.
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
    └── CLAUDE.proposed.md           # step 7, conventions an agent would get wrong
```

If the target already has an `ARCHITECTURE.md`, step 7 leaves it alone and writes `.interrogate/ARCHITECTURE.proposed.md` instead.

Step 7 never writes `CLAUDE.md`. That file changes how every later Claude Code session behaves in the repository, so the proposal is kept separate for its own review.

Whether you commit `.interrogate/` is up to you. Add it to `.gitignore` if you only want the final document.

## Running unattended

```
Usage: interrogate [options] [target-dir]

  --steps a,b,c      Run only these steps, in the order given.
  --feature "text"   Feature or endpoint for the trace step.
  --force            Re-run steps whose notes already exist.
  --commit           Commit the notes after each step.
  --trust-project    Load the target's own Claude Code settings, hooks, and MCP servers.
  --model name       Model to use for every step.
  --dry-run          Print the commands without running them.
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
```

Behavior worth knowing:

- **Resume.** A step is skipped when its notes file exists and is non-empty. `--force` overrides that.
- **Failure.** If `claude` exits non-zero, or a step finishes without writing its notes, the runner stops and later steps don't run.
- **`--commit`.** Commits `.interrogate/` and `ARCHITECTURE.md` after each step with the message `interrogate: <step>`. If the current branch is `main` or `master`, it first switches to a new branch named `interrogate/assessment`. It never pushes.
- **Cost.** Seven sessions, one of which fans out to subagents. On a large repository this is not cheap. Use `--steps` to run part of it, and `--model` to choose a cheaper model for a first pass.
- **Bash.** The script avoids Bash 4 features, so it runs on the Bash 3.2 that ships with macOS.

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

You can edit a notes file between steps. Later steps treat the notes as leads to verify, and step 7 builds only from what the notes contain.

The skills are marked `disable-model-invocation`, so Claude never starts one on its own.

## What it is allowed to do

The unattended runner passes `--permission-mode dontAsk` with a short allow list. In that mode Claude Code denies anything that would otherwise ask for approval, so the limits below are enforced by Claude Code, not requested in a prompt.

| Action | Allowed |
| :- | :- |
| Read and search files in the target | Yes |
| Claude Code's built-in read-only shell commands (`ls`, `cat`, `grep`, `find`, read-only `git`, and similar) | Yes |
| `git log`, `git show`, `git ls-files`, `git blame`, `git shortlog` | Yes |
| `sort`, `sort -rn`, `sort -nr`, `uniq`, `uniq -c` (exact forms, for the churn pipeline) | Yes |
| Write files under `.interrogate/` | Yes |
| Write `ARCHITECTURE.md` | Step 7 only |
| Write anywhere else, run other shell commands, fetch from the network | No |

The runner also passes `--setting-sources user` by default. A `claude -p` run shows no workspace trust dialog, so without that flag the target repository's own hooks and `.mcp.json` servers would run on your machine unprompted. A repository you are assessing for the first time is one you haven't vetted. Pass `--trust-project` only when you trust the target.

Permission rules are not a sandbox. For a repository you don't trust at all, run the whole thing in a container or VM as well.

## After the run

The plugin stops at files. It doesn't commit to your default branch, push, open pull requests, or file issues. A suggested order:

1. **Read `ARCHITECTURE.md` yourself** and check a few citations. It is a model's assessment.
2. **Open one pull request with `ARCHITECTURE.md`.** Maintainers who know the code disputing the findings is the real review of the assessment.
3. **Review `.interrogate/CLAUDE.proposed.md`.** If you adopt it, open a separate pull request.
4. **File issues from `.interrogate/issues.md`.** Each entry has a title, evidence, severity, and suggested scope. It describes the problem and leaves the fix open.
5. **Fix findings later**, one pull request per issue, each in its own session.

## Changing the prompts

Each step is one Markdown file at `skills/<step>/SKILL.md`: YAML frontmatter, then the prompt. Edit the prompt, then run `/reload-plugins` in an open session, or just re-run the runner.

Check your edits with:

```bash
claude plugin validate .
```

If you add a step, also add it to `ALL_STEPS` and `note_for` in `bin/interrogate`, and have the previous step name it as the next command.

Ideas that fit the same shape: a data-model step, a test-strategy step, or a dependency and supply-chain step that asks what is pinned and what has provenance.

## Limits

- **It reads code. It doesn't run it.** Nothing is built, executed, or tested, so runtime behavior, performance, and configuration that only exists in a deployed environment are out of view.
- **Citations can be wrong.** Step 7 re-checks a sample, not all of them.
- **Very large or monorepo codebases** may need the steps pointed at one service at a time. Run the tool from that service's directory.
- **Findings vary between runs.** Treat a single run as one reviewer's opinion.
- **Not yet validated end to end.** See the status note at the top.

## Sources

The prompts apply Anthropic's published Claude Code guidance to architecture assessment. The wording is this project's, and Anthropic has not reviewed or endorsed it.

- [Best practices](https://code.claude.com/docs/en/best-practices): explore before changing anything, manage context, ask for evidence
- [Common workflows](https://code.claude.com/docs/en/common-workflows): understanding a new codebase
- [Prompt library](https://code.claude.com/docs/en/prompt-library)
- [Run Claude Code programmatically](https://code.claude.com/docs/en/headless): `claude -p` and its flags
- [Permissions](https://code.claude.com/docs/en/permissions): rule syntax, `dontAsk`, and what runs in an untrusted folder
- [Create a plugin](https://code.claude.com/docs/en/plugins/create)
