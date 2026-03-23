#!/bin/bash

# counts the number of specflow tests per file by counting the number of instances of the word 'scenario' per file

# Header row (optional)
printf "file\tscenario_count\n"

find . -type f -name "*.feature" -print0 |
while IFS= read -r -d '' file; do
  count=$(grep -oiw "scenario" "$file" | wc -l | tr -d ' ')
  printf "%s\t%s\n" "$file" "$count"
done
