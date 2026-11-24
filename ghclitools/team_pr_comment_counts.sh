#!/usr/bin/env bash
# Counts PRs commented on per member of a GitHub team since a given date, sorted descending.
# Usage: team_pr_comment_counts.sh <since-date YYYY-MM-DD> [org] [team]

set -euo pipefail

since="${1:-}"
org="${2:-software}"
team="${3:-ped-team}"

if [[ ! "$since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Usage: $0 <since-date YYYY-MM-DD> [org] [team]" >&2
  exit 1
fi

gh api "orgs/${org}/teams/${team}/members" --paginate --jq '.[].login' |
  while read -r user; do
    count=$(gh search prs --commenter="$user" --created=">=${since}" --limit 1000 | wc -l)
    echo -e "${count}\t${user}"
    sleep 1
  done | sort -rn
