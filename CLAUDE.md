# CLAUDE.md

For project context, architecture, build commands, code conventions, and contribution workflow, read [AGENTS.md](AGENTS.md). That is the single source of truth for all AI agents.

## Mandatory Validation

**After each meaningful change**, run:

```powershell
./Scripts/Invoke-QuickTest.ps1 -IncludeAnalyzer -OutputFormat Structured
```

Parse the JSON output. If `success` is `false`, fix all `failedTests` and `analyzerErrors` before proceeding.

**Before every commit**, run the full pipeline:

```powershell
./Tests/test-local.ps1
```

All three stages (build, analyze, test) must pass. Do not commit until they do.

CI is a safety net only -- failures should never first appear there.

## Session State

Use `.claude/plan.md` as a personal scratchpad for the current session. It is gitignored and not shared across agents or users.

- Note what you are working on and any in-progress reasoning
- This file is ephemeral -- do not use it for project planning
- Project planning lives in GitHub Issues and Milestones

## Finding Work

```powershell
gh issue list --label ai-ready --state open
```

Read the issue, self-assign with `gh issue edit <num> --add-label ai-in-progress --remove-label ai-ready`, then follow the workflow in AGENTS.md.
