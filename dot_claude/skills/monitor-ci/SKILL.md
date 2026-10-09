---
name: monitor-ci
description: Monitor a GitHub pull request until all comments are addressed and all CI jobs are green. Use when asked to run /monitor-ci, fix PR comments, resolve review comments, address Bugbot comments, repair failing GitHub Actions checks, or keep polling a PR until CI is passing.
---

# /monitor-ci

Use this skill to actively shepherd a GitHub PR to a clean state: all actionable PR comments resolved, all review feedback addressed, and all CI/check jobs green.

## Inputs

Start from the current branch unless the user gives a PR number or URL.

Identify the PR:

```bash
gh pr view --json number,url,headRefName,baseRefName,state,isDraft,reviewDecision
```

If there is no PR for the current branch, ask for the PR number or URL.

## Loop

Repeat this cycle until completion:

1. Fetch the latest PR state.
2. Collect all unresolved comments and review feedback.
3. Collect all non-green CI/check results.
4. Address every actionable comment and failing job.
5. Run the narrowest useful local verification.
6. Commit and push fixes when code changed.
7. Sleep before polling again if comments remain, checks are failing, or checks are still pending.

Default sleep:

```bash
sleep "${MONITOR_CI_SLEEP_SECONDS:-300}"
```

## Collect PR Feedback

Fetch comments, reviews, review threads, and check summary:

```bash
PR="$(gh pr view --json number --jq .number)"
gh pr view "$PR" --json url,title,headRefName,baseRefName,reviewDecision,mergeStateStatus,statusCheckRollup
gh pr checks "$PR"
gh pr view "$PR" --comments
gh api "repos/{owner}/{repo}/pulls/$PR/reviews"
gh api "repos/{owner}/{repo}/pulls/$PR/comments"
gh api graphql -f query='
query($owner:String!, $repo:String!, $pr:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$pr) {
      reviewThreads(first:100) {
        nodes {
          isResolved
          path
          line
          comments(first:20) {
            nodes {
              author { login }
              body
              url
            }
          }
        }
      }
    }
  }
}' -F owner="$(gh repo view --json owner --jq .owner.login)" -F repo="$(gh repo view --json name --jq .name)" -F pr="$PR"
```

Treat comments from code review tools, Bugbot, bots, and humans as actionable unless they are clearly praise, already fixed, obsolete, duplicated by a newer thread, or explicitly marked non-blocking. When skipping a comment, note why.

## Diagnose CI

For every failed or cancelled check, fetch logs before changing code:

```bash
gh run list --branch "$(gh pr view "$PR" --json headRefName --jq .headRefName)" --limit 10
gh run view <run-id> --json name,status,conclusion,jobs
gh run view --job <job-id> --log
```

Prefer the failing job's exact command locally when available. If logs are truncated, download artifacts or rerun only after capturing enough evidence:

```bash
gh run download <run-id>
gh run rerun <run-id> --failed
```

## Fixing Rules

- Fix root causes, not just symptoms in tests or snapshots.
- Keep changes scoped to the PR and preserve unrelated user work.
- Do not mark a thread resolved unless the fix is pushed or the comment is demonstrably obsolete.
- If feedback asks for clarification rather than code, reply with the concrete explanation after verifying it.
- If a CI failure is flaky, rerun the failed job once, but keep investigating if it fails again.
- If blocked by credentials, permissions, or an external outage, report the blocker with the exact check/comment and stop sleeping.

## Completion Criteria

Stop only when all are true:

- No unresolved actionable PR comments or review threads remain.
- No requested changes remain unaddressed.
- Every required GitHub check is successful.
- No check is pending, queued, in progress, failed, cancelled, timed out, or action-required.
- Local verification relevant to the fixes has passed or the reason it cannot run is documented.

Return a concise summary of comments addressed, CI failures fixed, commits pushed, and the final PR/check status.
