#!/bin/bash

# Run a git command on all subdirectories in parallel
supergit() {
  local cmd="$*"
  local jobs="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 8)}"
  export cmd

  find . -mindepth 1 -maxdepth 1 -type d -print0 |
    xargs -0 -n1 -P "$jobs" -I{} bash -lc '
      echo "=== {} ==="
      cd "{}" && bash -lc "$cmd"
    '
}

