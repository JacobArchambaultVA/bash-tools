#!/usr/bin/env bash
# Lists develop and Feature* branches (local and remote) with a commit in the past N days.
# Usage: recent_branches.sh <days>

set -euo pipefail

days="${1:-}"
if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 <days>" >&2
    exit 1
fi

cutoff=$(date -d "$days days ago" +%s)

git for-each-ref --format='%(committerdate:unix) %(refname:short)' refs/heads refs/remotes |
    while read -r ts ref; do
        name="${ref#origin/}"
        [[ "$name" == "HEAD" || "$ref" == "origin" ]] && continue
        if (( ts >= cutoff )) && [[ "$name" == "develop" || "$name" == [Ff]eature* ]]; then
            echo "$name"
        fi
    done | sort -u
