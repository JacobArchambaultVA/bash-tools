#!/bin/bash

# Binary-search ped-services-common merge commits on develop to find which merge broke a service build.
# Usage: ./dotnet-blame.sh <service-dir>
#   e.g. ./dotnet-blame.sh ped-services-270
# <service-dir> and ped-services-common must be siblings in the same parent directory.
# Env overrides: BRANCH (default: develop), BUILD_CONFIG (default: debug-combined)

set -uo pipefail

BRANCH="${BRANCH:-develop}"
BUILD_CONFIG="${BUILD_CONFIG:-debug-combined}"

if [ $# -ne 1 ]; then
    echo "Usage: $(basename "$0") <service-dir>"
    exit 1
fi

if [ ! -d "$1" ]; then
    echo "✗ ERROR: Directory not found: $1"
    exit 1
fi

SERVICE_DIR="$(cd "$1" && pwd)"
SERVICE_NAME="$(basename "$SERVICE_DIR")"
COMMON_DIR="$(dirname "$SERVICE_DIR")/ped-services-common"

if [ ! -d "$COMMON_DIR/.git" ]; then
    echo "✗ ERROR: ped-services-common not found as a sibling at: $COMMON_DIR"
    exit 1
fi

# Locate solution and props files
mapfile -t SOLUTIONS < <(find "$SERVICE_DIR" -type f -name "*-Combined*.sln" -not -path "*/bin/*" -not -path "*/obj/*" | sort)
if [ ${#SOLUTIONS[@]} -eq 0 ]; then
    echo "✗ ERROR: No *-Combined*.sln found under $SERVICE_DIR"
    exit 1
fi
SOLUTION="${SOLUTIONS[0]}"
[ ${#SOLUTIONS[@]} -gt 1 ] && echo "⚠ Multiple combined solutions found; using $SOLUTION"

PROPS_FILE="$(find "$SERVICE_DIR" -type f -name "Directory.Packages.props" -not -path "*/bin/*" -not -path "*/obj/*" | head -1)"
if [ -z "$PROPS_FILE" ]; then
    echo "✗ ERROR: Directory.Packages.props not found under $SERVICE_DIR"
    exit 1
fi

# Version looks like 4.0.0-443-d584045; take the trailing hash
BASE_HASH="$(grep -oE 'CommonLib"[[:space:]]+Version="[^"]*-[0-9a-f]{7,40}"' "$PROPS_FILE" \
    | head -1 | sed -E 's/.*-([0-9a-f]{7,40})"$/\1/')"
if [ -z "$BASE_HASH" ]; then
    echo "✗ ERROR: Could not find a CommonLib version ending in a commit hash in $PROPS_FILE"
    exit 1
fi

if ! BASE_SHA="$(git -C "$COMMON_DIR" rev-parse --verify --quiet "${BASE_HASH}^{commit}")"; then
    echo "✗ ERROR: Commit $BASE_HASH not found in ped-services-common (try 'git fetch')"
    exit 1
fi

if ! git -C "$COMMON_DIR" rev-parse --verify --quiet "$BRANCH" > /dev/null; then
    echo "✗ ERROR: Branch $BRANCH not found in ped-services-common"
    exit 1
fi

if ! git -C "$COMMON_DIR" merge-base --is-ancestor "$BASE_SHA" "$BRANCH"; then
    echo "✗ ERROR: $BASE_HASH is not an ancestor of $BRANCH in ped-services-common"
    exit 1
fi

if ! git -C "$COMMON_DIR" diff --quiet || ! git -C "$COMMON_DIR" diff --cached --quiet; then
    echo "✗ ERROR: ped-services-common has uncommitted changes. Commit or stash them first."
    exit 1
fi

# Merge commits on the branch, newest first, ending with the base commit (inclusive)
mapfile -t MERGES < <(git -C "$COMMON_DIR" rev-list --first-parent --merges "${BASE_SHA}..${BRANCH}")
MERGES+=("$BASE_SHA")
COUNT=${#MERGES[@]}

if [ "$COUNT" -lt 2 ]; then
    echo "Nothing to search: $BRANCH has no merges after $BASE_HASH"
    exit 0
fi

# Restore ped-services-common to where it was when we exit
ORIG_REF="$(git -C "$COMMON_DIR" symbolic-ref --quiet --short HEAD || git -C "$COMMON_DIR" rev-parse HEAD)"
restore_common() {
    echo ""
    echo "Restoring ped-services-common to $ORIG_REF"
    git -C "$COMMON_DIR" checkout --quiet "$ORIG_REF"
}
trap restore_common EXIT
trap 'exit 130' INT TERM

LOG_DIR="$(mktemp -d -t dotnet-blame-XXXXXX)"

describe() {
    git -C "$COMMON_DIR" log -1 --format='%h %ad %s' --date=short "$1"
}

# Returns 0 if the service builds against ped-services-common at the given commit
build_at() {
    local sha="$1"
    local log="$LOG_DIR/${sha:0:9}.log"
    echo "------------------------------------------"
    echo "Testing: $(describe "$sha")"
    if ! git -C "$COMMON_DIR" checkout --quiet --detach "$sha"; then
        echo "✗ ERROR: checkout of $sha failed"
        exit 1
    fi
    if dotnet build -c "$BUILD_CONFIG" "$SOLUTION" > "$log" 2>&1; then
        echo "✓ PASS"
        return 0
    fi
    echo "✗ FAIL (log: $log)"
    grep -E "error [A-Z]+[0-9]+" "$log" | sort -u | head -5 | sed 's/^/    /'
    return 1
}

echo "=========================================="
echo "Service:   $SERVICE_NAME"
echo "Solution:  $SOLUTION"
echo "Base:      $(describe "$BASE_SHA")"
echo "Head:      $(describe "${MERGES[0]}")"
echo "Merges:    $COUNT"
echo "Logs:      $LOG_DIR"
echo "=========================================="

# Index 0 = newest, COUNT-1 = oldest (base)
GOOD=$((COUNT - 1))
BAD=0

if build_at "${MERGES[0]}"; then
    echo ""
    echo "✓ $SERVICE_NAME builds against the newest merge on $BRANCH. Nothing to blame."
    exit 0
fi

if ! build_at "${MERGES[$GOOD]}"; then
    echo ""
    echo "✗ $SERVICE_NAME fails even against the base commit $BASE_HASH. The break is not in this merge range."
    exit 1
fi

while [ $((GOOD - BAD)) -gt 1 ]; do
    MID=$(( (GOOD + BAD) / 2 ))
    if build_at "${MERGES[$MID]}"; then
        GOOD=$MID
    else
        BAD=$MID
    fi
done

echo ""
echo "=========================================="
echo "Result"
echo "=========================================="
echo "✓ Last passing:  $(describe "${MERGES[$GOOD]}")"
echo "✗ First failing: $(describe "${MERGES[$BAD]}")"
echo ""
echo "Changes introduced by the failing merge:"
echo "  git -C \"$COMMON_DIR\" log --oneline ${MERGES[$GOOD]:0:9}..${MERGES[$BAD]:0:9}"
