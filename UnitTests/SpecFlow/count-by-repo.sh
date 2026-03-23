#!/bin/bash

# bash script for finding how many feature files are in each repo. Run from ~/source/repos
find . -type f -name '*.feature' | awk -F/ 'NF>2 {print }' | uniq -c | sort -n
