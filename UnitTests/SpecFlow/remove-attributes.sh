#!/bin/bash
# script for removing given, when, then:
TARGET_DIR="${1:-.}"

grep -RIlZ --exclude-dir=.git --exclude-dir=bin --exclude-dir=obj --exclude-dir=.vs --exclude-dir=TestResults -e '\[Scope' -e '\[Binding' -e '\[Given' -e '\[When' -e '\[Then' "$TARGET_DIR" | xargs -0 sed -i '/\[Scope\|\[Binding\|\[Given\|\[When\|\[Then/d'
