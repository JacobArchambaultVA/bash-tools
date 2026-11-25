#!/usr/bin/env bash
# Counts PRs opened since a date in each ped-services* repo cloned under ~/source/repos and estimates
# the cost of manually re-running required checks cancelled by duplicate pipeline triggers
# (concurrency cancel-in-progress). Defaults to 15 minutes per PR at a $100k annual salary
# (2080 work hours/year), counting PRs created on or after 2026-06-11, when cancel-in-progress
# was added to required checks. The GitHub owner/repo is taken from each clone's origin remote.
# Requires `gh` authenticated against that host.
#
# Usage: pipeline_cancellation_cost_calculator.sh [minutes_per_pr] [annual_salary] [since_date YYYY-MM-DD]

set -euo pipefail

base_dir="$HOME/source/repos"
minutes_per_pr="${1:-15}"
annual_salary="${2:-100000}"
since="${3:-2026-06-11}"
hours_per_year=2080
usage="Usage: $0 [minutes_per_pr] [annual_salary] [since_date YYYY-MM-DD]"

for value in "$minutes_per_pr" "$annual_salary"; do
  if [[ ! "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "$usage" >&2
    echo "Error: '$value' is not a valid number" >&2
    exit 1
  fi
done

if [[ ! "$since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "$usage" >&2
  echo "Error: '$since' is not a valid date (YYYY-MM-DD)" >&2
  exit 1
fi

if [[ ! -d "$base_dir" ]]; then
  echo "Error: base directory not found: $base_dir" >&2
  exit 1
fi

cd "$base_dir"

for repo in ped-services*/; do
  repo="${repo%/}"
  url=$(git -C "$repo" remote get-url origin 2>/dev/null) || continue
  # Turns https://host/owner/name.git or git@host:owner/name.git into owner/name.
  slug=$(sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##' <<< "$url")
  [[ "$slug" == *.wiki ]] && continue
  if ! count=$(gh api -X GET search/issues -f q="repo:${slug} is:pr created:>=${since}" --jq '.total_count'); then
    echo "Error: failed to query PRs for $slug" >&2
    exit 1
  fi
  printf '%s\t%d\n' "$repo" "$count"
  # The search API allows 30 requests/minute.
  sleep 2
done | awk -F '\t' \
  -v mins="$minutes_per_pr" -v salary="$annual_salary" -v hours="$hours_per_year" '
BEGIN {
  rate = salary / hours * mins / 60
  fmt = "%-45s  %10s  %12s\n"
  printf fmt, "repo", "pr count", "cost"
  printf fmt, "----", "--------", "----"
}
{
  printf "%-45s  %10d  %12s\n", $1, $2, sprintf("$%.2f", $2 * rate)
  total += $2
}
END {
  printf fmt, "----", "--------", "----"
  printf "%-45s  %10d  %12s\n", "TOTAL", total, sprintf("$%.2f", total * rate)
}'
