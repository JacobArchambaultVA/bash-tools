#!/usr/bin/env bash
# Counts commits that modified any .inspector-ignore file in each ped-services* repo
# under ~/source/repos (all branches, merges included) and estimates a cost floor for that effort.
# Defaults to 15 minutes per change at a $100k annual salary (2080 work hours/year).
# Run `git fetch --all` in each repo first so remote branches are included.
#
# Usage: inspector_ignore_cost_calculator.sh [minutes_per_change] [annual_salary]

set -euo pipefail

base_dir="$HOME/source/repos"
minutes_per_change="${1:-15}"
annual_salary="${2:-100000}"
hours_per_year=2080

for value in "$minutes_per_change" "$annual_salary"; do
  if [[ ! "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Usage: $0 [minutes_per_change] [annual_salary]" >&2
    echo "Error: '$value' is not a valid number" >&2
    exit 1
  fi
done

if [[ ! -d "$base_dir" ]]; then
  echo "Error: base directory not found: $base_dir" >&2
  exit 1
fi

cd "$base_dir"

for repo in ped-services*/; do
  repo="${repo%/}"
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
  # --full-history keeps merge commits that touched the file; the default simplification drops them.
  count=$(git --no-pager -C "$repo" log --all --full-history --format=%H -- ':(glob)**/.inspector-ignore' | wc -l)
  printf '%s\t%d\n' "$repo" "$count"
done | awk -F '\t' \
  -v mins="$minutes_per_change" -v salary="$annual_salary" -v hours="$hours_per_year" '
BEGIN {
  rate = salary / hours * mins / 60
  fmt = "%-45s  %12s  %12s\n"
  printf fmt, "repo", "change count", "cost floor"
  printf fmt, "----", "------------", "----------"
}
{
  printf "%-45s  %12d  %12s\n", $1, $2, sprintf("$%.2f", $2 * rate)
  total += $2
}
END {
  printf fmt, "----", "------------", "----------"
  printf "%-45s  %12d  %12s\n", "TOTAL", total, sprintf("$%.2f", total * rate)
}'
