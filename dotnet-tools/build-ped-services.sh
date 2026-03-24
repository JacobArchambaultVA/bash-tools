#!/bin/bash

# Script to clean and build all ped-services projects
# Usage: ./build-ped-services.sh

# Directory where the script is run from (should be the repos folder)
REPO_DIR="$(pwd)"

# Arrays to track results
declare -a PASSED_BUILDS
declare -a FAILED_BUILDS

echo "Starting builds in: $REPO_DIR"
echo ""

# Find all *-Combined*.sln files under ped-services-* directories
mapfile -t SOLUTION_FILES < <(find "$REPO_DIR" -type f -path "*/ped-services-*/*" -name "*-Combined*.sln" | sort)

if [ ${#SOLUTION_FILES[@]} -eq 0 ]; then
    echo "No matching solution files were found using pattern: *-Combined*.sln"
    exit 1
fi

echo "Found ${#SOLUTION_FILES[@]} solution file(s)"
echo ""

for solution_file in "${SOLUTION_FILES[@]}"; do
    # Determine owning repo directory (top-level folder under REPO_DIR)
    rel_path="${solution_file#$REPO_DIR/}"
    dir_name="${rel_path%%/*}"
    
    echo "=========================================="
    echo "Processing: $dir_name"
    echo "Solution: $solution_file"
    echo "=========================================="
    
    # Clean
    echo "Cleaning..."
    if ! dotnet clean -c debug-combined "$solution_file"; then
        echo "✗ ERROR: Clean failed for $dir_name"
        FAILED_BUILDS+=("$dir_name")
        echo ""
        continue
    fi
    
    # Build
    echo "Building with debug-combined configuration..."
    if ! dotnet build -c debug-combined "$solution_file"; then
        echo "✗ ERROR: Build failed for $dir_name"
        FAILED_BUILDS+=("$dir_name")
        echo ""
        continue
    fi
    
    echo "✓ $dir_name completed successfully"
    PASSED_BUILDS+=("$dir_name")
    echo ""
done

echo "=========================================="
echo "Build Summary"
echo "=========================================="
echo ""

if [ ${#PASSED_BUILDS[@]} -gt 0 ]; then
    echo "✓ PASSED (${#PASSED_BUILDS[@]}):"
    for build in "${PASSED_BUILDS[@]}"; do
        echo "  - $build"
    done
    echo ""
fi

if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    echo "✗ FAILED (${#FAILED_BUILDS[@]}):"
    for build in "${FAILED_BUILDS[@]}"; do
        echo "  - $build"
    done
    echo ""
fi

echo "=========================================="
echo "All builds completed"
echo "=========================================="
