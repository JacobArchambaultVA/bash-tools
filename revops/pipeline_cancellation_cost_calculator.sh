#!/usr/bin/env bash
# Counts PRs created in each ped-services* repo cloned under ~/source/repos since cancel-in-progress
# concurrency reached that repo's required checks, and estimates the cost of manually re-running
# checks cancelled by duplicate pipeline triggers. Defaults to 15 minutes per PR at a $100k annual
# salary (2080 work hours/year).
#
# Each repo's start date is the earliest of: the first commit on its default branch (origin/HEAD,
# first-parent, so merge dates are used) that added cancel-in-progress to a workflow other than the
# non-required ones in excluded_workflows, and the date it began calling a common template listed in
# inherited_templates whose own concurrency block cancels runs, for repos that call it (the template's
# merge date to common's default branch; open PRs inherit it by syncing, so repo adoption date is ignored).
# Repos with neither are listed with 0 PRs. Pass since_date to use
# one fixed date for every repo instead. Run `git fetch` in each repo first so history is current.
# The GitHub owner/repo is taken from each clone's origin remote; requires `gh` authenticated
# against that host.
#
# Usage: pipeline_cancellation_cost_calculator.sh [minutes_per_pr] [annual_salary] [since_date YYYY-MM-DD]

set -euo pipefail

base_dir="$HOME/source/repos"
minutes_per_pr="${1:-15}"
annual_salary="${2:-100000}"
since_override="${3:-}"
hours_per_year=2080
excluded_workflows=(delete_failed_workflow_runs.yml markdown-linter.yml python-lint.yml)
# Common templates whose own concurrency block cancels runs in every repo that calls them.
inherited_templates=(codeql-template.yml deploy-dev-template.yml)
common_repo="ped-services-common"
usage="Usage: $0 [minutes_per_pr] [annual_salary] [since_date YYYY-MM-DD]"

for value in "$minutes_per_pr" "$annual_salary"; do
  if [[ ! "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "$usage" >&2
    echo "Error: '$value' is not a valid number" >&2
    exit 1
  fi
done

if [[ -n "$since_override" && ! "$since_override" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "$usage" >&2
  echo "Error: '$since_override' is not a valid date (YYYY-MM-DD)" >&2
  exit 1
fi

if [[ ! -d "$base_dir" ]]; then
  echo "Error: base directory not found: $base_dir" >&2
  exit 1
fi

pathspec=(.github/workflows)
for workflow in "${excluded_workflows[@]}"; do
  pathspec+=(":(exclude).github/workflows/$workflow")
done

cd "$base_dir"

# Date each template merged cancel-in-progress to the common repo's default branch.
declare -A template_dates=()
if [[ -z "$since_override" && -d "$common_repo" ]]; then
  common_ref=$(git -C "$common_repo" rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo HEAD)
  for template in "${inherited_templates[@]}"; do
    template_dates[$template]=$(git --no-pager -C "$common_repo" log --first-parent --reverse --format=%cs \
      -G'cancel-in-progress' "$common_ref" -- ".github/workflows/$template" | head -n 1)
  done
fi

for repo in ped-services*/; do
  repo="${repo%/}"
  url=$(git -C "$repo" remote get-url origin 2>/dev/null) || continue
  # Turns https://host/owner/name.git or git@host:owner/name.git into owner/name.
  slug=$(sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##' <<< "$url")
  [[ "$slug" == *.wiki ]] && continue

  since="$since_override"
  if [[ -z "$since" ]]; then
    ref=$(git -C "$repo" rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo HEAD)
    since=$(git --no-pager -C "$repo" log --first-parent --reverse --format=%cs \
      -G'cancel-in-progress' "$ref" -- "${pathspec[@]}" | head -n 1)

    # Cancellation inherited from a shared template starts on the template's merge date for any repo
    # that calls it: open PRs pick it up by syncing the default branch, before the repo adopts it.
    # The earliest date across all sources wins.
    for template in "${inherited_templates[@]}"; do
      inherited="${template_dates[$template]:-}"
      [[ -z "$inherited" ]] && continue
      uses_template=$(git --no-pager -C "$repo" log --first-parent --format=%h -1 \
        -G"$template" "$ref" -- .github/workflows)
      [[ -z "$uses_template" ]] && continue
      if [[ -z "$since" || "$inherited" < "$since" ]]; then
        since="$inherited"
      fi
    done
  fi

  if [[ -z "$since" ]]; then
    printf '%s\t-\t0\n' "$repo"
    continue
  fi

  if ! count=$(gh api -X GET search/issues -f q="repo:${slug} is:pr created:>=${since}" --jq '.total_count'); then
    echo "Error: failed to query PRs for $slug" >&2
    exit 1
  fi
  printf '%s\t%s\t%d\n' "$repo" "$since" "$count"
  # The search API allows 30 requests/minute.
  sleep 2
done | awk -F '\t' \
  -v mins="$minutes_per_pr" -v salary="$annual_salary" -v hours="$hours_per_year" '
BEGIN {
  rate = salary / hours * mins / 60
  fmt = "%-45s  %10s  %10s  %12s\n"
  printf fmt, "repo", "since", "pr count", "cost"
  printf fmt, "----", "-----", "--------", "----"
}
{
  printf "%-45s  %10s  %10d  %12s\n", $1, $2, $3, sprintf("$%.2f", $3 * rate)
  total += $3
}
END {
  printf fmt, "----", "-----", "--------", "----"
  printf "%-45s  %10s  %10d  %12s\n", "TOTAL", "", total, sprintf("$%.2f", total * rate)
}'
